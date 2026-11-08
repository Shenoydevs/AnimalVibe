--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KeepoutRegistryModule = require(ReplicatedStorage.Shared.utils.KeepoutRegistry)

export type KeepoutRegistry = KeepoutRegistryModule.KeepoutRegistry
export type Keepout = KeepoutRegistryModule.Keepout

export type BiomeContext = {
	startPos: Vector3,
	chunkScale: number,
	biomeMinZ: number,
	biomeMaxZ: number,
	halfWidth: number,
	seed: Random,
	assets: Instance,
	container: Instance,
	keepouts: KeepoutRegistry,
	findGround: (worldX: number, worldZ: number) -> Vector3?,
	randomOffPathGround: (minChunkZ: number, maxChunkZ: number, minOffset: number?, maxOffset: number?) -> Vector3?,
	getPathCenter: (chunkZ: number) -> number,
	getRoadBounds: (chunkZ: number) -> (number, number),
}

export type Biome = {
	Name: string, -- unique id used for folders, boundary parts, and enemy tiers
	PropFolder: string,
	TerrainType: Enum.Material,
	roadShoulderMaterial: Enum.Material?, -- defaults to Ground; lets paved biomes avoid dirt verges
	PropChance: { [string]: number },
	generateFeatures: ((ctx: BiomeContext) -> ())?,
	getTerrainMaterial: ((voxelX: number, voxelZ: number, noiseSeed: number) -> Enum.Material)?,
	hillScale: number?, -- post-multiply on the raw noise height; defaults to 1
	hillThreshold: number?, -- noise cutoff below which terrain is flat; defaults to MapGenerationConfig.hillThreshold
	hillHeight: number?, -- max hill amplitude; defaults to MapGenerationConfig.hillHeight
	hillNoiseScale: number?, -- noise frequency (bigger = broader/smoother hills); defaults to MapGenerationConfig.hillNoiseScale
	grassDetailHeight: number?, -- small-amplitude noise added on top of the hill height; roughs up otherwise-flat grass ground without raising hillHeight everywhere; defaults to MapGenerationConfig.grassDetailHeight (0 = off)
	grassDetailScale: number?, -- noise frequency for grassDetailHeight; defaults to MapGenerationConfig.grassDetailScale
	sideRiseScale: number?,
	rollHeight: number?, -- defaults to MapGenerationConfig.rollHeight
	rollScale: number?, -- defaults to MapGenerationConfig.rollScale
	grassPatchThreshold: number?, -- noise cutoff for the grass-patch mask (terrain material + Grass/Plants prop gate); lower = more grass; defaults to MapGenerationConfig.grassPatchThreshold
}

return {}
