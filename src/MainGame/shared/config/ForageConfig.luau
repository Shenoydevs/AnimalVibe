--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)

export type ForageDrop = { itemID: string, minCount: number, maxCount: number }

export type ForageKind = {
	actionText: string,
	objectText: string,
	drops: { ForageDrop }, -- one entry rolled per harvest
	harvests: number,
	holdDuration: number,
	destroyWhenDepleted: boolean, -- false keeps large set pieces (farm fields) standing once picked clean
}

-- Keyed by the biome PropChance category (or "Farm" for Farmland's field model) whose props become forageable.
local ForageConfig = {
	tag = "Forage",
	kindAttribute = "forageKind",
	promptDistance = 10,
	harvestCooldown = 0.75,
	zoneRadiusScale = 0.9,

	kinds = {
		Blueberries = {
			actionText = "Pick",
			objectText = "Blueberry bush",
			drops = { { itemID = "Blueberry", minCount = 1, maxCount = 2 } },
			harvests = 2,
			holdDuration = 0.6,
			destroyWhenDepleted = true,
		},
		Raspberries = {
			actionText = "Pick",
			objectText = "Raspberry bush",
			drops = { { itemID = "Raspberry", minCount = 1, maxCount = 2 } },
			harvests = 2,
			holdDuration = 0.6,
			destroyWhenDepleted = true,
		},
		Grapes = {
			actionText = "Pick",
			objectText = "Grapevine",
			drops = { { itemID = "Grapes", minCount = 1, maxCount = 3 } },
			harvests = 3,
			holdDuration = 0.8,
			destroyWhenDepleted = true,
		},
		Farm = {
			actionText = "Harvest",
			objectText = "Farm plot",
			drops = {
				{ itemID = "Carrot", minCount = 1, maxCount = 2 },
				{ itemID = "Wheat", minCount = 1, maxCount = 2 },
				{ itemID = "Watermelon", minCount = 1, maxCount = 1 },
				{ itemID = "Mango", minCount = 1, maxCount = 2 },
			},
			harvests = 8,
			holdDuration = 1.2,
			destroyWhenDepleted = false,
		},
	} :: { [string]: ForageKind },
}

for kindName, kind in ForageConfig.kinds do
	assert(kind.harvests >= 1, `[ForageConfig] {kindName} needs at least one harvest`)
	assert(#kind.drops > 0, `[ForageConfig] {kindName} has no drops`)
	for _, drop in kind.drops do
		assert(ItemConfig[drop.itemID] ~= nil, `[ForageConfig] {kindName} drop "{drop.itemID}" is not a defined item`)
		assert(drop.minCount >= 1 and drop.maxCount >= drop.minCount, `[ForageConfig] {kindName} invalid count for "{drop.itemID}"`)
	end
end

return ForageConfig
