--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage.Packages
local Fusion = require(Packages.Fusion)
local Networker = require(Packages.Networker)
local Promise = require(Packages.promise)
local Trove = require(Packages.Trove)
local WaitFor = require(Packages.WaitFor)

local CharacterUtils = require(ReplicatedStorage.Shared.utils.CharacterUtils)
local Throttle = require(ReplicatedStorage.Shared.utils.Throttle)
local Network = require(ReplicatedStorage.Shared.network.GameNetwork)

type NetworkerClient = Networker.Client

local DEGREES_PER_TICK = 15
local CIRCLE_TICKS = 24 -- 360 / DEGREES_PER_TICK; ticks beyond this are wrap-around buffer
local VISIBLE_TICKS = 6 -- angular window shown at once (6 * 15 = 90 degrees)
local SPAWN_POLL_INTERVAL = 0.5
local HEADING_SPRING_SPEED = 20
local HEADING_SPRING_DAMPING = 1
local DISTANCE_UPDATE_INTERVAL = 1 / 10
local METERS_LERP_RATE = 8

local POINT_FALLBACK_Y_SCALE = -0.013
local POINT_FALLBACK_WIDTH_SCALE = 0.0477
local POINT_FALLBACK_HEIGHT_SCALE = 1.219

local _trove = Trove.new()
local _scope = Fusion.scoped(Fusion)
local _headingGoal = _scope:Value(0)
local _headingSpring = _scope:Spring(_headingGoal, HEADING_SPRING_SPEED, HEADING_SPRING_DAMPING)
local _unwrappedHeading = 0
local _headingInitialized = false

local _networker: NetworkerClient
local _compass: GuiObject
local _inside: ScrollingFrame
local _ticks: { GuiObject } = {}
local _tickCount = 0
local _leftBuffer = 0
local _point: GuiObject
local _pointLabel: TextLabel
local _characterPng: ImageLabel
local _dayText: TextLabel
local _amtText: TextLabel

local _spawnPosition: Vector3? = nil
local _appliedDay = 0
local _lastExactHeading = -1
local _lastMeters = -1
local _displayedMeters = 0
local _distanceStep = Throttle.new(DISTANCE_UPDATE_INTERVAL)

local _tickPixelWidth = 0
local _slotPixelWidth = 0 
local _windowHalfWidth = 0
local _maxScroll = 0
local _geometryReady = false

local HudCompassController = {
	day = 1 :: number, -- mirrored from the server via Networker
}

local function _isTickName(name: string): boolean
	local n = tonumber(name)
	return n ~= nil and n >= 1 and n == math.floor(n)
end


local function _headingForTick(index: number): number
	return ((index - 1 - _leftBuffer) * DEGREES_PER_TICK) % 360
end

local function _centerPoint(point: GuiObject): ()
	if point.Parent == _compass then
		point.AnchorPoint = Vector2.new(0.5, 0.5)
		point.Position = UDim2.new(0.5, 0, point.Position.Y.Scale, point.Position.Y.Offset)
		return
	end

	local compassSize = _compass.AbsoluteSize
	local relY, relW, relH = POINT_FALLBACK_Y_SCALE, POINT_FALLBACK_WIDTH_SCALE, POINT_FALLBACK_HEIGHT_SCALE
	if compassSize.X > 0 and compassSize.Y > 0 and point.AbsoluteSize.X > 0 then
		local centerAbs = point.AbsolutePosition + point.AbsoluteSize / 2
		relY = (centerAbs.Y - _compass.AbsolutePosition.Y) / compassSize.Y
		relW = point.AbsoluteSize.X / compassSize.X
		relH = point.AbsoluteSize.Y / compassSize.Y
	end

	point.Parent = _compass
	point.AnchorPoint = Vector2.new(0.5, 0.5)
	point.Position = UDim2.fromScale(0.5, relY)
	point.Size = UDim2.fromScale(relW, relH)
end

local function _findPoint(): GuiObject?
	local onCompass = _compass:FindFirstChild("point")
	if onCompass and onCompass:IsA("GuiObject") then
		return onCompass
	end
	for _, tick in _ticks do
		local nested = tick:FindFirstChild("point")
		if nested and nested:IsA("GuiObject") then
			return nested
		end
	end
	local anywhere = _inside:FindFirstChild("point", true)
	return if anywhere and anywhere:IsA("GuiObject") then anywhere else nil
end

local function _resolveTicks()
	local ordered: { GuiObject } = {}
	for _, child in _inside:GetChildren() do
		if child:IsA("GuiObject") and _isTickName(child.Name) then
			table.insert(ordered, child)
		end
	end
	table.sort(ordered, function(a, b)
		return (tonumber(a.Name) :: number) < (tonumber(b.Name) :: number)
	end)

	_ticks = ordered
	_tickCount = #ordered
	_leftBuffer = math.floor((_tickCount - CIRCLE_TICKS) / 2)
	if _leftBuffer < 0 then
		_leftBuffer = 0
		warn(`[HudCompass] {_tickCount} tick frames found; need at least {CIRCLE_TICKS} for a seamless circle`)
	end

	local listLayout = _inside:FindFirstChildWhichIsA("UIListLayout")
	if listLayout and _ticks[1] then
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.FillDirection = Enum.FillDirection.Horizontal
		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		local padScale = 1 / VISIBLE_TICKS - _ticks[1].Size.X.Scale
		listLayout.Padding = UDim.new(math.max(padScale, 0), 0)
	end

	local point = _findPoint()
	if point then
		_centerPoint(point)
		_point = point
	end

	local labelPromises = table.create(_tickCount)
	for i, tick in ordered do
		tick.LayoutOrder = i
		labelPromises[i] = WaitFor.Child(tick, "cordinatesText")
	end

	return Promise.all(labelPromises)
		:andThen(function(labels: { TextLabel })
			for i, label in labels do
				label.Text = tostring(_headingForTick(i))
			end
			if not _point then
				return Promise.reject("[HudCompass] no 'point' marker found under the compass")
			end
			return WaitFor.Children(_point, { "cordinatesText", "waypointBG" })
		end)
		:andThen(function(pointChildren: { Instance })
			_pointLabel = pointChildren[1] :: TextLabel
			return WaitFor.Child(pointChildren[2], "characterPng")
		end)
		:andThen(function(characterPng: Instance)
			_characterPng = characterPng :: ImageLabel
		end)
end

local function _resolveUi()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	return WaitFor.Child(playerGui, "ScreenGui")
		:andThen(function(screenGui: Instance)
			return WaitFor.Child(screenGui, "HudCompass")
		end)
		:andThen(function(hudCompass: Instance)
			return WaitFor.Child(hudCompass, "Compass")
		end)
		:andThen(function(compassRoot: Instance)
			return WaitFor.Children(compassRoot, { "compass", "dayBg", "distanceBg" })
				:andThen(function(sections: { Instance })
					return Promise.all({
						WaitFor.Child(sections[1], "Inside"),
						WaitFor.Child(sections[2], "dayText"),
						WaitFor.Child(sections[3], "amtText"),
					}):andThen(function(resolved: { Instance })
						_compass = sections[1] :: GuiObject
						return resolved
					end)
				end)
		end)
		:andThen(function(resolved: { Instance })
			_inside = resolved[1] :: ScrollingFrame
			_inside.ScrollingEnabled = false 
			_inside.ClipsDescendants = true
			_dayText = resolved[2] :: TextLabel
			_amtText = resolved[3] :: TextLabel
			return _resolveTicks()
		end)
end


local function _cacheGeometry(): boolean
	if _geometryReady then
		return true
	end
	local first, second = _ticks[1], _ticks[2]
	if not first or not second then
		return false
	end
	local width = first.AbsoluteSize.X
	local slot = second.AbsolutePosition.X - first.AbsolutePosition.X
	if width <= 0 or slot <= 0 then
		return false -- layout hasn't resolved yet
	end
	_tickPixelWidth = width
	_slotPixelWidth = slot
	_windowHalfWidth = _inside.AbsoluteWindowSize.X / 2
	_maxScroll = _inside.AbsoluteCanvasSize.X - _inside.AbsoluteWindowSize.X
	_geometryReady = true
	return true
end

local function _updateCompass(): ()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local look = camera.CFrame.LookVector
	local rawHeading = math.deg(math.atan2(look.X, -look.Z)) % 360

	if not _headingInitialized then
		_headingInitialized = true
		_unwrappedHeading = rawHeading
		_headingGoal:set(rawHeading)
		_headingSpring:setPosition(rawHeading)
	end

	_unwrappedHeading += (rawHeading - _unwrappedHeading + 180) % 360 - 180
	_headingGoal:set(_unwrappedHeading)

	if not _cacheGeometry() then
		return
	end

	local heading = Fusion.peek(_headingSpring) % 360

	local center = (_leftBuffer + heading / DEGREES_PER_TICK) * _slotPixelWidth + _tickPixelWidth / 2
	local canvasX = center - _windowHalfWidth


	local span = CIRCLE_TICKS * _slotPixelWidth
	if _maxScroll >= span then
		local minSafe = (_maxScroll - span) / 2
		canvasX = minSafe + (canvasX - minSafe) % span
	end
	_inside.CanvasPosition = Vector2.new(canvasX, _inside.CanvasPosition.Y)

	local exactHeading = math.round(heading) % 360
	if exactHeading ~= _lastExactHeading then
		_lastExactHeading = exactHeading
		_pointLabel.Text = tostring(exactHeading)
	end
end

local function _updateDistance(dt: number): ()
	local spawnPosition = _spawnPosition
	local root = CharacterUtils.getPlayerRoot(Players.LocalPlayer)
	if not spawnPosition or not root then
		return
	end

	local dx = root.Position.X - spawnPosition.X
	local dz = root.Position.Z - spawnPosition.Z
	local targetMeters = math.sqrt(dx * dx + dz * dz)
	_displayedMeters += (targetMeters - _displayedMeters) * math.clamp(dt * METERS_LERP_RATE, 0, 1)

	local meters = math.round(_displayedMeters)
	if meters == _lastMeters then
		return
	end
	_lastMeters = meters
	_amtText.Text = `{meters}m`
end

local function _resolveSpawnPosition(): ()
	task.spawn(function()
		while not _spawnPosition do
			local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation")
			if spawnLocation then
				_spawnPosition = spawnLocation.Position
			else
				task.wait(SPAWN_POLL_INTERVAL)
			end
		end
	end)
end

local function _applyDay(day: number): ()
	if day <= _appliedDay then
		return
	end
	_appliedDay = day
	_dayText.Text = `Day {day}`
end

local function _loadCharacterThumbnail(): ()
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(
				Players.LocalPlayer.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end)
		if ok and image then
			_characterPng.Image = image
		end
	end)
end

function HudCompassController:OnStart(): ()
	_resolveUi()
		:andThen(function()
			_networker = Networker.client.new(Network.Hud, HudCompassController)
			_networker:getServerChangedSignal("day"):Connect(function()
				_applyDay(HudCompassController.day)
			end)
			task.spawn(function()
				local day: number? = _networker:fetch("getDay")
				if day then
					_applyDay(day)
				end
			end)

			_loadCharacterThumbnail()

			_trove:Connect(RunService.RenderStepped, function(dt: number)
				_updateCompass() -- continuous tape scroll; needs full framerate to look smooth

				local ready, elapsed = _distanceStep(dt)
				if ready then
					_updateDistance(elapsed)
				end
			end)
		end)
		:catch(warn)

	_resolveSpawnPosition()
end

export type HudCompassController = typeof(HudCompassController)
return HudCompassController
