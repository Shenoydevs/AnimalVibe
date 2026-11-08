--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local scope = Fusion.scoped(Fusion)

return {
	HeldItem = scope:Value(nil :: string?),
	EquippedTool = scope:Value(nil :: string?),
	EquippedSlot = scope:Value(nil :: number?),
	RopeEquipped = scope:Value(false :: boolean?),
}
