--!strict

export type TierEntry = {
	dayMin: number,
	dayMax: number,
	nightPool: { string },
	guardPool: { string },
	guardCount: { min: number, max: number },
	nightCount: { min: number, max: number },
}

local EnemyConfig = {
	-- AI state machine identifiers shared by EnemyComponent and EnemyAIService
	states = {
		IDLE = "IDLE",
		PATROL = "PATROL",
		ALERTED = "ALERTED",
		ATTACKING = "ATTACKING",
		DEAD = "DEAD",
	},

	warningRange = 70,
	detectionRange = 30,
	attackRange = 5,
	directChaseRange = 15,

	patrolRadius = 20,
	patrolWaitMin = 2,
	patrolWaitMax = 5,

	defaultRespawnDelay = 480,

	chaseLeashRadius = 40,

	-- Idle-tick culling: patrol scan/movement is skipped for any hostile with no
	-- player within this range. Already-engaged (alerted/attacking) hostiles are
	-- never culled, since they are by definition next to their target.
	simulationRadius = 250,

	pathRecomputeDistance = 10,
	pathRecomputeInterval = 1.5,
	waypointReachedDistance = 4,

	pathMinRecomputeCooldown = 0.5,

	pathStuckTimeout = 2,
	pathStuckDistance = 1.5,

	nightSpawnClusterRadius = 120,

	agentParams = {
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
		PathSettings = {
			SupportPartialPath = true,
		},
	},

	animations = {
		walk = "rbxassetid://80466265528650",
		idle = "rbxassetid://124603082091959",
	},

	-- Client-side floating health bar (EnemyHealthBarComponent). Presentation only.
	healthBar = {
		maxDistance = 90, -- BillboardGui.MaxDistance; hostiles past this render no bar
		studsOffsetY = 1.75, -- height above the Head
	},

	tiers = {
		[1] = {
			dayMin = 1,
			dayMax = 3,
			nightPool = { "Normal Hunter" },
			guardPool = { "Normal Hunter" },
			guardCount = { min = 1, max = 2 },
			nightCount = { min = 2, max = 3 },
		} :: TierEntry,
		[2] = {
			dayMin = 4,
			dayMax = 7,
			nightPool = { "Normal Hunter", "Agile Hunter" },
			guardPool = { "Normal Hunter", "Agile Hunter" },
			guardCount = { min = 2, max = 3 },
			nightCount = { min = 3, max = 4 },
		} :: TierEntry,
		[3] = {
			dayMin = 8,
			dayMax = math.huge,
			nightPool = { "Normal Hunter", "Agile Hunter", "Armored Hunter", "The General", "Mercenary", "Special Forces Soldier" },
			guardPool = { "Armored Hunter", "The General", "Mercenary", "Special Forces Soldier", "Special Forces Commander" },
			guardCount = { min = 3, max = 4 },
			nightCount = { min = 4, max = 6 },
		} :: TierEntry,
	},

	displayNames = {
		["Normal Hunter"] = "Hunter",
		["Armored Hunter"] = "Armored Hunter",
		["Agile Hunter"] = "Agile Hunter",
		["The General"] = "The General",
		["Mercenary"] = "Mercenary",
		["Special Forces Soldier"] = "Special Forces Soldier",
		["Special Forces Commander"] = "Special Forces Commander",
	},
}

return EnemyConfig
