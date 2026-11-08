--!strict

export type CharacterData = {
	damage: number,
	walkSpeed: number,
	sprintSpeed: number,
	attackCooldown: number,

	cartModifier: number,
	staminaModifier: number,
	healthModifier: number,
	passive: string,
	active: string,

	walkingAnim: string,
	walkingBaseAnimSpeed: number,
	runningAnim: string,
	runningBaseAnimSpeed: number,
	idleAnim: string,
	fallAnim: string,
	jumpAnim: string,
	attackAnim: string,
	knockoutAnim: string,
	deadAnim: string,

	hitboxData: { Vector3 | number },
}

local characterConfig: { [string]: CharacterData } = {
	Horse = {
		damage = 17.5,
		walkSpeed = 16,
		sprintSpeed = 35,
		attackCooldown = 0.5,

		cartModifier = 1.3,
		staminaModifier = 0.8,
		healthModifier = 1,
		passive = "None",
		active = "None",
		
		walkingAnim = "108623303243666",
		walkingBaseAnimSpeed = 3,
		runningAnim = "99865919145599",
		runningBaseAnimSpeed = 1.5,	
		idleAnim = "76532893826623",
		fallAnim = "100305321556503",
		jumpAnim = "115948201682377",
		attackAnim = "78491524261775",
		knockoutAnim = "90206534596554",
		deadAnim = "99662482465670",

		hitboxData = {
			Vector3.new(6, 6, 7),
			Vector3.new(0, 0, -4),
			4,
		}
	},

	Wolf = {
		damage = 40,
		walkSpeed = 16,
		sprintSpeed = 32,
		attackCooldown = 1,

		cartModifier = 1,
		staminaModifier = 1,
		healthModifier = 1,
		passive = "WolfPack",
		active = "None",

		walkingAnim = "83286720284422",
		walkingBaseAnimSpeed = 1.8,
		runningAnim = "126859556627452",
		runningBaseAnimSpeed = 0.9,
		idleAnim = "117106640423887",
		fallAnim = "76362941748508",
		jumpAnim = "133856842927967",
		attackAnim = "102303815098773",
		knockoutAnim = "92423572453714",
		deadAnim = "81873814990752",

		hitboxData = {
			Vector3.new(5, 5, 5.5),
			Vector3.new(0, 0, -4.5),
			5,
		}
	},

	Bear = {
		damage = 80,
		walkSpeed = 16,
		sprintSpeed = 27,
		attackCooldown = 1.5,

		cartModifier = 0.7,
		staminaModifier = 1.5,
		healthModifier = 1.5,
		passive = "None",
		active = "None",
		
		walkingAnim = "95830829666134",
		walkingBaseAnimSpeed = 2,
		runningAnim = "106941697935265",
		runningBaseAnimSpeed = 1.2,
		idleAnim = "122359140131623",
		fallAnim = "121026467805964",
		jumpAnim = "136212496884322",
		attackAnim = "124459041414255",
		knockoutAnim = "83927470322482",
		deadAnim = "130636964069451",
		
		hitboxData = {
			Vector3.new(6.5, 5, 8),
			Vector3.new(0, 0, -4),
			7,
		}
	},

	Deer = {
		damage = 17.5,
		walkSpeed = 24,
		sprintSpeed = 52,
		attackCooldown = 0.5,

		cartModifier = 1.15,
		staminaModifier = 0.7,
		healthModifier = 0.5,
		passive = "Radar",
		active = "None",
		
		walkingAnim = "116380843423639",
		walkingBaseAnimSpeed = 1.5,
		runningAnim = "124659709112521",
		runningBaseAnimSpeed = 1,
		idleAnim = "128274867995496",
		fallAnim = "100842160550988",
		jumpAnim = "130650822740197",
		attackAnim = "113743181510746",
		knockoutAnim = "125422432645069",
		deadAnim = "124432779209009",
		
		hitboxData = {
			Vector3.new(5, 5, 6),
			Vector3.new(0, 0, -3.25),
			7,
		}
	},
}

return characterConfig
