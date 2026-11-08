--!strict

export type WeatherData = {
	chance: number?,
	excludedBiomes: { string }?,
	allowedBiomes: { string }?,
	alwaysInBiomes: { string }?,
	enemySpawn: boolean,
	onlyAgileHunters: boolean?,
	agileSpeedBoost: number?,
	exposedDamage: number?,
	exposedDamageInterval: number?,
	armorDurabilityReduction: number?,
	strikeChance: number?,
	strikeDamage: number?,
	strikeInterval: number?,
	strikeWarningDelay: number?, -- seconds between the warning rumble and the strike landing
	warningSoundId: string?, -- rbxassetid:// of the distant rumble every player hears before a strike
	strikeSoundId: string?, -- rbxassetid:// of the crack played at the strike position
	speedReduction: number?,
}

local weatherConfig: { [string]: WeatherData } = {
	Standard = {
		chance = nil,
		excludedBiomes = {},
		enemySpawn = true,
	},

	NormalRain = {
		chance = 0.50,
		excludedBiomes = { "Snowfields", "Arctic Expanse" },
		enemySpawn = true,
		onlyAgileHunters = true,
		agileSpeedBoost = 0.50,
	},

	AcidRain = {
		chance = 0.05,
		excludedBiomes = { "Snowfields", "Arctic Expanse" },
		enemySpawn = false,
		exposedDamage = 10,
		exposedDamageInterval = 5,
		armorDurabilityReduction = 0.50,
	},

	Thunder = {
		chance = 0.20,
		excludedBiomes = { "Snowfields", "Arctic Expanse" },
		enemySpawn = true,
		strikeChance = 0.50,
		strikeDamage = 70,
		strikeInterval = 8,
		strikeWarningDelay = 3,
		warningSoundId = nil,
		strikeSoundId = nil,
	},

	Blizzard = {
		chance = 0.70,
		allowedBiomes = { "Snowfields", "Arctic Expanse" },
		alwaysInBiomes = { "Arctic Expanse" },
		enemySpawn = true,
		speedReduction = 0.50,
	},
}

return weatherConfig
