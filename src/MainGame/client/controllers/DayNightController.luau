--!strict
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Trove = require(Packages.Trove)

local CartConfig = require(ReplicatedStorage.Shared.config.CartConfig)
local DayNightConfig = require(ReplicatedStorage.Shared.config.DayNightConfig)
local DayNightNetwork = require(ReplicatedStorage.Shared.network.DayNightNetwork)
local CharacterUtils = require(ReplicatedStorage.Shared.utils.CharacterUtils)
local Throttle = require(ReplicatedStorage.Shared.utils.Throttle)

local _campfireController = require(script.Parent.CampfireController)
local NotificationController = require(script.Parent.NotificationController)

type NetworkerClient = Networker.Client
type Phase = DayNightNetwork.Phase

local CAMPFIRE_TAG = "Campfire"
local CART_TAG = "Cart"
local CART_LIGHT_ON_THRESHOLD = 0.05

local _trove = Trove.new()
local _transitionTrove = _trove:Extend()

local _instantInfo = TweenInfo.new(0)
local _transitionInfo = TweenInfo.new(
	DayNightConfig.transitionDuration,
	DayNightConfig.transitionEasingStyle,
	DayNightConfig.transitionEasingDirection
)

local _networker: NetworkerClient
local _phase: Phase = "Day"
local _phaseInitialized = false
local _darknessReadyAt = 0 -- os.clock() after which the outside-safezone darkness may build

local _colorCorrection: ColorCorrectionEffect
local _bloom: BloomEffect
local _atmosphere: Atmosphere
local _personalCorrection: ColorCorrectionEffect
local _overlay: ImageLabel

local _safezoneFactor = 1 -- 1 = lit / safe, 0 = fully exposed to the dark
local _campfireLightBases: { [PointLight]: { brightness: number, range: number } } = {}
local _campfireFireBases: { [Fire]: { size: number, heat: number } } = {}
local _cartModel: Model?
local _cartLight: PointLight?
local _cartLightBaseRange: number?
local _nightLight: Instance?
local _nightLightBases: { [Light]: number } = {}

local DayNightController = {}

local function _setNightLightEnabled(enabled: boolean, info: TweenInfo): ()
	local nightLight = _nightLight
	if not nightLight or not nightLight.Parent then
		return
	end

	local lights: { Light } = {}
	if nightLight:IsA("Light") then
		table.insert(lights, nightLight)
	end
	for _, descendant in nightLight:GetDescendants() do
		if descendant:IsA("Light") then
			table.insert(lights, descendant)
		end
	end

	if #lights == 0 then
		warn(`[DayNightController] {nightLight:GetFullName()} contains no Light instances to toggle`)
		return
	end

	for _, light in lights do
		local base = _nightLightBases[light]
		if not base then
			base = light.Brightness
			_nightLightBases[light] = base
		end
		if enabled then
			if not light.Enabled then
				light.Brightness = 0
				light.Enabled = true
			end
			local tween = TweenService:Create(light, info, { Brightness = base })
			_transitionTrove:Add(tween)
			tween:Play()
		else
			local tween = TweenService:Create(light, info, { Brightness = 0 })
			_transitionTrove:Add(tween)
			-- Disable only once fully faded; a cancelled fade (new phase) leaves the light to the next tween.
			tween.Completed:Connect(function(state: Enum.PlaybackState)
				if state == Enum.PlaybackState.Completed then
					light.Enabled = false
				end
			end)
			tween:Play()
		end
	end
end

local function _attachNightLight(character: Model): ()
	if _nightLight then
		_nightLight:Destroy()
		_nightLight = nil
	end
	table.clear(_nightLightBases)

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("NightLight", true)
	if not template then
		warn("[DayNightController] ReplicatedStorage.Assets is missing the NightLight asset")
		return
	end

	_nightLight = template:Clone()
	_nightLight.Name = "NightLight"
	_nightLight.Parent = character
	_setNightLightEnabled(_phase == "Night", _instantInfo)
end

local function _resolveOrCreate(name: string, create: () -> Instance): Instance
	local found = Lighting:FindFirstChild(name)
	if found then
		return found
	end
	local created = create()
	created.Name = name
	created.Parent = Lighting
	return created
end

local function _tweenLighting(phase: Phase, info: TweenInfo): ()
	local preset = if phase == "Night" then DayNightConfig.presets.Night else DayNightConfig.presets.Day
	local light = preset.lighting
	local color = preset.colorCorrection
	local atmos = preset.atmosphere
	local bloom = preset.bloom

	local tweens = {
		TweenService:Create(Lighting, info, {
			Brightness = light.Brightness,
			Ambient = light.Ambient,
			OutdoorAmbient = light.OutdoorAmbient,
			ExposureCompensation = light.ExposureCompensation,
		}),
		TweenService:Create(_colorCorrection, info, {
			Brightness = color.Brightness,
			Contrast = color.Contrast,
			Saturation = color.Saturation,
			TintColor = color.TintColor,
		}),
		TweenService:Create(_atmosphere, info, {
			Density = atmos.Density,
			Offset = atmos.Offset,
			Haze = atmos.Haze,
			Color = atmos.Color,
			Decay = atmos.Decay,
		}),
		TweenService:Create(_bloom, info, {
			Intensity = bloom.Intensity,
			Size = bloom.Size,
			Threshold = bloom.Threshold,
		}),
	}
	for _, tween in tweens do
		_transitionTrove:Add(tween)
		tween:Play()
	end
end

-- Sweeps the sun forward (never backwards through noon) to the phase's held clock. The server
-- stops writing ClockTime for transitionDuration, then resumes from the same value, so there's no snap.
local function _tweenClock(phase: Phase, info: TweenInfo): ()
	local target = if phase == "Night" then DayNightConfig.nightClockTime else DayNightConfig.daySunClockStart
	local from = Lighting.ClockTime
	local driver = Instance.new("NumberValue")
	driver.Value = from
	_transitionTrove:Add(driver)
	_transitionTrove:Connect(driver.Changed, function(value: number)
		Lighting.ClockTime = value % 24
	end)
	local tween = TweenService:Create(driver, info, { Value = from + (target - from) % 24 })
	_transitionTrove:Add(tween)
	tween:Play()
end

local function _cacheCampfire(model: Instance): ()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("PointLight") and not _campfireLightBases[descendant] then
			_campfireLightBases[descendant] = { brightness = descendant.Brightness, range = descendant.Range }
		elseif descendant:IsA("Fire") and not _campfireFireBases[descendant] then
			_campfireFireBases[descendant] = { size = descendant.Size, heat = descendant.Heat }
		end
	end
end

local function _tweenCampfires(night: boolean, info: TweenInfo, only: Instance?): ()
	local boost = DayNightConfig.campfireNightBoost
	for light, base in _campfireLightBases do
		if not light.Parent then
			_campfireLightBases[light] = nil
			continue
		end
		if only and not light:IsDescendantOf(only) then
			continue
		end
		local tween = TweenService:Create(light, info, {
			Brightness = if night then base.brightness * boost.brightnessMultiplier else base.brightness,
			Range = if night then base.range * boost.rangeMultiplier else base.range,
		})
		_transitionTrove:Add(tween)
		tween:Play()
	end
	for fire, base in _campfireFireBases do
		if not fire.Parent then
			_campfireFireBases[fire] = nil
			continue
		end
		if only and not fire:IsDescendantOf(only) then
			continue
		end
		local tween = TweenService:Create(fire, info, {
			Size = if night then base.size * boost.fireSizeMultiplier else base.size,
			Heat = if night then base.heat * boost.fireHeatMultiplier else base.heat,
		})
		_transitionTrove:Add(tween)
		tween:Play()
	end
end

local function _tweenCart(night: boolean, info: TweenInfo): ()
	local light = _cartLight
	if not light or not light.Parent then
		return
	end
	local base = _cartLightBaseRange
	if not base then
		base = light.Range -- the server's fuel tween only touches Brightness, so Range is ours to drive
		_cartLightBaseRange = base
	end
	local tween = TweenService:Create(light, info, {
		Range = if night then math.max(base, DayNightConfig.cartNightBoost.lightRange) else base,
	})
	_transitionTrove:Add(tween)
	tween:Play()
end

local function _resolveCart(model: Instance): ()
	if not model:IsA("Model") then
		return
	end
	if _cartModel == model and _cartLight and _cartLight.Parent then
		return -- already tracking this cart; re-capturing now would bank a boosted Range as the base
	end
	local lightHost: Instance = model:FindFirstChild("Light", true) or model
	local pointLight = lightHost:FindFirstChildWhichIsA("PointLight", true)
		or model:FindFirstChildWhichIsA("PointLight", true)
	if not pointLight then
		return
	end
	_cartModel = model
	_cartLight = pointLight
	_cartLightBaseRange = nil
	if _phase == "Night" then
		_tweenCart(true, _instantInfo)
	end
end

local function _refreshTaggedTargets(): ()
	for _, model in CollectionService:GetTagged(CAMPFIRE_TAG) do
		_cacheCampfire(model)
	end
	for _, model in CollectionService:GetTagged(CART_TAG) do
		_resolveCart(model)
	end
end

local function _applySafezoneVisual(factor: number): ()
	local exposure = 1 - factor
	local cfg = DayNightConfig.safezone
	_personalCorrection.Brightness = cfg.outsideColorCorrectionBrightness * exposure

	local alpha = 1 - (1 - cfg.outsideOverlayTransparency) * exposure
	if cfg.vignetteImage then
		_overlay.ImageTransparency = alpha
	else
		_overlay.BackgroundTransparency = alpha
	end
end

local function _isInSafezone(pos: Vector3): boolean
	local margin = DayNightConfig.safezone.margin

	for _, zone in _campfireController:getZones() do
		local dx = pos.X - zone.position.X
		local dz = pos.Z - zone.position.Z
		local reach = zone.radius + margin
		if math.abs(pos.Y - zone.position.Y) <= zone.halfHeight and dx * dx + dz * dz <= reach * reach then
			return true
		end
	end

	local model = _cartModel
	local light = _cartLight
	if model and model.Parent and light and light.Enabled and light.Brightness > CART_LIGHT_ON_THRESHOLD then
		local cartPos = model:GetPivot().Position
		local dx = pos.X - cartPos.X
		local dz = pos.Z - cartPos.Z
		local reach = CartConfig.lightRadius + margin
		if dx * dx + dz * dz <= reach * reach then
			return true
		end
	end

	return false
end

local function _evaluateSafezone(dt: number): ()
	local target = 1
	if _phase == "Night" and os.clock() >= _darknessReadyAt then
		local root = CharacterUtils.getPlayerRoot(Players.LocalPlayer)
		target = if root and _isInSafezone(root.Position) then 1 else 0
	end
	_safezoneFactor += (target - _safezoneFactor) * math.clamp(dt * DayNightConfig.safezone.factorLerpRate, 0, 1)
	_applySafezoneVisual(_safezoneFactor)
end

local function _setPhase(phase: Phase, info: TweenInfo): ()
	local night = phase == "Night"
	local instant = info.Time <= 0
	_phase = phase
	_transitionTrove:Clean()
	_refreshTaggedTargets()
	_setNightLightEnabled(night, info)

	_tweenLighting(phase, info)
	_tweenCampfires(night, info)
	_tweenCart(night, info)
	-- On an instant sync the server's replicated ClockTime is already correct.
	if not instant then
		_tweenClock(phase, info)
	end

	-- Personal darkness waits for the global fade, then builds through factorLerpRate.
	_darknessReadyAt = os.clock() + info.Time
	if instant and not night then
		_safezoneFactor = 1
		_applySafezoneVisual(_safezoneFactor)
	end
end

local function _buildOverlay(): ()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DayNightOverlay"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = -5 -- behind the HUD, in front of the 3D view
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local overlay = Instance.new("ImageLabel")
	overlay.Name = "Vignette"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Image = DayNightConfig.safezone.vignetteImage or ""
	overlay.ImageColor3 = Color3.new(0, 0, 0)
	overlay.ImageTransparency = 1
	overlay.ScaleType = Enum.ScaleType.Stretch
	overlay.Active = false
	overlay.Parent = screenGui

	screenGui.Parent = playerGui
	_overlay = overlay
	_trove:Add(screenGui)
end

function DayNightController:onNightWarning(): ()
	NotificationController:push(
		DayNightConfig.nightApproachMessage,
		DayNightConfig.notificationDuration,
		NotificationController.PRIORITY_MED,
		"Alert"
	)
end

function DayNightController:onPhaseChange(phase: Phase): ()
	_phaseInitialized = true
	if phase == "Day" then
		NotificationController:push(
			DayNightConfig.dawnMessage,
			DayNightConfig.notificationDuration,
			NotificationController.PRIORITY_LOW,
			"Info"
		)
	end
	_setPhase(phase, _transitionInfo)
end

function DayNightController:OnStart(): ()
	_colorCorrection = _resolveOrCreate("ColorCorrection", function()
		return Instance.new("ColorCorrectionEffect")
	end) :: ColorCorrectionEffect
	_bloom = _resolveOrCreate("Bloom", function()
		return Instance.new("BloomEffect")
	end) :: BloomEffect
	_atmosphere = _resolveOrCreate("Atmosphere", function()
		return Instance.new("Atmosphere")
	end) :: Atmosphere
	_personalCorrection = _resolveOrCreate("DayNightPersonal", function()
		return Instance.new("ColorCorrectionEffect")
	end) :: ColorCorrectionEffect
	_personalCorrection.Enabled = true
	_personalCorrection.Brightness = 0

	_buildOverlay()

	local localPlayer = Players.LocalPlayer
	if localPlayer.Character then
		_attachNightLight(localPlayer.Character)
	end
	_trove:Connect(localPlayer.CharacterAdded, _attachNightLight)
	_trove:Connect(localPlayer.CharacterRemoving, function(character: Model)
		if _nightLight and _nightLight:IsDescendantOf(character) then
			_nightLight:Destroy()
			_nightLight = nil
		end
	end)

	for _, model in CollectionService:GetTagged(CAMPFIRE_TAG) do
		_cacheCampfire(model)
	end
	_trove:Connect(CollectionService:GetInstanceAddedSignal(CAMPFIRE_TAG), function(model: Instance)
		_cacheCampfire(model)
		if _phase == "Night" then
			-- Only the new fire snaps; the rest may be mid-transition.
			_tweenCampfires(true, _instantInfo, model)
		end
	end)

	for _, model in CollectionService:GetTagged(CART_TAG) do
		_resolveCart(model)
	end
	_trove:Connect(CollectionService:GetInstanceAddedSignal(CART_TAG), _resolveCart)

	_networker = Networker.client.new(DayNightNetwork.DayNight, DayNightController)
	task.spawn(function()
		local phase: Phase? = _networker:fetch("getPhase")
		if not _phaseInitialized then
			_setPhase(phase or "Day", _instantInfo)
		end
	end)

	local safezoneStep = Throttle.new(DayNightConfig.safezone.checkInterval)
	_trove:Connect(RunService.RenderStepped, function(dt: number)
		local ready, elapsed = safezoneStep(dt)
		if ready then
			_evaluateSafezone(elapsed)
		end
	end)
end

export type DayNightController = typeof(DayNightController)
return DayNightController
