--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeTypes = require(ReplicatedStorage.Shared.types.BiomeTypes)
local _campfireConfig = require(ReplicatedStorage.Shared.config.CampfireConfig)
local _mapGenerationConfig = require(ReplicatedStorage.Shared.config.MapGenerationConfig)
local _scavengeConfig = require(ReplicatedStorage.Shared.config.ScavengeConfig)

type BiomeContext = BiomeTypes.BiomeContext
type KeepoutRegistry = BiomeTypes.KeepoutRegistry

local _chestKeepoutRadius: number = 7
local _campfireTag: string = "Campfire"
local _chestTag: string = "Chest"
local _waterResourceTag: string = "WaterResource"

local _rayParams: RaycastParams = RaycastParams.new()
_rayParams.FilterType = Enum.RaycastFilterType.Include
_rayParams.FilterDescendantsInstances = { workspace.Terrain }

local BiomeUtils = {}

BiomeUtils.placementAttempts = 10

-- `count` distinct random entries from `pool`, seeded per-server. Returns the whole
-- pool shuffled when it holds fewer than `count`.
function BiomeUtils.sample(seed: Random, pool: { string }, count: number): { string }
	local copy: { string } = table.clone(pool)
	for i = #copy, 2, -1 do
		local j: number = seed:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	local result: { string } = {}
	for i = 1, math.min(count, #copy) do
		result[i] = copy[i]
	end
	return result
end

function BiomeUtils.footprintRadius(model: Model): number
	local extents: Vector3 = model:GetExtentsSize()
	return math.max(extents.X, extents.Z) / 2
end

function BiomeUtils.cloneAsset(assets: Instance, name: string, logTag: string): Model?
	local sub: Instance? = assets:FindFirstChild(name)
	if not sub then
		warn(`[{logTag}] Asset folder "{name}" not found`)
		return nil
	end
	local template: Model? = sub:FindFirstChildWhichIsA("Model")
	if not template then
		warn(`[{logTag}] No Model inside folder "{name}"`)
		return nil
	end
	return template:Clone() :: Model
end

function BiomeUtils.placeModel(container: Instance, model: Model, groundPos: Vector3, angleDeg: number): ()
	local rot: CFrame = CFrame.Angles(0, math.rad(angleDeg), 0)
	model:PivotTo(CFrame.new(groundPos) * rot)
	local bbCF: CFrame, bbSize: Vector3 = model:GetBoundingBox()
	local bottomY: number = bbCF.Y - bbSize.Y / 2
	local liftY: number = groundPos.Y - bottomY
	model:PivotTo(CFrame.new(groundPos + Vector3.new(0, liftY, 0)) * rot)
	model.Parent = container
end

local function groundMaterial(pos: Vector3): Enum.Material?
	local ray: RaycastResult? = workspace:Raycast(
		Vector3.new(pos.X, pos.Y + 15, pos.Z),
		Vector3.new(0, -30, 0),
		_rayParams
	)
	return if ray then ray.Material else nil
end

function BiomeUtils.isOnRoad(pos: Vector3): boolean
	return groundMaterial(pos) == Enum.Material.Cobblestone
end

function BiomeUtils.isOnWater(pos: Vector3): boolean
	return groundMaterial(pos) == Enum.Material.Water
end

local function placeChest(
	assets: Instance,
	container: Instance,
	keepouts: KeepoutRegistry,
	groundPos: Vector3,
	angleDeg: number,
	biomeName: string
): ()
	local chest: Model? = BiomeUtils.cloneAsset(assets, "Chest", `Biome{biomeName}`)
	if not chest then
		return
	end
	chest:SetAttribute("isLootBox", true)
	chest:SetAttribute("biome", biomeName)
	CollectionService:AddTag(chest, _chestTag)
	BiomeUtils.placeModel(container, chest, groundPos, angleDeg)
	keepouts:add(groundPos.X, groundPos.Z, _chestKeepoutRadius)
end

export type AdjacentChestOptions = {
	anchor: Vector3,
	minDist: number,
	maxDist: number,
	biomeName: string,
	logTag: string,
	baseOffset: number?,
	requireOffRoad: boolean?,
	clearRadius: number?,
}

function BiomeUtils.placeAdjacentChest(ctx: BiomeContext, opts: AdjacentChestOptions): ()
	local seed: Random = ctx.seed
	local angle: number = seed:NextNumber(0, math.pi * 2)
	local dist: number = (opts.baseOffset or 0) + seed:NextNumber(opts.minDist, opts.maxDist)
	local ground: Vector3? = ctx.findGround(
		opts.anchor.X + math.cos(angle) * dist,
		opts.anchor.Z + math.sin(angle) * dist
	)
	if not ground then
		return
	end
	if opts.requireOffRoad ~= false and (BiomeUtils.isOnRoad(ground) or BiomeUtils.isOnWater(ground)) then
		return
	end
	if opts.clearRadius and not ctx.keepouts:isClear(ground.X, ground.Z, opts.clearRadius) then
		return
	end
	placeChest(ctx.assets, ctx.container, ctx.keepouts, ground, seed:NextNumber(0, 360), opts.biomeName)
end

-- Splits the biome's depth into `count` equal bands and shuffles their order per-server.
-- `startClearance` (chunks) keeps every band clear of the biome's leading edge — used by
-- the first biome so features never land on the spawn / cart-assembly area.
function BiomeUtils.shuffledBands(
	ctx: BiomeContext,
	count: number,
	margin: number?,
	startClearance: number?
): { { min: number, max: number } }
	local m: number = margin or 5
	local baseMin: number = ctx.biomeMinZ + (startClearance or 0)
	local depth: number = ctx.biomeMaxZ - baseMin
	local bandSize: number = depth / count

	local bands: { { min: number, max: number } } = {}
	for i = 1, count do
		table.insert(bands, {
			min = baseMin + (i - 1) * bandSize + m,
			max = baseMin + i * bandSize - m,
		})
	end

	for i = count, 2, -1 do
		local j: number = ctx.seed:NextInteger(1, i)
		bands[i], bands[j] = bands[j], bands[i]
	end

	return bands
end

function BiomeUtils.pathChunkDistance(ctx: BiomeContext, worldX: number, worldZ: number): number
	local chunkX: number = (worldX - ctx.startPos.X) / (ctx.chunkScale * 4)
	local chunkZ: number = (worldZ - ctx.startPos.Z) / (ctx.chunkScale * 4)
	local left: number, right: number = ctx.getRoadBounds(chunkZ)
	return math.max(left - chunkX, chunkX - right, 0)
end

-- True when the four cardinal ground samples `sampleDist` studs out span no more
-- than `maxSpread` studs in height.
local function isFlatEnough(ctx: BiomeContext, center: Vector3, sampleDist: number, maxSpread: number): boolean
	local minY: number = center.Y
	local maxY: number = center.Y
	for _, offset: Vector3 in {
		Vector3.new(sampleDist, 0, 0),
		Vector3.new(-sampleDist, 0, 0),
		Vector3.new(0, 0, sampleDist),
		Vector3.new(0, 0, -sampleDist),
	} do
		local ground: Vector3? = ctx.findGround(center.X + offset.X, center.Z + offset.Z)
		if not ground then
			return false
		end
		minY = math.min(minY, ground.Y)
		maxY = math.max(maxY, ground.Y)
	end
	return maxY - minY <= maxSpread
end

local function _isValidCampsiteGround(ctx: BiomeContext, candidate: Vector3, clearRadius: number): boolean
	return not BiomeUtils.isOnRoad(candidate)
		and not BiomeUtils.isOnWater(candidate)
		and ctx.keepouts:isClear(candidate.X, candidate.Z, clearRadius)
		and isFlatEnough(ctx, candidate, _campfireConfig.safeRadius * 0.5, _campfireConfig.maxSlopeSpread)
end

local function placeCampsite(ctx: BiomeContext, floorPos: Vector3, logTag: string, isCave: boolean?): ()
	local clearing: Region3 = Region3.new(floorPos - Vector3.new(15, 8, 15), floorPos + Vector3.new(15, 4, 15)):ExpandToGrid(4)
	workspace.Terrain:ReplaceMaterial(clearing, 4, Enum.Material.Grass, Enum.Material.LeafyGrass)
	local campfire: Model? = BiomeUtils.cloneAsset(ctx.assets, "Camp Fire", logTag)
	if campfire then
		campfire:SetAttribute("campfireGroundPosition", floorPos)
		campfire:SetAttribute("safeRadius", _campfireConfig.safeRadius)
		campfire:SetAttribute("safeHalfHeight", _campfireConfig.safeHalfHeight)
		campfire:SetAttribute("isCaveCampsite", isCave == true)
		BiomeUtils.placeModel(ctx.container, campfire, floorPos, 0)
		CollectionService:AddTag(campfire, _campfireTag)
	end
	for _, angleDeg: number in { 0, 120, 240 } do
		local rad: number = math.rad(angleDeg)
		local offset: Vector3 = Vector3.new(math.cos(rad) * 5, 0, math.sin(rad) * 5)
		local chair: Model? = BiomeUtils.cloneAsset(ctx.assets, "Chair", logTag)
		if chair then
			BiomeUtils.placeModel(ctx.container, chair, floorPos + offset, angleDeg + 180)
		end
	end
end

export type OpenCampsiteOptions = {
	minCZ: number,
	maxCZ: number,
	biomeName: string,
	logTag: string,
	searchClearRadius: number?,
	keepoutRadius: number?,
	chestMinDist: number?,
	chestMaxDist: number?,
	attempts: number?,
}

function BiomeUtils.placeOpenCampsite(ctx: BiomeContext, opts: OpenCampsiteOptions): ()
	local ground: Vector3? = nil
	for _ = 1, opts.attempts or BiomeUtils.placementAttempts do
		local candidate: Vector3? = ctx.randomOffPathGround(opts.minCZ, opts.maxCZ)
		if not candidate then
			break
		end
		if _isValidCampsiteGround(ctx, candidate, opts.searchClearRadius or _campfireConfig.keepoutRadius) then
			ground = candidate
			break
		end
	end
	if not ground then
		return
	end

	ctx.keepouts:add(ground.X, ground.Z, opts.keepoutRadius or 12)
	placeCampsite(ctx, ground, opts.logTag)
	BiomeUtils.placeAdjacentChest(ctx, {
		anchor = ground,
		minDist = opts.chestMinDist or 9,
		maxDist = opts.chestMaxDist or 14,
		biomeName = opts.biomeName,
		logTag = opts.logTag,
	})
end


-- Tops up a biome to its guaranteed campfire count, spacing them along the path.
-- Open-field campsites already placed by the biome's generateFeatures count toward
-- the quota; cave campsites do not.
function BiomeUtils.placeGuaranteedCampsites(ctx: BiomeContext, logTag: string): ()
	local minWorldZ: number = ctx.startPos.Z + ctx.biomeMinZ * ctx.chunkScale * 4
	local maxWorldZ: number = ctx.startPos.Z + ctx.biomeMaxZ * ctx.chunkScale * 4

	local existing: number = 0
	for _, instance: Instance in CollectionService:GetTagged(_campfireTag) do
		if not instance:IsA("Model") or instance:GetAttribute("isCaveCampsite") then
			continue
		end
		local z: number = instance:GetPivot().Position.Z
		if z >= minWorldZ and z < maxWorldZ then
			existing += 1
		end
	end

	local target: number = ctx.seed:NextInteger(_campfireConfig.campfiresPerBiome.min, _campfireConfig.campfiresPerBiome.max)
	local needed: number = target - existing
	if needed <= 0 then
		return
	end

	local segmentSize: number = (ctx.biomeMaxZ - ctx.biomeMinZ) / needed
	for i = 1, needed do
		local segMinCZ: number = ctx.biomeMinZ + (i - 1) * segmentSize + 2
		local segMaxCZ: number = ctx.biomeMinZ + i * segmentSize - 2

		local ground: Vector3? = nil
		for _ = 1, _campfireConfig.placementAttempts do
			local candidate: Vector3? = ctx.randomOffPathGround(segMinCZ, segMaxCZ)
			if not candidate then
				continue
			end
			if not _isValidCampsiteGround(ctx, candidate, _campfireConfig.keepoutRadius) then
				continue
			end
			ground = candidate
			break
		end
		if not ground then
			warn(`[{logTag}] No valid spot for guaranteed campfire {i}/{needed}`)
			continue
		end

		ctx.keepouts:add(ground.X, ground.Z, _campfireConfig.keepoutRadius)
		placeCampsite(ctx, ground, logTag)
	end
end

export type PlaceHousesOptions = {
	subSegment: boolean?, -- give each house its own Z slice of [minCZ, maxCZ] so they spread out
	minGap: number?, -- extra studs reserved around each house on top of its footprint radius
	minPathOffset: number?, -- chunks off-path to search; defaults to randomOffPathGround's own range
	maxPathOffset: number?,
}

function BiomeUtils.placeHouses(
	ctx: BiomeContext,
	housePool: { string },
	count: number,
	minCZ: number,
	maxCZ: number,
	biomeName: string,
	logTag: string,
	opts: PlaceHousesOptions?
): ()
	local seed: Random = ctx.seed
	local minGap: number = if opts then opts.minGap or 0 else 0
	local subSegment: boolean = if opts then opts.subSegment == true else false
	local minPathOffset: number? = if opts then opts.minPathOffset else nil
	local maxPathOffset: number? = if opts then opts.maxPathOffset else nil
	local segmentSize: number = (maxCZ - minCZ) / count

	for i, houseName: string in BiomeUtils.sample(seed, housePool, count) do
		local house: Model? = BiomeUtils.cloneAsset(ctx.assets, houseName, logTag)
		if not house then
			continue
		end
		local extents: Vector3 = house:GetExtentsSize()
		local houseRadius: number = math.max(extents.X, extents.Z) / 2 + 5
		local clearRadius: number = houseRadius + minGap

		local segMinCZ: number = if subSegment then minCZ + (i - 1) * segmentSize else minCZ
		local segMaxCZ: number = if subSegment then minCZ + i * segmentSize else maxCZ

		local houseGround: Vector3? = nil
		local maxAttempts: number = if subSegment then 14 else 10
		for attempt = 1, maxAttempts do
			local wide: boolean = subSegment and attempt > 10
			local searchMinCZ: number = if wide then minCZ else segMinCZ
			local searchMaxCZ: number = if wide then maxCZ else segMaxCZ
			local candidate: Vector3? = ctx.randomOffPathGround(searchMinCZ, searchMaxCZ, minPathOffset, maxPathOffset)
			if not candidate then
				break
			end
			if ctx.keepouts:isClear(candidate.X, candidate.Z, clearRadius) then
				houseGround = candidate
				break
			end
		end
		if not houseGround then
			house:Destroy()
			continue
		end

		ctx.keepouts:add(houseGround.X, houseGround.Z, clearRadius)
		BiomeUtils.placeModel(ctx.container, house, houseGround, seed:NextNumber(0, 360))
		CollectionService:AddTag(house, _scavengeConfig.tag)

		local chestAngle: number = seed:NextNumber(0, math.pi * 2)
		local chestDist: number = houseRadius + seed:NextNumber(3, 8)
		local chestGround: Vector3? = ctx.findGround(
			houseGround.X + math.cos(chestAngle) * chestDist,
			houseGround.Z + math.sin(chestAngle) * chestDist
		)
		if chestGround and not BiomeUtils.isOnRoad(chestGround) and not BiomeUtils.isOnWater(chestGround) then
			placeChest(ctx.assets, ctx.container, ctx.keepouts, chestGround, seed:NextNumber(0, 360), biomeName)
		end
	end
end

function BiomeUtils.placeScatteredChests(ctx: BiomeContext, minCount: number, maxCount: number, biomeName: string): ()
	local seed: Random = ctx.seed
	for _ = 1, seed:NextInteger(minCount, maxCount) do
		local chestGround: Vector3? = ctx.randomOffPathGround(ctx.biomeMinZ + 5, ctx.biomeMaxZ - 5)
		if not chestGround then
			continue
		end
		if BiomeUtils.isOnRoad(chestGround) or BiomeUtils.isOnWater(chestGround) then
			continue
		end
		if not ctx.keepouts:isClear(chestGround.X, chestGround.Z, 7) then
			continue
		end
		placeChest(ctx.assets, ctx.container, ctx.keepouts, chestGround, seed:NextNumber(0, 360), biomeName)
	end
end

export type PondOptions = {
	minCZ: number,
	maxCZ: number,
	logTag: string,
	radius: number?, -- default 22
	bankMaterial: Enum.Material?,
	bankWidth: number?, -- default 5
	lobed: boolean?,
	shorePropName: string?,
	attempts: number?,
	minPathOffset: number?, -- chunks off-path to search; default 6 (randomOffPathGround's own default)
	maxPathOffset: number?, -- default 20
}
local function _isValleyPondSite(ctx: BiomeContext, center: Vector3, footprint: number): boolean
	local chunkStuds: number = ctx.chunkScale * 4
	local valleyHalfWidth: number = ctx.halfWidth * chunkStuds * _mapGenerationConfig.pondMaxWidthFraction
	if
		math.abs(center.X - ctx.startPos.X) + footprint >= valleyHalfWidth
		or center.Z - footprint < ctx.startPos.Z + ctx.biomeMinZ * chunkStuds
		or center.Z + footprint > ctx.startPos.Z + ctx.biomeMaxZ * chunkStuds
	then
		return false
	end
	local minimum: number, maximum: number = center.Y, center.Y
	local steps: number = math.ceil(footprint * 2 / 8)
	-- Include the banks and clearing square so a valid center cannot hide a hillside or road overlap.
	for z = 0, steps do
		local worldZ: number = center.Z - footprint + z / steps * footprint * 2
		local left: number, right: number = ctx.getRoadBounds((worldZ - ctx.startPos.Z) / chunkStuds)
		if
			center.X + footprint >= ctx.startPos.X + left * chunkStuds - _mapGenerationConfig.roadShoulderWidth
			and center.X - footprint <= ctx.startPos.X + right * chunkStuds + _mapGenerationConfig.roadShoulderWidth
		then
			return false
		end
		for x = 0, steps do
			local ground: Vector3? = ctx.findGround(center.X - footprint + x / steps * footprint * 2, worldZ)
			if not ground or ground.Y > ctx.startPos.Y + _mapGenerationConfig.pondMaxElevation then
				return false
			end
			minimum, maximum = math.min(minimum, ground.Y), math.max(maximum, ground.Y)
			if maximum - minimum > _mapGenerationConfig.pondMaxHeightSpread then
				return false
			end
		end
	end
	return true
end

function BiomeUtils.carvePond(ctx: BiomeContext, opts: PondOptions): Vector3?
	local seed: Random = ctx.seed
	local radius: number = opts.radius or seed:NextNumber(18, 26)
	local bankWidth: number = opts.bankWidth or 5
	local bankMaterial: Enum.Material = opts.bankMaterial or Enum.Material.Mud
	local footprint: number = math.max(radius + bankWidth + 5, radius * 1.15 + 4)
	local keepoutRadius: number = footprint * math.sqrt(2)

	local center: Vector3? = nil
	for _ = 1, opts.attempts or 24 do
		local candidate: Vector3? =
			ctx.randomOffPathGround(opts.minCZ, opts.maxCZ, opts.minPathOffset, opts.maxPathOffset)
		if not candidate then
			continue
		end
		if
			ctx.keepouts:isClear(candidate.X, candidate.Z, keepoutRadius)
			and _isValleyPondSite(ctx, candidate, footprint)
		then
			center = candidate
			break
		end
	end
	if not center then
		return nil
	end

	local wx: number, wy: number, wz: number = center.X, center.Y, center.Z
	local waterLevel: number = wy - 1
	ctx.keepouts:add(wx, wz, keepoutRadius)

	workspace.Terrain:FillCylinder(
		CFrame.new(wx, wy - 1, wz),
		5,
		radius + bankWidth,
		bankMaterial
	)
	workspace.Terrain:FillBall(Vector3.new(wx, wy + 3, wz), radius, Enum.Material.Air)
	workspace.Terrain:FillBall(Vector3.new(wx, waterLevel - 6, wz), radius - 2, Enum.Material.Water)

	if opts.lobed then
		local lobeCount: number = seed:NextInteger(3, 5)
		for _ = 1, lobeCount do
			local lobeAngle: number = seed:NextNumber(0, math.pi * 2)
			local lobeDist: number = seed:NextNumber(radius * 0.2, radius * 0.55)
			local lobeRadius: number = seed:NextNumber(radius * 0.35, radius * 0.6)
			local lx: number = wx + math.cos(lobeAngle) * lobeDist
			local lz: number = wz + math.sin(lobeAngle) * lobeDist
			workspace.Terrain:FillBall(Vector3.new(lx, wy + 3, lz), lobeRadius, Enum.Material.Air)
			workspace.Terrain:FillBall(Vector3.new(lx, waterLevel - 6, lz), lobeRadius - 2, Enum.Material.Water)
		end
	end

	workspace.Terrain:FillBlock(
		CFrame.new(wx, waterLevel + 22, wz),
		Vector3.new((radius + bankWidth + 5) * 2, 44, (radius + bankWidth + 5) * 2),
		Enum.Material.Air
	)

	local gatherZone: Part = Instance.new("Part")
	gatherZone.Name = "WaterGatherZone"
	gatherZone.Size = Vector3.new(radius * 2, 4, radius * 2)
	gatherZone.CFrame = CFrame.new(wx, waterLevel, wz)
	gatherZone.Anchored = true
	gatherZone.CanCollide = false
	gatherZone.CanTouch = false
	gatherZone.CastShadow = false
	gatherZone.Transparency = 1
	-- Where the water ball (radius - 2, centred 6 below the surface) meets the surface.
	gatherZone:SetAttribute("shoreRadius", math.sqrt(math.max((radius - 2) ^ 2 - 36, 0)))
	gatherZone.Parent = ctx.container
	CollectionService:AddTag(gatherZone, _waterResourceTag)

	task.wait()

	local shorePropName: string? = opts.shorePropName
	if shorePropName then
		for a = 0, 3 do
			local ang: number = (a / 4) * math.pi * 2 + seed:NextNumber(-0.3, 0.3)
			local r: number = radius * seed:NextNumber(0.95, 1.2)
			local shore: Vector3? = ctx.findGround(wx + math.cos(ang) * r, wz + math.sin(ang) * r)
			if shore then
				local prop: Model? = BiomeUtils.cloneAsset(ctx.assets, shorePropName, opts.logTag)
				if prop then
					BiomeUtils.placeModel(ctx.container, prop, shore, seed:NextNumber(0, 360))
				end
			end
		end
	end

	return center
end

return BiomeUtils
