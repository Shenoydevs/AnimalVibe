--!strict

type InventoryConfig = {
	hotbarSize: number,
	maxSackCapacity: number,
	dragThresholdPx: number,
	maxMovesPerSecond: number,
}

local inventoryConfig: InventoryConfig = {
	hotbarSize = 5,
	maxSackCapacity = 70,
	dragThresholdPx = 6,
	maxMovesPerSecond = 15,
}

return inventoryConfig
