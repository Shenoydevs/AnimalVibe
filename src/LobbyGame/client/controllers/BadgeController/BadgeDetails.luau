--!strict
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local BadgeConfig = require(ReplicatedStorage.Common.config.BadgeConfig)
local BadgeNetwork = require(script.Parent.Parent.Parent.network.BadgeNetwork)
local BadgeState = require(script.Parent.Parent.Parent.states.BadgeState)
local BadgeIcon = require(script.Parent.BadgeIcon)
local PopupUtils = require(script.Parent.Parent.Parent.utils.PopupUtils)

type Scope = typeof(Fusion.scoped(Fusion))

local Private = {}
local Shared = {}

function Private._equip()
	local badgeId = Fusion.peek(BadgeState.selectedId)
	if not Fusion.peek(BadgeState.earned)[badgeId] then
		return
	end

	BadgeNetwork.equip(if Fusion.peek(BadgeState.equippedId) == badgeId then "" else badgeId)
end

function Private._bindSelection(scope: Scope, wrapper: Frame, top: Frame)
	local nameLabel = top:WaitForChild("NameLabel") :: TextLabel
	local description = top:WaitForChild("DescriptionText") :: TextLabel
	local iconFrame = top:WaitForChild("IconFrame") :: Frame
	local iconScale = iconFrame:WaitForChild("UIScale") :: UIScale
	local reducedMotion = scope:Value(GuiService.ReducedMotionEnabled)
	local hovered = scope:Value(false)
	local pressed = scope:Value(false)
	local flash = scope:Value(0)
	local selectionTweens: { Tween } = {}
	local labelRest = {
		[nameLabel] = { position = nameLabel.Position, transparency = nameLabel.TextTransparency },
		[description] = { position = description.Position, transparency = description.TextTransparency },
	}
	-- One spring drives the icon's whole scale, so hover, press and selection pops blend.
	local iconSpring = scope:Spring(
		scope:Computed(function(use): number
			if use(reducedMotion) then
				return 1
			end
			return if use(pressed) then 0.93 elseif use(hovered) then 1.06 else 1
		end),
		24,
		0.5
	)
	local tilt = scope:Spring(scope:Value(0), 22, 0.3)
	scope:Hydrate(iconScale)({ Scale = iconSpring })
	scope:Hydrate(iconFrame)({ Rotation = tilt })

	local function moving(): boolean
		return wrapper.Visible and not GuiService.ReducedMotionEnabled
	end
	local function wobble(kick: number)
		tilt:addVelocity(if math.random() < 0.5 then -kick else kick)
	end
	local function flashIcon()
		flash:set(0.85)
		task.delay(0.12, function()
			flash:set(0)
		end)
	end
	local function resetSelectionMotion()
		for _, tween in selectionTweens do
			tween:Cancel()
			tween:Destroy()
		end
		table.clear(selectionTweens)
		iconSpring:setPosition(1)
		iconSpring:setVelocity(0)
		tilt:setPosition(0)
		tilt:setVelocity(0)
		for label, rest in labelRest do
			label.Position = rest.position
			label.TextTransparency = rest.transparency
		end
	end
	local function playSelectionMotion()
		resetSelectionMotion()
		if not moving() then
			return
		end
		iconSpring:setPosition(0.68)
		wobble(90)
		for label, rest in labelRest do
			label.Position = rest.position - UDim2.fromOffset(28, 0)
			label.TextTransparency = 1
			local info = TweenInfo.new(
				0.28,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out,
				0,
				false,
				if label == description then 0.04 else 0
			)
			table.insert(
				selectionTweens,
				TweenService:Create(label, info, {
					Position = rest.position,
					TextTransparency = rest.transparency,
				})
			)
		end
		for _, tween in selectionTweens do
			tween:Play()
		end
	end

	BadgeIcon.bind(scope, iconFrame, BadgeState.selectedId, flash)
	scope:Hydrate(nameLabel)({
		Text = scope:Computed(function(use)
			return BadgeConfig.badges[use(BadgeState.selectedId)].displayName
		end),
	})
	scope:Hydrate(description)({
		Text = scope:Computed(function(use)
			return BadgeConfig.badges[use(BadgeState.selectedId)].description
		end),
	})

	-- The big icon has no action; it squashes on press and wobbles on release.
	iconFrame.MouseEnter:Connect(function()
		hovered:set(true)
	end)
	iconFrame.MouseLeave:Connect(function()
		hovered:set(false)
		pressed:set(false)
	end)
	iconFrame.InputBegan:Connect(function(input: InputObject)
		if PopupUtils.IsClick(input) then
			pressed:set(true)
		end
	end)
	iconFrame.InputEnded:Connect(function(input: InputObject)
		if not Fusion.peek(pressed) or not PopupUtils.IsClick(input) then
			return
		end
		pressed:set(false)
		if input.UserInputType == Enum.UserInputType.Touch then
			hovered:set(false)
		end
		if moving() then
			wobble(180)
			if Fusion.peek(BadgeState.earned)[Fusion.peek(BadgeState.selectedId)] then
				flashIcon()
			end
		end
	end)

	GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
		reducedMotion:set(GuiService.ReducedMotionEnabled)
		resetSelectionMotion()
	end)
	scope:Hydrate(wrapper)({
		[Fusion.OnChange("Visible")] = function(visible)
			if visible then
				playSelectionMotion()
			else
				hovered:set(false)
				pressed:set(false)
				resetSelectionMotion()
			end
		end,
	})
	scope:Observer(BadgeState.selectedId):onChange(playSelectionMotion)
	-- Equipping or unequipping the shown badge bumps and lights the icon.
	scope:Observer(BadgeState.equippedId):onChange(function()
		if not moving() then
			return
		end
		iconSpring:addVelocity(if Fusion.peek(BadgeState.equippedId) == "" then -2 else 3)
		wobble(220)
		flashIcon()
	end)
end

function Shared.bind(scope, wrapper)
	local content = wrapper:WaitForChild("Content")
	local top = content:WaitForChild("Top")
	Private._bindSelection(scope, wrapper, top)

	local equipButton: ImageButton = top:WaitForChild("DisplayBtn")
	local buttonLabel: TextLabel = equipButton:WaitForChild("BtnLabel")
	local equipText = buttonLabel.Text
	local equipState = scope:Value(equipButton.GuiState)
	local canToggleEquip = scope:Computed(function(use)
		local selectedId = use(BadgeState.selectedId)
		return use(BadgeState.earned)[selectedId] == true
	end)

	scope:Hydrate(equipButton)({
		[Fusion.Out("GuiState")] = equipState,
		Active = canToggleEquip,
		Interactable = canToggleEquip,
		Selectable = canToggleEquip,
	})
	scope:Hydrate(buttonLabel)({
		Text = scope:Computed(function(use)
			local selectedId = use(BadgeState.selectedId)
			if not use(BadgeState.earned)[selectedId] then
				return "UNEARNED"
			end
			if use(BadgeState.equippedId) == selectedId then
				local state = use(equipState)
				return if state == Enum.GuiState.Hover or state == Enum.GuiState.Press then "UNEQUIP" else "EQUIPPED"
			end
			return equipText
		end),
	})
	equipButton.Activated:Connect(Private._equip)
end

return Shared
