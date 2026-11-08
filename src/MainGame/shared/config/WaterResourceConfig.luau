--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)

local WaterResourceConfig = {
	gatherCooldown = 4,
	itemPool = { "Crab", "Fish", "Kelp", "Frog" },

	drinkAmount = 10,
	drinkCooldown = 1,
	drinkHoldDuration = 0.6,
	gatherHoldDuration = 0.5,

	drinkKeys = { keyboard = Enum.KeyCode.E, gamepad = Enum.KeyCode.ButtonX },
	gatherKeys = { keyboard = Enum.KeyCode.Q, gamepad = Enum.KeyCode.DPadDown },

	promptDistance = 12,
	gatherPromptOffset = 2.5,
	promptHeightAboveWater = 3,
}

assert(#WaterResourceConfig.itemPool > 0, "[WaterResourceConfig] itemPool is empty")
for _, itemId in WaterResourceConfig.itemPool do
	assert(ItemConfig[itemId] ~= nil, `[WaterResourceConfig] itemPool "{itemId}" is not a defined item`)
end

return WaterResourceConfig
