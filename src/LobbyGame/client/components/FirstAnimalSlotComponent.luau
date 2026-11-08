local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Component = require(ReplicatedStorage.Packages.Component)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Trove = require(ReplicatedStorage.Packages.Trove)

local states = require(script.Parent.Parent.states)
local FirstAnimalState = states.FirstAnimalState

local _touchEnabled = UserInputService.TouchEnabled
local _dotsGlow = Color3.fromRGB(196, 214, 92)

local FirstAnimalSlotComponent = Component.new({ Tag = "FirstAnimalSlot" })

function FirstAnimalSlotComponent:Construct()
	self._scope = Fusion.scoped(Fusion)
	self._trove = Trove.new()
	self._selectButton = self.Instance.SelectButton
	self._labelButton = self._selectButton.Label
	self._stats = self.Instance.Stats
	self._wrapper = self.Instance:FindFirstAncestor("Wrapper")
	self._tweens = {}
	self._statTweens = {}
end

function FirstAnimalSlotComponent:Start()
	local scope = self._scope
	local slot = self.Instance
	local content = slot.Content
	local dots = slot.dots
	self._reducedMotion = scope:Value(GuiService.ReducedMotionEnabled)
	self._hovered = scope:Value(false)
	self._flash = scope:Value(false)
	local isSelected = scope:Computed(function(use)
		return use(FirstAnimalState.SelectedAnimal) == slot
	end)

	-- The slot sits in a list layout, so its full-size layers scale together instead of the slot.
	self._scale = scope:Spring(
		scope:Computed(function(use)
			if use(self._reducedMotion) then
				return 1
			end
			return if use(self._hovered) then 1.04 else 1
		end),
		26,
		0.55
	)
	for _, layer in { slot.slotBG, content, dots, self._stats } do
		local layerScale = Instance.new("UIScale")
		layerScale.Parent = layer
		scope:Hydrate(layerScale)({ Scale = self._scale })
	end
	-- The card lights through its dot pattern: brighter on hover, selection and a select flash.
	local dotsColor = dots.ImageColor3
	scope:Hydrate(dots)({
		ImageColor3 = scope:Tween(
			scope:Computed(function(use)
				if use(self._flash) then
					return _dotsGlow:Lerp(Color3.new(1, 1, 1), 0.4)
				end
				local glow = if use(isSelected) then 0.55 elseif use(self._hovered) then 0.3 else 0
				return dotsColor:Lerp(_dotsGlow, glow)
			end),
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		),
	})

	self._rest = {
		[content] = { Position = content.Position },
		[content.Icon] = { ImageTransparency = content.Icon.ImageTransparency },
		[content.DisplayName] = { TextTransparency = content.DisplayName.TextTransparency },
		[slot.slotBG] = { ImageTransparency = slot.slotBG.ImageTransparency },
		[dots] = { ImageTransparency = dots.ImageTransparency },
		[self._labelButton] = { TextTransparency = self._labelButton.TextTransparency },
	}
	self._statRest = { [self._stats.blur] = { ImageTransparency = self._stats.blur.ImageTransparency } }
	self._fills = {}
	for _, bar in self._stats.bars:GetChildren() do
		if bar:IsA("Frame") then
			local fill = bar.Background.Fill
			table.insert(self._fills, { fill = fill, size = fill.Size, order = bar.LayoutOrder })
			self._statRest[fill] = { Size = fill.Size }
			self._statRest[bar.BarName] = { TextTransparency = bar.BarName.TextTransparency }
			self._statRest[bar.BarProg] = { TextTransparency = bar.BarProg.TextTransparency }
		end
	end
	table.sort(self._fills, function(a, b)
		return a.order < b.order
	end)

	scope:Hydrate(self._labelButton)({
		Text = scope:Computed(function(use)
			return use(isSelected) and "SELECTED" or "SELECT"
		end),
	})
	scope:Observer(isSelected):onChange(function()
		self:_crossfadeLabel()
	end)

	self:_handleStatsInteraction()

	self._trove:Connect(self._selectButton.Activated, function()
		self:_onSelected()
	end)
	self._trove:Connect(GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"), function()
		self._reducedMotion:set(GuiService.ReducedMotionEnabled)
		self:_settle()
		self:_showStats(self._stats.Visible)
	end)
	if self._wrapper then
		self._trove:Connect(self._wrapper:GetPropertyChangedSignal("Visible"), function()
			self:_reveal()
		end)
		if self._wrapper.Visible then
			self:_reveal()
		end
	end
end

function FirstAnimalSlotComponent:Stop()
	self:_settle()
	self:_showStats(false)
	Fusion.doCleanup(self._scope)
	self._trove:Clean()
end

function FirstAnimalSlotComponent:_moving()
	return self._wrapper ~= nil and self._wrapper.Visible and not GuiService.ReducedMotionEnabled
end

function FirstAnimalSlotComponent:_play(list, target, info, goals)
	local tween = TweenService:Create(target, info, goals)
	table.insert(list, tween)
	tween:Play()
end

function FirstAnimalSlotComponent:_cancel(list)
	for _, tween in list do
		tween:Cancel()
		tween:Destroy()
	end
	table.clear(list)
end

function FirstAnimalSlotComponent:_settle()
	self:_cancel(self._tweens)
	self._scale:setPosition(1)
	self._scale:setVelocity(0)
	for target, properties in self._rest do
		for property, value in properties do
			target[property] = value
		end
	end
end

-- Slots rise and fade in one after another as the selector opens.
function FirstAnimalSlotComponent:_reveal()
	self:_settle()
	if not self:_moving() then
		self._hovered:set(false)
		self:_showStats(false)
		return
	end
	local delay = 0.1 + (self.Instance.LayoutOrder - 1) * 0.07
	local content = self.Instance.Content
	self._scale:setPosition(0.82)
	content.Position = self._rest[content].Position + UDim2.fromOffset(0, 18)
	self:_play(
		self._tweens,
		content,
		TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay),
		self._rest[content]
	)
	for target, properties in self._rest do
		if target ~= content and target ~= self._labelButton then
			for property in properties do
				target[property] = 1
			end
			self:_play(
				self._tweens,
				target,
				TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay),
				properties
			)
		end
	end
end

function FirstAnimalSlotComponent:_crossfadeLabel()
	local label = self._labelButton
	if not self:_moving() then
		return
	end
	label.TextTransparency = 1
	self:_play(
		self._tweens,
		label,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		self._rest[label]
	)
end

function FirstAnimalSlotComponent:_handleStatsInteraction()
	if _touchEnabled then
		self._trove:Connect(self.Instance.TouchTap, function()
			self:_showStats(not self._stats.Visible)
		end)
	else
		self._trove:Connect(self.Instance.MouseEnter, function()
			self._hovered:set(true)
			self:_showStats(true)
		end)

		self._trove:Connect(self.Instance.MouseLeave, function()
			self._hovered:set(false)
			self:_showStats(false)
		end)
	end
end

-- Stats fade in over the card with each bar filling in turn, rather than popping on.
function FirstAnimalSlotComponent:_showStats(visible)
	self:_cancel(self._statTweens)
	for target, properties in self._statRest do
		for property, value in properties do
			target[property] = value
		end
	end
	self._stats.Visible = visible
	if not visible or not self:_moving() then
		return
	end
	local blur = self._stats.blur
	blur.ImageTransparency = 1
	self:_play(
		self._statTweens,
		blur,
		TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		self._statRest[blur]
	)
	for index, entry in self._fills do
		local delay = 0.04 + (index - 1) * 0.05
		local bar = entry.fill.Parent.Parent
		entry.fill.Size = UDim2.new(0, 0, entry.size.Y.Scale, entry.size.Y.Offset)
		self:_play(
			self._statTweens,
			entry.fill,
			TweenInfo.new(0.36, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, false, delay),
			{ Size = entry.size }
		)
		for _, label in { bar.BarName, bar.BarProg } do
			label.TextTransparency = 1
			self:_play(
				self._statTweens,
				label,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay),
				self._statRest[label]
			)
		end
	end
end

function FirstAnimalSlotComponent:_onSelected()
	FirstAnimalState.SelectedAnimal:set(self.Instance)
	if not self:_moving() then
		return
	end
	-- Choosing an animal punches the card and flashes its pattern.
	self._scale:addVelocity(2.2)
	self._flash:set(true)
	task.delay(0.12, function()
		self._flash:set(false)
	end)
end

return FirstAnimalSlotComponent
