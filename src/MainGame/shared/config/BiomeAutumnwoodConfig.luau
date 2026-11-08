--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeTypes = require(ReplicatedStorage.Shared.types.BiomeTypes)
local BiomeUtils = require(ReplicatedStorage.Shared.utils.BiomeUtils)

type BiomeContext = BiomeTypes.BiomeContext

local _logTag: string = "BiomeAutumnwood"
local _biomeName: string = "Autumnwood"

local _houseCount: number = 4
local _houseMinGap: number = 18
local _houseMinPathOffset: number = 8
local _houseMaxPathOffset: number = 24

local function generateFeatures(ctx: BiomeContext): ()
	BiomeUtils.placeHouses(ctx, { "House 1", "House 2", "House 3", "House 4" }, _houseCount, ctx.biomeMinZ + 5, ctx.biomeMaxZ - 5, _biomeName, _logTag, {
		subSegment = true,
		minGap = _houseMinGap,
		minPathOffset = _houseMinPathOffset,
		maxPathOffset = _houseMaxPathOffset,
	})
	BiomeUtils.placeOpenCampsite(ctx, {
		minCZ = ctx.biomeMinZ + 8,
		maxCZ = ctx.biomeMaxZ - 8,
		biomeName = _biomeName,
		logTag = _logTag,
	})
	BiomeUtils.placeScatteredChests(ctx, 2, 3, _biomeName)
	BiomeUtils.carvePond(ctx, {
		minCZ = ctx.biomeMinZ + 8,
		maxCZ = ctx.biomeMaxZ - 8,
		bankMaterial = Enum.Material.Mud,
		lobed = true,
		logTag = _logTag,
	})
end

local function getTerrainMaterial(voxelX: number, voxelZ: number, noiseSeed: number): Enum.Material
	local n: number = math.noise(voxelX / 12 + noiseSeed, voxelZ / 12)
	if n > 0.22 then
		return Enum.Material.Grass
	elseif n < -0.25 then
		return Enum.Material.Mud
	end
	return Enum.Material.Ground
end

return {
	Name = _biomeName,
	PropFolder = "Autumnwood",
	TerrainType = Enum.Material.Ground,
	hillScale = 0.35,
	rollHeight = 5,
	PropChance = {
		["None"] = 850,
		["Trees"] = 15,
		["Bush"] = 4,
		["Plants"] = 45,
		["Blueberries"] = 10,
		["Raspberries"] = 10,
		["Grass"] = 25,
	},
	getTerrainMaterial = getTerrainMaterial,
	generateFeatures = generateFeatures,
} :: BiomeTypes.Biome
