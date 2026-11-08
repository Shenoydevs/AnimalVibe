--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	ShareItem = Signal.new(),
	ModDebuff = Signal.new(),
	SetDebuff = Signal.new(),
	IFrames = Signal.new(),
	Revived = Signal.new(),
	ItemConsumed = Signal.new(),
	ConsumeVFX = Signal.new(),
}
