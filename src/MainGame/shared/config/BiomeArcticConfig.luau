--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeTypes = require(ReplicatedStorage.Shared.types.BiomeTypes)
local BiomeUtils = require(ReplicatedStorage.Shared.utils.BiomeUtils)

type BiomeContext = BiomeTypes.BiomeContext

local _logTag: string = "BiomeArctic"
local _biomeName: string = "Arctic Expanse"

local _houseCount: number = 4
local _houseMinGap: number = 18
local _houseMinPathOffset: number = 8
local _houseMaxPathOffset: number = 24

local function generateFeatures(ctx: BiomeContext): ()
	BiomeUtils.placeHouses(ctx, { "House 1", "House 2", "House 3", "House 4" }, _houseCount, ctx.biomeMinZ + 5, ctx.biomeMaxZ - 8, _biomeName, _logTag, {
		subSegment = true,
		minGap = _houseMinGap,
		minPathOffset = _houseMinPathOffset,
		maxPathOffset = _houseMaxPathOffset,
	})
	BiomeUtils.placeScatteredChests(ctx, 2, 2, _biomeName)
	BiomeUtils.carvePond(ctx, {
		minCZ = ctx.biomeMinZ + 8,
		maxCZ = ctx.biomeMaxZ - 8,
		bankMaterial = Enum.Material.Glacier,
		logTag = _logTag,
	})
end

local function getTerrainMaterial(voxelX: number, voxelZ: number, noiseSeed: number): Enum.Material
	local n: number = math.noise(voxelX / 13 + noiseSeed, voxelZ / 13)
	return if n > 0.3 then Enum.Material.Glacier else Enum.Material.Snow
end

return {
	Name = _biomeName,
	PropFolder = "Arctic Expanse",
	TerrainType = Enum.Material.Snow,
	hillScale = 1.25,
	sideRiseScale = 1.3,
	rollHeight = 5,
	PropChance = {
		["None"] = 1300,
		["Trees"] = 2,
		["Bush"] = 4,
		["Blueberries"] = 4,
		["Raspberries"] = 4,
	},
	getTerrainMaterial = getTerrainMaterial,
	generateFeatures = generateFeatures,
} :: BiomeTypes.Biome
