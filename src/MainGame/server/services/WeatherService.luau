--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Timer = require(Packages.Timer)
local Trove = require(Packages.Trove)

local NotificationConfig = require(ReplicatedStorage.Shared.config.NotificationConfig)
local WeatherConfig = require(ReplicatedStorage.Shared.config.WeatherConfig)
local WeatherNetwork = require(ReplicatedStorage.Shared.network.WeatherNetwork)
local CharacterUtils = require(ReplicatedStorage.Shared.utils.CharacterUtils)
local Signals = require(ServerScriptService.Server.signals)
local GameSignals = Signals.GameSignals
local CharacterSignals = Signals.CharacterSignals

local _campfireService = require(ServerScriptService.Server.services.CampfireService)
local CartService = require(ServerScriptService.Server.services.CartService)
local MapGenerationService = require(ServerScriptService.Server.services.MapGenerationService)
local NotificationService = require(ServerScriptService.Server.services.NotificationService)
local PlayerUtils = require(ServerScriptService.Server.utils.PlayerUtils)

type WeatherData = WeatherConfig.WeatherData
type NetworkerServer = Networker.Server

local _rollOrder: { string } = { "AcidRain", "Thunder", "NormalRain", "Blizzard" }

local _trove = Trove.new()
local _rand: Random = Random.new()
local _currentWeather: string = "Standard"
local _currentData: WeatherData = WeatherConfig.Standard
local _weatherStartTime: number = 0
local _lastExposureCycle: number = 0
local _lastStrikeCycle: number = 0
local _networker: NetworkerServer? = nil
-- Bumped on every weather roll so a strike warned under Thunder never lands after the weather changes.
local _strikeToken: number = 0

local WeatherService = {}

local function _biomeInList(list: { string }?, biome: string): boolean
	if not list then return false end
	for _, b in list do
		if b == biome then return true end
	end
	return false
end

local function _isEligible(data: WeatherData, biome: string): boolean
	if _biomeInList(data.excludedBiomes, biome) then return false end
	if data.allowedBiomes and not _biomeInList(data.allowedBiomes, biome) then return false end
	return true
end

local function _rollWeather(biome: string): string
	for _, name in _rollOrder do
		local data: WeatherData = WeatherConfig[name]
		if _biomeInList(data.alwaysInBiomes, biome) then
			return name
		end
	end

	for _, name in _rollOrder do
		local data: WeatherData = WeatherConfig[name]
		if not _isEligible(data, biome) then continue end
		if data.chance and _rand:NextNumber() < data.chance then
			return name
		end
	end

	return "Standard"
end

local function _getCurrentBiome(): string
	local cartPos: Vector3? = CartService:getPosition()
	if not cartPos then return "Forest" end
	return MapGenerationService:GetBiomeAtPosition(cartPos.Z)
end

function WeatherService:_damageExposedPlayers(amount: number): ()
	PlayerUtils.forEachAlive(function(player: Player, char: Model)
		if _campfireService:isPositionSafe(char:GetPivot().Position) then return end
		CharacterSignals.ModDebuff:Fire(player, "damage", amount)
	end)
end

function WeatherService:_strikeRandomPlayer(amount: number, warningDelay: number): ()
	local candidates: { Player } = {}
	PlayerUtils.forEachAlive(function(player: Player, char: Model)
		if _campfireService:isPositionSafe(char:GetPivot().Position) then return end
		table.insert(candidates, player)
	end)
	if #candidates == 0 then return end
	local target: Player = candidates[_rand:NextInteger(1, #candidates)]
	local token: number = _strikeToken

	if _networker then
		_networker:fireAll("onThunderWarning", warningDelay)
	end
	NotificationService:notify(target, "Alert", "The air is crackling around you. Get to cover!", warningDelay, NotificationConfig.priority.high)

	task.delay(warningDelay, function()
		if token ~= _strikeToken then return end
		local character: Model? = target.Character
		local root: BasePart? = CharacterUtils.getPlayerRoot(target)
		if not character or not root or character:GetAttribute("alive") ~= true then return end
		local position: Vector3 = root.Position
		if _networker then
			_networker:fireAll("onThunderStrike", position)
		end
		if _campfireService:isPositionSafe(position) then return end
		CharacterSignals.ModDebuff:Fire(target, "damage", amount)
	end)
end

function WeatherService:_effectTick(): ()
	local data: WeatherData = _currentData
	local elapsed: number = workspace:GetServerTimeNow() - _weatherStartTime

	if data.exposedDamage and data.exposedDamageInterval then
		local cycle: number = math.floor(elapsed / (data.exposedDamageInterval :: number))
		if cycle > _lastExposureCycle then
			_lastExposureCycle = cycle
			WeatherService:_damageExposedPlayers(data.exposedDamage :: number)
		end
	end

	if data.strikeChance and data.strikeInterval then
		local cycle: number = math.floor(elapsed / (data.strikeInterval :: number))
		if cycle > _lastStrikeCycle then
			_lastStrikeCycle = cycle
			if _rand:NextNumber() < (data.strikeChance :: number) then
				WeatherService:_strikeRandomPlayer(data.strikeDamage :: number, data.strikeWarningDelay or 0)
			end
		end
	end
end

function WeatherService:_rollForNewDay(): ()
	local biome: string = _getCurrentBiome()
	local name: string = _rollWeather(biome)

	_currentWeather = name
	_currentData = WeatherConfig[name]
	_weatherStartTime = workspace:GetServerTimeNow()
	_lastExposureCycle = 0
	_lastStrikeCycle = 0
	_strikeToken += 1
	if _networker then
		_networker:fireAll("onWeatherChanged", name)
	end
end

function WeatherService:GetCurrentWeather(): string
	return _currentWeather
end

function WeatherService.getWeather(_self: unknown, _player: Player): string
	return _currentWeather
end

function WeatherService:GetCurrentWeatherData(): WeatherData
	return _currentData
end

function WeatherService:AllowsEnemySpawn(): boolean
	return _currentData.enemySpawn
end

function WeatherService:IsAgileHunterOnly(): boolean
	return _currentData.onlyAgileHunters == true
end

function WeatherService:GetAgileSpeedMultiplier(entityType: string): number
	local boost: number? = _currentData.agileSpeedBoost
	if entityType == "Agile Hunter" and boost then
		return 1 + boost
	end
	return 1
end

function WeatherService:OnStart(): ()
	_networker = _trove:Add(
		Networker.server.new(WeatherNetwork.Weather, WeatherService, { WeatherService.getWeather }),
		"destroy"
	)
	_currentWeather = "Standard"
	_currentData = WeatherConfig.Standard
	_weatherStartTime = workspace:GetServerTimeNow()

	_trove:Connect(GameSignals.DayCycleCompleted, function()
		WeatherService:_rollForNewDay()
	end)

	local tickTimer = _trove:Add(Timer.new(1))
	tickTimer.Tick:Connect(function()
		WeatherService:_effectTick()
	end)
	tickTimer:Start()
end

export type WeatherService = typeof(WeatherService)
return WeatherService
