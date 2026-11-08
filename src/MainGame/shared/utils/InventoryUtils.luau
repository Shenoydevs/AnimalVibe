--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryConfig = require(ReplicatedStorage.Shared.config.InventoryConfig)
local InventoryTypes = require(ReplicatedStorage.Shared.types.InventoryTypes)
local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)

type ItemStack = InventoryTypes.ItemStack
type SlotArray = InventoryTypes.SlotArray

local InventoryUtils = {}

function InventoryUtils.getSackCapacity(slots: SlotArray): number
	local capacity = 0
	for slot = 1, InventoryConfig.hotbarSize do
		local stack: ItemStack? = slots[slot]
		local itemData = stack and ItemConfig[stack.itemId]
		if itemData and itemData.inventoryCapacity then
			capacity = math.max(capacity, itemData.inventoryCapacity)
		end
	end
	return capacity
end

return InventoryUtils
