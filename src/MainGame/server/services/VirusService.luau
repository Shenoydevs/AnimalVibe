--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Timer = require(Packages.Timer)
local Trove = require(Packages.Trove)

local VirusConfig = require(ReplicatedStorage.Shared.config.VirusConfig)
local Network = require(ReplicatedStorage.Shared.network.GameNetwork)
local Signals = require(ServerScriptService.Server.signals)
local PlayerUtils = require(ServerScriptService.Server.utils.PlayerUtils)

local GameSignals = Signals.GameSignals
local CharacterSignals = Signals.CharacterSignals

type NetworkerServer = Networker.Server

local _trove = Trove.new()
local _networker: NetworkerServer
local _virusBoundaryZ: number = VirusConfig.initialBoundaryZ
local _previousBoundaryZ: number = VirusConfig.initialBoundaryZ
local _boundaryAdvanceStartTime: number = 0
local _virusReleased: boolean = false
local _stormPhase: number = 0
local _currentDamagePerSecond: number = VirusConfig.baseDamagePerSecond

local VirusService = {}

-- Mirrors the client's visual tween so the damage zone never leads the fog
-- wall: both interpolate from the pre-advance boundary to the new one over
-- the same VirusConfig.boundaryTweenTime window.
local function _getEffectiveBoundaryZ(): number
	local elapsed: number = workspace:GetServerTimeNow() - _boundaryAdvanceStartTime
	local t: number = math.clamp(elapsed / VirusConfig.boundaryTweenTime, 0, 1)
	return _previousBoundaryZ + (_virusBoundaryZ - _previousBoundaryZ) * t
end

function VirusService:_damagePlayersInZone(): ()
	local boundaryZ: number = _getEffectiveBoundaryZ()
	PlayerUtils.forEachAlive(function(player: Player, char: Model)
		if char:GetPivot().Position.Z < boundaryZ then
			CharacterSignals.ModDebuff:Fire(player, "sickness", _currentDamagePerSecond)
		end
	end)
end

function VirusService:OnStart(): ()
	_networker = Networker.server.new(Network.Virus)

	_trove:Connect(GameSignals.DayCycleCompleted, function()
		if not _virusReleased then
			_virusReleased = true
			_networker:fireAll("onVirusReleased")
		end

		_stormPhase += 1
		_currentDamagePerSecond = math.min(
			VirusConfig.baseDamagePerSecond + VirusConfig.damagePerSecondStep * (_stormPhase - 1),
			VirusConfig.maxDamagePerSecond
		)
		local advance: number = math.min(
			VirusConfig.baseAdvancePerCycle + VirusConfig.advancePerCycleStep * (_stormPhase - 1),
			VirusConfig.maxAdvancePerCycle
		)

		_previousBoundaryZ = _virusBoundaryZ
		_virusBoundaryZ += advance
		_boundaryAdvanceStartTime = workspace:GetServerTimeNow()
		_networker:fireAll("onVirusBoundaryUpdate", _virusBoundaryZ, _stormPhase)
	end)

	local damageTimer = _trove:Add(Timer.new(1))
	damageTimer.Tick:Connect(function()
		if not _virusReleased then return end
		VirusService:_damagePlayersInZone()
	end)
	damageTimer:Start()
end

function VirusService:GetBoundaryZ(): number
	return _virusBoundaryZ
end

export type VirusService = typeof(VirusService)
return VirusService
