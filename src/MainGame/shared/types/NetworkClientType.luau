--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)

export type NetworkerClient = typeof(Networker.client.new("", {}))

return {}
