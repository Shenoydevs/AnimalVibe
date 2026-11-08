local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)

export type NetworkerServer = typeof(Networker.server.new(""))

return {}
