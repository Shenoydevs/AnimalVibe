--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local BadgeConfig = require(ReplicatedStorage.Common.config.BadgeConfig)

local _scope = Fusion.scoped(Fusion)

local BadgeState = {
	earned = _scope:Value({}),
	equippedId = _scope:Value(""),
	selectedId = _scope:Value(BadgeConfig.defaultEquippedId),
}

return BadgeState
