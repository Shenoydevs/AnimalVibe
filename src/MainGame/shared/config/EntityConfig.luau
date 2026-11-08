--!strict

type EntityData = {
	health: number,
	damage: number,
	walkSpeed: number,
	attackCooldown: number,
	damageReduction: number,
	allowedBiomes: { string }?,
	keyDropChance: number,
	meatDropChance: number,
}

local entityConfig: { [string]: EntityData } = {
	["Normal Hunter"] = {
		health = 100,
		damage = 15,
		walkSpeed = 16,
		attackCooldown = 1,
		damageReduction = 1,
		keyDropChance = 0.35,
		meatDropChance = 0.6,
	},

	["Armored Hunter"] = {
		health = 150,
		damage = 25,
		walkSpeed = 8,
		attackCooldown = 1,
		damageReduction = 1.5,
		keyDropChance = 0.45,
		meatDropChance = 0.65,
	},

	["Agile Hunter"] = {
		health = 50,
		damage = 10,
		walkSpeed = 32,
		attackCooldown = 0.5,
		damageReduction = 1,
		keyDropChance = 0.25,
		meatDropChance = 0.5,
	},

	["The General"] = {
		health = 100,
		damage = 15,
		walkSpeed = 16,
		attackCooldown = 0.5,
		damageReduction = 1,
		keyDropChance = 0.35,
		meatDropChance = 0.6,
	},

	["Mercenary"] = {
		health = 100,
		damage = 15,
		walkSpeed = 16,
		attackCooldown = 1,
		damageReduction = 1,
		keyDropChance = 0.35,
		meatDropChance = 0.6,
	},

	["Special Forces Soldier"] = {
		health = 300,
		damage = 30,
		walkSpeed = 16,
		attackCooldown = 0.8,
		damageReduction = 1,
		allowedBiomes = { "Arctic Expanse" },
		keyDropChance = 0.55,
		meatDropChance = 0.7,
	},

	["Special Forces Commander"] = {
		health = 500,
		damage = 40,
		walkSpeed = 16,
		attackCooldown = 0.7,
		damageReduction = 1,
		allowedBiomes = { "Arctic Expanse" },
		keyDropChance = 0.65,
		meatDropChance = 0.75,
	},
}

return entityConfig
