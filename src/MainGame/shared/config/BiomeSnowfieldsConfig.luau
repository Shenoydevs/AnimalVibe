--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeTypes = require(ReplicatedStorage.Shared.types.BiomeTypes)
local BiomeUtils = require(ReplicatedStorage.Shared.utils.BiomeUtils)

type BiomeContext = BiomeTypes.BiomeContext

local _logTag: string = "BiomeSnowfields"
local _biomeName: string = "Snowfields"

local _streamWidth: number = 8
local _streamStepLength: number = 4

local function generateFrozenStreams(ctx: BiomeContext): ()
	local seed: Random = ctx.seed
	local xBound: number = (ctx.halfWidth - 2) * ctx.chunkScale * 4
	local minWorldZ: number = ctx.startPos.Z + (ctx.biomeMinZ + 3) * ctx.chunkScale * 4
	local maxWorldZ: number = ctx.startPos.Z + (ctx.biomeMaxZ - 3) * ctx.chunkScale * 4

	local streamCount: number = seed:NextInteger(2, 3)
	for _ = 1, streamCount do
		local fromWest: boolean = seed:NextNumber() > 0.5
		local x: number = ctx.startPos.X + (if fromWest then -xBound else xBound)
		local z: number = seed:NextNumber(minWorldZ, maxWorldZ)
		local dir: number = if fromWest then 0 else math.pi
		local meander: number = seed:NextNumber(0, 1000)

		for step = 1, 500 do
			local localX: number = x - ctx.startPos.X
			if math.abs(localX) > xBound or z < minWorldZ or z > maxWorldZ then
				break
			end

			local offMainRoad: boolean = BiomeUtils.pathChunkDistance(ctx, x, z) >= 2
			if offMainRoad and ctx.keepouts:isClear(x, z, _streamWidth / 2) then
				workspace.Terrain:FillBlock(
					CFrame.new(x, ctx.startPos.Y + 8, z),
					Vector3.new(_streamWidth, 14, _streamWidth),
					Enum.Material.Air
				)
				workspace.Terrain:FillBlock(
					CFrame.new(x, ctx.startPos.Y - 2, z),
					Vector3.new(_streamWidth, 6, _streamWidth),
					Enum.Material.Glacier
				)
			end

			dir += math.noise(step / 10, meander) * 0.35
			x += math.cos(dir) * _streamStepLength
			z += math.sin(dir) * _streamStepLength
		end
		task.wait()
	end
end

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
		bankMaterial = Enum.Material.Glacier,
		shorePropName = "Bamboo",
		logTag = _logTag,
	})
	generateFrozenStreams(ctx)
end

local function getTerrainMaterial(voxelX: number, voxelZ: number, noiseSeed: number): Enum.Material
	local n: number = math.noise(voxelX / 16 + noiseSeed, voxelZ / 16)
	return if n > 0.28 then Enum.Material.Ground else Enum.Material.Snow
end

return {
	Name = _biomeName,
	PropFolder = "Snowfields",
	TerrainType = Enum.Material.Snow,
	hillScale = 0.15,
	rollHeight = 5,
	PropChance = {
		["None"] = 1000,
		["Trees"] = 3,
		["Bush"] = 4,
		["Plants"] = 12,
		["Blueberries"] = 6,
		["Raspberries"] = 6,
		["Grass"] = 8,
	},
	getTerrainMaterial = getTerrainMaterial,
	generateFeatures = generateFeatures,
} :: BiomeTypes.Biome
