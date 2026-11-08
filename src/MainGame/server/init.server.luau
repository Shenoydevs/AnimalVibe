--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Packages.Loader)

Loader.SpawnAll(Loader.LoadDescendants(script, Loader.MatchesName("Service$")), "OnStart")
Loader.LoadDescendants(script, Loader.MatchesName("Component$"))
