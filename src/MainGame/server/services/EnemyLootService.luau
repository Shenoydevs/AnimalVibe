--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Trove = require(ReplicatedStorage.Packages.Trove)
local ChestConfig = require(ReplicatedStorage.Shared.config.ChestConfig)
local EntityConfig = require(ReplicatedStorage.Shared.config.EntityConfig)

local signals = require(ServerScriptService.Server.signals)
local GroundItemUtils = require(ServerScriptService.Server.utils.GroundItemUtils)
local EnemySignals = signals.EnemySignals

local _trove = Trove.new()
local _rand = Random.new()

local EnemyLootService = {}

local function _dropItem(itemId: string, position: Vector3): ()
	GroundItemUtils.spawnAt(itemId, CFrame.new(position))
end

function EnemyLootService:OnStart(): ()
	_trove:Connect(EnemySignals.EnemyDied, function(model: Model, _spawnId: string)
		local entityType = model:GetAttribute("entityType")
		local data = if type(entityType) == "string" then EntityConfig[entityType] else nil
		if not data then
			return
		end

		local position: Vector3 = model:GetPivot().Position

		if _rand:NextNumber() <= data.keyDropChance then
			_dropItem(ChestConfig.keyItemID, position)
		end

		if _rand:NextNumber() <= data.meatDropChance then
			_dropItem("Meat", position)
		end
	end)
end

export type EnemyLootService = typeof(EnemyLootService)
return EnemyLootService
