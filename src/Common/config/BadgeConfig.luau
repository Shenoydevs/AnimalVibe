--!strict

local _icon = "rbxassetid://139693194229990"

local BadgeConfig = {
	rarities = { "Common", "Rare", "Epic", "Legendary", "Exclusive" },
	rarityColors = {
		Common = Color3.fromRGB(160, 160, 160),
		Rare = Color3.fromRGB(70, 150, 255),
		Epic = Color3.fromRGB(175, 95, 235),
		Legendary = Color3.fromRGB(255, 195, 60),
		Exclusive = Color3.fromRGB(235, 75, 75),
	},
	badges = {
		commonPaw = {
			displayName = "Friendly Paw",
			description = "A friendly paw for the start of your adventure.",
			rarity = "Common",
			icon = _icon,
			order = 1,
		},
		commonLeaf = {
			displayName = "Forest Leaf",
			description = "A little piece of the forest to carry with you.",
			rarity = "Common",
			icon = _icon,
			order = 2,
		},
		rareWave = {
			displayName = "Ocean Wave",
			description = "A splash of color from the open ocean.",
			rarity = "Rare",
			icon = _icon,
			order = 1,
		},
		rareFeather = {
			displayName = "Sky Feather",
			description = "A feather carried on a wandering breeze.",
			rarity = "Rare",
			icon = _icon,
			order = 2,
		},
		epicMoon = {
			displayName = "Moon Glow",
			description = "A quiet glow for moonlit adventures.",
			rarity = "Epic",
			icon = _icon,
			order = 1,
		},
		epicCrystal = {
			displayName = "Wild Crystal",
			description = "A bright crystal from deep in the wild.",
			rarity = "Epic",
			icon = _icon,
			order = 2,
		},
		legendaryCrown = {
			displayName = "Golden Crown",
			description = "A golden touch for your favorite animal.",
			rarity = "Legendary",
			icon = _icon,
			order = 1,
		},
		legendarySun = {
			displayName = "Rising Sun",
			description = "A warm reminder of a brand-new day.",
			rarity = "Legendary",
			icon = _icon,
			order = 2,
		},
		exclusiveFlame = {
			displayName = "Wild Flame",
			description = "A bold little flame full of adventure.",
			rarity = "Exclusive",
			icon = _icon,
			order = 1,
		},
		exclusiveStar = {
			displayName = "Scarlet Star",
			description = "A bright star with a splash of scarlet.",
			rarity = "Exclusive",
			icon = _icon,
			order = 2,
		},
	},
	starterEarned = {
		commonPaw = true,
		rareWave = true,
		epicMoon = true,
		legendaryCrown = true,
		exclusiveFlame = true,
	},
	defaultEquippedId = "commonPaw",
}

return BadgeConfig
