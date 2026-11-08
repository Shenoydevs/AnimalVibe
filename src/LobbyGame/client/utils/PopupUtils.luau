--!strict
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Promise = require(ReplicatedStorage.Packages.promise)
local BackdropUtils = require(script.Parent.BackdropUtils)

local _tagHide = "HideOnPopup"
local _showInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local _hideInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local _effectIn = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local _effectOut = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local _fadeInInfo = TweenInfo.new(0.34, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local _fadeOutInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local _badgeInInfo = TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local _badgeMoveInInfo = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local _badgeOutInfo = TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local _shopInInfo = TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local _shopMoveInInfo = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local _shopOutInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local _reducedInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local _defaultFOV = 70
local _popupFOV = 50
local _blurSize = 24
local _white = Color3.new(1, 1, 1)
local _hiddenShine = Vector2.new(-1, 0)
local _passedShine = Vector2.new(1, 0)

local _guis = {}
local _camera = workspace.CurrentCamera
local _currentPopup = nil
local _transition = nil
local _activeTweens = {}
local _scope = Fusion.scoped(Fusion)

local _blurEffect = game:GetService("Lighting"):WaitForChild("Popup_BlurEffect")

local Private = {}
local Shared = {}

function Private._playEffects(tweenInfo, blur, fieldOfView)
	for _, tween in _activeTweens do
		tween:Cancel()
		tween:Destroy()
	end
	_activeTweens = {
		TweenService:Create(_blurEffect, tweenInfo, { Size = blur }),
		TweenService:Create(_camera, tweenInfo, { FieldOfView = fieldOfView }),
	}
	for _, tween in _activeTweens do
		tween:Play()
	end
end

function Private._releaseMotion(wrapper, motion)
	if not motion then
		return
	end
	for _, child in motion:GetChildren() do
		child.Parent = wrapper
	end
	motion.Visible = false
end

function Private._createWrapperTweens(wrapper, showing)
	local motion = wrapper:FindFirstChild("Motion")
	local scale = wrapper:FindFirstChildOfClass("UIScale")
	local reducedMotion = GuiService.ReducedMotionEnabled
	local badgeMotion = wrapper:GetAttribute("badgePopupMotion") == true
	local shopMotion = wrapper:GetAttribute("animalShopMotion") == true
	local fresh = not wrapper.Visible
	local tweens: { Tween } = {}

	-- Runtime Motion canvases scale and fade; other authored popups keep their slide.
	if motion then
		-- Composite only during motion; the authored hierarchy renders directly at rest.
		for _, child in wrapper:GetChildren() do
			if child ~= motion and child:IsA("GuiObject") then
				child.Parent = motion
			end
		end
		motion.Visible = true
		local info = if reducedMotion
			then _reducedInfo
			elseif badgeMotion then (if showing then _badgeInInfo else _badgeOutInfo)
			elseif shopMotion then (if showing then _shopInInfo else _shopOutInfo)
			elseif showing then _fadeInInfo
			else _fadeOutInfo
		local moveInfo = if showing and not reducedMotion
			then (if badgeMotion then _badgeMoveInInfo elseif shopMotion then _shopMoveInInfo else info)
			else info
		if fresh then
			wrapper.Position = UDim2.new(
				0.5,
				0,
				0.5,
				if reducedMotion then 0 elseif badgeMotion then 90 elseif shopMotion then 54 else 32
			)
			motion.GroupTransparency = 1
			scale.Scale = if reducedMotion then 1 elseif badgeMotion then 0.68 elseif shopMotion then 0.84 else 0.9
		end
		if reducedMotion then
			wrapper.Position = UDim2.fromScale(0.5, 0.5)
			scale.Scale = 1
		end
		table.insert(tweens, TweenService:Create(motion, info, { GroupTransparency = if showing then 0 else 1 }))
		table.insert(
			tweens,
			TweenService:Create(scale, moveInfo, {
				Scale = if showing or reducedMotion
					then 1
					elseif badgeMotion then 0.72
					elseif shopMotion then 0.92
					else 0.94,
			})
		)
		table.insert(
			tweens,
			TweenService:Create(wrapper, moveInfo, {
				Position = UDim2.new(
					0.5,
					0,
					0.5,
					if showing or reducedMotion then 0 elseif badgeMotion then 64 elseif shopMotion then 32 else 18
				),
			})
		)
		for _, group in motion:GetDescendants() do
			if not group:IsA("CanvasGroup") then
				continue
			end
			if fresh then
				group.GroupTransparency = 1
			end
			local delay = if showing and not reducedMotion then 0.04 else 0
			local groupInfo = TweenInfo.new(
				if reducedMotion then 0.08 else 0.14,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out,
				0,
				false,
				delay
			)
			table.insert(
				tweens,
				TweenService:Create(group, groupInfo, { GroupTransparency = if showing then 0 else 1 })
			)
		end
	else
		if fresh or reducedMotion then
			wrapper.Position = UDim2.fromScale(0.5, if reducedMotion then 0.5 else 1.5)
		end
		local info = if reducedMotion then TweenInfo.new(0) elseif showing then _showInfo else _hideInfo
		table.insert(
			tweens,
			TweenService:Create(wrapper, info, {
				Position = UDim2.fromScale(0.5, if showing or reducedMotion then 0.5 else 1.5),
			})
		)
	end
	wrapper.Visible = true
	return tweens, motion, scale
end

function Private._animateWrapper(wrapper, showing, onComplete)
	local tweens, motion, scale = Private._createWrapperTweens(wrapper, showing)
	return Promise.new(function(resolve, _, onCancel)
		local preferenceChanged: RBXScriptConnection? = nil
		local function finish(state)
			if state ~= Enum.PlaybackState.Completed then
				return
			end
			if preferenceChanged then
				preferenceChanged:Disconnect()
			end
			Private._releaseMotion(wrapper, motion)
			if onComplete then
				onComplete()
			end
			for _, tween in tweens do
				tween:Destroy()
			end
			resolve()
		end
		local completed = tweens[1].Completed:Once(finish)
		preferenceChanged = GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
			if not GuiService.ReducedMotionEnabled then
				return
			end
			-- Settle the current promise rather than replacing it and losing callers' andThen actions.
			completed:Disconnect()
			for _, tween in tweens do
				tween:Cancel()
			end
			wrapper.Position = UDim2.fromScale(0.5, 0.5)
			if motion then
				scale.Scale = 1
				motion.GroupTransparency = if showing then 0 else 1
				for _, group in motion:GetDescendants() do
					if group:IsA("CanvasGroup") then
						group.GroupTransparency = if showing then 0 else 1
					end
				end
			end
			finish(Enum.PlaybackState.Completed)
		end)
		onCancel(function()
			completed:Disconnect()
			if preferenceChanged then
				preferenceChanged:Disconnect()
			end
			for _, tween in tweens do
				tween:Cancel()
				tween:Destroy()
			end
			Private._releaseMotion(wrapper, motion)
		end)
		for _, tween in tweens do
			tween:Play()
		end
	end)
end

function Private._getEffectInfo(wrapper, showing)
	if GuiService.ReducedMotionEnabled then
		return _reducedInfo
	end
	if wrapper:GetAttribute("badgePopupMotion") then
		return if showing then _badgeInInfo else _badgeOutInfo
	end
	if wrapper:GetAttribute("animalShopMotion") and wrapper:FindFirstChild("Motion") then
		return if showing then _shopInInfo else _shopOutInfo
	end
	if wrapper:FindFirstChild("Motion") then
		return if showing then _fadeInInfo else _fadeOutInfo
	end
	return if showing then _effectIn else _effectOut
end

function Shared.ShowPopup(gui)
	local wrapper = gui.Wrapper
	if _transition then
		_transition:cancel()
	end
	if _currentPopup and _currentPopup ~= gui then
		_currentPopup.Wrapper.Visible = false
	end

	local effectInfo = Private._getEffectInfo(wrapper, true)
	Shared.HideAllGuis()
	BackdropUtils.Show(effectInfo)
	_currentPopup = gui
	_blurEffect.Enabled = true
	local fov = if GuiService.ReducedMotionEnabled then _defaultFOV else _popupFOV
	Private._playEffects(effectInfo, _blurSize, fov)
	_transition = Private._animateWrapper(wrapper, true, nil)
	return _transition
end

function Shared.HidePopup(gui)
	if gui ~= _currentPopup then
		return nil
	end
	local wrapper = gui.Wrapper
	if _transition then
		_transition:cancel()
	end

	local effectInfo = Private._getEffectInfo(wrapper, false)
	Private._playEffects(effectInfo, 0, _defaultFOV)
	BackdropUtils.Hide(nil, effectInfo)
	_transition = Private._animateWrapper(wrapper, false, function()
		_blurEffect.Enabled = false
		wrapper.Visible = false
		_currentPopup = nil
		Shared.ShowAllGuis()
	end)
	return _transition
end

function Shared.IsClick(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- Authored gradients are single-colour sequences; the highlight band sits outside at rest.
function Shared.ShineSequence(color: Color3): ColorSequence
	local highlight = color:Lerp(_white, 0.6)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.42, color),
		ColorSequenceKeypoint.new(0.5, highlight),
		ColorSequenceKeypoint.new(0.58, color),
		ColorSequenceKeypoint.new(1, color),
	})
end

-- Popup headers share one treatment: the title drops in and glints and the divider's highlights
-- slide into place on opening; the title has no action but bounces on hover, squashes on press
-- and wiggles with a glint on release. Returns a function that replays the glint.
function Shared.BindHeader(wrapper: Frame): (delay: number?) -> ()
	local elements = wrapper:WaitForChild("Elements")
	local title = elements:WaitForChild("TitleText") :: TextLabel
	local titleGradient = title:FindFirstChildOfClass("UIGradient") :: UIGradient
	local divider = elements:WaitForChild("DividerLine"):FindFirstChildOfClass("UIGradient") :: UIGradient
	local titleRest = { position = title.Position, transparency = title.TextTransparency }
	local dividerOffset = divider.Offset
	local reducedMotion = _scope:Value(GuiService.ReducedMotionEnabled)
	local hovered = _scope:Value(false)
	local pressed = _scope:Value(false)
	local tweens: { Tween } = {}

	local restRotation = title.Rotation
	local titleScale = Instance.new("UIScale")
	titleScale.Parent = title
	-- Fusion ignores velocity kicks on a constant spring goal, so the wiggle follows a state.
	local tilt = _scope:Spring(_scope:Value(restRotation), 22, 0.3)
	local scale = _scope:Spring(
		_scope:Computed(function(use): number
			if use(reducedMotion) then
				return 1
			end
			return if use(pressed) then 0.93 elseif use(hovered) then 1.06 else 1
		end),
		28,
		0.55
	)
	_scope:Hydrate(titleScale)({ Scale = scale })
	_scope:Hydrate(title)({ Rotation = tilt })
	titleGradient.Color = Shared.ShineSequence(titleGradient.Color.Keypoints[1].Value)
	titleGradient.Offset = _hiddenShine

	local function moving(): boolean
		return wrapper.Visible and not GuiService.ReducedMotionEnabled
	end
	local function play(target: Instance, info: TweenInfo, goals: { [string]: any })
		local tween = TweenService:Create(target, info, goals)
		table.insert(tweens, tween)
		tween:Play()
	end
	local function reset()
		for _, tween in tweens do
			tween:Cancel()
			tween:Destroy()
		end
		table.clear(tweens)
		scale:setPosition(1)
		scale:setVelocity(0)
		tilt:setPosition(restRotation)
		tilt:setVelocity(0)
		title.Position = titleRest.position
		title.TextTransparency = titleRest.transparency
		titleGradient.Offset = _hiddenShine
		divider.Offset = dividerOffset
	end
	local function glint(delay: number?)
		if not moving() then
			return
		end
		titleGradient.Offset = _hiddenShine
		play(
			titleGradient,
			TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, delay or 0),
			{ Offset = _passedShine }
		)
	end

	wrapper:GetPropertyChangedSignal("Visible"):Connect(function()
		reset()
		if not wrapper.Visible then
			hovered:set(false)
			pressed:set(false)
			return
		end
		if GuiService.ReducedMotionEnabled then
			return
		end
		title.Position = titleRest.position - UDim2.fromOffset(0, 16)
		title.TextTransparency = 1
		play(
			title,
			TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.06),
			{ Position = titleRest.position }
		)
		-- Back easing would overshoot transparency, so the fade eases separately.
		play(
			title,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.06),
			{ TextTransparency = titleRest.transparency }
		)
		divider.Offset = dividerOffset - Vector2.new(1, 0)
		play(
			divider,
			TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, false, 0.1),
			{ Offset = dividerOffset }
		)
		glint(0.35)
	end)
	GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
		reducedMotion:set(GuiService.ReducedMotionEnabled)
		reset()
	end)
	title.MouseEnter:Connect(function()
		hovered:set(true)
	end)
	title.MouseLeave:Connect(function()
		hovered:set(false)
		pressed:set(false)
	end)
	title.InputBegan:Connect(function(input: InputObject)
		if Shared.IsClick(input) then
			pressed:set(true)
		end
	end)
	title.InputEnded:Connect(function(input: InputObject)
		if not Fusion.peek(pressed) or not Shared.IsClick(input) then
			return
		end
		pressed:set(false)
		if input.UserInputType == Enum.UserInputType.Touch then
			hovered:set(false)
		end
		if moving() then
			tilt:addVelocity(if math.random() < 0.5 then -160 else 160)
			glint(0)
		end
	end)
	return glint
end

function Shared.GetCurrentPopup()
	return _currentPopup
end

function Shared.HideAllGuis()
	for _, gui in CollectionService:GetTagged(_tagHide) do
		if gui.Enabled then
			gui.Enabled = false
			_guis[gui] = true
		end
	end
end

function Shared.ShowAllGuis()
	for gui in _guis do
		gui.Enabled = true
	end
	_guis = {}
end

GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
	if GuiService.ReducedMotionEnabled and _currentPopup then
		local cameraTween = _activeTweens[2]
		if cameraTween then
			cameraTween:Cancel()
		end
		_camera.FieldOfView = _defaultFOV
	end
end)

return Shared
