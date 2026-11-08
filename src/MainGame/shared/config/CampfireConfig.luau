--!strict

export type circleConfig = {
	color: Color3,
	transparency: number,
	thickness: number,
	embed: number,
}

local campfireConfig = {
	safeRadius = 28,
	safeHalfHeight = 14,
	repelMargin = 4,

	healDamagePerSecond = 10,
	healTickInterval = 0.5,

	campfiresPerBiome = { min = 1, max = 2 },
	keepoutRadius = 15,
	placementAttempts = 10,
	maxSlopeSpread = 4,

	circle = {
		color = Color3.fromRGB(255, 170, 70),
		transparency = 0.65,
		thickness = 1.5,
		embed = 1.2,
	} :: circleConfig,
}

export type campfireConfig = typeof(campfireConfig)
return campfireConfig
