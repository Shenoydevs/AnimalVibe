--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InventoryTypes = require(ReplicatedStorage.Shared.types.InventoryTypes)

type SlotArray = InventoryTypes.SlotArray
type FilterCategory = InventoryTypes.FilterCategory

local scope = Fusion.scoped(Fusion)

return {
	Slots = scope:Value({} :: SlotArray),
	IsOpen = scope:Value(false),
	ActiveCategory = scope:Value("All" :: FilterCategory),
	DraggingFrom = scope:Value(nil :: number?),
}
