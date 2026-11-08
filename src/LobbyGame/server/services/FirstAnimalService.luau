--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local Networker = require(ReplicatedStorage.Packages.Networker)
local AnimalConfig = require(ReplicatedStorage.Common.config.AnimalConfig)
local AnimalShopConfig = require(ReplicatedStorage.Shared.config.AnimalShopConfig)
local AnimalSkinConfig = require(ReplicatedStorage.Shared.config.AnimalSkinConfig)
local Network = require(ReplicatedStorage.Shared.network)
local ChallengeService = require(script.Parent.ChallengeService)

local _animals = ReplicatedStorage.Assets.Animals
local _lastRequest = {}
local _characterConnections = {}

local Private = {}
local Shared = {}

function Private._getRig(animalName)
	local rig = _animals:FindFirstChild(animalName)
	if not (rig and rig:IsA("Model")) then
		return nil
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart") and rig:FindFirstChildOfClass("Humanoid")) then
		return nil
	end
	return rig
end

function Private._spawn(player)
	if player.Parent ~= Players or not DataService:hasProfile(player) then
		return
	end
	if not DataService:get(player, { "Inventory", "HasSelectedFirstAnimal" }) then
		return
	end

	local animalName: string = DataService:get(player, { "Inventory", "EquippedAnimal" })
	local character = player.Character
	if not AnimalShopConfig[animalName] or not character or character:GetAttribute("animalName") == animalName then
		return
	end
	if not DataService:get(player, { "Animals", animalName, "Unlocked" }) then
		return
	end
	local rig = Private._getRig(animalName)
	if not rig then
		return
	end

	local replacement = rig:Clone()
	local humanoid: Humanoid = replacement:FindFirstChildOfClass("Humanoid")
	local config = AnimalConfig[animalName]
	if config then
		humanoid.MaxHealth = config.health
		humanoid.Health = config.health
		humanoid.WalkSpeed = config.walkSpeed
	end
	replacement.Name = player.Name
	replacement:SetAttribute("animalName", animalName)
	replacement:PivotTo(character:GetPivot())
	replacement.Parent = workspace
	player.Character = replacement
	character:Destroy()
end

function Private._checkRequest(player, animalName)
	if player.Parent ~= Players or not DataService:hasProfile(player) then
		return "notReady"
	end
	local now = workspace:GetServerTimeNow()
	local lastRequest = _lastRequest[player]
	if lastRequest and now - lastRequest < 0.25 then
		return "rateLimited"
	end
	_lastRequest[player] = now
	if type(animalName) ~= "string" or not AnimalShopConfig[animalName] then
		return "invalid"
	end
	return nil
end

function Private._confirm(_, player, animalName)
	local rejection = Private._checkRequest(player, animalName)
	if rejection then
		return { status = rejection }
	end
	if not AnimalShopConfig[animalName].starter then
		return { status = "invalid" }
	end
	if DataService:get(player, { "Inventory", "HasSelectedFirstAnimal" }) then
		return { status = "alreadySelected" }
	end
	if not DataService:get(player, { "Animals", animalName, "Unlocked" }) then
		return { status = "locked" }
	end
	if not Private._getRig(animalName) then
		return { status = "unavailable" }
	end

	DataService:set(player, { "Inventory", "EquippedAnimal" }, animalName)
	DataService:set(player, { "Inventory", "HasSelectedFirstAnimal" }, true)
	Private._spawn(player)
	ChallengeService.recordEquip(player, animalName)
	return { status = "selected" }
end

function Private._equip(_, player, animalName)
	local rejection = Private._checkRequest(player, animalName)
	if rejection then
		return { status = rejection }
	end
	if not DataService:get(player, { "Inventory", "HasSelectedFirstAnimal" }) then
		return { status = "chooseStarter" }
	end
	if not Private._getRig(animalName) then
		return { status = "unavailable" }
	end
	if not DataService:get(player, { "Animals", animalName, "Unlocked" }) then
		return { status = "locked" }
	end

	DataService:set(player, { "Inventory", "EquippedAnimal" }, animalName)
	Private._spawn(player)
	ChallengeService.recordEquip(player, animalName)
	return { status = "equipped" }
end

function Private._buy(_, player, animalName)
	local rejection = Private._checkRequest(player, animalName)
	if rejection then
		return { status = rejection }
	end
	if not DataService:get(player, { "Inventory", "HasSelectedFirstAnimal" }) then
		return { status = "chooseStarter" }
	end
	if not Private._getRig(animalName) then
		return { status = "unavailable" }
	end
	local config = AnimalShopConfig[animalName]
	if config.starter or DataService:get(player, { "Animals", animalName, "Unlocked" }) then
		return { status = "owned" }
	end
	if DataService:get(player, { "PlayerStats", "Level" }) < config.requiredLevel then
		return { status = "levelRequired" }
	end
	local coins: number = DataService:get(player, { "PlayerStats", "Nova" })
	if coins < config.coinPrice then
		return { status = "insufficientCoins" }
	end

	-- Both writes use the existing session-locked profile and do not yield.
	DataService:set(player, { "Animals", animalName, "Unlocked" }, true)
	DataService:set(player, { "PlayerStats", "Nova" }, coins - config.coinPrice)
	return { status = "purchased" }
end

function Private._checkSkinRequest(player, animalName, skinName)
	local rejection = Private._checkRequest(player, animalName)
	if rejection then
		return rejection
	end
	if type(skinName) ~= "string" or not AnimalSkinConfig[animalName] or not AnimalSkinConfig[animalName][skinName] then
		return "invalid"
	end
	if not DataService:get(player, { "Inventory", "HasSelectedFirstAnimal" }) then
		return "chooseStarter"
	end
	if not DataService:get(player, { "Animals", animalName, "Unlocked" }) then
		return "locked"
	end
	return nil
end

function Private._buySkin(_, player, animalName, skinName)
	local rejection = Private._checkSkinRequest(player, animalName, skinName)
	if rejection then
		return { status = rejection }
	end
	if DataService:get(player, { "Animals", animalName, "Skins", skinName }) then
		return { status = "owned" }
	end
	local price = AnimalSkinConfig[animalName][skinName].coinPrice
	local coins: number = DataService:get(player, { "PlayerStats", "Nova" })
	if coins < price then
		return { status = "insufficientCoins" }
	end

	-- Both writes use the existing session-locked profile and do not yield.
	DataService:set(player, { "Animals", animalName, "Skins", skinName }, true)
	DataService:set(player, { "PlayerStats", "Nova" }, coins - price)
	return { status = "purchased" }
end

function Private._equipSkin(_, player, animalName, skinName)
	local rejection = Private._checkSkinRequest(player, animalName, skinName)
	if rejection then
		return { status = rejection }
	end
	if not DataService:get(player, { "Animals", animalName, "Skins", skinName }) then
		return { status = "locked" }
	end

	DataService:set(player, { "Animals", animalName, "EquippedSkin" }, skinName)
	return { status = "equipped" }
end

function Shared.loadPlayer(player)
	_characterConnections[player] = player.CharacterAdded:Connect(function()
		Private._spawn(player)
	end)
	Private._spawn(player)
end

function Shared.OnStart()
	Networker.server.new(Network.FirstAnimal, Private, {
		Private._confirm,
		Private._equip,
		Private._buy,
		Private._buySkin,
		Private._equipSkin,
	})
	Players.PlayerRemoving:Connect(function(player)
		local connection = _characterConnections[player]
		if connection then
			connection:Disconnect()
			_characterConnections[player] = nil
		end
		_lastRequest[player] = nil
	end)
end

return Shared
