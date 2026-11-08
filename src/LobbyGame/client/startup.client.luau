local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Loader = require(ReplicatedStorage.Packages.Loader)

local player = Players.LocalPlayer

Loader.SpawnAll(Loader.LoadDescendants(player.PlayerScripts.Client, Loader.MatchesName("Controller$")), "OnStart")
Loader.LoadDescendants(player.PlayerScripts.Client, Loader.MatchesName("Component$"))
