--!strict

local _animals = {
	Horse = { starter = true, order = 1, coinPrice = 0, requiredLevel = 1, robuxPrice = 0 },
	Wolf = { starter = true, order = 2, coinPrice = 0, requiredLevel = 1, robuxPrice = 0 },
	Bear = { starter = true, order = 3, coinPrice = 0, requiredLevel = 1, robuxPrice = 0 },
	Deer = { starter = true, order = 4, coinPrice = 0, requiredLevel = 1, robuxPrice = 0 },
	Fox = { starter = false, order = 5, coinPrice = 500, requiredLevel = 5, robuxPrice = 49 },
	Lion = { starter = false, order = 6, coinPrice = 1500, requiredLevel = 10, robuxPrice = 149 },
	Elephant = { starter = false, order = 7, coinPrice = 3000, requiredLevel = 15, robuxPrice = 249 },
}

-- Robux purchases are not enabled.
return _animals
