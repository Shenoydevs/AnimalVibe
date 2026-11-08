--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryTypes = require(ReplicatedStorage.Shared.types.InventoryTypes)
type ItemData = InventoryTypes.ItemData

local itemConfig: { [string]: ItemData } = {
	["Acorn"] = { displayName = "Acorn", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 5, slot = "Mouth", useType = "Eat" },
	["Almond"] = { displayName = "Almond", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 5, slot = "Mouth", useType = "Eat" },
	["Apple"] = { displayName = "Apple", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 10, slot = "Mouth", useType = "Eat" },
	["Avocado"] = { displayName = "Avocado", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 15, slot = "Mouth", useType = "Eat" },
	["Banana"] = { displayName = "Banana", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 15, slot = "Mouth", useType = "Eat" },
	["Blackberry"] = { displayName = "Blackberry", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 7, slot = "Mouth", useType = "Eat" },
	["Blueberry"] = { displayName = "Blueberry", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 7, slot = "Mouth", useType = "Eat" },
	["Carrot"] = { displayName = "Carrot", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 10, slot = "Mouth", useType = "Eat" },
	["Cherry"] = { displayName = "Cherry", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 7, slot = "Mouth", useType = "Eat" },
	["Coconut"] = { displayName = "Coconut", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 15, slot = "Mouth", useType = "Eat" },
	["Crab"] = { displayName = "Crab", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 35, slot = "Mouth", useType = "Eat" },
	["Durian"] = { displayName = "Durian", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 20, slot = "Mouth", useType = "Eat" },
	["Fish"] = { displayName = "Fish", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 25, slot = "Mouth", useType = "Eat" },
	["Frog"] = { displayName = "Frog", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 5, slot = "Mouth", useType = "Eat" },
	["Grapes"] = { displayName = "Grapes", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 7, slot = "Mouth", useType = "Eat" },
	["Kelp"] = { displayName = "Kelp", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 5, slot = "Mouth", useType = "Eat" },
	["Mango"] = { displayName = "Mango", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 10, slot = "Mouth", useType = "Eat" },
	["Meat"] = { displayName = "Raw Meat", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 40, healValue = 20, slot = "Mouth", useType = "Eat" },
	["Raspberry"] = { displayName = "Raspberry", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 5, slot = "Mouth", useType = "Eat" },
	["Watermelon"] = { displayName = "Watermelon", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 15, slot = "Mouth", useType = "Eat" },
	["Wheat"] = { displayName = "Wheat", category = "Food", icon = "rbxassetid://124142247223281", canShare = true, hungerValue = 20, slot = "Mouth", useType = "Eat" },

	["Animal Bones"] = { displayName = "Animal Bones", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },
	["Blue Flower"] = { displayName = "Blue Flower", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },
	["Bone Charm"] = { displayName = "Bone Charm", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },
	["Brass Button"] = { displayName = "Brass Button", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },
	["Green Flower"] = { displayName = "Green Flower", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },
	["Hunter's Badge"] = { displayName = "Hunter's Badge", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },
	["Hunter's Boot Sole"] = { displayName = "Hunter's Boot Sole", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },
	["Moonstone Shard"] = { displayName = "Moonstone Shard", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },
	["NOVA Fragments"] = { displayName = "NOVA Fragments", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },
	["Permit"] = { displayName = "Hunting Permit", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },
	["Red Flower"] = { displayName = "Red Flower", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },
	["Scrap Metal"] = { displayName = "Scrap Metal", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },
	["Shell Casing"] = { displayName = "Shell Casing", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },
	["Trophy Tag"] = { displayName = "Trophy Tag", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },
	["Wire Coil"] = { displayName = "Wire Coil", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },
	["Wood"] = { displayName = "Wood", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },
	["Yellow Flower"] = { displayName = "Yellow Flower", category = "Supplies", icon = "rbxassetid://124142247223281", slot = "Mouth", useType = "None" },

	["Hunting Knife"] = { displayName = "Hunting Knife", category = "Tools", icon = "rbxassetid://124142247223281", slot = "Hotbar", useType = "None" },
	["Key"] = { displayName = "Key", category = "Tools", icon = "rbxassetid://124142247223281", slot = "Hotbar", useType = "Unlock" },
	["Rifle Scope"] = { displayName = "Rifle Scope", category = "Tools", icon = "rbxassetid://124142247223281", slot = "Hotbar", useType = "None" },
	["Scent Rag"] = { displayName = "Scent Rag", category = "Tools", icon = "rbxassetid://124142247223281", slot = "Hotbar", useType = "None" },

	["Ancient Sack"] = { displayName = "Ancient Sack", category = "Tools", icon = "rbxassetid://124142247223281", notDroppable = true, inventoryCapacity = 70, slot = "Hotbar", useType = "None" },
	["Big Sack"] = { displayName = "Big Sack", category = "Tools", icon = "rbxassetid://124142247223281", notDroppable = true, inventoryCapacity = 20, slot = "Hotbar", useType = "None" },
	["Medium Sack"] = { displayName = "Medium Sack", category = "Tools", icon = "rbxassetid://124142247223281", notDroppable = true, inventoryCapacity = 10, slot = "Hotbar", useType = "None" },
	["Mini Sack"] = { displayName = "Mini Sack", category = "Tools", icon = "rbxassetid://124142247223281", notDroppable = true, inventoryCapacity = 5, slot = "Hotbar", useType = "None" },
	["Sack"] = { displayName = "Sack", category = "Tools", icon = "rbxassetid://124142247223281", notDroppable = true, inventoryCapacity = 4, slot = "Hotbar", useType = "None" },

	["Basic Bandage"] = { displayName = "Basic Bandage", category = "Gear", icon = "rbxassetid://124142247223281", healAmount = 20, slot = "Mouth", useType = "Heal" },
	["Emergency Bandage"] = { displayName = "Emergency Bandage", category = "Gear", icon = "rbxassetid://124142247223281", healAmount = 60, slot = "Mouth", useType = "Heal" },
	["Medkit"] = { displayName = "Medkit", category = "Gear", icon = "rbxassetid://124142247223281", healAmount = 50, slot = "Mouth", useType = "Heal" },

	["Alpha Crown"] = { displayName = "Alpha Crown", category = "Gear", icon = "rbxassetid://124142247223281", hpBonus = 7 },
	["Ghost Pelt"] = { displayName = "Ghost Pelt", category = "Gear", icon = "rbxassetid://124142247223281", hpBonus = 15 },
	["Glow Moss Collar"] = { displayName = "Glow Moss Collar", category = "Gear", icon = "rbxassetid://124142247223281", hpBonus = 20 },
	["Hunter's Trophy Belt"] = { displayName = "Hunter's Trophy Belt", category = "Gear", icon = "rbxassetid://124142247223281", hpBonus = 5 },
	["Leather Chest Strap"] = { displayName = "Leather Chest Strap", category = "Gear", icon = "rbxassetid://124142247223281", hpBonus = 3 },
	["Leather Head Guard"] = { displayName = "Leather Head Guard", category = "Gear", icon = "rbxassetid://124142247223281", hpBonus = 10 },
	["Leather Leg Wraps"] = { displayName = "Leather Leg Wraps", category = "Gear", icon = "rbxassetid://124142247223281", hpBonus = 5, speedBonus = 7 },
	["Leather Pads"] = { displayName = "Leather Pads", category = "Gear", icon = "rbxassetid://124142247223281", hpBonus = 3 },
	["Leather Vest"] = { displayName = "Leather Vest", category = "Gear", icon = "rbxassetid://124142247223281", hpBonus = 20 },
	["Neck Spike Collar"] = { displayName = "Neck Spike Collar", category = "Gear", icon = "rbxassetid://124142247223281", hpBonus = 5 },
	["Night Vision Goggles"] = { displayName = "Night Vision Goggles", category = "Gear", icon = "rbxassetid://124142247223281" },
	["Rally Horn"] = { displayName = "Rally Horn", category = "Gear", icon = "rbxassetid://124142247223281" },
	["Static Charge Fur Coat"] = { displayName = "Static Charge Fur Coat", category = "Gear", icon = "rbxassetid://124142247223281", hpBonus = 40 },
	["Strong Lantern"] = { displayName = "Strong Lantern", category = "Gear", icon = "rbxassetid://124142247223281" },
	["Weak Lantern"] = { displayName = "Weak Lantern", category = "Gear", icon = "rbxassetid://124142247223281" },
	["Wooden Chest Strap"] = { displayName = "Wooden Chest Strap", category = "Gear", icon = "rbxassetid://124142247223281", hpBonus = 7 },
	["Wooden Head Guard"] = { displayName = "Wooden Head Guard", category = "Gear", icon = "rbxassetid://124142247223281", hpBonus = 15 },
	["Wooden Leg Wraps"] = { displayName = "Wooden Leg Wraps", category = "Gear", icon = "rbxassetid://124142247223281", hpBonus = 10, speedBonus = 5 },
	["Wooden Pads"] = { displayName = "Wooden Pads", category = "Gear", icon = "rbxassetid://124142247223281", hpBonus = 7 },
	["Wooden Vest"] = { displayName = "Wooden Vest", category = "Gear", icon = "rbxassetid://124142247223281", hpBonus = 30 },
}

for itemId, itemData in itemConfig do
	assert(itemData.hungerValue == nil or itemData.category == "Food", `[ItemConfig] "{itemId}" has a hungerValue but is not Food`)
	assert(itemData.hpBonus == nil or itemData.category == "Gear", `[ItemConfig] "{itemId}" has an hpBonus but is not Gear`)
	assert(itemData.speedBonus == nil or itemData.category == "Gear", `[ItemConfig] "{itemId}" has a speedBonus but is not Gear`)
	assert(itemData.healAmount == nil or itemData.category == "Gear", `[ItemConfig] "{itemId}" has a healAmount but is not Gear`)
	assert(itemData.inventoryCapacity == nil or itemData.category == "Tools", `[ItemConfig] "{itemId}" has an inventoryCapacity but is not Tools`)
	assert(itemData.slot ~= "Hotbar" or itemData.category == "Tools", `[ItemConfig] "{itemId}" is slot=Hotbar but not Tools category`)
	assert(itemData.slot ~= "Mouth" or itemData.category ~= "Tools", `[ItemConfig] "{itemId}" is slot=Mouth but is Tools category`)
	assert(itemData.useType ~= "Eat" or itemData.category == "Food", `[ItemConfig] "{itemId}" has useType Eat but is not Food`)
	assert(itemData.useType ~= "Heal" or itemData.healAmount ~= nil, `[ItemConfig] "{itemId}" has useType Heal but no healAmount`)
	assert(itemData.useType ~= "Unlock" or itemData.slot == "Hotbar", `[ItemConfig] "{itemId}" has useType Unlock but is not slot=Hotbar`)
end

return itemConfig
