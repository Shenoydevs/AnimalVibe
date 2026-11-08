local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local config = require(ReplicatedStorage.Shared.config)

local PartyConfig = config.PartyConfig

local scope = Fusion.scoped(Fusion)

return {
	InParty = scope:Value(false),
	TimeLeft = scope:Value(0),
	PlayerCount = scope:Value(PartyConfig.MaxPlayers),
	PrivateMode = scope:Value(true),
}
