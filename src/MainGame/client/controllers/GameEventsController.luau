--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local Network = require(ReplicatedStorage.Shared.network.GameNetwork)
local NotificationController = require(script.Parent.NotificationController)

local _warHornSound: Sound = Instance.new("Sound")
_warHornSound.Name = "WarHorn"
_warHornSound.SoundId = "rbxassetid://6875748361"
_warHornSound.Volume = 1
_warHornSound.Parent = SoundService

local GameEventsController = {}

function GameEventsController:onHuntersSpawned(): ()
	NotificationController:push("Hunters are spawning...", 3, NotificationController.PRIORITY_LOW, "Alert")
	_warHornSound:Play()
end


function GameEventsController:OnStart(): ()
	Networker.client.new(Network.Game, GameEventsController)
end

export type GameEventsController = typeof(GameEventsController)
return GameEventsController
