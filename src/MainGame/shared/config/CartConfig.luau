--!strict
local cartConfig = {
	maxFuel = 100,
	lightDepletionRate = 2,
	lightRadius = 20,
	lightRefillPerEssence = 25,
	lightTweenTime = 1,
	lightRepelMargin = 4,

	essenceDespawnTime = 60,
	essenceTravelSpeed = 55,
	essenceAbsorbDistance = 2,
	indicatorMinDistance = 50,
	indicatorScreenMargin = 70,

	maxPullers = 4,
	baseCartSpeed = 18,
	soloWalkSpeedMultiplier = 1.1,
	helperEfficiency = 0.6,
	minCartSpeed = 6,
	maxPullSpeed = 40,
	slackDistance = 4,
	tautDistance = 9,
	surgeDistance = 16,
	surgeSpeedBonus = 0.25,
	maxRopeDistance = 40,
	ropeBreakGraceTime = 1.5,
	interactDistance = 16,
	interactionCooldown = 0.15,
	unstuckCooldown = 5,
	unstuckDistance = 4,
	unstuckLift = 10,
	brakeTime = 0.5,
	moveInputThreshold = 0.1,
	pullInputInterval = 0.1,
	pullInputTimeout = 0.5,

	pullForceFactor = 4,
	turnTorqueFactor = 6,
	turnResponsiveness = 8,
	maxTurnAngularVelocity = 2,
	tiltSampleInterval = 1 / 20,
	tiltSampleInset = 0.4,
	tiltRayHeight = 3,
	tiltRayDepth = 8,
	tiltMinGroundNormalY = 0.25,
	tiltMaxPitch = 35,
	tiltMaxRoll = 25,
	tiltResponsiveness = 8,

	wheelMotorTorque = 5000,
	wheelSpinRate = 1.2,

	ropeSagMax = 2.5,

	storageSlotCount = 15,
	storageRetrieveHoldTime = 0.4,
	storageRetrieveDistance = 8,
}

export type cartConfig = typeof(cartConfig)
return cartConfig
