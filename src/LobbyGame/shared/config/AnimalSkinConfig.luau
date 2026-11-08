--!strict
local AnimalShopTypes = require(script.Parent.Parent.types.AnimalShopTypes)

type AnimalSkin = AnimalShopTypes.AnimalSkin

-- Placeholder skins until art is ready. Skin keys are saved in Animals.<animal>.Skins; keep them stable.
local skins: { [string]: { [string]: AnimalSkin } } = {
	Horse = {
		Default = { order = 1, coinPrice = 0 },
		Golden = { order = 2, coinPrice = 1000 },
		Shadow = { order = 3, coinPrice = 2500 },
	},
	Wolf = {
		Default = { order = 1, coinPrice = 0 },
		Golden = { order = 2, coinPrice = 1000 },
		Shadow = { order = 3, coinPrice = 2500 },
	},
	Bear = {
		Default = { order = 1, coinPrice = 0 },
		Golden = { order = 2, coinPrice = 1000 },
		Shadow = { order = 3, coinPrice = 2500 },
	},
	Deer = {
		Default = { order = 1, coinPrice = 0 },
		Golden = { order = 2, coinPrice = 1000 },
		Shadow = { order = 3, coinPrice = 2500 },
	},
	Fox = {
		Default = { order = 1, coinPrice = 0 },
		Golden = { order = 2, coinPrice = 1000 },
		Shadow = { order = 3, coinPrice = 2500 },
	},
	Lion = {
		Default = { order = 1, coinPrice = 0 },
		Golden = { order = 2, coinPrice = 1000 },
		Shadow = { order = 3, coinPrice = 2500 },
	},
	Elephant = {
		Default = { order = 1, coinPrice = 0 },
		Golden = { order = 2, coinPrice = 1000 },
		Shadow = { order = 3, coinPrice = 2500 },
	},
}

return skins
