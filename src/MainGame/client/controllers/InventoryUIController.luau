--!strict
local GamepadService = game:GetService("GamepadService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage.Packages
local Fusion = require(Packages.Fusion)
local Trove = require(Packages.Trove)

local utils = require(script.Parent.Parent.utils)
local InventoryConfig = require(ReplicatedStorage.Shared.config.InventoryConfig)
local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)
local InventoryTypes = require(ReplicatedStorage.Shared.types.InventoryTypes)
local InventoryUtils = require(ReplicatedStorage.Shared.utils.InventoryUtils)
local DeviceUtils = require(ReplicatedStorage.Shared.utils.DeviceUtils)
local InventoryController = require(script.Parent.InventoryController)
local HeldItemController = require(script.Parent.HeldItemController)
local states = require(script.Parent.Parent.states)
local GuiUtils = utils.GuiUtils
local KeybindUtils = utils.KeybindUtils
local Signals = require(script.Parent.Parent.signals)

local InventoryState = states.InventoryState
local PlayerActionState = states.PlayerActionState
local peek = Fusion.peek

type ItemStack = InventoryTypes.ItemStack
type SlotArray = InventoryTypes.SlotArray
type FilterCategory = InventoryTypes.FilterCategory

type SlotRefs = {
	frame: GuiObject,
	icon: ImageLabel,
	hitBox: GuiButton,
	stroke: UIStroke?,
	strokeThickness: number,
}

type DragState = {
	fromIndex: number,
	startPos: Vector2,
	live: boolean,
	trove: typeof(Trove.new()),
}

local HOVER_THICKNESS_BONUS = 2
local DIMMED_TRANSPARENCY = 0.8
local DRAG_SOURCE_TRANSPARENCY = 0.5

local CATEGORY_BUTTONS: { [string]: FilterCategory } = {
	AllBTN = "All",
	Food = "Food",
	Supplies = "Supplies",
}

local _playerGui: PlayerGui
local _inventoryBase: GuiObject
local _verticalSlots: GuiObject
local _ghost: ImageLabel

local _slotRefs: { [number]: SlotRefs } = {}
local _hitBoxToIndex: { [Instance]: number } = {}
local _drag: DragState? = nil
local _hoverIndex: number? = nil

local scope = Fusion.scoped(Fusion)

local InventoryUIController = {}

local function _waitFor(parent: Instance, childName: string): Instance?
	return GuiUtils.waitFor(parent, childName, "InventoryUI")
end

local function _getPointerPos(): Vector2
	local location: Vector2 = UserInputService:GetMouseLocation()
	local inset: Vector2 = GuiService:GetGuiInset()
	return location - inset
end

local function _slotIndexAt(pos: Vector2): number?
	for _, object in _playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
		local index: number? = _hitBoxToIndex[object]
		if index then
			return index
		end
	end
	return nil
end

local function _applyHover(index: number?): ()
	if _hoverIndex == index then return end

	if _hoverIndex ~= nil then
		local previous: SlotRefs? = _slotRefs[_hoverIndex]
		if previous and previous.stroke then
			previous.stroke.Thickness = previous.strokeThickness
		end
	end

	_hoverIndex = index

	if index ~= nil then
		local refs: SlotRefs? = _slotRefs[index]
		if refs and refs.stroke then
			refs.stroke.Thickness = refs.strokeThickness + HOVER_THICKNESS_BONUS
		end
	end
end

local function _render(): ()
	local slots: SlotArray = peek(InventoryState.Slots)
	local category: FilterCategory = peek(InventoryState.ActiveCategory)
	local draggingFrom: number? = peek(InventoryState.DraggingFrom)

	for index, refs in _slotRefs do
		local stack: ItemStack? = slots[index]
		local itemData = if stack then ItemConfig[stack.itemId] else nil

		if stack and itemData then
			local dimmed: boolean = index > InventoryConfig.hotbarSize
				and category ~= "All"
				and itemData.category ~= category

			refs.icon.Image = itemData.icon
			refs.icon.ImageTransparency = if draggingFrom == index
				then DRAG_SOURCE_TRANSPARENCY
				elseif dimmed then DIMMED_TRANSPARENCY
				else 0
			refs.icon.Visible = true
		else
			refs.icon.Image = ""
			refs.icon.Visible = false
		end
	end
end

local function _cancelDrag(): ()
	local drag: DragState? = _drag
	if not drag then return end

	_drag = nil
	drag.trove:Destroy()
	_ghost.Visible = false
	_applyHover(nil)
	InventoryState.DraggingFrom:set(nil)
end

local function _updateDrag(drag: DragState): ()
	local pos: Vector2 = _getPointerPos()

	if not drag.live then
		if (pos - drag.startPos).Magnitude < InventoryConfig.dragThresholdPx then
			return
		end

		local refs: SlotRefs? = _slotRefs[drag.fromIndex]
		local slots: SlotArray = peek(InventoryState.Slots)
		local stack: ItemStack? = slots[drag.fromIndex]
		local itemData = if stack then ItemConfig[stack.itemId] else nil
		if not refs or not stack or not itemData then
			_cancelDrag()
			return
		end

		drag.live = true
		_ghost.Image = itemData.icon
		_ghost.Visible = true
		InventoryState.DraggingFrom:set(drag.fromIndex)
	end

	_ghost.Position = UDim2.fromOffset(pos.X, pos.Y)
	_applyHover(_slotIndexAt(pos))
end

local function _endDrag(drag: DragState): ()
	local wasLive: boolean = drag.live
	local fromIndex: number = drag.fromIndex
	local toIndex: number? = _slotIndexAt(_getPointerPos())

	_cancelDrag()

	if not wasLive then return end

	local fromIsSack: boolean = fromIndex > InventoryConfig.hotbarSize
	local toIsSack: boolean = toIndex ~= nil and toIndex > InventoryConfig.hotbarSize

	if toIndex ~= nil and toIndex ~= fromIndex and fromIsSack == toIsSack then
		InventoryController:requestMove(fromIndex, toIndex)
	elseif fromIsSack and not toIsSack then
		HeldItemController:requestUnstore(fromIndex)
	end
end

local function _pressOnHotbar(fromIndex: number): ()
	local slots: SlotArray = peek(InventoryState.Slots)
	Signals.CharacterSignals.ToggleEquip:Fire(fromIndex, slots[fromIndex])
end

local function _pressOnBag(fromIndex: number): ()
	local slots: SlotArray = peek(InventoryState.Slots)
	if not slots[fromIndex] then return end

	local trove = Trove.new()
	local drag: DragState = {
		fromIndex = fromIndex,
		startPos = _getPointerPos(),
		live = false,
		trove = trove,
	}
	_drag = drag

	trove:Connect(RunService.RenderStepped, function()
		_updateDrag(drag)
	end)

	trove:Connect(UserInputService.InputEnded, function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			_endDrag(drag)
		end
	end)

	trove:Connect(UserInputService.InputBegan, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonB then
			_cancelDrag()
		end
	end)
end

local function _beginPress(fromIndex: number): ()
	if _drag then return end

	if not peek(InventoryState.IsOpen) or fromIndex == 1 then
		_pressOnHotbar(fromIndex)
	else
		_pressOnBag(fromIndex)
	end
end

local function _cycleHotbar(direction: number): ()
	if _drag or peek(InventoryState.IsOpen) then return end

	local slots: SlotArray = peek(InventoryState.Slots)
	local size: number = InventoryConfig.hotbarSize
	local start: number = peek(PlayerActionState.EquippedSlot) or (if direction > 0 then 0 else size + 1)

	for step = 1, size do
		local index: number = ((start + direction * step - 1) % size) + 1
		if slots[index] then
			if index ~= start then
				_pressOnHotbar(index)
			end
			return
		end
	end
end

local function _applySackCapacity(): ()
	local capacity: number = InventoryUtils.getSackCapacity(peek(InventoryState.Slots))
	for index, refs in _slotRefs do
		if index > InventoryConfig.hotbarSize then
			refs.frame.Visible = index <= InventoryConfig.hotbarSize + capacity
		end
	end
end

local function _applyOpen(): ()
	local isOpen: boolean = peek(InventoryState.IsOpen)
	if not isOpen then
		_cancelDrag()
	end
	_inventoryBase.Visible = isOpen
	_verticalSlots.Visible = isOpen

	if isOpen and DeviceUtils.getCurrent() == "Gamepad" then
		GamepadService:EnableGamepadCursor(_inventoryBase)
	else
		GamepadService:DisableGamepadCursor()
	end
end

local function _registerSlot(index: number, slotFrame: GuiObject): ()
	local iconInstance: Instance? = slotFrame:FindFirstChild("IconPH", true)
	local hitBoxInstance: Instance? = slotFrame:FindFirstChild("HitBox", true)
	if not iconInstance or not iconInstance:IsA("ImageLabel") or not hitBoxInstance or not hitBoxInstance:IsA("GuiButton") then
		warn(`[InventoryUI] Slot {index} is missing an IconPH ImageLabel or HitBox button, skipping`)
		return
	end
	local icon: ImageLabel = iconInstance
	local hitBox: GuiButton = hitBoxInstance

	local stroke: UIStroke? = slotFrame:FindFirstChildWhichIsA("UIStroke", true)

	_slotRefs[index] = {
		frame = slotFrame,
		icon = icon,
		hitBox = hitBox,
		stroke = stroke,
		strokeThickness = if stroke then stroke.Thickness else 0,
	}
	_hitBoxToIndex[hitBox] = index

	hitBox.MouseButton1Down:Connect(function()
		_beginPress(index)
	end)

	if index > InventoryConfig.hotbarSize then return end

	KeybindUtils.getSignal(`slotHotkey{index}`):Connect(function(inputState : Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			_beginPress(index)
		end
	end)
end

local function _connectCategoryButton(frame: Instance, category: FilterCategory): ()
	local button: GuiButton?
	if frame:IsA("GuiButton") then
		button = frame
	else
		button = frame:FindFirstChildWhichIsA("GuiButton", true)
	end

	if not button then
		local overlay: TextButton = Instance.new("TextButton")
		overlay.Name = "ClickCapture"
		overlay.BackgroundTransparency = 1
		overlay.Text = ""
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.ZIndex = 10
		overlay.Parent = frame
		button = overlay
	end

	local categoryButton: GuiButton = button :: GuiButton
	categoryButton.MouseButton1Click:Connect(function()
		InventoryState.ActiveCategory:set(category)
	end)
end

local function _createGhost(screenGui: ScreenGui): ImageLabel
	local ghost: ImageLabel = Instance.new("ImageLabel")
	ghost.Name = "DragGhost"
	ghost.BackgroundTransparency = 1
	ghost.ImageTransparency = 0.25
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.Size = UDim2.fromOffset(64, 64)
	ghost.ZIndex = 1000
	ghost.Visible = false
	ghost.Parent = screenGui
	return ghost
end

function InventoryUIController:OnStart(): ()
	local playerGui: PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	_playerGui = playerGui

	local screenGui = _waitFor(playerGui, "ScreenGui") :: ScreenGui?
	if not screenGui then return end
	local gameHud = _waitFor(screenGui, "GameHud")
	if not gameHud then return end
	local bottom = _waitFor(gameHud, "Bottom")
	if not bottom then return end

	local hotBar = _waitFor(bottom, "HotBar") :: GuiObject?
	local verticalSlots = _waitFor(bottom, "InventoryVerticleSlots") :: GuiObject?
	local inventoryBase = _waitFor(bottom, "InventoryBase") :: GuiObject?
	if not hotBar or not verticalSlots or not inventoryBase then return end
	_verticalSlots = verticalSlots
	_inventoryBase = inventoryBase

	local scrollingFrame = _waitFor(inventoryBase, "ScrollingFrame") :: ScrollingFrame?
	local slotTemplate = if scrollingFrame then _waitFor(scrollingFrame, "SlotTemplate") :: GuiObject? else nil
	if not scrollingFrame or not slotTemplate then return end

	_ghost = _createGhost(screenGui)

	for index = 6, 10 do
		local slotFrame = _waitFor(hotBar, `Slot{index}`) :: GuiObject?
		if slotFrame then
			slotFrame.Visible = false
		end
	end

	for index = 1, InventoryConfig.hotbarSize do
		local slotFrame = _waitFor(hotBar, `Slot{index}`) :: GuiObject?
		if slotFrame then
			_registerSlot(index, slotFrame)
		end
	end

	slotTemplate.Visible = false
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local gridLayout: UIGridLayout? = scrollingFrame:FindFirstChildWhichIsA("UIGridLayout")
	if gridLayout then
		gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	end

	for index = InventoryConfig.hotbarSize + 1, InventoryConfig.hotbarSize + InventoryConfig.maxSackCapacity do
		local slotFrame: GuiObject = slotTemplate:Clone() :: GuiObject
		slotFrame.Name = `Slot{index}`
		slotFrame.LayoutOrder = index
		slotFrame.Visible = false
		slotFrame.Parent = scrollingFrame
		_registerSlot(index, slotFrame)
	end

	for buttonName, category in CATEGORY_BUTTONS do
		local frame: Instance? = _waitFor(verticalSlots, buttonName)
		if frame then
			_connectCategoryButton(frame, category)
		end
	end

	KeybindUtils.getSignal("hotbarPrev"):Connect(function(inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			_cycleHotbar(-1)
		end
	end)
	KeybindUtils.getSignal("hotbarNext"):Connect(function(inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			_cycleHotbar(1)
		end
	end)

	scope:Observer(InventoryState.Slots):onBind(function()
		local drag: DragState? = _drag
		if drag then
			local slots: SlotArray = peek(InventoryState.Slots)
			if not slots[drag.fromIndex] then
				_cancelDrag()
			end
		end
		_render()
	end)

	scope:Observer(InventoryState.ActiveCategory):onChange(_render)
	scope:Observer(InventoryState.DraggingFrom):onChange(_render)
	scope:Observer(InventoryState.IsOpen):onBind(_applyOpen)
	scope:Observer(InventoryState.Slots):onBind(_applySackCapacity)
end

export type InventoryUIController = typeof(InventoryUIController)
return InventoryUIController
