--!strict
local caveGenerationConfig = {
	enabled = true,
	tunnelRadius = 12,
	tunnelHeight = 20,
	entranceRadius = 22,
	entranceHeight = 28,
	entranceRiseLength = 36,
	entranceTerrainBlend = 95,
	entranceRidgeHeight = 8,
	-- Hill shaping: the summit stays at full cover height; only the slopes are warped and roughened.
	hillCrownHeight = 16,
	hillDetailHeight = 3,
	hillWarpScale = 45,
	hillWarpStrength = 24,
	mouthRockWidth = 9,
	outcropThreshold = 0.32,
	shelterRadius = 32,
	shelterHeight = 36,
	roofThickness = 16,
	floorThickness = 20,
	wallNoiseScale = 18,
	wallNoiseStrength = 4,
	maxSlope = 0.35,
	entranceWidthFraction = 0.74,
	outerWidthFraction = 0.88,
	siteAttempts = 16,
	-- One cave per window, alternating sides; a three-layer cave reaches ~60 chunks past its window start,
	-- so the last window must end by biomeDepth.min - 60.
	siteWindows = {
		{ min = 30, max = 50 },
		{ min = 75, max = 90 },
	} :: { { min: number, max: number } },
	campfireRadius = 18,
	campfireHalfHeight = 12,
	maxAssetSize = 14,
	layersByBiome = {
		Forest = 3,
		Farmland = 1,
		["Industrial Ruins"] = 2,
		Autumnwood = 3,
		Snowfields = 2,
		["Arctic Expanse"] = 3,
	} :: { [string]: number },
}

export type caveGenerationConfig = typeof(caveGenerationConfig)
return caveGenerationConfig
