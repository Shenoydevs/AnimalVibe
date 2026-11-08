--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local EnemyConfig = require(ReplicatedStorage.Shared.config.EnemyConfig)
local EnemyNetwork = require(ReplicatedStorage.Shared.network.EnemyNetwork)
local NotificationController = require(script.Parent.NotificationController)

local EnemyController = {}

function EnemyController:onEnemyWarning(entityType: string): ()
	local displayName: string = EnemyConfig.displayNames[entityType] or entityType
	NotificationController:push(
		displayName .. " are nearby!",
		4,
		NotificationController.PRIORITY_HIGH,
		"Alert"
	)
end

function EnemyController:OnStart(): ()
	Networker.client.new(EnemyNetwork.Enemy, EnemyController)
end

export type EnemyController = typeof(EnemyController)
return EnemyController
