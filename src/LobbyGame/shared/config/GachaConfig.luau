--!strict
local GachaTypes = require(script.Parent.Parent.types.GachaTypes)

type Rarity = GachaTypes.Rarity
type Style = GachaTypes.Style

-- Placeholder catalog and balance until real styles and tuning exist.
-- Style IDs are saved in Gacha.styles; keep them stable when editing display text.
local GachaConfig = {
	maxStyles = 3,
	-- The pity counters guarantee this rarity on the spin that reaches the target.
	pityTarget = 50,
	secretPityTarget = 200,
	-- Lowest to highest; auto-spin goals compare positions in this list.
	rarities = { "Common", "Rare", "Epic", "Legendary", "Mythical", "Secret" } :: { Rarity },
	-- Text colours, matching the authored SpinGui odds rows; Secret has no row and shimmers instead.
	rarityColors = {
		Common = ColorSequence.new(Color3.fromRGB(133, 153, 59)),
		Rare = ColorSequence.new(Color3.fromRGB(39, 197, 214)),
		Epic = ColorSequence.new(Color3.fromRGB(220, 49, 215)),
		Legendary = ColorSequence.new(Color3.fromRGB(220, 147, 49)),
		Mythical = ColorSequence.new(Color3.fromRGB(219, 50, 54)),
		Secret = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 200)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(130, 200, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 140)),
		}),
	} :: { [Rarity]: ColorSequence },
	-- Percent chances per spin type; each table sums to 100.
	odds = {
		normal = { Common = 60, Rare = 25, Epic = 10, Legendary = 4, Mythical = 0.9, Secret = 0.1 },
		lucky = { Common = 30, Rare = 30, Epic = 22, Legendary = 12, Mythical = 5, Secret = 1 },
	} :: { [string]: { [Rarity]: number } },
	duplicateCoins = {
		Common = 25,
		Rare = 50,
		Epic = 100,
		Legendary = 250,
		Mythical = 500,
		Secret = 1000,
	} :: { [Rarity]: number },
	styles = {
		pebble = { name = "Test Common 1", rarity = "Common", description = "Placeholder common style." },
		bark = { name = "Test Common 2", rarity = "Common", description = "Placeholder common style." },
		frost = { name = "Test Rare 1", rarity = "Rare", description = "Placeholder rare style." },
		moss = { name = "Test Rare 2", rarity = "Rare", description = "Placeholder rare style." },
		ember = { name = "Test Epic 1", rarity = "Epic", description = "Placeholder epic style." },
		tide = { name = "Test Epic 2", rarity = "Epic", description = "Placeholder epic style." },
		solar = { name = "Test Legendary 1", rarity = "Legendary", description = "Placeholder legendary style." },
		storm = { name = "Test Legendary 2", rarity = "Legendary", description = "Placeholder legendary style." },
		nebula = { name = "Test Mythical 1", rarity = "Mythical", description = "Placeholder mythical style." },
		aurora = { name = "Test Mythical 2", rarity = "Mythical", description = "Placeholder mythical style." },
		void = { name = "Test Secret", rarity = "Secret", description = "Placeholder secret style." },
	} :: { [string]: Style },
}

return GachaConfig
