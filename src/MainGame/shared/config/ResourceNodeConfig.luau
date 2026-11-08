--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)

export type DropEntry = {
	itemID: string,
	minCount: number,
	maxCount: number,
}

type ResourceNodeData = {
	shakeThreshold: number,
	midDropPool: { DropEntry },
	breakDrop: DropEntry,
	defaultMaxHealth: number,
	healthByVariant: { [string]: number },
}

-- healthByVariant is keyed by the placed tree's template name (Tree1-4, MapGenerationService
-- stamps this as the "treeVariant" attribute at clone time since the clone gets renamed to its
-- chunk coordinate right after). Unrecognized/missing variants fall back to defaultMaxHealth.
local ResourceNodeConfig: ResourceNodeData = {
	shakeThreshold = 0.5,
	midDropPool = {
		{ itemID = "Apple", minCount = 1, maxCount = 2 },
		{ itemID = "Acorn", minCount = 1, maxCount = 2 },
		{ itemID = "Avocado", minCount = 1, maxCount = 2 },
		{ itemID = "Almond", minCount = 1, maxCount = 2 },
		{ itemID = "Banana", minCount = 1, maxCount = 2 },
		{ itemID = "Cherry", minCount = 1, maxCount = 2 },
		{ itemID = "Coconut", minCount = 1, maxCount = 2 },
		{ itemID = "Durian", minCount = 1, maxCount = 2 },
	},
	breakDrop = { itemID = "Wood", minCount = 2, maxCount = 4 },
	defaultMaxHealth = 150,
	healthByVariant = {
		Tree2 = 80,
		Tree3 = 120,
		Tree1 = 150,
		Tree4 = 220,
	},
}

assert(
	ResourceNodeConfig.shakeThreshold > 0 and ResourceNodeConfig.shakeThreshold < 1,
	"[ResourceNodeConfig] invalid shakeThreshold"
)
assert(
	ResourceNodeConfig.breakDrop.minCount >= 1
		and ResourceNodeConfig.breakDrop.maxCount >= ResourceNodeConfig.breakDrop.minCount,
	"[ResourceNodeConfig] invalid breakDrop"
)
assert(ItemConfig[ResourceNodeConfig.breakDrop.itemID] ~= nil, `[ResourceNodeConfig] breakDrop "{ResourceNodeConfig.breakDrop.itemID}" is not a defined item`)
assert(#ResourceNodeConfig.midDropPool > 0, "[ResourceNodeConfig] midDropPool is empty")
for _, drop in ResourceNodeConfig.midDropPool do
	assert(ItemConfig[drop.itemID] ~= nil, `[ResourceNodeConfig] midDropPool "{drop.itemID}" is not a defined item`)
	assert(
		drop.minCount >= 1 and drop.maxCount >= drop.minCount,
		`[ResourceNodeConfig] invalid drop count for "{drop.itemID}"`
	)
end
assert(ResourceNodeConfig.defaultMaxHealth > 0, "[ResourceNodeConfig] invalid defaultMaxHealth")
for variant, health in ResourceNodeConfig.healthByVariant do
	assert(health > 0, `[ResourceNodeConfig] invalid health for "{variant}"`)
end

return ResourceNodeConfig
