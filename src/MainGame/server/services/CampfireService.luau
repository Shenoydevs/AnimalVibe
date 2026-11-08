--!strict
local _collectionService = game:GetService("CollectionService")
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _serverScriptService = game:GetService("ServerScriptService")

local _packages = _replicatedStorage.Packages
local _networkerModule = require(_packages.Networker)
local _timer = require(_packages.Timer)
local _troveModule = require(_packages.Trove)

local _campfireConfig = require(_replicatedStorage.Shared.config.CampfireConfig)
local _campfireNetwork = require(_replicatedStorage.Shared.network.CampfireNetwork)
local _campfireTypes = require(_replicatedStorage.Shared.types.CampfireTypes)
local _safezoneUtils = require(_replicatedStorage.Shared.utils.SafezoneUtils)
local _playerUtils = require(_serverScriptService.Server.utils.PlayerUtils)

local _signals = require(_serverScriptService.Server.signals)
local _gameSignals = _signals.GameSignals
local _characterSignals = _signals.CharacterSignals

type networkerServer = _networkerModule.Server

export type campfireZone = _campfireTypes.campfireZone

local _campfireTag: string = "Campfire"

local _trove = _troveModule.new()
local _networker: networkerServer? = nil
local _zones: { campfireZone } = {}
local _registered: { [Instance]: campfireZone } = {}
local _zonesReady: boolean = false

local campfireService = {}

local function _registerCampfire(instance: Instance): ()
	if _registered[instance] or not instance:IsA("Model") then
		return
	end
	local radius: number = (instance:GetAttribute("safeRadius") :: number?) or _campfireConfig.safeRadius
	local groundPosition: Vector3? = instance:GetAttribute("campfireGroundPosition") :: Vector3?
	if not groundPosition then
		local bounds: CFrame, size: Vector3 = instance:GetBoundingBox()
		groundPosition = Vector3.new(bounds.X, bounds.Y - size.Y / 2, bounds.Z)
	end
	local zone: campfireZone = {
		position = instance:GetPivot().Position,
		groundPosition = groundPosition,
		radius = radius,
		halfHeight = (instance:GetAttribute("safeHalfHeight") :: number?) or _campfireConfig.safeHalfHeight,
	}
	_registered[instance] = zone
	table.insert(_zones, zone)
end

local function _unregisterCampfire(instance: Instance): ()
	local zone: campfireZone? = _registered[instance]
	if not zone then
		return
	end
	_registered[instance] = nil
	local index: number? = table.find(_zones, zone)
	if index then
		table.remove(_zones, index)
	end
end

local function _broadcastZones(): ()
	local networker: networkerServer? = _networker
	if networker then
		networker:fireAll("onCampfireList", _zones)
	end
end

function campfireService:isPositionSafe(position: Vector3): boolean
	for _, zone in _zones do
		if _safezoneUtils.isInside(position, zone.position, zone.radius, zone.halfHeight) then
			return true
		end
	end
	return false
end

function campfireService:clampOutsideZones(position: Vector3): Vector3
	if not campfireService:isPositionSafe(position) then
		return position
	end
	for _, zone in _zones do
		local clamped: Vector3 = _safezoneUtils.clampOutside(
			position,
			zone.position,
			zone.radius,
			_campfireConfig.repelMargin,
			zone.halfHeight
		)
		if clamped ~= position then
			if not campfireService:isPositionSafe(clamped) then
				return clamped
			end
			break
		end
	end
	local result: Vector3 = position
	-- Moving only forward prevents overlapping zones from pushing an enemy back and forth.
	for _ = 1, #_zones do
		for _, zone in _zones do
			if _safezoneUtils.isInside(result, zone.position, zone.radius, zone.halfHeight) then
				local dz: number = result.Z - zone.position.Z
				local exitX: number = zone.position.X + math.sqrt(zone.radius * zone.radius - dz * dz)
				result = Vector3.new(exitX + _campfireConfig.repelMargin, result.Y, result.Z)
			end
		end
		if not campfireService:isPositionSafe(result) then
			return result
		end
	end
	return result
end

function campfireService.getCampfires(_self: unknown, _player: Player): { campfireZone }
	return _zones
end

function campfireService:_healPlayersInZones(): ()
	if #_zones == 0 then
		return
	end
	local healPerTick: number = _campfireConfig.healDamagePerSecond * _campfireConfig.healTickInterval
	_playerUtils.forEachAlive(function(player: Player, char: Model): ()
		local damage: number? = char:GetAttribute("damage") :: number?
		if not damage or damage <= 0 then
			return
		end
		if not campfireService:isPositionSafe(char:GetPivot().Position) then
			return
		end
		_characterSignals.ModDebuff:Fire(player, "damage", -math.min(damage, healPerTick))
	end)
end

function campfireService.stop(): ()
	_trove:Clean()
	_networker = nil
	table.clear(_zones)
	table.clear(_registered)
	_zonesReady = false
end

function campfireService:OnStart(): ()
	campfireService.stop()
	_networker = _trove:Add(
		_networkerModule.server.new(_campfireNetwork.campfire, campfireService, { campfireService.getCampfires }),
		"destroy"
	)

	local function markZonesReady(): ()
		for _, instance in _collectionService:GetTagged(_campfireTag) do
			_registerCampfire(instance)
		end
		_zonesReady = true
		_broadcastZones()
	end
	_trove:Connect(_gameSignals.BiomeFeaturesGenerated, markZonesReady)
	_trove:Connect(_gameSignals.MapGenerationCompleted, markZonesReady)

	_trove:Connect(_collectionService:GetInstanceAddedSignal(_campfireTag), function(instance: Instance): ()
		_registerCampfire(instance)
		if _zonesReady then
			_broadcastZones()
		end
	end)

	_trove:Connect(_collectionService:GetInstanceRemovedSignal(_campfireTag), function(instance: Instance): ()
		_unregisterCampfire(instance)
		if _zonesReady then
			_broadcastZones()
		end
	end)

	for _, instance in _collectionService:GetTagged(_campfireTag) do
		_registerCampfire(instance)
	end
	if #_zones > 0 then
		_zonesReady = true
		_broadcastZones()
	end

	local healTimer = _trove:Add(_timer.new(_campfireConfig.healTickInterval))
	_trove:Connect(healTimer.Tick, function(): ()
		campfireService:_healPlayersInZones()
	end)
	healTimer:Start()
end

export type campfireService = typeof(campfireService)
return campfireService
