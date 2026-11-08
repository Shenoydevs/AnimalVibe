--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	PlayerEntered = Signal.new(),
	PlayerExited = Signal.new(),
	PlayerLeft = Signal.new(),
}
