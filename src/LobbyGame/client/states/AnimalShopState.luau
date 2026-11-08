--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local _scope = Fusion.scoped(Fusion)

return {
	owned = _scope:Value({}),
	available = _scope:Value({}),
	equippedAnimal = _scope:Value(""),
	coins = _scope:Value(0),
	search = _scope:Value(""),
	includeOwned = _scope:Value(true),
	includeOffsale = _scope:Value(true),
}
