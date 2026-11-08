--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local states = require(script.Parent.Parent.states)
local DataService = require(ReplicatedStorage.Packages.DataService).client

local PlayerState = states.PlayerState

local Private = {}
local PlayerDataController = {}

function Private._readData(): ()
	local stats = DataService:get({ "PlayerStats" })
	PlayerState.Level:set(stats.Level)
	PlayerState.Xp:set(stats.Xp)
	PlayerState.Coins:set(stats.Nova)
end

function PlayerDataController:OnStart(): ()
	DataService:waitForData()
	DataService:getChangedSignal({ "PlayerStats" }):Connect(Private._readData)
	Private._readData()
end

export type PlayerDataController = typeof(PlayerDataController)

return PlayerDataController
