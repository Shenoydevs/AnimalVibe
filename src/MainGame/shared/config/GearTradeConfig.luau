--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)

type TradeCost = {
	itemID: string,
	count: number,
}

export type GearTrade = {
	costs: { TradeCost }?, -- nil = no trade-in source defined yet
}

local GearTradeConfig: { [string]: GearTrade } = {
	["Leather Pads"] = { costs = { { itemID = "Hunter's Boot Sole", count = 1 }, { itemID = "Scent Rag", count = 1 } } },
	["Neck Spike Collar"] = { costs = { { itemID = "Wire Coil", count = 2 }, { itemID = "Hunting Knife", count = 1 } } },
	["Leather Vest"] = { costs = { { itemID = "Hunter's Boot Sole", count = 4 }, { itemID = "Brass Button", count = 3 }, { itemID = "Scent Rag", count = 2 } } },
	["Leather Chest Strap"] = { costs = { { itemID = "Hunter's Boot Sole", count = 2 }, { itemID = "Scent Rag", count = 1 } } },
	["Leather Leg Wraps"] = { costs = { { itemID = "Hunter's Boot Sole", count = 1 } } },
	["Leather Head Guard"] = { costs = { { itemID = "Hunter's Boot Sole", count = 2 }, { itemID = "Wire Coil", count = 2 }, { itemID = "Scent Rag", count = 1 } } },
	["Wooden Pads"] = { costs = { { itemID = "Wood", count = 8 } } },
	["Wooden Head Guard"] = { costs = { { itemID = "Wood", count = 10 } } },
	["Wooden Leg Wraps"] = { costs = { { itemID = "Wood", count = 7 } } },
	["Wooden Vest"] = { costs = { { itemID = "Wood", count = 15 } } },
	["Wooden Chest Strap"] = { costs = { { itemID = "Wood", count = 9 } } },
	["Medkit"] = { costs = nil },
	["Basic Bandage"] = { costs = { { itemID = "Scent Rag", count = 2 } } },
	["Emergency Bandage"] = { costs = { { itemID = "Scent Rag", count = 3 }, { itemID = "Wire Coil", count = 2 } } },
	["Mini Sack"] = { costs = nil },
	["Medium Sack"] = { costs = nil },
	["Big Sack"] = { costs = nil },
	["Ancient Sack"] = { costs = { { itemID = "Moonstone Shard", count = 10 } } },
	["Night Vision Goggles"] = { costs = { { itemID = "Rifle Scope", count = 2 }, { itemID = "Brass Button", count = 1 }, { itemID = "Scrap Metal", count = 5 } } },
	["Glow Moss Collar"] = { costs = nil },
	["Static Charge Fur Coat"] = { costs = nil },
	["Rally Horn"] = { costs = nil },
	["Hunter's Trophy Belt"] = { costs = { { itemID = "Hunter's Badge", count = 1 }, { itemID = "Permit", count = 1 }, { itemID = "Bone Charm", count = 2 } } },
	["Ghost Pelt"] = { costs = { { itemID = "Hunter's Badge", count = 2 }, { itemID = "Bone Charm", count = 3 }, { itemID = "Permit", count = 1 }, { itemID = "Moonstone Shard", count = 20 } } },
	["Alpha Crown"] = { costs = { { itemID = "Moonstone Shard", count = 15 }, { itemID = "Bone Charm", count = 6 }, { itemID = "Scrap Metal", count = 30 } } },
	["Weak Lantern"] = { costs = nil },
	["Strong Lantern"] = { costs = nil },
}

for itemId, trade in GearTradeConfig do
	assert(ItemConfig[itemId] ~= nil, `[GearTradeConfig] "{itemId}" is not a defined item`)
	assert(ItemConfig[itemId].category == "Gear" or ItemConfig[itemId].category == "Tools", `[GearTradeConfig] "{itemId}" is not a Gear or Tools item`)
	if trade.costs then
		assert(#trade.costs > 0, `[GearTradeConfig] "{itemId}" has an empty costs list`)
		for _, cost in trade.costs do
			assert(ItemConfig[cost.itemID] ~= nil, `[GearTradeConfig] "{itemId}" references unknown item "{cost.itemID}"`)
			assert(cost.count >= 1, `[GearTradeConfig] "{itemId}" has an invalid count for "{cost.itemID}"`)
		end
	end
end

for itemId, itemData in ItemConfig do
	if itemData.category == "Gear" then
		assert(GearTradeConfig[itemId] ~= nil, `[GearTradeConfig] missing entry for Gear item "{itemId}"`)
	end
end

return GearTradeConfig
