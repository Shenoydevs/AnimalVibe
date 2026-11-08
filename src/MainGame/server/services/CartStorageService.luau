--!strict
local _players = game:GetService("Players")
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _troveModule = require(_replicatedStorage.Packages.Trove)
local _cartTypes = require(_replicatedStorage.Shared.types.CartTypes)
local _cartConfig = require(_replicatedStorage.Shared.config.CartConfig)
local _notificationConfig = require(_replicatedStorage.Shared.config.NotificationConfig)
local _cartService = require(script.Parent.CartService)
local _heldItemService = require(script.Parent.HeldItemService)
local _equipStateService = require(script.Parent.EquipStateService)
local _inventoryService = require(script.Parent.InventoryService)
local _notificationService = require(script.Parent.NotificationService)
local _assetUtils = require(script.Parent.Parent.utils.AssetUtils)
local _cartInteractionUtils = require(script.Parent.Parent.utils.CartInteractionUtils)

type storageComponent = _cartTypes.cartStorageInterface
type slotEntry = { itemId: string, model: Model, trove: typeof(_troveModule.new()) }
type storageRecord = {
	component: storageComponent,
	trove: typeof(_troveModule.new()),
	slots: { [number]: slotEntry },
	freeSlots: { number },
	nextActionAt: { [Player]: number },
}

local _trove = _troveModule.new()
local _records: { [BasePart]: storageRecord } = {}
local cartStorageService = {}

local function _canInteract(record: storageRecord, player: Player, position: Vector3, distance: number): boolean
	local now: number = os.clock()
	if now < (record.nextActionAt[player] or 0) then return false end
	record.nextActionAt[player] = now + _cartConfig.interactionCooldown
	local part: BasePart = record.component:getPart()
	if not _cartService:isAssembled() or not _cartService:ownsPart(part) then return false end
	if not _cartInteractionUtils.getRootWithin(player, position, distance) then return false end
	return true
end

function cartStorageService:register(component: storageComponent): ()
	local part: BasePart = component:getPart()
	assert(not _records[part], "Cart storage already registered")
	local freeSlots: { number } = {}
	for index = component:getSlotCount(), 1, -1 do table.insert(freeSlots, index) end
	_records[part] = { component = component, trove = _trove:Extend(), slots = {}, freeSlots = freeSlots, nextActionAt = {} }
end

function cartStorageService:unregister(component: storageComponent): ()
	local part: BasePart = component:getPart()
	local record: storageRecord? = _records[part]
	if not record or record.component ~= component then return end
	_records[part] = nil
	for slotIndex in record.slots do component:clearSlot(slotIndex) end
	table.clear(record.slots)
	table.clear(record.freeSlots)
	table.clear(record.nextActionAt)
	_trove:Remove(record.trove)
end

function cartStorageService:_retrieve(record: storageRecord, player: Player, slotIndex: number, entry: slotEntry): ()
	if _records[record.component:getPart()] ~= record or record.slots[slotIndex] ~= entry then return end
	if not _canInteract(record, player, entry.model:GetPivot().Position, _cartConfig.storageRetrieveDistance) then return end
	if not _inventoryService:addItem(player, entry.itemId) then return end
	record.slots[slotIndex] = nil
	table.insert(record.freeSlots, slotIndex)
	record.component:clearSlot(slotIndex)
	record.trove:Remove(entry.trove)
end

function cartStorageService:deposit(component: storageComponent, player: Player): ()
	local record: storageRecord? = _records[component:getPart()]
	if not record or record.component ~= component then return end
	if not _canInteract(record, player, component:getPart().Position, component:getDepositDistance()) then return end
	local heldItemId: string? = _heldItemService:getItem(player)
	local itemId: string? = heldItemId or _equipStateService:GetEquippedItem(player)
	if not itemId then
		_notificationService:notify(player, "Alert", "You need to be holding something to store it.", 3, _notificationConfig.priority.low)
		return
	end
	local slotIndex: number? = record.freeSlots[#record.freeSlots]
	if not slotIndex then
		_notificationService:notify(player, "Alert", "Cart storage is full!", 4, _notificationConfig.priority.med)
		return
	end
	local clone: Model? = _assetUtils.cloneResource(itemId, true)
	if not clone then
		warn(`[cartStorageService] No storable visual for item "{itemId}"`)
		return
	end
	local slotTrove = record.trove:Extend()
	slotTrove:Add(clone)
	local removed: boolean = if heldItemId then _heldItemService:take(player) ~= nil
		else _inventoryService:removeItem(player, itemId, 1)
	if not removed then record.trove:Remove(slotTrove) return end
	table.remove(record.freeSlots)
	local entry: slotEntry = { itemId = itemId, model = clone, trove = slotTrove }
	local storedIndex: number = slotIndex
	record.slots[storedIndex] = entry
	component:showItem(storedIndex, clone, function(retrievingPlayer: Player): ()
		self:_retrieve(record, retrievingPlayer, storedIndex, entry)
	end)
end

function cartStorageService:OnStart(): ()
	_trove:Connect(_players.PlayerRemoving, function(player: Player): ()
		for _, record in _records do record.nextActionAt[player] = nil end
	end)
end

export type cartStorageService = typeof(cartStorageService)
return cartStorageService
