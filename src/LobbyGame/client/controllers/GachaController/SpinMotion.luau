--!strict
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

-- Authored values are captured on first touch so every animation settles back on them.
local _rest: { [Instance]: { [string]: any } } = setmetatable({}, { __mode = "k" }) :: any
local _tweens: { [Instance]: { [string]: Tween } } = setmetatable({}, { __mode = "k" }) :: any
local _shakes: { [GuiObject]: {} } = setmetatable({}, { __mode = "k" }) :: any
local _spinning: { [GuiObject]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local _random = Random.new()
local _quick = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local SpinMotion = {}

function SpinMotion.reduced(): boolean
	return GuiService.ReducedMotionEnabled
end

function SpinMotion.rest(target: Instance, property: string): any
	local values = _rest[target]
	if not values then
		values = {}
		_rest[target] = values
	end
	if values[property] == nil then
		values[property] = (target :: any)[property]
	end
	return values[property]
end

function SpinMotion.cancel(target: Instance, key: string): ()
	local list = _tweens[target]
	local tween = list and list[key]
	if tween then
		tween:Cancel()
	end
end

-- One tween per target and key; a newer animation on the same property replaces the older one.
function SpinMotion.play(target: Instance, key: string, info: TweenInfo, goals: { [string]: any }): Tween
	SpinMotion.cancel(target, key)
	local list = _tweens[target] or {}
	_tweens[target] = list
	local tween = TweenService:Create(target, info, goals)
	list[key] = tween
	tween.Completed:Once(function(): ()
		if list[key] == tween then
			list[key] = nil
		end
		tween:Destroy()
	end)
	tween:Play()
	return tween
end

function SpinMotion.scale(target: GuiObject): UIScale
	local existing = target:FindFirstChildOfClass("UIScale")
	if existing then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = "SpinMotionScale"
	scale.Parent = target
	return scale
end

function SpinMotion.pop(target: GuiObject, from: number, duration: number?, style: Enum.EasingStyle?): ()
	local scale = SpinMotion.scale(target)
	local rest: number = SpinMotion.rest(scale, "Scale")
	if SpinMotion.reduced() then
		SpinMotion.cancel(scale, "Scale")
		scale.Scale = rest
		return
	end
	scale.Scale = rest * from
	SpinMotion.play(
		scale,
		"Scale",
		TweenInfo.new(duration or 0.3, style or Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = rest }
	)
end

-- Moves from an offset back onto the authored position.
function SpinMotion.slideIn(target: GuiObject, from: UDim2, duration: number, delay: number?): ()
	local rest: UDim2 = SpinMotion.rest(target, "Position")
	if SpinMotion.reduced() then
		SpinMotion.cancel(target, "Position")
		target.Position = rest
		return
	end
	target.Position = rest + from
	SpinMotion.play(
		target,
		"Position",
		TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, false, delay or 0),
		{ Position = rest }
	)
end

function SpinMotion.slideOut(target: GuiObject, to: UDim2, duration: number): ()
	local rest: UDim2 = SpinMotion.rest(target, "Position")
	if SpinMotion.reduced() then
		return
	end
	SpinMotion.play(
		target,
		"Position",
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = rest + to }
	)
end

function SpinMotion.settle(target: GuiObject): ()
	SpinMotion.cancel(target, "Position")
	_shakes[target] = nil
	target.Position = SpinMotion.rest(target, "Position")
end

function SpinMotion.fadeIn(label: TextLabel, duration: number, delay: number?): ()
	local rest: number = SpinMotion.rest(label, "TextTransparency")
	if SpinMotion.reduced() then
		SpinMotion.cancel(label, "TextTransparency")
		label.TextTransparency = rest
		return
	end
	label.TextTransparency = 1
	SpinMotion.play(
		label,
		"TextTransparency",
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay or 0),
		{ TextTransparency = rest }
	)
end

-- Fades between the authored text alpha and a dimmed one, for selected/unselected labels.
function SpinMotion.dim(label: TextLabel, dimmed: boolean, transparency: number): ()
	local rest: number = SpinMotion.rest(label, "TextTransparency")
	local goal = if dimmed then transparency else rest
	if SpinMotion.reduced() then
		SpinMotion.cancel(label, "TextTransparency")
		label.TextTransparency = goal
		return
	end
	SpinMotion.play(
		label,
		"TextTransparency",
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextTransparency = goal }
	)
end

function SpinMotion.shake(target: GuiObject, strength: number, duration: number): ()
	if SpinMotion.reduced() then
		return
	end
	local rest: UDim2 = SpinMotion.rest(target, "Position")
	SpinMotion.cancel(target, "Position")
	local token = {}
	_shakes[target] = token
	task.spawn(function(): ()
		local start = os.clock()
		while _shakes[target] == token do
			local progress = (os.clock() - start) / duration
			if progress >= 1 then
				break
			end
			local amount = strength * (1 - progress)
			target.Position = rest
				+ UDim2.fromOffset(_random:NextNumber(-1, 1) * amount, _random:NextNumber(-1, 1) * amount * 0.6)
			task.wait(0.03)
		end
		if _shakes[target] == token then
			_shakes[target] = nil
			target.Position = rest
		end
	end)
end

-- A copy of a painted base's shape, invisible at rest. Without a parent it covers the base from
-- inside; with one it sits behind the base as its sibling.
function SpinMotion.layer(base: ImageLabel, name: string, parent: GuiObject?): ImageLabel
	local container: Instance = parent or base
	local existing = container:FindFirstChild(name)
	if existing then
		return existing :: ImageLabel
	end
	local layer = Instance.new("ImageLabel")
	layer.Name = name
	layer.BackgroundTransparency = 1
	layer.Image = base.Image
	layer.ScaleType = base.ScaleType
	layer.SliceCenter = base.SliceCenter
	layer.SliceScale = base.SliceScale
	layer.ImageTransparency = 1
	if parent then
		layer.AnchorPoint = base.AnchorPoint
		layer.Position = SpinMotion.rest(base, "Position")
		layer.Size = base.Size
		layer.ZIndex = base.ZIndex - 1
	else
		layer.AnchorPoint = Vector2.new(0.5, 0.5)
		layer.Position = UDim2.fromScale(0.5, 0.5)
		layer.Size = UDim2.fromScale(1, 1)
		layer.ZIndex = base.ZIndex
	end
	layer.Parent = container
	return layer
end

-- A white copy of a painted base brightens it briefly.
function SpinMotion.flash(base: ImageLabel, peak: number?, duration: number?): ()
	if SpinMotion.reduced() then
		return
	end
	local flash = SpinMotion.layer(base, "SpinFlash")
	flash.ImageTransparency = 1 - (peak or 0.5)
	SpinMotion.play(
		flash,
		"ImageTransparency",
		TweenInfo.new(duration or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ ImageTransparency = 1 }
	)
end

function SpinMotion.wiggle(icon: GuiObject, angle: number): ()
	local rest: number = SpinMotion.rest(icon, "Rotation")
	-- A hover after the click that started a spin must not replace the spin loop.
	if SpinMotion.reduced() or _spinning[icon] then
		return
	end
	icon.Rotation = rest + angle
	SpinMotion.play(
		icon,
		"Rotation",
		TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{ Rotation = rest }
	)
end

-- Keeps an icon turning while its action runs; stopping eases it back upright.
function SpinMotion.spinIcon(icon: GuiObject, spinning: boolean): ()
	local rest: number = SpinMotion.rest(icon, "Rotation")
	_spinning[icon] = nil
	if spinning and not SpinMotion.reduced() then
		_spinning[icon] = true
		icon.Rotation = rest
		local loop = SpinMotion.play(
			icon,
			"Rotation",
			TweenInfo.new(0.7, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
			{ Rotation = rest + 360 }
		)
		-- The loop has no natural end, so turning reduced motion on must stop it straight away.
		local preference: RBXScriptConnection
		preference = GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function(): ()
			if SpinMotion.reduced() and loop.PlaybackState == Enum.PlaybackState.Playing then
				SpinMotion.spinIcon(icon, false)
			end
		end)
		loop.Completed:Once(function(): ()
			preference:Disconnect()
		end)
		return
	end
	SpinMotion.cancel(icon, "Rotation")
	local turned = (icon.Rotation - rest) % 360
	if SpinMotion.reduced() or turned == 0 then
		icon.Rotation = rest
		return
	end
	-- Finish the turn forwards rather than unwinding it.
	icon.Rotation = rest + turned
	local tween = SpinMotion.play(
		icon,
		"Rotation",
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Rotation = if turned > 180 then rest + 360 else rest }
	)
	tween.Completed:Once(function(state: Enum.PlaybackState): ()
		if state == Enum.PlaybackState.Completed then
			icon.Rotation = rest
		end
	end)
end

type ButtonLook = {
	scale: number,
	lift: number,
	glow: number,
	shade: number,
	shadow: number,
	drop: number,
}

local _restLook: ButtonLook = { scale = 1, lift = 0, glow = 1, shade = 0, shadow = 1, drop = 0 }
local _hoverLook: ButtonLook = { scale = 1.05, lift = -3, glow = 0.8, shade = 0, shadow = 0.45, drop = 7 }
local _pressLook: ButtonLook = { scale = 0.93, lift = 1, glow = 1, shade = 0.2, shadow = 0.65, drop = 2 }
local _bounce = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- Hover lifts, brightens and casts a shadow; press squashes and darkens; release bounces and
-- flashes the painted base.
function SpinMotion.button(frame: GuiObject, hitBox: GuiButton, base: ImageLabel?, icon: GuiObject?): ()
	local scale = SpinMotion.scale(frame)
	local restScale: number = SpinMotion.rest(scale, "Scale")
	local restPosition: UDim2 = SpinMotion.rest(frame, "Position")
	-- The state change that follows a click must not cut the release bounce short.
	local bounceUntil = 0
	-- Disabling the gui leaves GuiState stuck on its last value, so the button rests until it changes.
	local stale = false
	local function look(): ButtonLook
		if stale or not hitBox.Active then
			return _restLook
		elseif hitBox.GuiState == Enum.GuiState.Hover then
			return _hoverLook
		elseif hitBox.GuiState == Enum.GuiState.Press then
			return _pressLook
		end
		return _restLook
	end
	local function goal(): number
		return if SpinMotion.reduced() then restScale else restScale * look().scale
	end
	local function update(): ()
		local current = look()
		-- Colour feedback stays under reduced motion; only the movement is dropped.
		local moving = if SpinMotion.reduced() then _restLook else current
		local scaleInfo = if os.clock() < bounceUntil then _bounce else _quick
		SpinMotion.play(scale, "Scale", scaleInfo, { Scale = restScale * moving.scale })
		SpinMotion.play(frame, "Position", _quick, { Position = restPosition + UDim2.fromOffset(0, moving.lift) })
		if not base then
			return
		end
		local restColor: Color3 = SpinMotion.rest(base, "ImageColor3")
		local glow = SpinMotion.layer(base, "SpinGlow")
		SpinMotion.play(glow, "ImageTransparency", _quick, { ImageTransparency = current.glow })
		SpinMotion.play(base, "ImageColor3", _quick, { ImageColor3 = restColor:Lerp(Color3.new(), current.shade) })
		local parent = base.Parent
		if parent and parent:IsA("GuiObject") then
			local shadow = SpinMotion.layer(base, "SpinShadow", parent)
			shadow.ImageColor3 = Color3.new()
			SpinMotion.play(shadow, "Shadow", _quick, {
				ImageTransparency = moving.shadow,
				Position = SpinMotion.rest(base, "Position") + UDim2.fromOffset(0, moving.drop),
			})
		end
	end
	local screenGui = hitBox:FindFirstAncestorOfClass("ScreenGui")
	if screenGui then
		screenGui:GetPropertyChangedSignal("Enabled"):Connect(function(): ()
			stale = true
			update()
		end)
	end
	hitBox:GetPropertyChangedSignal("GuiState"):Connect(function(): ()
		stale = false
		update()
		if icon and hitBox.GuiState == Enum.GuiState.Hover then
			SpinMotion.wiggle(icon, 14)
		end
	end)
	hitBox.Activated:Connect(function(): ()
		if SpinMotion.reduced() then
			return
		end
		bounceUntil = os.clock() + _bounce.Time
		scale.Scale = restScale * 1.15
		SpinMotion.play(scale, "Scale", _bounce, { Scale = goal() })
		if base then
			SpinMotion.flash(base, 0.5, 0.35)
		end
	end)
end

-- Recolours a label through its authored UIGradient, which is how SpinGui colours its white text.
function SpinMotion.tint(label: TextLabel, color: ColorSequence): ()
	local gradient = label:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = color
	end
end

-- Gives an authored button (a HitBox with an optional Base, and an ItemIcon when it wiggles) its
-- feedback, returning the hit box and icon.
function SpinMotion.bindButton(frame: GuiObject, withIcon: boolean?): (ImageButton, GuiObject?)
	local hitBox = frame:WaitForChild("HitBox") :: ImageButton
	local icon = if withIcon then frame:FindFirstChild("ItemIcon") :: GuiObject? else nil
	SpinMotion.button(frame, hitBox, frame:FindFirstChild("Base") :: ImageLabel?, icon)
	return hitBox, icon
end

return SpinMotion
