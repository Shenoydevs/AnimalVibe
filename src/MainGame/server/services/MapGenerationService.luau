--!strict
local _collectionService = game:GetService("CollectionService")
local _players = game:GetService("Players")
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _runService = game:GetService("RunService")
local _serverScriptService = game:GetService("ServerScriptService")

local _troveModule = require(_replicatedStorage.Packages.Trove)
local _gameSignals = require(_serverScriptService.Server.signals.GameSignals)
local _biomeTypes = require(_replicatedStorage.Shared.types.BiomeTypes)
local _biomeUtils = require(_replicatedStorage.Shared.utils.BiomeUtils)
local _keepoutRegistry = require(_replicatedStorage.Shared.utils.KeepoutRegistry)
local _mapConfig = require(_replicatedStorage.Shared.config.MapConfig)
local _config = require(_replicatedStorage.Shared.config.MapGenerationConfig)
local _caveConfig = require(_replicatedStorage.Shared.config.CaveGenerationConfig)
local _forageConfig = require(_replicatedStorage.Shared.config.ForageConfig)
local _terrainSurface = require(script.Parent.Parent.utils.TerrainSurface)
local _terrainWriter = require(script.Parent.Parent.utils.TerrainWriter)
local _caveGenerator = require(script.Parent.Parent.utils.CaveGenerator)
local _cavePopulation = require(script.Parent.Parent.utils.CavePopulation)

type biome = _biomeTypes.Biome
type streamRun = { x: number, lastX: number, z: number }
type propTemplate = { model: Model, halfHeight: number }
type weightedCategory = { name: string, ceiling: number }
type biomeCache = { totalWeight: number, weights: { weightedCategory }, models: { [string]: { propTemplate } } }
type populationChunk = {
	x: number,
	z: number,
	category: string,
	random: Random,
	biome: biome,
	templates: { propTemplate },
}
type populationRow = { left: number, right: number, biome: biome, cache: biomeCache }

local _biomes: { biome } = _mapConfig.biomeSequence
local _chunkStuds: number = _config.chunkScale * 4
local _halfWidth: number = 0
local _biomeDepth: number = _mapConfig.biomeDepth.min
local _mapDepth: number = 0
local _startPos: Vector3 = Vector3.zero
local _seed: number = 0
local _generationSeed: Random = Random.new()
local _rayTop: number = 0
local _surface: _terrainSurface.terrainSurface? = nil
local _caves: _caveGenerator.caveGenerator? = nil
local _trove = _troveModule.new()
local _chunks: { [string]: boolean } = {}
local _terrainRegions: { Region3 } = {}
local _pendingPopulation: { populationChunk } = {}
-- Props wait here until the features that could overlap them exist, keyed by the biome that must be featured first.
local _blockedPopulation: { [number]: { populationChunk } } = {}
local _populationRows: { [number]: populationRow } = {}

-- TaskQueue flushes an entire batch on defer; these cursors carry unfinished work across frame budgets.
local _populationHead: number = 1
local _streamQueue: { streamRun } = {}
local _streamQueued: { [string]: boolean } = {}
local _streamHead: number = 1
local _keepouts: _keepoutRegistry.KeepoutRegistry = _keepoutRegistry.new()
local _biomeFolders: { [string]: Folder } = {}
local _biomeCaches: { [string]: biomeCache } = {}
local _biomeIndices: { [string]: number } = {}
local _featuredBiomes: number = 0
local _pregenComplete: boolean = false
local _session: number = 0
local _cancelled: boolean = true
local _caveAssets: { [string]: _cavePopulation.assetCache } = {}

local _params: RaycastParams = RaycastParams.new()
_params.FilterType = Enum.RaycastFilterType.Include
_params.FilterDescendantsInstances = { workspace.Terrain }
_params.IgnoreWater = false

local mapGenerationService = {}

local function _getSurface(): _terrainSurface.terrainSurface
	local surface = _surface
	assert(surface, "Terrain surface has not been initialized")
	return surface
end

local function _getCaves(): _caveGenerator.caveGenerator
	local caves = _caves
	assert(caves, "Cave layout has not been initialized")
	return caves
end

local function _chunkKey(x: number, z: number): string
	return `{x}:{z}`
end

local function _biomeIndexAt(chunkZ: number): number
	return math.clamp(math.floor(chunkZ / _biomeDepth) + 1, 1, #_biomes)
end

local function _getBiome(chunkZ: number): biome
	return _biomes[_biomeIndexAt(chunkZ)]
end

local function _getPathCenter(chunkZ: number): number
	return _getSurface():getPathCenter(chunkZ)
end

local function _getRoadBounds(chunkZ: number): (number, number)
	return _getSurface():getRoadBounds(chunkZ)
end

local function _findGround(worldX: number, worldZ: number): Vector3?
	local ray: RaycastResult? = workspace:Raycast(
		Vector3.new(worldX, _rayTop, worldZ),
		Vector3.new(0, -(_rayTop - _startPos.Y + 512), 0),
		_params
	)
	return if ray then ray.Position else nil
end

local function _randomOffPathGround(minCZ: number, maxCZ: number, minOffset: number?, maxOffset: number?): Vector3?
	for _ = 1, 15 do
		local cz: number = _generationSeed:NextInteger(math.ceil(minCZ), math.floor(maxCZ))
		local side: number = if _generationSeed:NextNumber() > 0.5 then 1 else -1
		local cx: number = math.clamp(
			_getPathCenter(cz) + side * _generationSeed:NextNumber(minOffset or 6, maxOffset or 20),
			-_halfWidth + 3,
			_halfWidth - 3
		)
		local ground: Vector3? = _findGround(_startPos.X + cx * _chunkStuds, _startPos.Z + cz * _chunkStuds)
		if ground then
			return ground
		end
	end
	return nil
end

local function _collectModels(node: Instance, out: { propTemplate }): ()
	for _, child in node:GetChildren() do
		if child:IsA("Model") then
			table.insert(out, { model = child, halfHeight = child:GetExtentsSize().Y / 2 })
		else
			_collectModels(child, out)
		end
	end
end

local function _buildBiomeCaches(): ()
	for index, biome in _biomes do
		assert(not _biomeIndices[biome.Name], `Duplicate biome name: {biome.Name}`)
		_biomeIndices[biome.Name] = index
		local cache: biomeCache = { totalWeight = 0, weights = {}, models = {} }
		local categories: { string } = {}
		for category in biome.PropChance do
			table.insert(categories, category)
		end
		table.sort(categories)
		local folder: Instance? = _replicatedStorage.Assets:FindFirstChild(biome.PropFolder)
		assert(folder, `Missing biome assets: {biome.PropFolder}`)
		for _, category in categories do
			assert(biome.PropChance[category] >= 0, `Negative prop weight: {biome.Name}/{category}`)
			cache.totalWeight += biome.PropChance[category]
			table.insert(cache.weights, { name = category, ceiling = cache.totalWeight })
			local assets: Instance? = if folder then folder:FindFirstChild(category) else nil
			if assets then
				local templates: { propTemplate } = {}
				_collectModels(assets, templates)
				table.sort(templates, function(a: propTemplate, b: propTemplate): boolean
					return a.model:GetFullName() < b.model:GetFullName()
				end)
				cache.models[category] = templates
			end
		end
		assert(cache.totalWeight > 0, `No prop weights for {biome.Name}`)
		_biomeCaches[biome.Name] = cache
	end
end

local function _pickCategory(cache: biomeCache, random: Random): string
	local roll: number = random:NextNumber(0, cache.totalWeight)
	local lo: number, hi: number = 1, #cache.weights
	while lo < hi do
		local mid: number = math.floor((lo + hi) / 2)
		if roll <= cache.weights[mid].ceiling then
			hi = mid
		else
			lo = mid + 1
		end
	end
	return cache.weights[lo].name
end

local function _makeBudget(session: number): () -> ()
	local deadline: number = os.clock() + _config.budgetMs / 1000
	return function(): ()
		assert(not _cancelled and session == _session, "Map generation cancelled")
		if os.clock() >= deadline then
			task.wait()
			assert(not _cancelled and session == _session, "Map generation cancelled")
			deadline = os.clock() + _config.budgetMs / 1000
		end
	end
end

local function _queuePopulation(x: number, z: number): ()
	local row: populationRow? = _populationRows[z]
	if not row then
		local left: number, right: number = _getRoadBounds(z + 0.5)
		local biome: biome = _getBiome(z)
		row = {
			left = left - _config.roadShoulderWidth / _chunkStuds,
			right = right + _config.roadShoulderWidth / _chunkStuds,
			biome = biome,
			cache = _biomeCaches[biome.Name],
		}
		_populationRows[z] = row
	end
	if x + 1 >= row.left and x <= row.right then
		return
	end
	local random: Random = Random.new((_seed + x * 73856093 + z * 19349663) % 2147483647)
	local category: string = _pickCategory(row.cache, random)
	local templates: { propTemplate }? = row.cache.models[category]
	if category == "None" or not templates or #templates == 0 then
		return
	end
	-- Keep the per-chunk RNG after its category roll so later template/rotation choices stay identical.
	local pending: populationChunk = {
		x = x,
		z = z,
		category = category,
		random = random,
		biome = row.biome,
		templates = templates,
	}
	local gate: number = _biomeIndexAt(z + _config.featureMarginChunks)
	if gate <= _featuredBiomes then
		table.insert(_pendingPopulation, pending)
	else
		local blocked: { populationChunk } = _blockedPopulation[gate] or {}
		_blockedPopulation[gate] = blocked
		table.insert(blocked, pending)
	end
end

-- Only batch unwritten chunks so streaming cannot overwrite finished terrain or features.
local function _makeChunks(firstX: number, lastX: number, z: number): ()
	local x: number = firstX
	while x <= lastX do
		if _chunks[_chunkKey(x, z)] then
			x += 1
			continue
		end
		local endX: number = x
		while endX < lastX and endX - x + 1 < _config.terrainBatchChunks and not _chunks[_chunkKey(endX + 1, z)] do
			endX += 1
		end
		table.insert(_terrainRegions, _terrainWriter.writeChunks(_getSurface(), _getCaves(), _startPos, x, z, endX))
		for cx = x, endX do
			_chunks[_chunkKey(cx, z)] = true
			if z <= _mapDepth then
				_queuePopulation(cx, z)
			end
		end
		x = endX + 1
	end
end

local function _populateChunk(chunk: populationChunk): ()
	local x: number, z: number = chunk.x, chunk.z
	local biome: biome = chunk.biome
	local random: Random = chunk.random
	local category: string = chunk.category
	local templates: { propTemplate } = chunk.templates
	local worldX: number = _startPos.X + (x + 0.5) * _chunkStuds
	local worldZ: number = _startPos.Z + (z + 0.5) * _chunkStuds
	if not _keepouts:isClear(worldX, worldZ, _config.propClearRadius) then
		return
	end
	if (category == "Grass" or category == "Plants") and not _getSurface():grassPatch(worldX, worldZ) then
		return
	end
	local ray: RaycastResult? = workspace:Raycast(
		Vector3.new(worldX, _rayTop, worldZ),
		Vector3.new(0, -(_rayTop - _startPos.Y + 512), 0),
		_params
	)
	-- Features alter the finished surface; the original height field cannot describe their collision geometry.
	if not ray or _config.propSkipMaterials[ray.Material] or ray.Normal.Y < 0.75 then
		return
	end
	local template: propTemplate = templates[random:NextInteger(1, #templates)]
	local prop: Model = template.model:Clone()
	if category == "Trees" then
		prop:SetAttribute("treeVariant", template.model.Name)
	elseif _forageConfig.kinds[category] then
		prop:SetAttribute(_forageConfig.kindAttribute, category)
		_collectionService:AddTag(prop, _forageConfig.tag)
	end
	prop.Name = `{x}|{z}`
	prop:PivotTo(
		CFrame.new(ray.Position + Vector3.new(0, template.halfHeight - math.min(template.halfHeight * 0.3, 2), 0))
			* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	)
	prop.Parent = _biomeFolders[biome.Name]
end

local function _queueStreamRow(firstX: number, lastX: number, z: number): ()
	local runStart: number? = nil
	for cx = firstX, lastX do
		local key: string = _chunkKey(cx, z)
		if _chunks[key] or _streamQueued[key] then
			if runStart then
				table.insert(_streamQueue, { x = runStart, lastX = cx - 1, z = z })
				runStart = nil
			end
			continue
		end
		_streamQueued[key] = true
		local start: number = runStart or cx
		runStart = start
		if cx - start + 1 >= _config.terrainBatchChunks or cx == lastX then
			table.insert(_streamQueue, { x = start, lastX = cx, z = z })
			runStart = nil
		end
	end
end

local function _checkSurroundings(location: Vector3): ()
	local x: number = math.floor((location.X - _startPos.X) / _chunkStuds)
	local z: number = math.floor((location.Z - _startPos.Z) / _chunkStuds)
	local radius: number = math.ceil(_config.renderDistance / _chunkStuds)
	if _pregenComplete and x - radius >= -_halfWidth and x + radius <= _halfWidth and z + radius <= _mapDepth then
		return
	end
	-- Rows nearest the player first, ahead before behind, each queued as batched runs rather than single chunks.
	for step = 0, radius * 2 do
		local dz: number = if step % 2 == 1 then (step + 1) / 2 else -(step / 2)
		local cz: number = z + dz
		if cz < 0 then
			continue
		end
		local span: number = math.floor(math.sqrt(radius * radius - dz * dz))
		_queueStreamRow(x - span, x + span, cz)
	end
end

local function _biomeContext(index: number, assets: Instance): _biomeTypes.BiomeContext
	return {
		startPos = _startPos,
		chunkScale = _config.chunkScale,
		biomeMinZ = (index - 1) * _biomeDepth,
		biomeMaxZ = index * _biomeDepth,
		halfWidth = _halfWidth,
		seed = _generationSeed,
		assets = assets,
		container = _biomeFolders[_biomes[index].Name],
		keepouts = _keepouts,
		findGround = _findGround,
		randomOffPathGround = _randomOffPathGround,
		getPathCenter = _getPathCenter,
		getRoadBounds = _getRoadBounds,
	}
end

local function _generateBiomeFeatures(index: number): ()
	local biome: biome = _biomes[index]
	local assets: Instance? = _replicatedStorage.Assets:FindFirstChild(biome.PropFolder)
	if assets then
		local ctx: _biomeTypes.BiomeContext = _biomeContext(index, assets)
		if biome.generateFeatures then
			biome.generateFeatures(ctx)
		end
		_biomeUtils.placeGuaranteedCampsites(ctx, biome.Name)
		for _, cave in _getCaves().caves do
			if cave.biomeIndex == index then
				_cavePopulation.populate(ctx, cave, biome.Name, _caveAssets[biome.Name])
			end
		end
	end
	_featuredBiomes = index
	for _, pending in _blockedPopulation[index] or {} do
		table.insert(_pendingPopulation, pending)
	end
	_blockedPopulation[index] = nil
	_gameSignals.BiomeFeaturesGenerated:Fire(_biomeFolders[biome.Name])
end

function mapGenerationService:GetBiomeAtPosition(worldZ: number): string
	return _getBiome((worldZ - _startPos.Z) / _chunkStuds).Name
end

function mapGenerationService:GetBiomeIndex(biomeName: string): number
	return _biomeIndices[biomeName] or 1
end

local function _startGeneration(session: number): ()
	_seed = _config.seed or Random.new():NextInteger(1, 1000000)
	_generationSeed = Random.new(_seed)
	local startPart: Instance = workspace:WaitForChild("StartPart")
	assert(startPart:IsA("BasePart"), "StartPart must be a BasePart")
	_startPos = startPart.Position
	_chunks, _pendingPopulation, _streamQueue, _streamQueued = {}, {}, {}, {}
	_blockedPopulation, _populationRows = {}, {}
	_terrainRegions = {}
	_biomeFolders, _biomeCaches, _biomeIndices = {}, {}, {}
	_populationHead, _streamHead = 1, 1
	_featuredBiomes, _pregenComplete = 0, false
	_keepouts = _keepoutRegistry.new()
	_halfWidth = _generationSeed:NextInteger(_mapConfig.halfWidth.min, _mapConfig.halfWidth.max)
	_biomeDepth = _generationSeed:NextInteger(_mapConfig.biomeDepth.min, _mapConfig.biomeDepth.max)
	_mapDepth = #_biomes * _biomeDepth
	_rayTop = _startPos.Y + _config.endCapMaxRise + _config.sideRiseHeight * 2 + 512
	local mapFolder: Instance = workspace:WaitForChild("Map")
	assert(mapFolder:IsA("Folder"), "Map must be a Folder")
	local cartFolder: Instance = mapFolder:WaitForChild("Cart")
	assert(cartFolder:IsA("Folder"), "Map.Cart must be a Folder")
	local assets: Instance = _replicatedStorage:WaitForChild("Assets")
	_buildBiomeCaches()
	local cartTemplate: Instance = assets:WaitForChild("Cart")
	assert(cartTemplate:IsA("Model") and cartTemplate.PrimaryPart, "Assets.Cart must be a Model with a PrimaryPart")
	_caveAssets = _cavePopulation.buildCaches(assets, _biomes)
	assert(not _cancelled and session == _session, "Map generation cancelled")
	_trove:Add(function(): ()
		for _, region in _terrainRegions do
			workspace.Terrain:FillRegion(region, 4, Enum.Material.Air)
		end
		mapFolder:SetAttribute("generationSeed", nil)
		mapFolder:SetAttribute("biomeStartZ", nil)
		mapFolder:SetAttribute("biomeDepthStuds", nil)
	end)
	mapFolder:SetAttribute("generationSeed", _seed)
	mapFolder:SetAttribute("biomeStartZ", _startPos.Z)
	mapFolder:SetAttribute("biomeDepthStuds", _biomeDepth * _chunkStuds)
	for _, biome in _biomes do
		local folder: Instance? = mapFolder:FindFirstChild(biome.Name)
		if not folder then
			local created: Folder = _trove:Add(Instance.new("Folder"))
			created.Name, created.Parent = biome.Name, mapFolder
			folder = created
		end
		assert(folder, `Missing biome folder: {biome.Name}`)
		assert(folder:IsA("Folder"), `Map.{biome.Name} must be a Folder`)
		local generated: Folder = _trove:Add(Instance.new("Folder"))
		generated.Name, generated.Parent = "Generated", folder
		_biomeFolders[biome.Name] = generated
	end
	local cartSize: Vector3 = cartTemplate:GetExtentsSize()
	local minRoadWidth: number = math.max(_config.roadMinWidth, cartSize.X + 8)
	local yieldIfOver: () -> () = _makeBudget(session)
	assert(
		_config.terrainBatchChunks >= 1 and _config.terrainBatchChunks % 1 == 0,
		"Terrain batch size must be a positive integer"
	)
	_surface = _terrainSurface.new(
		_startPos,
		_seed,
		_biomes,
		_halfWidth,
		_biomeDepth,
		_mapConfig.biomeBlendChunks,
		minRoadWidth,
		yieldIfOver
	)
	_caves = _caveGenerator.new(_getSurface(), _startPos, _seed + 101, _biomes, _halfWidth, _biomeDepth)
	_getCaves():reserve(_keepouts)
	for _, cave in _getCaves().caves do
		for _, passage in cave.passages do
			assert(
				math.min(passage.a.Y, passage.b.Y) - _caveConfig.floorThickness
					> workspace.FallenPartsDestroyHeight + 16,
				"Caves extend below FallenPartsDestroyHeight; lower it in Studio or raise StartPart"
			)
		end
	end
	for z = 0, _config.spawnDepth do
		for x = -_halfWidth, _halfWidth, _config.terrainBatchChunks do
			_makeChunks(x, math.min(x + _config.terrainBatchChunks - 1, _halfWidth), z)
			yieldIfOver()
		end
	end
	local spawnGround: Vector3? =
		_findGround(_startPos.X + _getPathCenter(3) * _chunkStuds, _startPos.Z + 3 * _chunkStuds)
	assert(spawnGround, "Generated spawn terrain is missing")
	local spawnLocation: SpawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Size, spawnLocation.Anchored, spawnLocation.Neutral = Vector3.new(6, 1, 6), true, true
	spawnLocation.Transparency, spawnLocation.CanCollide = 1, false
	spawnLocation.CFrame, spawnLocation.Parent = CFrame.new(spawnGround + Vector3.new(0, 5, 0)), workspace
	_trove:Add(spawnLocation)
	local cartX: number = _startPos.X + _getPathCenter(_config.cartChunkZ) * _chunkStuds
	local cartZ: number = _startPos.Z + _config.cartChunkZ * _chunkStuds
	local cartGround: Vector3? = _findGround(cartX, cartZ)
	if not cartGround then
		local expectedY: number, material: Enum.Material = _getSurface():sample(cartX, cartZ)
		local chunkX: number = math.floor((cartX - _startPos.X) / _chunkStuds)
		warn(
			`[MapGenerationService] No terrain under the cart at ({cartX}, {cartZ}). seed={_seed} halfWidth={_halfWidth}`
				.. ` expectedY={expectedY} material={material.Name} startY={_startPos.Y}`
				.. ` chunkWritten={_chunks[_chunkKey(chunkX, _config.cartChunkZ)] == true}`
		)
		cartGround = Vector3.new(cartX, expectedY, cartZ)
	end
	assert(cartGround, "Generated cart terrain is missing")
	local cart: Model = _trove:Add(cartTemplate:Clone())
	cart:PivotTo(CFrame.new(cartGround + Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.pi, 0))
	cart.Parent = cartFolder
	_gameSignals.MapSpawnReady:Fire()
	local background: thread = task.spawn(function(): ()
		local nextBiome: number = 1
		local function featureReadyBiomes(z: number): ()
			while nextBiome <= #_biomes and z >= math.min(nextBiome * _biomeDepth + _config.featureMarginChunks, _mapDepth) do
				_generateBiomeFeatures(nextBiome)
				assert(not _cancelled and session == _session, "Map generation cancelled")
				nextBiome += 1
			end
		end
		for z = _config.spawnDepth + 1, _mapDepth do
			for x = -_halfWidth, _halfWidth, _config.terrainBatchChunks do
				-- Terrain around players outranks pre-generation; never compete with it for the frame budget.
				while _streamHead <= #_streamQueue do
					task.wait()
					assert(not _cancelled and session == _session, "Map generation cancelled")
				end
				_makeChunks(x, math.min(x + _config.terrainBatchChunks - 1, _halfWidth), z)
				yieldIfOver()
			end
			featureReadyBiomes(z)
		end
		_pregenComplete = true
		featureReadyBiomes(_mapDepth)
		_gameSignals.MapGenerationCompleted:Fire()
	end)
	_trove:Add(background)
	local nextScan: number = os.clock() + _config.streamIntervalSec
	_trove:Connect(_runService.Heartbeat, function(): ()
		if _cancelled or session ~= _session then
			return
		end
		if os.clock() >= nextScan then
			nextScan = os.clock() + _config.streamIntervalSec
			for _, player in _players:GetPlayers() do
				if player.Character then
					_checkSurroundings(player.Character:GetPivot().Position)
				end
			end
		end
		local deadline: number = os.clock() + _config.budgetMs / 1000
		while _streamHead <= #_streamQueue and os.clock() < deadline do
			local run: streamRun = _streamQueue[_streamHead]
			_streamHead += 1
			_makeChunks(run.x, run.lastX, run.z)
			for cx = run.x, run.lastX do
				_streamQueued[_chunkKey(cx, run.z)] = nil
			end
		end
		if _streamHead > #_streamQueue then
			table.clear(_streamQueue)
			_streamHead = 1
		end
		while _populationHead <= #_pendingPopulation and os.clock() < deadline do
			local chunk: populationChunk = _pendingPopulation[_populationHead]
			_populationHead += 1
			_populateChunk(chunk)
		end
		if _populationHead > #_pendingPopulation then
			table.clear(_pendingPopulation)
			_populationHead = 1
		end
	end)
end

function mapGenerationService.stop(): ()
	_cancelled = true
	_session += 1
	_trove:Clean()
	_surface, _caves = nil, nil
	_chunks, _pendingPopulation, _streamQueue, _streamQueued = {}, {}, {}, {}
	_blockedPopulation, _populationRows = {}, {}
	_terrainRegions = {}
	_biomeFolders, _biomeCaches, _biomeIndices, _caveAssets = {}, {}, {}, {}
	_populationHead, _streamHead = 1, 1
	_featuredBiomes, _pregenComplete = 0, false
	_keepouts = _keepoutRegistry.new()
	_startPos = Vector3.zero
	_halfWidth, _mapDepth, _seed, _rayTop = 0, 0, 0, 0
	_biomeDepth = _mapConfig.biomeDepth.min
	_generationSeed = Random.new()
end

function mapGenerationService:OnStart(): ()
	mapGenerationService.stop()
	_cancelled = false
	local session: number = _session
	_trove:Add(task.defer(function(): ()
		_startGeneration(session)
	end))
end

export type mapGenerationService = typeof(mapGenerationService)
return mapGenerationService
