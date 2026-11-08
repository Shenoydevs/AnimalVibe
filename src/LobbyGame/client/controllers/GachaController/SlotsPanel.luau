--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GachaConfig = require(ReplicatedStorage.Shared.config.GachaConfig)
local SpinMotion = require(script.Parent.SpinMotion)

type Slot = {
	frame: GuiObject,
	base: ImageLabel,
	name: TextLabel,
	namePosition: UDim2,
	icon: GuiObject,
	buttons: GuiObject,
	equipped: GuiObject,
	unequipped: GuiObject,
	colors: { UIGradient },
}

-- A slot's whole background shows its state: grey until picked, then the highlight while empty or
-- the style's rarity colour once filled. The authored slot art has its colour baked in, so slots
-- draw SpinGui's white brush (the odds rows' base image) coloured by a gradient instead. The brush
-- is translucent, so a same-shaped copy under the slot's contents adds body while the scene still
-- shows through. Each colour fades from a dimmed top to a darker foot, keeping the slot's white
-- and rarity-coloured text readable on it.
local _slotImage = "rbxassetid://138373826551976"
local _fillLayers = 1
local _topShade = 0.6
local _footShade = 0.18
local _fillTransparency = NumberSequence.new(0.25, 0.45)
local _idleColor = ColorSequence.new(Color3.fromRGB(110, 110, 110))
local _pickedColor = ColorSequence.new(Color3.fromRGB(255, 214, 130))
local _emptyText = "EMPTY"

local _slots: { Slot } = {}
local _slotStyles: { string } = {}
-- The picked slot is the equipped one; a slot is always picked, starting with the first.
local _selected = 1
local _nameColor = ColorSequence.new(Color3.new(1, 1, 1))

local Private = {}
local Shared = {}

-- Darkens a colour down the slot, so multi-stop colours such as Secret keep their stops.
function Private._shade(color: ColorSequence): ColorSequence
	local keypoints = {}
	for _, keypoint in color.Keypoints do
		local value = keypoint.Value
		local amount = _topShade + (_footShade - _topShade) * keypoint.Time
		table.insert(
			keypoints,
			ColorSequenceKeypoint.new(keypoint.Time, Color3.new(value.R * amount, value.G * amount, value.B * amount))
		)
	end
	return ColorSequence.new(keypoints)
end

function Private._showSelection(): ()
	for order, slot in _slots do
		local style = GachaConfig.styles[_slotStyles[order]]
		local color = Private._shade(
			if order ~= _selected
				then _idleColor
				elseif style then GachaConfig.rarityColors[style.rarity]
				else _pickedColor
		)
		for _, gradient in slot.colors do
			gradient.Color = color
		end
		slot.equipped.Visible = order == _selected
		slot.unequipped.Visible = order ~= _selected
	end
end

-- Binds the style slots; onPick runs when the player picks a different slot.
function Shared.bind(left: Frame, onPick: (slot: number) -> ()): ()
	-- The authored panel shows two example slots; a copy of the second fills the rest.
	local items = left:WaitForChild("Items")
	local slotFrames = { items:WaitForChild("Slot") :: Frame, items:WaitForChild("Slot2") :: Frame }
	while #slotFrames < GachaConfig.maxStyles do
		local copy = slotFrames[2]:Clone()
		copy.Name = `Slot{#slotFrames + 1}`
		copy.Parent = items
		table.insert(slotFrames, copy)
	end
	for order, frame in slotFrames do
		frame.LayoutOrder = order
		local base = frame:WaitForChild("Base") :: ImageLabel
		local name = base:WaitForChild("ItemName") :: TextLabel
		local buttons = base:WaitForChild("Buttons") :: GuiObject
		local equipped = buttons:WaitForChild("EquippedBTN") :: Frame
		local unequipped = buttons:WaitForChild("UnEquippedBTN") :: Frame
		local gradient = name:FindFirstChildOfClass("UIGradient")
		if gradient then
			_nameColor = gradient.Color
		end

		-- Set before the button feedback copies the base image into its glow and shadow layers.
		base.Image = _slotImage
		base.ScaleType = Enum.ScaleType.Stretch
		local colors: { UIGradient } = {}
		for layer = 0, _fillLayers do
			local target: ImageLabel = base
			if layer > 0 then
				target = Instance.new("ImageLabel")
				target.Name = `SlotFill{layer}`
				target.BackgroundTransparency = 1
				target.Image = _slotImage
				target.ScaleType = Enum.ScaleType.Stretch
				target.Size = UDim2.fromScale(1, 1)
				target.ZIndex = base.ZIndex - 1
				target.Parent = base
			end
			local color = Instance.new("UIGradient")
			color.Name = "SlotColor"
			color.Color = Private._shade(_idleColor)
			color.Rotation = 90
			color.Transparency = _fillTransparency
			color.Parent = target
			table.insert(colors, color)
		end
		-- Under the slot's own contents, so the equip buttons keep their clicks.
		local selectHit = Instance.new("ImageButton")
		selectHit.Name = "SelectHitBox"
		selectHit.BackgroundTransparency = 1
		selectHit.ImageTransparency = 1
		selectHit.Size = UDim2.fromScale(1, 1)
		selectHit.ZIndex = base.ZIndex - 1
		selectHit.Parent = base

		_slots[order] = {
			frame = frame,
			base = base,
			name = name,
			namePosition = name.Position,
			icon = base:WaitForChild("ItemIcon") :: GuiObject,
			buttons = buttons,
			equipped = equipped,
			unequipped = unequipped,
			colors = colors,
		}
		_slotStyles[order] = ""

		-- Picking is never blocked, even mid-roll: a roll in flight already sent its slot, and
		-- ignoring a pick during a roll's hold once sent the next roll into the old slot.
		local function pick(): ()
			if _selected ~= order then
				_selected = order
				Private._showSelection()
				onPick(order)
			end
		end
		SpinMotion.button(frame, selectHit, base, nil)
		selectHit.Activated:Connect(pick)
		SpinMotion.bindButton(equipped)
		SpinMotion.bindButton(unequipped).Activated:Connect(pick)
	end
end

-- Shows every slot, empty or filled. With syncPick, the pick follows the saved equip: it stays on a
-- slot holding the equipped style (either copy), else moves to the first one. While a pick's equip
-- request is in flight the saved equip lags behind, so the caller turns syncing off.
function Shared.render(styles: { string }, equippedStyle: string, syncPick: boolean): ()
	for order, slot in _slots do
		local styleId = styles[order] or ""
		local style = GachaConfig.styles[styleId]
		_slotStyles[order] = if style then styleId else ""
		slot.name.Text = if style then string.upper(style.name) else _emptyText
		-- An empty slot has no icon or buttons, so its label sits in the middle.
		slot.name.Position = if style then slot.namePosition else UDim2.new(slot.namePosition.X, UDim.new(0.5, 0))
		SpinMotion.tint(slot.name, if style then GachaConfig.rarityColors[style.rarity] else _nameColor)
		slot.icon.Visible = style ~= nil
		slot.buttons.Visible = style ~= nil
	end
	if syncPick and _slotStyles[_selected] ~= equippedStyle then
		_selected = table.find(_slotStyles, equippedStyle) or _selected
	end
	-- A picked slot's colour follows its contents, from the highlight to the rolled rarity.
	Private._showSelection()
end

-- The player's picked slot, which the next roll fills or replaces.
function Shared.target(): number
	return _selected
end

-- The picked slot's style, "" when it is empty.
function Shared.pickedStyle(): string
	return _slotStyles[_selected]
end

-- The slot a roll landed in (a duplicate's owner) flashes like a clicked button, covering the
-- change to its new colour and name.
function Shared.flashSlot(order: number): ()
	local slot = _slots[order]
	if slot then
		SpinMotion.flash(slot.base, 0.6, 0.45)
	end
end

function Shared.playOpen(): ()
	for order, slot in _slots do
		SpinMotion.slideIn(slot.base, UDim2.fromOffset(-60, 0), 0.4, 0.3 + order * 0.07)
	end
end

return Shared
