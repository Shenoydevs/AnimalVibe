--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Fusion = require(Packages.Fusion)
local SoundService = game:GetService("SoundService")
local LocalPlayer = game:GetService("Players").LocalPlayer

local InventoryConfig = require(ReplicatedStorage.Shared.config.InventoryConfig)
local InventoryTypes = require(ReplicatedStorage.Shared.types.InventoryTypes)
local InventoryUtils = require(ReplicatedStorage.Shared.utils.InventoryUtils)
local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)
local Network = require(ReplicatedStorage.Shared.network.InventoryNetwork)
local states = require(script.Parent.Parent.states)
local utils = require(script.Parent.Parent.utils)

local InventoryState = states.InventoryState
local PlayerActionState = states.PlayerActionState
local KeybindUtils = utils.KeybindUtils
local peek = Fusion.peek

type NetworkerClient = Networker.Client
type SlotArray = InventoryTypes.SlotArray

local TOGGLE_ACTION = "toggleInventory"
local TOTAL_SLOTS = InventoryConfig.hotbarSize + InventoryConfig.maxSackCapacity

local _networker: NetworkerClient
local _scope = Fusion.scoped(Fusion)

local InventoryController = {}
local Private = {}

local function _sackCapacity(): number
	return InventoryUtils.getSackCapacity(peek(InventoryState.Slots))
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

function Private.inventoryUpdated(_: any, entries: any, newItem): ()
	local slots: SlotArray = {}

	if type(entries) == "table" then
		for _, entry in entries do
			if
				type(entry) == "table"
				and type(entry.slot) == "number"
				and type(entry.itemId) == "string"
				and type(entry.count) == "number"
				and entry.slot >= 1
				and entry.slot <= TOTAL_SLOTS
				and entry.count >= 1
			then
				slots[entry.slot] = { itemId = entry.itemId, count = entry.count }
			end
		end
	end

	if newItem then
		local root: BasePart? = if LocalPlayer.Character then LocalPlayer.Character.PrimaryPart else nil
		local pickSound: Instance? = if root then root:FindFirstChild("PickItem") else nil
		if pickSound and pickSound:IsA("Sound") then
			SoundService:PlayLocalSound(pickSound)
		end
	end

	InventoryState.Slots:set(slots)
end

function InventoryController:requestMove(fromIndex: number, toIndex: number): ()
	if fromIndex == toIndex then return end
	if fromIndex < 1 or fromIndex > TOTAL_SLOTS then return end
	if toIndex < 1 or toIndex > TOTAL_SLOTS then return end

	local slots: SlotArray = peek(InventoryState.Slots)
	if not slots[fromIndex] then return end

	_networker:fire("moveItem", fromIndex, toIndex)
end

function InventoryController:OnStart(): ()
	_networker = Networker.client.new(Network.Inventory, Private)

	KeybindUtils.getSignal(TOGGLE_ACTION):Connect(function(inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.Begin then return end
		if not _isSackEquipped() then return end
		if _sackCapacity() <= 0 then return end
		InventoryState.IsOpen:set(not peek(InventoryState.IsOpen))
	end)

	_scope:Observer(PlayerActionState.EquippedTool):onChange(function()
		if peek(InventoryState.IsOpen) and not _isSackEquipped() then
			InventoryState.IsOpen:set(false)
		end
	end)

	_scope:Observer(InventoryState.Slots):onChange(function()
		if peek(InventoryState.IsOpen) and _sackCapacity() <= 0 then
			InventoryState.IsOpen:set(false)
		end
	end)

	_networker:fire("requestSnapshot")
end

export type InventoryController = typeof(InventoryController)
return InventoryController
