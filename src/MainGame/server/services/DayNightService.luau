--!strict
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Timer = require(Packages.Timer)
local Trove = require(Packages.Trove)

type NetworkerServer = Networker.Server

local Signals = require(ServerScriptService.Server.signals)
local GameSignals = Signals.GameSignals
local CharacterSignals = Signals.CharacterSignals
local Network = require(ReplicatedStorage.Shared.network.GameNetwork)
local DayNightNetwork = require(ReplicatedStorage.Shared.network.DayNightNetwork)
local DayNightConfig = require(ReplicatedStorage.Shared.config.DayNightConfig)

type Phase = DayNightNetwork.Phase

local _trove = Trove.new()
local _startTime: number = 0
local _lastHour: number = math.floor(DayNightConfig.startHour)
local _lastCycle: number = 0
local _day: number = 1
local _phase: Phase = "Day"
local _hudNetworker: NetworkerServer
local _dayNightNetworker: NetworkerServer

local _lasthungerCycle: number = 0
local _lastthirstCycle: number = 0

local DayNightService = {}

local function phaseForHour(hour: number): Phase
	if hour >= DayNightConfig.dawnHour and hour < DayNightConfig.nightApproachHour then
		return "Day"
	end
	return "Night"
end

function DayNightService:HungerStep()
	for _, player in ipairs(Players:GetPlayers()) do
		CharacterSignals.ModDebuff:Fire(player, "hunger", DayNightConfig.hungerPerCycle)
	end
end

function DayNightService:ThirstStep()
	for _, player in ipairs(Players:GetPlayers()) do
		CharacterSignals.ModDebuff:Fire(player, "thirst", DayNightConfig.thirstPerCycle)
	end
end

function DayNightService:getTime(): number
	local elapsed: number = workspace:GetServerTimeNow() - _startTime
	return (DayNightConfig.startHour + (elapsed % DayNightConfig.cycleDuration) / DayNightConfig.cycleDuration * 24) % 24
end

function DayNightService.getDay(_self: unknown, _player: Player): number
	return _day
end

function DayNightService:getPhase(): Phase
	return _phase
end

function DayNightService:OnStart()
	_startTime = workspace:GetServerTimeNow()
	_phase = phaseForHour(math.floor(DayNightService:getTime()))

	local networker: NetworkerServer = Networker.server.new(Network.Game)
	_hudNetworker = Networker.server.new(Network.Hud, DayNightService, { DayNightService.getDay })
	_dayNightNetworker = Networker.server.new(DayNightNetwork.DayNight, DayNightService, { DayNightService.getPhase })

	local updateTimer = _trove:Add(Timer.new(DayNightConfig.updateRate))
	updateTimer:Start()

	updateTimer.Tick:Connect(function()
		local serverTime: number = workspace:GetServerTimeNow()
		local elapsed: number = serverTime - _startTime
		local clockTime: number = DayNightService:getTime()

		Lighting.ClockTime = clockTime

		local cycleHunger: number = math.floor(elapsed / DayNightConfig.hungerCycle)
		if cycleHunger > _lasthungerCycle then
			_lasthungerCycle = cycleHunger
			DayNightService:HungerStep()
		end

		local cycleThirst: number = math.floor(elapsed / DayNightConfig.thirstCycle)
		if cycleThirst > _lastthirstCycle then
			_lastthirstCycle = cycleThirst
			DayNightService:ThirstStep()
		end

		local currentCycle: number = math.floor(elapsed / DayNightConfig.cycleDuration)
		if currentCycle > _lastCycle then
			_lastCycle = currentCycle
			_day += 1
			_hudNetworker:setAll("day", _day)
			GameSignals.DayCycleCompleted:Fire()
		end

		local hour: number = math.floor(clockTime)
		if hour == _lastHour then return end
		local prevHour: number = _lastHour
		_lastHour = hour

		-- Loop handles multiple hours crossed in one tick during lag spikes.
		local hoursElapsed: number = (hour - prevHour) % 24
		for i = 1, hoursElapsed do
			local crossedHour: number = (prevHour + i) % 24
			if crossedHour == DayNightConfig.hunterHour then
				GameSignals.HuntersSpawned:Fire()
				networker:fireAll("onHuntersSpawned")
			end
			if crossedHour == DayNightConfig.nightApproachHour and _phase ~= "Night" then
				_phase = "Night"
				_dayNightNetworker:fireAll("onPhaseChange", _phase)
			elseif crossedHour == DayNightConfig.dawnHour and _phase ~= "Day" then
				_phase = "Day"
				_dayNightNetworker:fireAll("onPhaseChange", _phase)
			end
		end
	end)
end

export type DayNightService = typeof(DayNightService)

return DayNightService
