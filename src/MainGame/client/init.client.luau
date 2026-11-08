--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Loader = require(ReplicatedStorage.Packages.Loader)

Loader.SpawnAll(Loader.LoadDescendants(script, Loader.MatchesName("Controller$")), "OnStart")
Loader.LoadDescendants(script, Loader.MatchesName("Component$"))
