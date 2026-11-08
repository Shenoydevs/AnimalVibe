--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local Network = require(ReplicatedStorage.Shared.network)

local _networker = Networker.client.new(Network.FirstAnimal, {})

return {
	confirm = function(animalName)
		local result = _networker:fetch("_confirm", animalName)
		return result
	end,
	equip = function(animalName)
		local result = _networker:fetch("_equip", animalName)
		return result
	end,
	buy = function(animalName)
		local result = _networker:fetch("_buy", animalName)
		return result
	end,
	buySkin = function(animalName, skinName)
		local result = _networker:fetch("_buySkin", animalName, skinName)
		return result
	end,
	equipSkin = function(animalName, skinName)
		local result = _networker:fetch("_equipSkin", animalName, skinName)
		return result
	end,
}
