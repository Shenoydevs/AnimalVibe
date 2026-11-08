--!strict

export type mapGenerationConfig = {
	seed: number?,
	roadMinWidth: number,
	roadMaxWidth: number,
	roadWidthNoiseScale: number,
	roadShoulderWidth: number,
	sideRiseStart: number,
	sideRiseJitter: number, -- how far sideRiseStart wanders along the map so the outer slope never reads as a straight wall
	sideRiseHeight: number,
	sideNoiseScale: number,
	rollHeight: number, -- gentle non-negative undulation beside the road; 0 disables it (opt-in per biome)
	rollScale: number, -- noise frequency for rollHeight, in voxels
	rollFadeWidth: number, -- studs past the road shoulder over which rollHeight fades in
	pondMaxElevation: number,
	pondMaxWidthFraction: number, -- ponds stay inside this fraction of the half-width, clear of the outer slopes
	pondMaxHeightSpread: number,
	grassPatchScale: number,
	grassPatchThreshold: number,
	groundSlabDepth: number,
	chunkScale: number,
	hillNoiseScale: number, -- default noise frequency for hills; biomes may override via Biome.hillNoiseScale
	hillThreshold: number,
	hillHeight: number,
	grassDetailHeight: number, -- small-amplitude noise layered on top of the hill height; 0 disables it (opt-in per biome)
	grassDetailScale: number, -- noise frequency for grassDetailHeight
	roadType: Enum.Material,

	spawnDepth: number,
	cartChunkZ: number,
	streamIntervalSec: number,

	endCapRisePerChunk: number,
	endCapMaxRise: number,

	pathCurveScale: number,
	pathMaxDrift: number,
	pathHillAvoidWindow: number,
	pathHillAvoidWeight: number,
	pathHillIgnoreBelow: number, -- hill height (studs) the solver treats as free to drive over
	pathHillLookahead: number,
	pathDriftWeight: number,
	pathContinuityWeight: number,
	pathMaxStepChunks: number,
	pathSmoothWindow: number, -- moving-average half-window applied to path centers after solving
	pathCorridorChunks: number, -- chunks from the road edge where hills return to full height

	renderDistance: number,
	propClearRadius: number,
	propSkipMaterials: { [Enum.Material]: boolean },

	budgetMs: number,
	terrainBatchChunks: number,
	featureMarginChunks: number, -- terrain rows written past a biome's end before its features are placed
}

return {
	seed = nil,
	roadMinWidth = 20,
	roadMaxWidth = 28,
	roadWidthNoiseScale = 100,
	roadShoulderWidth = 10,
	sideRiseStart = 0.45,
	sideRiseJitter = 0.08,
	sideRiseHeight = 100,
	sideNoiseScale = 180,
	rollHeight = 0,
	rollScale = 60,
	rollFadeWidth = 30,
	pondMaxElevation = 8,
	pondMaxWidthFraction = 0.7,
	pondMaxHeightSpread = 4,
	grassPatchScale = 65,
	grassPatchThreshold = 0.26,
	groundSlabDepth = 64,
	chunkScale = 2.5,
	hillNoiseScale = 70,
	hillThreshold = 0.4,
	hillHeight = 70,
	grassDetailHeight = 0,
	grassDetailScale = 20,
	roadType = Enum.Material.Cobblestone,

	spawnDepth = 8,
	cartChunkZ = 6,
	streamIntervalSec = 1,

	endCapRisePerChunk = 8,
	endCapMaxRise = 160,

	pathCurveScale = 26,
	pathMaxDrift = 11,
	pathHillAvoidWindow = 12,
	pathHillAvoidWeight = 3,
	pathHillIgnoreBelow = 6,
	pathHillLookahead = 18,
	pathDriftWeight = 1,
	pathContinuityWeight = 0.5,
	pathMaxStepChunks = 0.8,
	pathSmoothWindow = 6,
	pathCorridorChunks = 6,

	renderDistance = 250,
	propClearRadius = 4,
	propSkipMaterials = {
		[Enum.Material.Cobblestone] = true,
		[Enum.Material.Water] = true,
		[Enum.Material.Glacier] = true,
	},

	budgetMs = 12,
	terrainBatchChunks = 16, -- adjacent chunks per voxel write; bounded to keep frame-budget checks frequent
	featureMarginChunks = 12,
} :: mapGenerationConfig
