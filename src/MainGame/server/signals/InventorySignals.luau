--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	DropAll = Signal.new(),
	ItemAdded = Signal.new(),
	ItemRemoved = Signal.new(),
	InventoryFull = Signal.new(),
}
