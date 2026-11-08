--!strict

export type AnimalData = {
	displayName: string,
	health: number,
	damage: number,
	walkSpeed: number,
	icon: number,
}

local animalConfig: { [string]: AnimalData } = {
	Horse = {
		displayName = "Horse",
		health = 100,
		damage = 10,
		walkSpeed = 16,
		icon = 100795082424906,
	},
	Wolf = {
		displayName = "Wolf",
		health = 100,
		damage = 10,
		walkSpeed = 16,
		icon = 100795082424906,
	},
	Bear = {
		displayName = "Bear",
		health = 100,
		damage = 10,
		walkSpeed = 16,
		icon = 100795082424906,
	},
	Deer = {
		displayName = "Deer",
		health = 100,
		damage = 10,
		walkSpeed = 16,
		icon = 100795082424906,
	},
}

return animalConfig
