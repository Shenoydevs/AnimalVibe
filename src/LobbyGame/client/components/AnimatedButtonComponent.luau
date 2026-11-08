--!strict
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)

local _tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local AnimatedButtonComponent = Component.new({ Tag = "AnimatedButton" })

function AnimatedButtonComponent:_numberAttribute(name, fallback, minimum)
	local value = self.Instance:GetAttribute(name)
	if
		typeof(value) == "number"
		and value == value
		and math.abs(value) < math.huge
		and (minimum == nil or value >= minimum)
	then
		return value
	end
	return fallback
end

function AnimatedButtonComponent:_cancelTweens()
	for _, tween in self._tweens do
		tween:Cancel()
		tween:Destroy()
	end
	table.clear(self._tweens)
end

function AnimatedButtonComponent:_updateGlow(flash)
	local glow = self._glow
	local target = self._glowTarget
	local button = self._button
	if not glow then
		return
	end
	if self._glowTween then
		self._glowTween:Cancel()
		self._glowTween:Destroy()
		self._glowTween = nil
	end

	local color = self.Instance:GetAttribute("buttonGlowColor")
	if
		typeof(color) ~= "Color3"
		or not self._glowVisible
		or target.ImageTransparency >= 1
		or not button.Active
		or not button.Interactable
		or GuiService.ReducedMotionEnabled
	then
		self._glowFlashUntil = 0
		glow.Value = 0
		return
	end
	local strength = if button.GuiState == Enum.GuiState.Hover
		then 0.55
		elseif button.GuiState == Enum.GuiState.Press then 0.12
		else 0
	local now = os.clock()
	if flash then
		glow.Value = 0.85
		self._glowFlashUntil = now + 0.22
	elseif button.GuiState == Enum.GuiState.Press then
		self._glowFlashUntil = 0
	end
	local duration = if self._glowFlashUntil > now then self._glowFlashUntil - now else 0.15
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	self._glowTween = TweenService:Create(glow, info, { Value = strength })
	self._glowTween:Play()
end

function AnimatedButtonComponent:_watchGlowVisibility(button, target)
	local visibilityTrove = Trove.new()
	self._trove:Add(visibilityTrove)
	local function updateVisibility()
		local visible = target:IsDescendantOf(game)
		local ancestor: Instance? = button
		while ancestor do
			if
				(ancestor:IsA("GuiObject") and not ancestor.Visible)
				or (ancestor:IsA("LayerCollector") and not ancestor.Enabled)
			then
				visible = false
				break
			end
			ancestor = ancestor.Parent
		end
		self._glowVisible = visible
		self:_updateGlow()
	end
	local function bindVisibility()
		visibilityTrove:Clean()
		local ancestor: Instance? = button
		while ancestor do
			if ancestor:IsA("GuiObject") then
				visibilityTrove:Connect(ancestor:GetPropertyChangedSignal("Visible"), updateVisibility)
			elseif ancestor:IsA("LayerCollector") then
				visibilityTrove:Connect(ancestor:GetPropertyChangedSignal("Enabled"), updateVisibility)
			end
			ancestor = ancestor.Parent
		end
		updateVisibility()
	end
	self._trove:Connect(target.AncestryChanged, bindVisibility)
	bindVisibility()
end

function AnimatedButtonComponent:_createGlow()
	local button = self._button
	if self._glow or not button or typeof(self.Instance:GetAttribute("buttonGlowColor")) ~= "Color3" then
		return
	end
	local target = if self.Instance:IsA("GuiButton") then self.Instance else button.Parent
	if not target or not (target:IsA("ImageLabel") or target:IsA("ImageButton")) then
		return
	end

	local glow = Instance.new("NumberValue")
	self._trove:Add(glow)
	self._glow = glow
	self._glowTarget = target
	local imageColor = target.ImageColor3
	local gradient = target:FindFirstChildOfClass("UIGradient")
	local gradientColor = if gradient then gradient.Color else nil
	local function applyGlow()
		local color = self.Instance:GetAttribute("buttonGlowColor")
		local strength = if typeof(color) == "Color3" then glow.Value else 0
		if strength == 0 then
			target.ImageColor3 = imageColor
			if gradient then
				gradient.Color = gradientColor
			end
			return
		end
		-- PLAY's dark face is authored in its gradient; tinting its white ImageColor3 cannot brighten it.
		if gradient then
			local keypoints: { ColorSequenceKeypoint } = {}
			for _, keypoint in gradientColor.Keypoints do
				table.insert(keypoints, ColorSequenceKeypoint.new(keypoint.Time, keypoint.Value:Lerp(color, strength)))
			end
			gradient.Color = ColorSequence.new(keypoints)
		else
			target.ImageColor3 = imageColor:Lerp(color, strength)
		end
	end
	self._trove:Connect(glow:GetPropertyChangedSignal("Value"), applyGlow)
	self._trove:Connect(self.Instance:GetAttributeChangedSignal("buttonGlowColor"), applyGlow)
	self._trove:Connect(target:GetPropertyChangedSignal("ImageTransparency"), function()
		self:_updateGlow()
	end)
	self._trove:Add(function()
		target.ImageColor3 = imageColor
		if gradient then
			gradient.Color = gradientColor
		end
	end)

	self:_watchGlowVisibility(button, target)
end

function AnimatedButtonComponent:_update(revealDelay)
	local button = self._button
	local uiScale = self._uiScale

	self:_cancelTweens()
	local legacyMotion = self.Instance:GetAttribute("badgeMotion")
	local hoverOffset = self:_numberAttribute("buttonHoverOffset", if legacyMotion then -3 else 0)
	local pressOffset = self:_numberAttribute("buttonPressOffset", if legacyMotion then 1 else 0)
	if legacyMotion or hoverOffset ~= 0 or pressOffset ~= 0 then
		if not self._motionTarget then
			self._motionTarget = uiScale.Parent
			self._baselinePosition = self._motionTarget.Position
		end
	elseif self._motionTarget then
		self._motionTarget.Position = self._baselinePosition
		self._motionTarget = nil
	end
	local target = self._motionTarget
	if
		not button.Active
		or not button.Interactable
		or GuiService.ReducedMotionEnabled
		or (self._wrapper and not self._wrapper.Visible)
	then
		uiScale.Scale = self._baselineScale
		if target then
			target.Position = self._baselinePosition
		end
		return
	end

	local targetScale = self._baselineScale
	local lift = 0
	if button.GuiState == Enum.GuiState.Hover then
		targetScale *= self:_numberAttribute("buttonHoverScale", if legacyMotion then 1.065 else 1.035, 0)
		lift = hoverOffset
	elseif button.GuiState == Enum.GuiState.Press then
		targetScale *= self:_numberAttribute("buttonPressScale", if legacyMotion then 0.95 else 0.96, 0)
		lift = pressOffset
	end

	local info = _tweenInfo
	if revealDelay then
		-- The same owner drives reveal and input, so a new interaction cancels the reveal.
		uiScale.Scale = targetScale * self:_numberAttribute("buttonRevealScale", 0, 0)
		if target then
			target.Position = self._baselinePosition + UDim2.fromOffset(0, 10)
		end
		info = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, false, revealDelay)
	end
	if uiScale.Scale ~= targetScale then
		table.insert(self._tweens, TweenService:Create(uiScale, info, { Scale = targetScale }))
	end
	if target then
		local position = self._baselinePosition + UDim2.fromOffset(0, lift)
		if target.Position ~= position then
			table.insert(self._tweens, TweenService:Create(target, info, { Position = position }))
		end
	end
	for _, tween in self._tweens do
		tween:Play()
	end
end

function AnimatedButtonComponent:Construct()
	self._trove = Trove.new()
	self._baselineScale = 1
	self._tweens = {}
	self._baselinePosition = UDim2.new()
	self._glowVisible = false
	self._glowFlashUntil = 0

	local uiScale: UIScale? = self.Instance:FindFirstChildWhichIsA("UIScale", true)
	local button = if self.Instance:IsA("GuiButton")
		then self.Instance
		else self.Instance:FindFirstChild("Hitbox", true)
	if not uiScale or not button or not button:IsA("GuiButton") then
		warn(
			`[AnimatedButtonComponent] {self.Instance:GetFullName()} needs a UIScale and a GuiButton or descendant Hitbox GuiButton`
		)
		return
	end

	self._uiScale = uiScale
	self._button = button
	self._baselineScale = uiScale.Scale
	if self.Instance:GetAttribute("badgeMotion") then
		self._motionTarget = uiScale.Parent
		self._baselinePosition = self._motionTarget.Position
	end
	self._wrapper = self.Instance:FindFirstAncestor("Wrapper")
end

function AnimatedButtonComponent:Start()
	local button = self._button
	if not button then
		return
	end

	local function update()
		self:_update()
		self:_updateGlow()
	end
	local function updateGlowColor()
		self:_createGlow()
		self:_updateGlow()
	end
	self._trove:Connect(self.Instance:GetAttributeChangedSignal("buttonGlowColor"), updateGlowColor)
	self._trove:Connect(button.Activated, function()
		self:_updateGlow(true)
	end)
	updateGlowColor()
	for _, property in { "GuiState", "Active", "Interactable" } do
		self._trove:Connect(button:GetPropertyChangedSignal(property), update)
	end
	self._trove:Connect(GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"), update)
	for _, attribute in { "buttonHoverScale", "buttonPressScale", "buttonHoverOffset", "buttonPressOffset" } do
		self._trove:Connect(self.Instance:GetAttributeChangedSignal(attribute), update)
	end
	local wrapper = self._wrapper
	if wrapper then
		local function updateVisibility()
			local legacyDelay = if self.Instance:GetAttribute("badgeMotion")
				then self:_numberAttribute("badgeRevealDelay", nil, 0)
				else nil
			local revealDelay = self:_numberAttribute("buttonRevealDelay", legacyDelay, 0)
			self:_update(if wrapper.Visible then revealDelay else nil)
		end
		self._trove:Connect(wrapper:GetPropertyChangedSignal("Visible"), updateVisibility)
		updateVisibility()
	else
		self:_update()
	end
end

function AnimatedButtonComponent:Stop()
	if self._glowTween then
		self._glowTween:Cancel()
		self._glowTween:Destroy()
		self._glowTween = nil
	end
	self._trove:Clean()
	self._glow = nil
	self._glowTarget = nil
	self._glowFlashUntil = 0
	self:_cancelTweens()
	if self._uiScale then
		self._uiScale.Scale = self._baselineScale
	end
	if self._motionTarget then
		self._motionTarget.Position = self._baselinePosition
	end
end

return AnimatedButtonComponent
