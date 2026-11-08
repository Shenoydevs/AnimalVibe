--!strict

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythical" | "Secret"

export type Style = {
	name: string,
	rarity: Rarity,
	description: string,
}

-- Matches the Gacha section of Common's DataTemplate.
export type GachaData = {
	spins: number,
	luckySpins: number,
	pity: number,
	secretPity: number,
	-- Style IDs by slot; "" marks an empty slot, and older saves may list fewer slots.
	styles: { string },
}

export type SpinOutcome = "added" | "replaced" | "duplicate"

export type SpinResult = {
	status: "rolled" | "noSpins" | "away" | "invalid" | "notReady" | "rateLimited",
	styleId: string?,
	rarity: Rarity?,
	outcome: SpinOutcome?,
	coins: number?,
	replacedId: string?,
	-- The picked slot the roll landed in.
	slot: number?,
}

export type ActionResult = {
	status: "equipped" | "left" | "away" | "invalid" | "notReady" | "rateLimited",
}

return {}
