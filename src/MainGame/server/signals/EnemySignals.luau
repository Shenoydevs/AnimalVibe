--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	EnemySpawned = Signal.new(),
	EnemyDied = Signal.new(),
	EnemyAggro = Signal.new(),
	EnemyDamaged = Signal.new(),
}
