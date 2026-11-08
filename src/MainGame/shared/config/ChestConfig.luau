--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)

local ChestConfig = {
	keyItemID = "Key",
	openAnimationId = "rbxassetid://137914516379223",
	destroyDelayAfterOpen = 3,

	lootWeights = {
		Acorn = 3.33,
		Almond = 3.33,
		Blueberry = 3.33,
		Cherry = 3.33,
		Frog = 3.33,
		Grapes = 3.33,
		Kelp = 3.33,
		Raspberry = 3.33,
		Wood = 3.34,
		["Scrap Metal"] = 3.33,
		["Wire Coil"] = 3.33,
		["Animal Bones"] = 3.33,
		["Brass Button"] = 3.33,
		["Shell Casing"] = 3.33,
		["Trophy Tag"] = 3.33,

		Apple = 3.57,
		Carrot = 3.57,
		Mango = 3.57,
		["Blue Flower"] = 3.57,
		["Green Flower"] = 3.57,
		["Red Flower"] = 3.57,
		["Yellow Flower"] = 3.58,

		Avocado = 1.5,
		Banana = 1.5,
		Coconut = 1.5,
		Watermelon = 1.5,
		Durian = 1.5,
		Wheat = 1.5,
		Fish = 1.5,
		Crab = 1.5,
		Meat = 1.5,
		["Moonstone Shard"] = 1.5,

		["Bone Charm"] = 7,
		Permit = 3,
	},
}

assert(ItemConfig[ChestConfig.keyItemID] ~= nil, `[ChestConfig] keyItemID "{ChestConfig.keyItemID}" is not a defined item`)
for itemId, weight in ChestConfig.lootWeights do
	assert(ItemConfig[itemId] ~= nil, `[ChestConfig] loot entry "{itemId}" is not a defined item`)
	assert(weight > 0, `[ChestConfig] loot entry "{itemId}" has a non-positive weight`)
end

return ChestConfig
