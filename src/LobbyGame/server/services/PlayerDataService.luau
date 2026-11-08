--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage.Packages
local Common = ReplicatedStorage.Common

local _package = require(Packages.DataService).server
local DataTemplate = require(Common.config.DataTemplate)
local BadgeService = require(script.Parent.BadgeService)
local FirstAnimalService = require(script.Parent.FirstAnimalService)
local ChallengeService = require(script.Parent.ChallengeService)

type PlayerData = DataTemplate.PlayerData

local PlayerDataService = {}

function PlayerDataService:OnStart(): ()
	function _package.onPlayerInit(_self: typeof(_package), player: Player, data: PlayerData): ()
		BadgeService.loadPlayer(player, data.badges)
		ChallengeService.loadPlayer(player)
		FirstAnimalService.loadPlayer(player)
	end

	_package:init({
		template = DataTemplate,
		profileStoreIndex = "Development",
		-- Ticking ServerScriptService's UseMockData attribute in Studio plays on a fresh, unsaved profile.
		useMock = RunService:IsStudio() and ServerScriptService:GetAttribute("UseMockData") == true,
	})
end

export type PlayerDataService = typeof(PlayerDataService)

return PlayerDataService
