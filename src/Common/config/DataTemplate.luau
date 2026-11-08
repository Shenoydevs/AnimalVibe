--!strict

local BadgeConfig = require(script.Parent.BadgeConfig)
local BadgeTypes = require(script.Parent.Parent.types.BadgeTypes)

type BadgeProfile = BadgeTypes.BadgeProfile

export type AnimalData = {
	Unlocked: boolean,
	Skins: { [string]: boolean },
	EquippedSkin: string,
}

export type PlayerData = {
	redeemedCodes: { [string]: boolean },
	badges: BadgeProfile,
	PlayerStats: {
		Nova: number,
		Level: number,
		Xp: number,
		Wins: number,
	},
	Animals: { [string]: AnimalData },
	Cart: {
		Skins: { [string]: boolean },
	},
	Inventory: {
		EquippedAnimal: string,
		Cart: string,
		HasSelectedFirstAnimal: boolean,
		EquippedStyle: string,
	},
	Challenges: {
		Timer: number,
		Progress: { [string]: number },
	},
	Gacha: {
		spins: number,
		luckySpins: number,
		pity: number,
		secretPity: number,
		styles: { string },
	},
}

local template: PlayerData = {
	redeemedCodes = {},
	badges = {
		earned = table.clone(BadgeConfig.starterEarned),
		equippedId = BadgeConfig.defaultEquippedId,
	},

	PlayerStats = {
		Nova = 0,
		Level = 1,
		Xp = 0,
		Wins = 0,
	},

	Animals = {
		Horse =    { Unlocked = true,  Skins = { Default = true }, EquippedSkin = "Default" },
		Wolf =     { Unlocked = true,  Skins = { Default = true }, EquippedSkin = "Default" },
		Bear =     { Unlocked = true,  Skins = { Default = true }, EquippedSkin = "Default" },
		Deer =     { Unlocked = true,  Skins = { Default = true }, EquippedSkin = "Default" },
		Fox =      { Unlocked = false, Skins = { Default = true }, EquippedSkin = "Default" },
		Elephant = { Unlocked = false, Skins = { Default = true }, EquippedSkin = "Default" },
		Lion =     { Unlocked = false, Skins = { Default = true }, EquippedSkin = "Default" },
	},

	Cart = {
		Skins = { Default = true },
	},

	Inventory = {
		EquippedAnimal = "Horse",
		Cart = "Default",
		HasSelectedFirstAnimal = false,
		EquippedStyle = "",
	},

	Challenges = {
		Timer = 0,
		Progress = {},
	},

	Gacha = {
		spins = 100,
		luckySpins = 0,
		pity = 0,
		secretPity = 0,
		styles = {},
	},
}

return template
