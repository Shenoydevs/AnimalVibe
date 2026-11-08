--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local Network = require(ReplicatedStorage.Shared.network)

local _networker = Networker.client.new(Network.Badge, {})

local Shared = {}

function Shared.equip(badgeId)
	_networker:fire("_equip", badgeId)
end

return Shared
