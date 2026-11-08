--!strict
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Networker = require(ReplicatedStorage.Packages.Networker)

local Network = require(ReplicatedStorage.Shared.network)
local PopupUtils = require(script.Parent.Parent.utils.PopupUtils)

type Tone = "neutral" | "success" | "error"

local _white = Color3.new(1, 1, 1)
local _toneColors: { [Tone]: Color3 } = {
	neutral = _white,
	success = Color3.fromRGB(176, 238, 140),
	error = Color3.fromRGB(255, 150, 130),
}
local _flashColors: { [Tone]: Color3 } = {
	neutral = _white,
	success = Color3.fromRGB(236, 255, 200),
	error = Color3.fromRGB(255, 196, 186),
}
local _colorTween = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local _hiddenShine = Vector2.new(-1, 0)
local _passedShine = Vector2.new(1, 0)
local _springSpeed = 28
local _springDamping = 0.55
local _revealScale = 0.82

local _scope = Fusion.scoped(Fusion)

type Spring = typeof(_scope:Spring(0))
type Use = <T>(target: Fusion.UsedAs<T>) -> T

local _reducedMotion = _scope:Value(GuiService.ReducedMotionEnabled)
local _colorInfo = _scope:Computed(function(use): TweenInfo
	return if use(_reducedMotion) then TweenInfo.new(0) else _colorTween
end)
local _tone = _scope:Value("neutral" :: Tone)
local _flash = _scope:Value(nil :: Tone?)
local _busy = _scope:Value(false)
local _boxHovered = _scope:Value(false)
local _focused = _scope:Value(false)
local _boxScale: Spring
local _shake: Spring
local _tweens: { Tween } = {}
local _rest: { [Instance]: { [string]: any } } = {}

local _networker
local _wrapper: Frame
local _input: TextBox
local _description: TextLabel
local _descriptionScale: UIScale
local _glintTitle: (delay: number?) -> ()
local _redeemGradient: UIGradient
local _redeeming = false

local Private = {}
local Shared = {}

function Private._info(duration: number, style: Enum.EasingStyle, delay: number?): TweenInfo
	return TweenInfo.new(duration, style, Enum.EasingDirection.Out, 0, false, delay or 0)
end

function Private._tween(target: Instance, info: TweenInfo, goals: { [string]: any }): ()
	local tween = TweenService:Create(target, info, goals)
	table.insert(_tweens, tween)
	tween.Completed:Once(function(state: Enum.PlaybackState): ()
		if state ~= Enum.PlaybackState.Completed then
			return
		end
		local index = table.find(_tweens, tween)
		if index then
			table.remove(_tweens, index)
		end
		tween:Destroy()
	end)
	tween:Play()
end

function Private._settle(): ()
	for _, tween in _tweens do
		tween:Cancel()
		tween:Destroy()
	end
	table.clear(_tweens)
	_boxScale:setPosition(1)
	_boxScale:setVelocity(0)
	_shake:setPosition(0)
	_shake:setVelocity(0)
	for target, properties in _rest do
		for property, value in properties do
			(target :: any)[property] = value
		end
	end
end

function Private._moving(): boolean
	return _wrapper.Visible and not GuiService.ReducedMotionEnabled
end

-- Springs that stay put at rest; reduced motion pins them to their authored value.
function Private._spring(goal: (Use) -> number, speed: number?, damping: number?): Spring
	return _scope:Spring(
		_scope:Computed(function(use): number
			return goal(use)
		end),
		speed or _springSpeed,
		damping or _springDamping
	)
end

function Private._sweep(gradient: UIGradient, duration: number): ()
	if not Private._moving() then
		return
	end
	gradient.Offset = _hiddenShine
	Private._tween(
		gradient,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Offset = _passedShine }
	)
end

function Private._pop(scale: UIScale, from: number): ()
	if not Private._moving() then
		scale.Scale = 1
		return
	end
	scale.Scale = from
	Private._tween(scale, Private._info(0.28, Enum.EasingStyle.Back), { Scale = 1 })
end

function Private._setStatus(text: string, tone: Tone): ()
	_description.Text = text
	_tone:set(tone)
	if tone == "neutral" or not Private._moving() then
		return
	end
	_flash:set(tone)
	task.delay(0.12, function(): ()
		if Fusion.peek(_flash) == tone then
			_flash:set(nil)
		end
	end)
	if tone == "success" then
		_boxScale:addVelocity(2.5)
		Private._sweep(_redeemGradient, 0.6)
		_glintTitle(0)
	else
		_shake:addVelocity(420)
	end
end

function Private._redeem()
	if _redeeming then
		return
	end

	local rawText = _input.Text
	_redeeming = true
	_busy:set(true)
	Private._setStatus("Redeeming code...", "neutral")

	local success, result = pcall(_networker.fetch, _networker, "_redeem", rawText)
	_redeeming = false
	_busy:set(false)

	if not success then
		Private._setStatus("Couldn't confirm redemption. Please try again.", "error")
		return
	end

	if result.status == "redeemed" then
		Private._setStatus(`Redeemed!`, "success")
	elseif result.status == "invalid" then
		Private._setStatus("Invalid code. Check spelling and case.", "error")
	elseif result.status == "alreadyRedeemed" then
		Private._setStatus("You already redeemed this code.", "error")
	elseif result.status == "notReady" then
		Private._setStatus("Your data is loading. Try again shortly.", "error")
	elseif result.status == "rateLimited" then
		Private._setStatus("Please wait a moment before trying again.", "error")
	end
end

function Private._bindBox(box: ImageLabel): ()
	local restColor = box.ImageColor3
	local restPosition = box.Position
	local boxScale = Instance.new("UIScale")
	boxScale.Parent = box
	_boxScale = Private._spring(function(use): number
		if use(_reducedMotion) then
			return 1
		end
		return if use(_focused) then 1.04 elseif use(_boxHovered) then 1.025 else 1
	end)
	-- A loose spring turns one velocity kick into a short side-to-side shake.
	_shake = Private._spring(function(): number
		return 0
	end, 34, 0.22)
	_scope:Hydrate(boxScale)({ Scale = _boxScale })
	_scope:Hydrate(box)({
		Position = _scope:Computed(function(use): UDim2
			return restPosition + UDim2.fromOffset(use(_shake), 0)
		end),
		ImageColor3 = _scope:Tween(
			_scope:Computed(function(use): Color3
				local flash: Tone? = use(_flash)
				if flash then
					return _flashColors[flash]
				end
				return if use(_focused)
					then restColor:Lerp(_white, 0.4)
					elseif use(_boxHovered) then restColor:Lerp(_white, 0.2)
					else restColor
			end),
			_colorInfo
		),
	})

	box.MouseEnter:Connect(function(): ()
		_boxHovered:set(true)
	end)
	box.MouseLeave:Connect(function(): ()
		_boxHovered:set(false)
	end)
	-- The painted field is larger than its TextBox, so clicking anywhere on it starts typing.
	box.InputBegan:Connect(function(input: InputObject): ()
		if PopupUtils.IsClick(input) and not _input:IsFocused() then
			_input:CaptureFocus()
		end
	end)
	_input.Focused:Connect(function(): ()
		_focused:set(true)
	end)
	_input.FocusLost:Connect(function(enterPressed: boolean): ()
		_focused:set(false)
		if enterPressed then
			Private._redeem()
		end
	end)
	_input:GetPropertyChangedSignal("Text"):Connect(function(): ()
		if _input:IsFocused() and Private._moving() then
			_boxScale:addVelocity(1.4)
		end
	end)
end

function Private._reveal(): ()
	Private._settle()
	if not _wrapper.Visible then
		_boxHovered:set(false)
		return
	end
	if GuiService.ReducedMotionEnabled then
		return
	end
	_description.Position = _rest[_description].Position + UDim2.fromOffset(0, 10)
	_description.TextTransparency = 1
	Private._tween(
		_description,
		Private._info(0.28, Enum.EasingStyle.Quart, 0.12),
		{ Position = _rest[_description].Position, TextTransparency = _rest[_description].TextTransparency }
	)
	-- The field springs up from the same scale as RedeemBTN's authored buttonRevealScale,
	-- so the two arrive alike.
	_boxScale:setPosition(_revealScale)
end

function Private._bindGui()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local gui = playerGui:WaitForChild("CodeGui") :: ScreenGui
	_wrapper = gui:WaitForChild("Wrapper") :: Frame
	local wrapper = _wrapper

	local content = wrapper:WaitForChild("Content")
	local elements = wrapper:WaitForChild("Elements")
	local box = content:WaitForChild("CodesBase") :: ImageLabel
	_description = content:WaitForChild("CodesDesc") :: TextLabel
	_input = box:WaitForChild("SearchPlayer") :: TextBox

	local closeButton = elements:WaitForChild("CloseBTN") :: ImageButton
	local redeemButton = content:WaitForChild("RedeemBTN") :: Frame
	local redeemHitbox = redeemButton:WaitForChild("Hitbox") :: ImageButton
	local redeemLabel = redeemButton:WaitForChild("BTNTilte") :: TextLabel
	_redeemGradient = redeemButton:FindFirstChildOfClass("UIGradient") :: UIGradient
	_rest[_description] = { Position = _description.Position, TextTransparency = _description.TextTransparency }
	_rest[_redeemGradient] = { Offset = _hiddenShine }

	_descriptionScale = Instance.new("UIScale")
	_descriptionScale.Parent = _description
	_rest[_descriptionScale] = { Scale = 1 }
	_scope:Hydrate(_description)({
		TextColor3 = _scope:Tween(
			_scope:Computed(function(use): Color3
				return _toneColors[use(_tone)]
			end),
			_colorInfo
		),
	})
	_description:GetPropertyChangedSignal("Text"):Connect(function(): ()
		Private._pop(_descriptionScale, if Fusion.peek(_tone) == "neutral" then 0.94 else 0.86)
	end)
	_scope:Hydrate(_redeemGradient)({ Color = PopupUtils.ShineSequence(_redeemGradient.Color.Keypoints[1].Value) })
	_redeemGradient.Offset = _hiddenShine
	-- The label dims while a redemption is in flight.
	local labelTransparency = redeemLabel.TextTransparency
	_scope:Hydrate(redeemLabel)({
		TextTransparency = _scope:Tween(
			_scope:Computed(function(use): number
				return if use(_busy) then 0.45 else labelTransparency
			end),
			_colorInfo
		),
	})

	Private._bindBox(box)
	_glintTitle = PopupUtils.BindHeader(wrapper)

	wrapper:GetPropertyChangedSignal("Visible"):Connect(function(): ()
		Private._reveal()
	end)
	GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function(): ()
		_reducedMotion:set(GuiService.ReducedMotionEnabled)
		Private._settle()
	end)
	closeButton.Activated:Connect(function()
		PopupUtils.HidePopup(gui)
	end)
	redeemHitbox.Activated:Connect(Private._redeem)

	local menuGui = playerGui:WaitForChild("CodeMenuGui") :: ScreenGui
	menuGui:WaitForChild("OpenCodes").Activated:Connect(function()
		if _redeeming then
			Private._setStatus("Redeeming code...", "neutral")
		else
			Private._setStatus("Codes are case-sensitive. Enter your code exactly.", "neutral")
		end
		PopupUtils.ShowPopup(gui)
	end)
	menuGui.Enabled = true
	if PopupUtils.GetCurrentPopup() then
		PopupUtils.HideAllGuis()
	end
end

function Shared.OnStart()
	_networker = Networker.client.new(Network.Codes, {})
	Private._bindGui()
end

return Shared
