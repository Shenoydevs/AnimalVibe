--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local scope = Fusion.scoped(Fusion)

return {
	BaseStamina = scope:Value(100),
	Stamina = scope:Value(0),

	Hunger = scope:Value(0),
	Thirst = scope:Value(0),
	Weight = scope:Value(0),
	Damage = scope:Value(0),
	Sickness = scope:Value(0),
}
