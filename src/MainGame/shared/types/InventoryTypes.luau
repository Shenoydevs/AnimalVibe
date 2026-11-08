--!strict

export type ItemCategory = "Tools" | "Food" | "Supplies" | "Gear"

export type FilterCategory = "All" | ItemCategory

export type ItemUseType = "Eat" | "Heal" | "Unlock" | "None"

export type ItemSlot = "Hotbar" | "Mouth"

export type ItemData = {
	displayName: string,
	category: ItemCategory,
	icon: string,
	canShare: boolean?,
	hungerValue: number?,
	healValue: number?,
	hpBonus: number?,
	speedBonus: number?,
	healAmount: number?,
	inventoryCapacity: number?,
	notDroppable: boolean?,
	useType: ItemUseType?,
	slot: ItemSlot?,
}

export type ItemStack = {
	itemId: string,
	count: number,
}

export type SlotArray = { [number]: ItemStack? }

export type SlotEntry = {
	slot: number,
	itemId: string,
	count: number,
}

return {}
