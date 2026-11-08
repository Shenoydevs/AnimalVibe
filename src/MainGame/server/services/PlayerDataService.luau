--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages

local _package = require(Packages.DataService).server
local DataTemplate = require(ReplicatedStorage.Common.config.DataTemplate)
local LevelingConfig = require(ReplicatedStorage.Common.config.LevelingConfig)

type PlayerStats = typeof(DataTemplate.PlayerStats)

-- One round per server; retain payout protection across same-server rejoins.
local _awardedRoundXp: { [number]: boolean } = {}

local PlayerDataService = {}

local function _isActive(player: Player): boolean
	return _package:hasProfile(player) and _package:getProfile(player):IsActive()
end

function PlayerDataService.awardRoundXp(player: Player): boolean
	if _awardedRoundXp[player.UserId] then
		return true
	end
	if not _isActive(player) then
		return false
	end

	_package:update(player, { "PlayerStats" }, function(stats: PlayerStats): PlayerStats
		local updated = table.clone(stats)
		updated.Level, updated.Xp = LevelingConfig.addXp(stats.Level, stats.Xp, LevelingConfig.roundXp)
		return updated
	end)
	_awardedRoundXp[player.UserId] = true
	return true
end

function PlayerDataService.awardNova(player: Player, amount: number): boolean
	if not _isActive(player) then
		return false
	end
	_package:update(player, { "PlayerStats", "Nova" }, function(nova: number): number
		return nova + amount
	end)
	return true
end

-- Yields until the profile has loaded, then returns the animal equipped in the Lobby.
function PlayerDataService.waitForEquippedAnimal(player: Player): string?
	return _package:waitForData(player):get({ "Inventory", "EquippedAnimal" })
end

function PlayerDataService:OnStart(): ()
	_package:init({
		template = DataTemplate,
		profileStoreIndex = "Development",
	})
end

export type PlayerDataService = typeof(PlayerDataService)

return PlayerDataService
