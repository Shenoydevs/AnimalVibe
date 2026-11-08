--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	HuntersSpawned = Signal.new(),
	DayCycleCompleted = Signal.new(),
	MapSpawnReady = Signal.new(),
	MapGenerationCompleted = Signal.new(),
	BiomeFeaturesGenerated = Signal.new(),
}
