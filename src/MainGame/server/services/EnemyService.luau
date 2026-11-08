--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Timer = require(ReplicatedStorage.Packages.Timer)
local Trove = require(ReplicatedStorage.Packages.Trove)

local DayNightConfig = require(ReplicatedStorage.Shared.config.DayNightConfig)
local EnemyConfig = require(ReplicatedStorage.Shared.config.EnemyConfig)
local EntityConfig = require(ReplicatedStorage.Shared.config.EntityConfig)
local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local CharacterUtils = require(ReplicatedStorage.Shared.utils.CharacterUtils)

local signals = require(ServerScriptService.Server.signals)
local EnemySignals = signals.EnemySignals
local GameSignals = signals.GameSignals

local MapGenerationService = require(ServerScriptService.Server.services.MapGenerationService)
local VirusService = require(ServerScriptService.Server.services.VirusService)
local DayNightService = require(ServerScriptService.Server.services.DayNightService)
local _campfireService = require(ServerScriptService.Server.services.CampfireService)
local WeatherService = require(ServerScriptService.Server.services.WeatherService)

type TierEntry = EnemyConfig.TierEntry

type SpawnRecord = {
	id: string,
	origin: Vector3,
	nightOnly: boolean,
	biome: string,
	lootBoxModel: Model?,
	nextRespawnAt: number?,
	activeEnemies: { [Model]: boolean },
}

local _trove = Trove.new()
local _spawnRegistry: { [string]: SpawnRecord } = {}
local _dayCount: number = 0
local _rand = Random.new()
local _spawnIdCounter: number = 0
local _hostilesFolder: Folder? = nil
local _hostileTemplates: Instance? = nil

local _groundParams = RaycastParams.new()
_groundParams.FilterType = Enum.RaycastFilterType.Include
_groundParams.FilterDescendantsInstances = { workspace.Terrain }
_groundParams.IgnoreWater = false

local _roadParams = RaycastParams.new()
_roadParams.FilterType = Enum.RaycastFilterType.Include
_roadParams.FilterDescendantsInstances = { workspace.Terrain }

local EnemyService = {}

local function _newSpawnId(): string
	_spawnIdCounter += 1
	return "spawn_" .. _spawnIdCounter
end

local function _getTier(dayCount: number, biome: string): TierEntry
	local tierCount: number = #EnemyConfig.tiers
	local tierIndex: number = 1
	for i = tierCount, 1, -1 do
		local tier: TierEntry = EnemyConfig.tiers[i]
		if dayCount >= tier.dayMin then
			tierIndex = i
			break
		end
	end
	-- Each biome deeper into the progression bumps difficulty one tier
	tierIndex = math.min(tierCount, tierIndex + MapGenerationService:GetBiomeIndex(biome) - 1)
	return EnemyConfig.tiers[tierIndex]
end

local function _pickRandom(pool: { string }): string
	return pool[_rand:NextInteger(1, #pool)]
end

local function _validateSpawnConfig(): ()
	local knownBiomes: { [string]: boolean } = {}
	for _, biome in MapConfig.biomeSequence do
		knownBiomes[biome.Name] = true
	end
	for entityType, data in EntityConfig do
		for _, biomeName in data.allowedBiomes or {} do
			assert(knownBiomes[biomeName], `[EnemyService] {entityType} allows unknown biome "{biomeName}"`)
		end
	end
	for index, tier in EnemyConfig.tiers do
		for _, pool in { tier.nightPool, tier.guardPool } do
			for _, entityType in pool do
				assert(EntityConfig[entityType], `[EnemyService] Tier {index} pool has unknown entity "{entityType}"`)
			end
		end
	end
end

local function _canSpawnIn(entityType: string, biome: string): boolean
	local allowed: { string }? = EntityConfig[entityType].allowedBiomes
	return allowed == nil or table.find(allowed, biome) ~= nil
end

local function _poolForBiome(pool: { string }, biome: string): { string }
	local filtered: { string } = {}
	for _, entityType in pool do
		if _canSpawnIn(entityType, biome) then
			table.insert(filtered, entityType)
		end
	end
	return filtered
end

local function _getNightPool(tier: TierEntry, biome: string): { string }
	local pool: { string } = _poolForBiome(tier.nightPool, biome)
	if not WeatherService:IsAgileHunterOnly() then
		return pool
	end
	local agileOnly: { string } = {}
	for _, name in pool do
		if name == "Agile Hunter" then
			table.insert(agileOnly, name)
		end
	end
	if #agileOnly == 0 then
		return pool
	end
	return agileOnly
end

local function _groundAt(x: number, z: number): Vector3?
	local result: RaycastResult? = workspace:Raycast(
		Vector3.new(x, 1000, z),
		Vector3.new(0, -2000, 0),
		_groundParams
	)
	return if result then result.Position else nil
end

local function _isOffPath(pos: Vector3): boolean
	local result: RaycastResult? = workspace:Raycast(
		Vector3.new(pos.X, pos.Y + 5, pos.Z),
		Vector3.new(0, -20, 0),
		_roadParams
	)
	if not result then return true end
	return result.Material ~= Enum.Material.Cobblestone and result.Material ~= Enum.Material.Water
end

local function _pickNearPosition(center: Vector3, minR: number, maxR: number, caveFloor: boolean?): Vector3?
	for _ = 1, 10 do
		local angle: number = _rand:NextNumber(0, math.pi * 2)
		local radius: number = _rand:NextNumber(minR, maxR)
		local x: number = center.X + math.cos(angle) * radius
		local z: number = center.Z + math.sin(angle) * radius
		local ground: Vector3? = nil
		if caveFloor then
			local ray: RaycastResult? = workspace:Raycast(Vector3.new(x, center.Y + 6, z), Vector3.new(0, -18, 0), _groundParams)
			if ray and ray.Normal.Y >= 0.8 then
				local head: Vector3 = ray.Position + Vector3.new(0, 6, 0)
				local origin: Vector3 = center + Vector3.new(0, 3, 0)
				if not workspace:Raycast(origin, head - origin, _groundParams)
					and not workspace:Raycast(ray.Position + Vector3.new(0, 1, 0), Vector3.new(0, 12, 0), _groundParams) then
					ground = ray.Position
				end
			end
		else
			ground = _groundAt(x, z)
		end
		if ground and _isOffPath(ground) and not _campfireService:isPositionSafe(ground) then
			return ground
		end
	end
	return nil
end

-- Resolved lazily so a late-arriving Assets/Hostiles folder is still found.
local function _getHostileTemplates(): Instance?
	if _hostileTemplates then return _hostileTemplates end
	local assets: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	_hostileTemplates = if assets then assets:FindFirstChild("Hostiles") else nil
	return _hostileTemplates
end

local function _spawnEnemy(record: SpawnRecord, entityType: string, spawnPos: Vector3): ()
	local templates: Instance? = _getHostileTemplates()
	if not templates then return end
	local template: Instance? = templates:FindFirstChild(entityType)
	if not template or not template:IsA("Model") then
		warn(`[EnemyService] No Hostiles template for "{entityType}"`)
		return
	end
	local model: Model = (template :: Model):Clone()

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			if d.Name ~= "HumanoidRootPart" then
				d.CanCollide = false
			end
		end
	end

	local cloneHum: Humanoid? = model:FindFirstChildWhichIsA("Humanoid")
	if cloneHum then
		local entityData = EntityConfig[entityType]
		cloneHum.BreakJointsOnDeath = false
		if entityData then
			cloneHum.MaxHealth = entityData.health
			cloneHum.Health = entityData.health
		end
	end

	model:SetAttribute("spawnId", record.id)
	model:SetAttribute("entityType", entityType)
	if not record.nightOnly then
		model:SetAttribute("lootBoxPos", record.origin)
	end

	if not model.PrimaryPart then
		model:Destroy()
		return
	end

	local yaw: number = _rand:NextNumber(0, math.pi * 2)
	model:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 5, 0)) * CFrame.Angles(0, yaw, 0))
	model.Parent = _hostilesFolder or workspace

	CollectionService:AddTag(model, "Enemy")
	record.activeEnemies[model] = true
end

local function _spawnGroup(record: SpawnRecord, pool: { string }, count: number, minR: number, maxR: number, caveFloor: boolean?): ()
	if #pool == 0 then return end
	for _ = 1, count do
		local pos: Vector3? = _pickNearPosition(record.origin, minR, maxR, caveFloor)
		if pos then
			_spawnEnemy(record, _pickRandom(pool), pos)
		end
	end
end

local function _spawnGuardGroup(chest: Model): ()
	local biome: string = (chest:GetAttribute("biome") :: string?) or "Forest"
	local origin: Vector3 = chest:GetPivot().Position
	local tier: TierEntry = _getTier(_dayCount, biome)
	local count: number = _rand:NextInteger(tier.guardCount.min, tier.guardCount.max)
	local id: string = _newSpawnId()
	local record: SpawnRecord = {
		id = id,
		origin = origin,
		nightOnly = false,
		biome = biome,
		lootBoxModel = chest,
		nextRespawnAt = nil,
		activeEnemies = {},
	}
	_spawnRegistry[id] = record

	_spawnGroup(record, _poolForBiome(tier.guardPool, biome), count, 15, 25, chest:GetAttribute("caveLayer") ~= nil)
end

local function _isNearCoveredCenter(pos: Vector3, coveredCenters: { Vector3 }): boolean
	for _, center in coveredCenters do
		if (pos - center).Magnitude <= EnemyConfig.nightSpawnClusterRadius then
			return true
		end
	end
	return false
end

local function _spawnNightEnemies(): ()
	if not WeatherService:AllowsEnemySpawn() then return end

	local coveredCenters: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local hrp: BasePart? = CharacterUtils.getPlayerRoot(player)
		if not hrp then continue end
		local center: Vector3 = hrp.Position
		if _isNearCoveredCenter(center, coveredCenters) then continue end
		table.insert(coveredCenters, center)
		local biome: string = MapGenerationService:GetBiomeAtPosition(center.Z)
		local tier: TierEntry = _getTier(_dayCount, biome)
		local count: number = _rand:NextInteger(tier.nightCount.min, tier.nightCount.max)
		local id: string = _newSpawnId()
		local record: SpawnRecord = {
			id = id,
			origin = center,
			nightOnly = true,
			biome = biome,
			lootBoxModel = nil,
			nextRespawnAt = nil,
			activeEnemies = {},
		}
		_spawnRegistry[id] = record

		_spawnGroup(record, _getNightPool(tier, biome), count, 80, 150)
	end
end

local function _despawnNightEnemies(): ()
	-- Night records are one-shot; drop them entirely so the registry doesn't
	-- grow by one inert record per player per night.
	for id, record in _spawnRegistry do
		if not record.nightOnly then continue end
		for model in record.activeEnemies do
			model:Destroy()
		end
		_spawnRegistry[id] = nil
	end
end

local function _checkRespawns(): ()
	local now: number = os.clock()
	for _, record in _spawnRegistry do
		if record.nextRespawnAt == nil then continue end
		if now < (record.nextRespawnAt :: number) then continue end

		if record.nightOnly then
			if DayNightService:getTime() < DayNightConfig.hunterHour then continue end
			if not WeatherService:AllowsEnemySpawn() then continue end
			local tier: TierEntry = _getTier(_dayCount, record.biome)
			local count: number = _rand:NextInteger(tier.nightCount.min, tier.nightCount.max)
			_spawnGroup(record, _getNightPool(tier, record.biome), count, 80, 150)
			record.nextRespawnAt = nil
		else
			local lootBox: Model? = record.lootBoxModel
			if lootBox and lootBox.Parent == nil then
				_spawnRegistry[record.id] = nil
				continue
			end
			if record.origin.Z < VirusService:GetBoundaryZ() then continue end
			local tier: TierEntry = _getTier(_dayCount, record.biome)
			local count: number = _rand:NextInteger(tier.guardCount.min, tier.guardCount.max)
			_spawnGroup(record, _poolForBiome(tier.guardPool, record.biome), count, 15, 25, lootBox ~= nil and lootBox:GetAttribute("caveLayer") ~= nil)
			record.nextRespawnAt = nil
		end
	end
end

function EnemyService:OnStart(): ()
	_validateSpawnConfig()
	_spawnRegistry = {}
	_dayCount = 0
	_spawnIdCounter = 0

	local mapFolder: Folder = workspace:WaitForChild("Map") :: Folder
	_hostilesFolder = mapFolder:WaitForChild("Hostiles") :: Folder

	_trove:Connect(GameSignals.BiomeFeaturesGenerated, function(container: Instance)
		for _, desc in container:GetDescendants() do
			if desc:IsA("Model") and desc:GetAttribute("isLootBox") == true then
				_spawnGuardGroup(desc :: Model)
			end
		end
	end)

	_trove:Connect(GameSignals.HuntersSpawned, function()
		_spawnNightEnemies()
	end)

	_trove:Connect(GameSignals.DayCycleCompleted, function()
		_dayCount += 1
		if DayNightService:getTime() < DayNightConfig.hunterHour then
			_despawnNightEnemies()
		end
	end)

	_trove:Connect(EnemySignals.EnemyDied, function(model: Model, spawnId: string)
		local record: SpawnRecord? = _spawnRegistry[spawnId]
		if not record then return end
		record.activeEnemies[model] = nil
		if next(record.activeEnemies) == nil then
			record.nextRespawnAt = os.clock() + EnemyConfig.defaultRespawnDelay
		end
	end)

	local respawnTimer = _trove:Add(Timer.new(10))
	respawnTimer.Tick:Connect(function()
		_checkRespawns()
	end)
	respawnTimer:Start()
end

export type EnemyService = typeof(EnemyService)
return EnemyService
