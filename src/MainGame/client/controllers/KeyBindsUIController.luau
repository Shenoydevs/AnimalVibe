--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage.Packages
local Fusion = require(Packages.Fusion)

local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)
local InventoryConfig = require(ReplicatedStorage.Shared.config.InventoryConfig)
local InventoryUtils = require(ReplicatedStorage.Shared.utils.InventoryUtils)
local KeybindConfig = require(ReplicatedStorage.Shared.config.KeybindConfig)
local KeybindUIConfig = require(ReplicatedStorage.Shared.config.KeybindUIConfig)
local DeviceUtils = require(ReplicatedStorage.Shared.utils.DeviceUtils)
local states = require(script.Parent.Parent.states)
local utils = require(script.Parent.Parent.utils)

local PlayerActionState = states.PlayerActionState
local InventoryState = states.InventoryState
local GuiUtils = utils.GuiUtils
local peek = Fusion.peek
local scope = Fusion.scoped(Fusion)

local PLACEHOLDER_ICON = "rbxassetid://124142247223281"
local GOLD_COLOR = Color3.fromRGB(255, 200, 90)
local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)

type NearbyKind = "Lockable" | "Pickup"
type TemplateKind = "Text" | "Icon"

type RowRefs = {
	root: GuiObject,
	label: TextLabel,
	keyDisplay: TextLabel | ImageLabel,
	kind: TemplateKind,
}

local _rows: { RowRefs } = {}
local _nearbyKinds: { [ProximityPrompt]: NearbyKind } = {}
local _keyBinds: GuiObject
local _textTemplate: GuiObject
local _iconTemplate: GuiObject

local KeyBindsUIController = {}

local function _waitFor(parent: Instance, childName: string): Instance?
	return GuiUtils.waitFor(parent, childName, "KeyBindsUI")
end

local function _resolveNearbyKind(): NearbyKind?
	local best: NearbyKind? = nil

	for _, kind in _nearbyKinds do
		if kind == "Lockable" then
			return "Lockable"
		end
		best = kind
	end
	return best
end

local function _hasSackCapacity(): boolean
	return InventoryUtils.getSackCapacity(peek(InventoryState.Slots)) > 0
end

local function _resolveRow( id: KeybindUIConfig.RowId, heldItem: string?, equippedTool: string?, equippedRope: boolean?): (boolean, string?)
	if id == "sprint" then
		return true, nil
	elseif id == "openSack" and equippedTool ~= nil then
		local equippedSack = ItemConfig[equippedTool]
		local sackEquippedInHotbar = equippedSack and equippedSack.inventoryCapacity ~= nil
		return sackEquippedInHotbar and _hasSackCapacity(), nil
	elseif id == "context" then
		local nearby = _resolveNearbyKind()
		local equippedUseType = equippedTool and ItemConfig[equippedTool] and ItemConfig[equippedTool].useType
		local equippedItem = ItemConfig[equippedTool]
		local sackEquippedInHotbar = equippedItem and equippedItem.inventoryCapacity
		if nearby == "Lockable" and equippedUseType == "Unlock" then
			return true, "UNLOCK"
		elseif heldItem == nil and nearby == "Pickup" then
			return true, if sackEquippedInHotbar then "STORE" else "PICK UP"
		elseif heldItem ~= nil then
			return true, "DROP"
		end
		return false, nil
	elseif id == "use" then
		if not heldItem then
			return false, nil
		end
		local useType = ItemConfig[heldItem] and ItemConfig[heldItem].useType
		if useType == "Eat" then
			return true, "EAT"
		end
		if useType == "Heal" then
			return true, "HEAL"
		end
		return false, nil
	elseif id == "store" then
		local equippedItem = ItemConfig[equippedTool]
		local sackEquippedInHotbar = equippedItem and equippedItem.inventoryCapacity
		if sackEquippedInHotbar then
			return true, "UNSTORE"
		end

		return heldItem ~= nil and _hasSackCapacity(), "STORE"
	elseif id == "dropTool" then
		local equippedItem = ItemConfig[equippedTool]
		local sackEquippedInHotbar = equippedItem and equippedItem.inventoryCapacity
		if sackEquippedInHotbar then return false, nil end
		return equippedTool ~= nil, nil
	elseif id == "cutRope" then
		if equippedRope == true then
			return true, "CUT"
		else return false, nil end
	elseif id == "unStuck" then
		if equippedRope == true then
			return true, "UNSTUCK"
		else return false, nil end
	end
	return false, nil
end

local function _render(): ()
	local heldItem: string? = peek(PlayerActionState.HeldItem)
	local equippedTool: string? = peek(PlayerActionState.EquippedTool)
	local equippedRope: string? = peek(PlayerActionState.RopeEquipped)

	for index, refs in _rows do
		local config = KeybindUIConfig[index]
		local visible, dynamicLabel = _resolveRow(config.id, heldItem, equippedTool, equippedRope)
		refs.root.Visible = visible
		if visible then
			refs.label.Text = config.label or dynamicLabel or ""
		end
	end
end

local function _isGamepadKeyCodeName(name: string): boolean
	return string.match(name, "^Button") ~= nil
		or string.match(name, "^DPad") ~= nil
		or string.match(name, "^Thumbstick") ~= nil
end

local function _resolveKeyCode(action: string, wantGamepad: boolean): Enum.KeyCode?
	local bindings = KeybindConfig[action]
	if not bindings then
		return nil
	end
	for _, binding in bindings do
		if typeof(binding) == "EnumItem" and binding.EnumType == Enum.KeyCode then
			if _isGamepadKeyCodeName(binding.Name) == wantGamepad then
				return binding :: Enum.KeyCode
			end
		end
	end
	return nil
end

local function _templateKindFor(config: KeybindUIConfig.RowConfig, device: DeviceUtils.Device): TemplateKind
	if device == "Gamepad" then
		return "Icon"
	end
	return if config.keyboardIcon then "Icon" else "Text"
end

local function _setKeyDisplay(refs: RowRefs, config: KeybindUIConfig.RowConfig, device: DeviceUtils.Device): ()
	if refs.kind == "Icon" then
		local image: string
		if device == "Gamepad" then
			local keyCode = _resolveKeyCode(config.action, true)
			image = if keyCode then UserInputService:GetImageForKeyCode(keyCode) else PLACEHOLDER_ICON
		else
			image = config.keyboardIcon or PLACEHOLDER_ICON
		end
		(refs.keyDisplay :: ImageLabel).Image = image
	else
		local keyCode = _resolveKeyCode(config.action, false)
		local textDisplay = refs.keyDisplay :: TextLabel
		textDisplay.Text = if keyCode then UserInputService:GetStringForKeyCode(keyCode) else ""
	end
end

local function _buildRow(index: number, config: KeybindUIConfig.RowConfig, kind: TemplateKind): RowRefs?
	local template = if kind == "Icon" then _iconTemplate else _textTemplate
	local clone = template:Clone()
	clone.Name = config.id
	clone.LayoutOrder = index
	clone.Visible = false
	clone.Parent = _keyBinds

	local label = clone:FindFirstChild("KeyBind", true) :: TextLabel?
	local keyDisplay = clone:FindFirstChild("Icon", true) :: (TextLabel | ImageLabel)?
	if not label or not keyDisplay then
		warn(`[KeyBindsUI] KeybindTemplate{kind} is missing KeyBind or Icon for row "{config.id}"`)
		clone:Destroy()
		return nil
	end

	label.TextColor3 = if config.gold then GOLD_COLOR else DEFAULT_COLOR

	return { root = clone, label = label, keyDisplay = keyDisplay, kind = kind }
end

local function _applyDevice(device: DeviceUtils.Device): ()
	for index, config in KeybindUIConfig do
		local kind = _templateKindFor(config, device)
		local refs = _rows[index]

		if not refs or refs.kind ~= kind then
			if refs then
				refs.root:Destroy()
			end
			refs = _buildRow(index, config, kind)
			_rows[index] = refs
		end

		if refs then
			_setKeyDisplay(refs, config, device)
		end
	end
	_render()
end

local function _trackPrompts(): ()
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		local part = prompt.Parent
		local target = part and part.Parent
		if not target then
			return
		end

		if CollectionService:HasTag(target, "Chest") then
			_nearbyKinds[prompt] = "Lockable"
		elseif CollectionService:HasTag(target, "ResourceProp") then
			_nearbyKinds[prompt] = "Pickup"
		else
			return
		end
		_render()
	end)

	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		if not _nearbyKinds[prompt] then
			return
		end
		_nearbyKinds[prompt] = nil
		_render()
	end)
end

function KeyBindsUIController:OnStart(): ()
	if DeviceUtils.getCurrent() == "Touch" then
		return
	end

	local playerGui: PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local screenGui = _waitFor(playerGui, "ScreenGui") :: ScreenGui?
	if not screenGui then
		return
	end
	local gameHud = _waitFor(screenGui, "GameHud")
	if not gameHud then
		return
	end
	local bottomRight = _waitFor(gameHud, "BottomRight")
	if not bottomRight then
		return
	end
	local keyBinds = _waitFor(bottomRight, "KeyBinds") :: GuiObject?
	if not keyBinds then
		return
	end
	_keyBinds = keyBinds

	local textTemplate = _waitFor(ReplicatedStorage.Assets.UI, "KeybindTemplateText") :: GuiObject?
	local iconTemplate = _waitFor(ReplicatedStorage.Assets.UI, "KeybindTemplateIcon") :: GuiObject?
	if not textTemplate or not iconTemplate then
		return
	end
	_textTemplate = textTemplate
	_iconTemplate = iconTemplate
	_textTemplate.Visible = false
	_iconTemplate.Visible = false

	_trackPrompts()

	_applyDevice(DeviceUtils.getCurrent())
	DeviceUtils.onChanged(_applyDevice)

	scope:Observer(PlayerActionState.HeldItem):onChange(_render)
	scope:Observer(PlayerActionState.EquippedTool):onChange(_render)
	scope:Observer(PlayerActionState.EquippedSlot):onChange(_render)
	scope:Observer(PlayerActionState.RopeEquipped):onChange(_render)
	scope:Observer(InventoryState.Slots):onChange(_render)
end

export type KeyBindsUIController = typeof(KeyBindsUIController)
return KeyBindsUIController
