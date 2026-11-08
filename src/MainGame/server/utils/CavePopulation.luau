--!strict
local _collectionService = game:GetService("CollectionService")
local _replicatedStorage = game:GetService("ReplicatedStorage")

local _biomeTypes = require(_replicatedStorage.Shared.types.BiomeTypes)
local _biomeUtils = require(_replicatedStorage.Shared.utils.BiomeUtils)
local _config = require(_replicatedStorage.Shared.config.CaveGenerationConfig)
local _caveGenerator = require(script.Parent.CaveGenerator)
local _caveBoulder = require(script.Parent.CaveBoulder)

local cavePopulation = {}

export type validatedAsset = { template: Model, size: Vector3 }
export type assetCache = { [string]: validatedAsset }

local _assetNames: { string } = { "Chest", "Camp Fire", "Chair" }

local _params: RaycastParams = RaycastParams.new()
_params.FilterType = Enum.RaycastFilterType.Include
_params.FilterDescendantsInstances = { workspace.Terrain }

local function _findTemplate(folder: Instance?, name: string): Model?
	local category: Instance? = if folder then folder:FindFirstChild(name) else nil
	return if category then category:FindFirstChildWhichIsA("Model") else nil
end

function cavePopulation.buildCaches(assets: Instance, biomes: { _biomeTypes.Biome }): { [string]: assetCache }
	local caches: { [string]: assetCache } = {}
	if not _config.enabled then
		return caches
	end
	local forest: Instance? = assets:FindFirstChild("Forest")
	local boulder = assets:FindFirstChild("Boulder")
	assert(boulder and boulder:IsA("Model") and boulder:FindFirstChildWhichIsA("BasePart", true), "Assets.Boulder must be a Model containing a BasePart")
	for _, biome in biomes do
		if (_config.layersByBiome[biome.Name] or 2) <= 0 then
			continue
		end
		local cache: assetCache = {}
		cache.Boulder = { template = boulder, size = boulder:GetExtentsSize() }
		local folder: Instance? = assets:FindFirstChild(biome.PropFolder)
		for _, name in _assetNames do
			local template: Model? = _findTemplate(folder, name) or _findTemplate(forest, name)
			assert(template, `Missing cave asset: {biome.PropFolder}/{name} (including Forest fallback)`)
			assert(template:FindFirstChildWhichIsA("BasePart", true), `Cave asset {name} has no parts`)
			if name == "Chest" then
				assert(template.PrimaryPart, `Cave chest {template:GetFullName()} needs a PrimaryPart`)
			end
			local size: Vector3 = template:GetExtentsSize()
			assert(
				math.max(size.X, size.Y, size.Z) <= _config.maxAssetSize,
				`Cave asset {template:GetFullName()} exceeds the {_config.maxAssetSize}-stud placement limit`
			)
			cache[name] = { template = template, size = size }
		end
		caches[biome.Name] = cache
	end
	return caches
end

local function _placeAsset(
	ctx: _biomeTypes.BiomeContext,
	cache: assetCache,
	name: string,
	floor: Vector3,
	angle: number,
	layer: number,
	biomeName: string
): Model?
	local asset: validatedAsset = cache[name]
	local size: Vector3 = asset.size
	local ray: RaycastResult? = workspace:Raycast(floor + Vector3.new(0, 6, 0), Vector3.new(0, -12, 0), _params)
	if not ray or ray.Normal.Y < 0.8 then
		warn(`[CavePopulation] No walkable floor for {name} at {floor}`)
		return nil
	end
	-- Probe from inside the room; a surface ray would place loot on the cave roof.
	local half: number = math.max(size.X, size.Z) * 0.5
	for _, offset: Vector3 in
		{
			Vector3.new(half, 0, half),
			Vector3.new(-half, 0, half),
			Vector3.new(half, 0, -half),
			Vector3.new(-half, 0, -half),
		}
	do
		local footing: RaycastResult? =
			workspace:Raycast(ray.Position + offset + Vector3.new(0, 6, 0), Vector3.new(0, -12, 0), _params)
		if not footing or math.abs(footing.Position.Y - ray.Position.Y) > 2 or footing.Normal.Y < 0.8 then
			warn(`[CavePopulation] Uneven footing for {name}`)
			return nil
		end
		local origin: Vector3 = footing.Position + Vector3.new(0, 2, 0)
		if workspace:Raycast(origin, Vector3.new(0, size.Y + 1, 0), _params) then
			warn(`[CavePopulation] Insufficient headroom for {name}`)
			return nil
		end
	end
	local model: Model = asset.template:Clone()
	model:SetAttribute("caveLayer", layer)
	if name == "Camp Fire" then
		model:SetAttribute("campfireGroundPosition", ray.Position)
		model:SetAttribute("safeRadius", _config.campfireRadius)
		model:SetAttribute("safeHalfHeight", _config.campfireHalfHeight)
		model:SetAttribute("isCaveCampsite", true)
	elseif name == "Chest" then
		model:SetAttribute("isLootBox", true)
		model:SetAttribute("biome", biomeName)
	end
	_biomeUtils.placeModel(ctx.container, model, ray.Position, angle)
	return model
end

function cavePopulation.populate(
	ctx: _biomeTypes.BiomeContext,
	cave: _caveGenerator.cave,
	biomeName: string,
	cache: assetCache
): ()
	local container: Folder = Instance.new("Folder")
	container.Name = "ProceduralCave"
	container:SetAttribute("entrance", cave.passages[1].a)
	container.Parent = ctx.container
	_caveBoulder.place(container, cave, cache.Boulder.template)
	local caveContext: _biomeTypes.BiomeContext = table.clone(ctx)
	caveContext.container = container
	for _, destination in cave.destinations do
		if destination.campfire then
			local firePosition: Vector3 = destination.position + Vector3.new(0, 0, 6)
			local fire: Model? =
				_placeAsset(caveContext, cache, "Camp Fire", firePosition, 0, destination.layer, biomeName)
			if fire then
				_collectionService:AddTag(fire, "Campfire")
				for _, angle: number in { 45, 135, 225 } do
					local offset: Vector3 = Vector3.new(math.cos(math.rad(angle)) * 7, 0, math.sin(math.rad(angle)) * 7)
					_placeAsset(
						caveContext,
						cache,
						"Chair",
						firePosition + offset,
						angle + 180,
						destination.layer,
						biomeName
					)
				end
			end
		end
		for chestIndex = 1, destination.chests do
			local spacing: number = if destination.layer == 3 then 12 else 9
			local offset: Vector3 = Vector3.new(if chestIndex % 2 == 0 then -spacing else spacing, 0, -6)
			local chest: Model? = _placeAsset(
				caveContext,
				cache,
				"Chest",
				destination.position + offset,
				180,
				destination.layer,
				biomeName
			)
			if chest then
				_collectionService:AddTag(chest, "Chest")
			end
		end
		task.wait()
	end
end

export type cavePopulation = typeof(cavePopulation)
return cavePopulation
