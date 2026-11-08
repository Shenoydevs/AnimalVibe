--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeTypes = require(ReplicatedStorage.Shared.types.BiomeTypes)
local BiomeUtils = require(ReplicatedStorage.Shared.utils.BiomeUtils)

type BiomeContext = BiomeTypes.BiomeContext

local _logTag: string = "BiomeForest"
local _biomeName: string = "Forest"

-- Keep features off the spawn / cart-assembly area at the biome's leading edge.
local _startClearanceChunks: number = 22
local _houseCount: number = 4
local _houseMinGap: number = 18
local _houseMinPathOffset: number = 8
local _houseMaxPathOffset: number = 24

local function generateFeatures(ctx: BiomeContext): ()
	local bands: { { min: number, max: number } } = BiomeUtils.shuffledBands(ctx, 2, nil, _startClearanceChunks)

	BiomeUtils.placeHouses(ctx, { "House 1", "House 2", "House 3", "House 4" }, _houseCount, bands[1].min, bands[1].max, _biomeName, _logTag, {
		subSegment = true,
		minGap = _houseMinGap,
		minPathOffset = _houseMinPathOffset,
		maxPathOffset = _houseMaxPathOffset,
	})
	BiomeUtils.placeScatteredChests(ctx, 2, 3, _biomeName)
	BiomeUtils.carvePond(ctx, {
		minCZ = bands[2].min,
		maxCZ = bands[2].max,
		bankMaterial = Enum.Material.Rock,
		shorePropName = "Bamboo",
		logTag = _logTag,
		lobed = true,
		minPathOffset = 20,
		maxPathOffset = 45,
	})
end

return {
	Name = _biomeName,
	PropFolder = "Forest",
	TerrainType = Enum.Material.Grass,
	hillThreshold = 0.25,
	hillHeight = 85,
	hillNoiseScale = 90,
	grassDetailHeight = 3,
	grassDetailScale = 16,
	grassPatchThreshold = 0.18,
	rollHeight = 6,
	PropChance = {
		["None"] = 1100,
		["Trees"] = 10,
		["Bush"] = 4,
		["Plants"] = 15,
		["Blueberries"] = 3,
		["Raspberries"] = 3,
	},
	generateFeatures = generateFeatures,
} :: BiomeTypes.Biome
