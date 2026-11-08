local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Packages.Loader)

local Features = ServerScriptService.Server

Loader.SpawnAll(Loader.LoadDescendants(Features, Loader.MatchesName("Service$")), "OnStart")
Loader.LoadDescendants(Features, Loader.MatchesName("Component$"))
