--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Fusion = require(Packages.Fusion)

local Network = require(ReplicatedStorage.Shared.network.HeldItemNetwork)
local states = require(script.Parent.Parent.states)
local utils = require(script.Parent.Parent.utils)
local signals = require(script.Parent.Parent.signals)

local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)

local PlayerActionState = states.PlayerActionState
local InventoryState = states.InventoryState
local KeybindUtils = utils.KeybindUtils
local peek = Fusion.peek

type NetworkerClient = Networker.Client

local _networker: NetworkerClient

local HeldItemController = {}
local Private = {}

function Private.heldItemUpdated(_: any, itemId: any): ()
	PlayerActionState.HeldItem:set(if type(itemId) == "string" then itemId else nil)  
	
	local itemData = ItemConfig[itemId]
	signals.CharacterSignals.UpdateShareable:Fire(if itemData then if itemData.canShare then true else false else false)
end

local function _isSackEquipped(): boolean
	local equippedTool = peek(PlayerActionState.EquippedTool)
	if not equippedTool then return false end

	local res = ItemConfig[equippedTool]
	if not res then return false end

	local equippedSack = ItemConfig[equippedTool]
	local sackEquippedInHotbar = equippedSack and equippedSack.inventoryCapacity ~= nil
	return sackEquippedInHotbar
end

function HeldItemController:requestUnstore(slotIndex: number): ()
	if peek(PlayerActionState.HeldItem) then return end
	_networker:fire("requestUnstore", slotIndex, _isSackEquipped())
end

local function _trackEquippedTool(): ()
	signals.CharacterSignals.UpdateEquipHelper:Connect(function(toggle: boolean, index: number?)
		if not toggle or not index then
			PlayerActionState.EquippedTool:set(nil)
			PlayerActionState.EquippedSlot:set(nil)
			return
		end
		local stack = peek(InventoryState.Slots)[index]
		PlayerActionState.EquippedTool:set(if stack then stack.itemId else nil)
		PlayerActionState.EquippedSlot:set(nil)
	end)
end

function HeldItemController:OnStart(): ()
	_networker = Networker.client.new(Network.HeldItem, Private)
	_networker:fire("requestSnapshot")

	_trackEquippedTool()

	KeybindUtils.getSignal("pickupOrDrop"):Connect(function(inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.Begin then return end
		if not peek(PlayerActionState.HeldItem) then return end
		_networker:fire("requestDrop")
	end)

	KeybindUtils.getSignal("attack"):Connect(function(inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.Begin then return end
		_networker:fire("requestUse")
	end)

	KeybindUtils.getSignal("storeItem"):Connect(function(inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.Begin then return end
		_networker:fire("requestStore", _isSackEquipped())
	end)
end

export type HeldItemController = typeof(HeldItemController)
return HeldItemController
