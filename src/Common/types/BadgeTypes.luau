--!strict

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Exclusive"

export type Badge = {
	displayName: string,
	description: string,
	rarity: Rarity,
	icon: string,
	order: number,
}

export type BadgeProfile = {
	earned: { [string]: boolean },
	equippedId: string,
}

export type Catalog = {
	rarities: { Rarity },
	rarityColors: { [Rarity]: Color3 },
	badges: { [string]: Badge },
	starterEarned: { [string]: boolean },
	defaultEquippedId: string,
}

return {}
