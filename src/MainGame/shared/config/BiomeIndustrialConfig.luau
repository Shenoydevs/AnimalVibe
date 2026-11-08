--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeTypes = require(ReplicatedStorage.Shared.types.BiomeTypes)
local BiomeUtils = require(ReplicatedStorage.Shared.utils.BiomeUtils)

type BiomeContext = BiomeTypes.BiomeContext

local _logTag: string = "BiomeIndustrial"
local _biomeName: string = "Industrial Ruins"

local _cityHalfSpanChunks: number = 25
local _mainRoadClearChunks: number = 3
local _roadGapChance: number = 0.3

local _buildingVariants: { string } = {
	"Destroyed Building 1",
	"Destroyed Building 2",
	"Destroyed Building 3",
	"Destroyed Building 4",
}

type RoadPoint = { x: number, z: number, alongX: boolean }

local function generateFeatures(ctx: BiomeContext): ()
	local seed: Random = ctx.seed
	local chunkStuds: number = ctx.chunkScale * 4
	local midZ: number = math.floor((ctx.biomeMinZ + ctx.biomeMaxZ) / 2)
	local cityCenterChunkX: number = ctx.getPathCenter(midZ)

	local minChunkX: number = cityCenterChunkX - _cityHalfSpanChunks
	local maxChunkX: number = cityCenterChunkX + _cityHalfSpanChunks
	local minChunkZ: number = ctx.biomeMinZ + 6
	local maxChunkZ: number = ctx.biomeMaxZ - 6

	local roadPoints: { RoadPoint } = {}
	local roadKeepouts: { { x: number, z: number, r: number } } = {}

	local function tileRoadLine(startX: number, startZ: number, alongX: boolean, endCoord: number): ()
		local x: number, z: number = startX, startZ
		while (if alongX then x else z) < endCoord do
			local variantName: string = if seed:NextNumber() > 0.5 then "Destroyed Road 1" else "Destroyed Road 2"
			local segment: Model? = BiomeUtils.cloneAsset(ctx.assets, variantName, _logTag)
			if not segment then
				return
			end
			local extents: Vector3 = segment:GetExtentsSize()
			local length: number = math.max(extents.X, extents.Z)
			local width: number = math.min(extents.X, extents.Z)
			local longIsX: boolean = extents.X >= extents.Z

			local skip: boolean = seed:NextNumber() < _roadGapChance
				or BiomeUtils.pathChunkDistance(ctx, x, z) < _mainRoadClearChunks
				or not ctx.keepouts:isClear(x, z, width / 2 + 2)
			local ground: Vector3? = if skip then nil else ctx.findGround(x, z)
			if ground and not BiomeUtils.isOnWater(ground) then
				local baseAngle: number = if alongX == longIsX then 0 else 90
				-- Bed the broken slabs into the ground instead of perching them on top.
				BiomeUtils.placeModel(
					ctx.container,
					segment,
					ground - Vector3.new(0, 1, 0),
					baseAngle + seed:NextNumber(-4, 4)
				)
				table.insert(roadPoints, { x = x, z = z, alongX = alongX })
				local dirX: number = if alongX then 1 else 0
				local dirZ: number = if alongX then 0 else 1
				for _, t: number in { -length / 4, length / 4 } do
					table.insert(roadKeepouts, { x = x + dirX * t, z = z + dirZ * t, r = width / 2 + 4 })
				end
			else
				segment:Destroy()
			end

			local advance: number = length + seed:NextNumber(0, 3)
			if alongX then
				x += advance
			else
				z += advance
			end
		end
	end

	-- Wide, interrupted streets leave room for the grassy lots in the reference.
	local spacingChunks: number = seed:NextInteger(18, 22)
	for lineChunkX = minChunkX, maxChunkX, spacingChunks do
		tileRoadLine(
			ctx.startPos.X + lineChunkX * chunkStuds,
			ctx.startPos.Z + minChunkZ * chunkStuds,
			false,
			ctx.startPos.Z + maxChunkZ * chunkStuds
		)
	end
	for lineChunkZ = minChunkZ, maxChunkZ, spacingChunks do
		tileRoadLine(
			ctx.startPos.X + minChunkX * chunkStuds,
			ctx.startPos.Z + lineChunkZ * chunkStuds,
			true,
			ctx.startPos.X + maxChunkX * chunkStuds
		)
	end
	for _, ko in roadKeepouts do
		ctx.keepouts:add(ko.x, ko.z, ko.r)
	end
	task.wait()

	local buildingCount: number = seed:NextInteger(8, 12)
	for _ = 1, buildingCount do
		local buildingName: string = _buildingVariants[seed:NextInteger(1, #_buildingVariants)]
		local building: Model? = BiomeUtils.cloneAsset(ctx.assets, buildingName, _logTag)
		if not building then
			break
		end
		local buildingRadius: number = BiomeUtils.footprintRadius(building)

		local placed: boolean = false
		for _ = 1, BiomeUtils.placementAttempts do
			if #roadPoints == 0 then
				break
			end
			local point: RoadPoint = roadPoints[seed:NextInteger(1, #roadPoints)]
			local side: number = if seed:NextNumber() > 0.5 then 1 else -1
			local offset: number = 15 + buildingRadius + seed:NextNumber(0, 6)
			local bx: number = point.x + (if point.alongX then 0 else side * offset)
			local bz: number = point.z + (if point.alongX then side * offset else 0)

			if BiomeUtils.pathChunkDistance(ctx, bx, bz) < _mainRoadClearChunks then
				continue
			end
			if not ctx.keepouts:isClear(bx, bz, buildingRadius + 2) then
				continue
			end
			local ground: Vector3? = ctx.findGround(bx, bz)
			if not ground or BiomeUtils.isOnWater(ground) then
				continue
			end

			local faceAngle: number = if point.alongX
				then (if side > 0 then 180 else 0)
				else (if side > 0 then 270 else 90)
			BiomeUtils.placeModel(ctx.container, building, ground, faceAngle + seed:NextNumber(-4, 4))
			placed = true

			if seed:NextNumber() < 0.45 then
				BiomeUtils.placeAdjacentChest(ctx, {
					anchor = ground,
					baseOffset = buildingRadius,
					minDist = 3,
					maxDist = 7,
					biomeName = _biomeName,
					logTag = _logTag,
					requireOffRoad = false,
					clearRadius = 4,
				})
			end

			ctx.keepouts:add(ground.X, ground.Z, buildingRadius + 6)
			break
		end
		if not placed then
			building:Destroy()
		end
	end

	-- One crane looming over the city
	local crane: Model? = BiomeUtils.cloneAsset(ctx.assets, "Crane", _logTag)
	if crane then
		local craneRadius: number = BiomeUtils.footprintRadius(crane)
		local placed: boolean = false
		for _ = 1, BiomeUtils.placementAttempts do
			if #roadPoints == 0 then
				break
			end
			local point: RoadPoint = roadPoints[seed:NextInteger(1, #roadPoints)]
			local side: number = if seed:NextNumber() > 0.5 then 1 else -1
			local offset: number = 15 + craneRadius + seed:NextNumber(0, 8)
			local cx: number = point.x + (if point.alongX then 0 else side * offset)
			local cz: number = point.z + (if point.alongX then side * offset else 0)
			if BiomeUtils.pathChunkDistance(ctx, cx, cz) < _mainRoadClearChunks then
				continue
			end
			if not ctx.keepouts:isClear(cx, cz, craneRadius + 2) then
				continue
			end
			local ground: Vector3? = ctx.findGround(cx, cz)
			if not ground or BiomeUtils.isOnWater(ground) then
				continue
			end
			BiomeUtils.placeModel(ctx.container, crane, ground, seed:NextNumber(0, 360))
			ctx.keepouts:add(ground.X, ground.Z, craneRadius + 8)
			placed = true
			break
		end
		if not placed then
			crane:Destroy()
		end
	end

	local debrisCount: number = seed:NextInteger(18, 26)
	for _ = 1, debrisCount do
		local dx: number = ctx.startPos.X + seed:NextInteger(minChunkX, maxChunkX) * chunkStuds
		local dz: number = ctx.startPos.Z + seed:NextInteger(minChunkZ, maxChunkZ) * chunkStuds
		if BiomeUtils.pathChunkDistance(ctx, dx, dz) < _mainRoadClearChunks then
			continue
		end
		local ground: Vector3? = ctx.findGround(dx, dz)
		if not ground or BiomeUtils.isOnWater(ground) then
			continue
		end
		local debrisName: string = if seed:NextNumber() > 0.5 then "Debris 1" else "Debris 2"
		local debris: Model? = BiomeUtils.cloneAsset(ctx.assets, debrisName, _logTag)
		if debris then
			local radius: number = BiomeUtils.footprintRadius(debris) + 2
			if not ctx.keepouts:isClear(dx, dz, radius) then
				debris:Destroy()
				continue
			end
			BiomeUtils.placeModel(ctx.container, debris, ground, seed:NextNumber(0, 360))
			ctx.keepouts:add(ground.X, ground.Z, radius)
		end
	end

	BiomeUtils.placeScatteredChests(ctx, 2, 3, _biomeName)
end

local function getTerrainMaterial(voxelX: number, voxelZ: number, noiseSeed: number): Enum.Material
	-- Broad reclaimed lots, with smaller weathered edges between pavement and grass.
	local n: number = math.noise(voxelX / 28 + noiseSeed, voxelZ / 28)
		+ math.noise(voxelX / 7 + noiseSeed + 137, voxelZ / 7) * 0.15
	if n < -0.32 then
		return Enum.Material.Mud
	elseif n < -0.14 then
		return Enum.Material.Asphalt
	elseif n < 0.05 then
		return Enum.Material.Concrete
	elseif n < 0.25 then
		return Enum.Material.LeafyGrass
	end
	return Enum.Material.Grass
end

return {
	Name = _biomeName,
	PropFolder = "Industrial Ruins",
	TerrainType = Enum.Material.Concrete,
	roadShoulderMaterial = Enum.Material.Concrete,
	hillScale = 0,
	-- Keep the city floor flat; retain the generator's default outer ridges.
	grassDetailHeight = 0,
	grassPatchThreshold = -0.12,
	PropChance = {
		["None"] = 1100,
		["Trees"] = 5,
		["Bush"] = 4,
		["Plants"] = 40,
		["Blueberries"] = 8,
		["Raspberries"] = 8,
	},
	getTerrainMaterial = getTerrainMaterial,
	generateFeatures = generateFeatures,
} :: BiomeTypes.Biome
