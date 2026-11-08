--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Trove = require(Packages.Trove)

local InventoryConfig = require(ReplicatedStorage.Shared.config.InventoryConfig)
local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)
local InventoryTypes = require(ReplicatedStorage.Shared.types.InventoryTypes)
local Network = require(ReplicatedStorage.Shared.network.InventoryNetwork)
local InventoryUtils = require(ReplicatedStorage.Shared.utils.InventoryUtils)
local NotificationConfig = require(ReplicatedStorage.Shared.config.NotificationConfig)
local NotificationService = require(ServerScriptService.Server.services.NotificationService)
local AssetUtils = require(ServerScriptService.Server.utils.AssetUtils)
local GroundItemUtils = require(ServerScriptService.Server.utils.GroundItemUtils)
local signals = require(ServerScriptService.Server.signals)

local InventorySignals = signals.InventorySignals

type NetworkerServer = Networker.Server
type ItemStack = InventoryTypes.ItemStack
type SlotArray = InventoryTypes.SlotArray
type SlotEntry = InventoryTypes.SlotEntry

type RateWindow = {
	windowStart: number,
	count: number,
}

local TOTAL_SLOTS = InventoryConfig.hotbarSize + InventoryConfig.maxSackCapacity

local _trove = Trove.new()
local _networker: NetworkerServer? = nil
local _inventories: { [Player]: SlotArray } = {}
local _rateWindows: { [Player]: RateWindow } = {}

local InventoryService = {}
local Private = {}

local function _getSackCapacity(player: Player): number
	local inventory: SlotArray? = _inventories[player]
	if not inventory then return 0 end
	return InventoryUtils.getSackCapacity(inventory)
end

local function _getCapacity(player: Player): number
	return InventoryConfig.hotbarSize + _getSackCapacity(player)
end

local function _isValidSlotIndex(value: any, capacity: number): boolean
	return type(value) == "number"
		and value % 1 == 0
		and value >= 1
		and value <= capacity
end

local function _checkRateLimit(player: Player): boolean
	local now: number = os.clock()
	local window: RateWindow? = _rateWindows[player]
	if not window or now - window.windowStart >= 1 then
		_rateWindows[player] = { windowStart = now, count = 1 }
		return true
	end
	window.count += 1
	return window.count <= InventoryConfig.maxMovesPerSecond
end

function InventoryService:_replicate(player: Player, newItem): ()
	local inventory: SlotArray? = _inventories[player]
	local networker: NetworkerServer? = _networker
	if not inventory or not networker then return end

	local entries: { SlotEntry } = {}
	for slot = 1, TOTAL_SLOTS do
		local stack: ItemStack? = inventory[slot]
		if stack then
			table.insert(entries, { slot = slot, itemId = stack.itemId, count = stack.count })
		end
	end

	networker:fire(player, "inventoryUpdated", entries, newItem)
end

function InventoryService:_onPlayerAdded(player: Player): ()
	if _inventories[player] then return end
	_inventories[player] = {}
	self:_grantStarterSack(player)
end

function InventoryService:_grantStarterSack(player: Player): ()
	local inventory: SlotArray? = _inventories[player]
	if not inventory then return end

	for slot = 1, InventoryConfig.hotbarSize do
		local stack: ItemStack? = inventory[slot]
		if stack and stack.itemId == "Sack" then return end
	end

	for slot = 1, InventoryConfig.hotbarSize do
		if not inventory[slot] then
			inventory[slot] = { itemId = "Sack", count = 1 }
			self:_replicate(player, true)
			return
		end
	end
end

function InventoryService:addTool(player: Player, itemId: string): boolean
	local inventory: SlotArray? = _inventories[player]
	local itemData = ItemConfig[itemId]
	if not inventory or not itemData or itemData.slot ~= "Hotbar" then return false end

	for slot = 1, InventoryConfig.hotbarSize do
		if not inventory[slot] then
			local clone: Model? = AssetUtils.cloneResource(itemId)
			if not clone then
				warn(`[InventoryService] "{itemId}" is missing a usable Resources model — can't grant it`)
				return false
			end
			clone.Parent = player.Backpack

			inventory[slot] = { itemId = itemId, count = 1 }
			self:_replicate(player, true)
			InventorySignals.ItemAdded:Fire(player, itemId, 1)
			return true
		end
	end

	InventorySignals.InventoryFull:Fire(player, itemId)
	NotificationService:notify(player, "Alert", "Your hotbar is full — drop a tool to make room.", 4, NotificationConfig.priority.med)
	return false
end

function InventoryService:addToSack(player: Player, itemId: string): boolean
	local inventory: SlotArray? = _inventories[player]
	local itemData = ItemConfig[itemId]
	local capacity: number = _getSackCapacity(player)
	if not inventory or not itemData or itemData.slot ~= "Mouth" or capacity == 0 then return false end

	for slot = InventoryConfig.hotbarSize + 1, InventoryConfig.hotbarSize + capacity do
		if not inventory[slot] then
			inventory[slot] = { itemId = itemId, count = 1 }
			self:_replicate(player, true)
			InventorySignals.ItemAdded:Fire(player, itemId, 1)
			return true
		end
	end

	InventorySignals.InventoryFull:Fire(player, itemId)
	NotificationService:notify(player, "Alert", "Your Sack is full — make room before storing more.", 4, NotificationConfig.priority.med)
	return false
end

function InventoryService:getSackCapacity(player: Player): number
	return _getSackCapacity(player)
end

function InventoryService:removeSackSlot(player: Player, slotIndex: number): string?
	local inventory: SlotArray? = _inventories[player]
	if not inventory then return nil end
	if slotIndex <= InventoryConfig.hotbarSize or slotIndex > InventoryConfig.hotbarSize + _getSackCapacity(player) then
		return nil
	end

	local stack: ItemStack? = inventory[slotIndex]
	if not stack then return nil end

	inventory[slotIndex] = nil
	self:_replicate(player)
	return stack.itemId
end

function InventoryService:addItem(player: Player, itemId: string): boolean
	local itemData = ItemConfig[itemId]
	if not itemData then return false end
	if itemData.slot == "Hotbar" then
		return self:addTool(player, itemId)
	elseif itemData.slot == "Mouth" then
		return self:addToSack(player, itemId)
	end
	return false
end

function InventoryService:removeItem(player: Player, itemId: string, count: number, fromSack : boolean): boolean
	local itemData = ItemConfig[itemId]

	local inventory: SlotArray? = _inventories[player]
	if not inventory or count < 1 then return false end
	if not itemData or itemData.notDroppable then return false end
	if self:countItem(player, itemId) < count then return false end
	if not fromSack then signals.CharacterSignals.ItemConsumed:Fire(player, itemId) end

	local remaining: number = math.floor(count)
	for slot = TOTAL_SLOTS, 1, -1 do
		if remaining == 0 then break end
		local stack: ItemStack? = inventory[slot]
		if stack and stack.itemId == itemId then
			local removed: number = math.min(stack.count, remaining)
			stack.count -= removed
			remaining -= removed
			if stack.count == 0 then
				inventory[slot] = nil
			end
		end
	end

	self:_replicate(player)
	InventorySignals.ItemRemoved:Fire(player, itemId, math.floor(count))
	return true
end

function InventoryService:dropItem(player: Player, itemId: string, count: number, fromSack: boolean): boolean
	if not InventoryService:removeItem(player, itemId, count, fromSack) then return false end

	local char: Model? = player.Character
	if not char then return false end

	GroundItemUtils.spawn(itemId, char)
	return true
end

function InventoryService:emptyBag(player: Player): boolean
	local inventory: SlotArray? = _inventories[player]
	if not inventory then return false end

	local droppedAll: boolean = true
	for slot = TOTAL_SLOTS, InventoryConfig.hotbarSize + 1, -1 do
		local stack: ItemStack? = inventory[slot]
		if stack and not InventoryService:dropItem(player, stack.itemId, stack.count, true) then
			droppedAll = false
		end
	end

	return droppedAll
end

function InventoryService:dropAll(player: Player): ()
	local inventory: SlotArray? = _inventories[player]
	local char: Model? = player.Character
	if not inventory or not char then return end

	for slot = TOTAL_SLOTS, 1, -1 do
		local stack: ItemStack? = inventory[slot]
		if not stack then continue end

		if not InventoryService:removeItem(player, stack.itemId, stack.count, true) then continue end
		GroundItemUtils.spawn(stack.itemId, char, true)
	end

	self:_replicate(player)
end

function InventoryService:countItem(player: Player, itemId: string): number
	local inventory: SlotArray? = _inventories[player]
	if not inventory then return 0 end

	local total: number = 0
	for _, stack in inventory do
		if stack and stack.itemId == itemId then
			total += stack.count
		end
	end
	return total
end

function Private.requestSnapshot(_: any, player: Player): ()
	InventoryService:_replicate(player)
end

function Private.moveItem(_: any, player: Player, fromIndex: any, toIndex: any): ()
	local inventory: SlotArray? = _inventories[player]
	if not inventory then return end
	if not _checkRateLimit(player) then return end

	local capacity: number = _getCapacity(player)
	if not _isValidSlotIndex(fromIndex, capacity) or not _isValidSlotIndex(toIndex, capacity) or fromIndex == toIndex then
		InventoryService:_replicate(player)
		return
	end

	local from: number = fromIndex :: number
	local to: number = toIndex :: number

	if (from <= InventoryConfig.hotbarSize) ~= (to <= InventoryConfig.hotbarSize) then
		InventoryService:_replicate(player)
		return
	end

	local source: ItemStack? = inventory[from]
	if not source then
		InventoryService:_replicate(player)
		return
	end

	inventory[from], inventory[to] = inventory[to], source
	InventoryService:_replicate(player)
end

function InventoryService:OnStart(): ()
	_networker = Networker.server.new(Network.Inventory, Private, { Private.requestSnapshot, Private.moveItem })

	local function watchPlayer(player: Player): ()
		InventoryService:_onPlayerAdded(player)
		_trove:Connect(player.CharacterAdded, function()
			InventoryService:_grantStarterSack(player)
		end)
		if player.Character then
			InventoryService:_grantStarterSack(player)
		end
	end

	_trove:Connect(Players.PlayerAdded, watchPlayer)

	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	_trove:Connect(Players.PlayerRemoving, function(player: Player)
		_inventories[player] = nil
		_rateWindows[player] = nil
	end)

	InventorySignals.DropAll:Connect(function(player)
		InventoryService:dropAll(player)
	end)
end

export type InventoryService = typeof(InventoryService)
return InventoryService
