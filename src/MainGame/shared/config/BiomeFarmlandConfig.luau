--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeTypes = require(ReplicatedStorage.Shared.types.BiomeTypes)
local ForageConfig = require(ReplicatedStorage.Shared.config.ForageConfig)
local BiomeUtils = require(ReplicatedStorage.Shared.utils.BiomeUtils)

type BiomeContext = BiomeTypes.BiomeContext

local _logTag: string = "BiomeFarmland"
local _biomeName: string = "Farmland"

local _barnClearRadius: number = 45
local _fieldClearRadius: number = 20
local _fieldMinPathChunks: number = 15

local function generateBarnstead(ctx: BiomeContext, barnName: string, minCZ: number, maxCZ: number): ()
	local seed: Random = ctx.seed

	local barn: Model? = BiomeUtils.cloneAsset(ctx.assets, barnName, _logTag)
	if not barn then
		return
	end
	local barnHalfExtent: number = BiomeUtils.footprintRadius(barn)

	local barnGround: Vector3? = nil
	for _ = 1, BiomeUtils.placementAttempts do
		local candidate: Vector3? = ctx.randomOffPathGround(minCZ, maxCZ)
		if not candidate then
			break
		end
		if ctx.keepouts:isClear(candidate.X, candidate.Z, _barnClearRadius) then
			barnGround = candidate
			break
		end
	end
	if not barnGround then
		barn:Destroy()
		return
	end

	local bx: number, bz: number = barnGround.X, barnGround.Z
	local barnAngle: number = seed:NextNumber(0, 360)
	BiomeUtils.placeModel(ctx.container, barn, barnGround, barnAngle)
	ctx.keepouts:add(bx, bz, barnHalfExtent + 15)

	local siloRad: number = math.rad(barnAngle + 90)
	local siloDist: number = barnHalfExtent + seed:NextNumber(5, 10)
	local siloGround: Vector3? = ctx.findGround(
		bx + math.cos(siloRad) * siloDist,
		bz + math.sin(siloRad) * siloDist
	)
	if siloGround then
		local silo: Model? = BiomeUtils.cloneAsset(ctx.assets, "Silo", _logTag)
		if silo then
			local siloR: number = BiomeUtils.footprintRadius(silo)
			BiomeUtils.placeModel(ctx.container, silo, siloGround, barnAngle)
			ctx.keepouts:add(siloGround.X, siloGround.Z, siloR + 5)
		end
	end

	local tractorRad: number = math.rad(barnAngle + seed:NextNumber(150, 210))
	local tractorDist: number = barnHalfExtent + seed:NextNumber(3, 7)
	local tractorGround: Vector3? = ctx.findGround(
		bx + math.cos(tractorRad) * tractorDist,
		bz + math.sin(tractorRad) * tractorDist
	)
	if tractorGround then
		local tractor: Model? = BiomeUtils.cloneAsset(ctx.assets, "Tractor", _logTag)
		if tractor then
			local tractorR: number = BiomeUtils.footprintRadius(tractor)
			BiomeUtils.placeModel(ctx.container, tractor, tractorGround, seed:NextNumber(0, 360))
			ctx.keepouts:add(tractorGround.X, tractorGround.Z, tractorR + 3)
		end
	end

	BiomeUtils.placeAdjacentChest(ctx, {
		anchor = barnGround,
		baseOffset = barnHalfExtent,
		minDist = 3,
		maxDist = 8,
		biomeName = _biomeName,
		logTag = _logTag,
	})
end

local function generateFields(ctx: BiomeContext): ()
	local seed: Random = ctx.seed
	local fieldCount: number = seed:NextInteger(4, 6)
	for _ = 1, fieldCount do
		local fieldGround: Vector3? = ctx.randomOffPathGround(ctx.biomeMinZ + 5, ctx.biomeMaxZ - 5)
		if not fieldGround then
			continue
		end
		if BiomeUtils.isOnRoad(fieldGround) or BiomeUtils.isOnWater(fieldGround) then
			continue
		end
		if BiomeUtils.pathChunkDistance(ctx, fieldGround.X, fieldGround.Z) < _fieldMinPathChunks then
			continue
		end
		if not ctx.keepouts:isClear(fieldGround.X, fieldGround.Z, _fieldClearRadius) then
			continue
		end

		local farmTemplate: Model? = BiomeUtils.cloneAsset(ctx.assets, "Farm", _logTag)
		if not farmTemplate then
			continue
		end
		local farmExtents: Vector3 = farmTemplate:GetExtentsSize()
		local fAngle: number = seed:NextNumber(0, math.pi * 0.5)
		local margin: number = 3
		local fw: number = farmExtents.X + margin * 2
		local fd: number = farmExtents.Z + margin * 2

		local cosA: number = math.cos(fAngle)
		local sinA: number = math.sin(fAngle)
		local hw: number = fw / 2
		local hd: number = fd / 2
		local footprintBlocked: boolean = false
		for _, offset: { number } in {
			{ hw * cosA - hd * sinA, hw * sinA + hd * cosA },
			{ -hw * cosA - hd * sinA, -hw * sinA + hd * cosA },
			{ hw * cosA + hd * sinA, hw * sinA - hd * cosA },
			{ -hw * cosA + hd * sinA, -hw * sinA - hd * cosA },
		} do
			local cornerX: number = fieldGround.X + offset[1]
			local cornerZ: number = fieldGround.Z + offset[2]
			if not ctx.keepouts:isClear(cornerX, cornerZ, 0) then
				footprintBlocked = true
				break
			end
			local cg: Vector3? = ctx.findGround(cornerX, cornerZ)
			if cg and (BiomeUtils.isOnRoad(cg) or BiomeUtils.isOnWater(cg)) then
				footprintBlocked = true
				break
			end
		end
		if footprintBlocked then
			farmTemplate:Destroy()
			continue
		end

		workspace.Terrain:FillBlock(
			CFrame.new(fieldGround.X, fieldGround.Y - 3, fieldGround.Z) * CFrame.Angles(0, fAngle, 0),
			Vector3.new(fw, 6, fd),
			Enum.Material.Mud
		)

		local fieldRadius: number = math.max(fw, fd) / 2 + 4
		ctx.keepouts:add(fieldGround.X, fieldGround.Z, fieldRadius)

		local refreshedGround: Vector3? = ctx.findGround(fieldGround.X, fieldGround.Z)
		if refreshedGround then
			BiomeUtils.placeModel(ctx.container, farmTemplate, refreshedGround, math.deg(fAngle))
			farmTemplate:SetAttribute(ForageConfig.kindAttribute, "Farm")
			CollectionService:AddTag(farmTemplate, ForageConfig.tag)
		else
			farmTemplate:Destroy()
		end
	end
end

local function generateFeatures(ctx: BiomeContext): ()
	local bands: { { min: number, max: number } } = BiomeUtils.shuffledBands(ctx, 2)

	local barnNames: { string } = BiomeUtils.sample(ctx.seed, { "Barn 1", "Barn 2", "Barn 3", "Barn 4" }, 2)
	generateBarnstead(ctx, barnNames[1], bands[1].min, bands[1].max)
	generateBarnstead(ctx, barnNames[2], bands[2].min, bands[2].max)
	BiomeUtils.placeScatteredChests(ctx, 1, 2, _biomeName)
	generateFields(ctx)
	BiomeUtils.carvePond(ctx, {
		minCZ = ctx.biomeMinZ + 5,
		maxCZ = ctx.biomeMaxZ - 5,
		bankMaterial = Enum.Material.Mud,
		lobed = true,
		logTag = _logTag,
	})
end

return {
	Name = _biomeName,
	PropFolder = "Farmland",
	TerrainType = Enum.Material.Grass,
	hillScale = 0,
	sideRiseScale = 0.6,
	PropChance = {
		["None"] = 1000,
		["Bush"] = 4,
		["Trees"] = 2,
		["Plants"] = 15,
		["Grapes"] = 1,
	},
	generateFeatures = generateFeatures,
} :: BiomeTypes.Biome
