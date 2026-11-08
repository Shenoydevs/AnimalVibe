--!strict
local _players = game:GetService("Players")
local _replicatedStorage = game:GetService("ReplicatedStorage")

local _timer = require(_replicatedStorage.Packages.Timer)
local _troveModule = require(_replicatedStorage.Packages.Trove)
local _mapConfig = require(_replicatedStorage.Shared.config.MapConfig)
local _notificationController = require(script.Parent.NotificationController)

local biomeController = {}
local _player: Player = _players.LocalPlayer
local _lastBiome: string = ""
local _root: BasePart? = nil
local _trove = _troveModule.new()
local _characterTrove = _troveModule.new()

local function _bindCharacter(character: Model): ()
	_characterTrove:Clean()
	_root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	_characterTrove:Connect(character.ChildAdded, function(child: Instance): ()
		if child.Name == "HumanoidRootPart" and child:IsA("BasePart") then
			_root = child
		end
	end)
	_characterTrove:Connect(character.ChildRemoved, function(child: Instance): ()
		if child == _root then
			_root = nil
		end
	end)
end

function biomeController:OnStart(): ()
	_trove:Clean()
	_lastBiome, _root = "", nil
	_trove:Add(_characterTrove)
	_trove:Connect(_player.CharacterAdded, _bindCharacter)
	_trove:Connect(_player.CharacterRemoving, function(): ()
		_characterTrove:Clean()
		_root = nil
	end)
	if _player.Character then
		_bindCharacter(_player.Character)
	end
	local map: Instance = workspace:WaitForChild("Map")
	local timer = _trove:Add(_timer.new(0.25))
	_trove:Connect(timer.Tick, function(): ()
		local root: BasePart? = _root
		local startZ: number? = map:GetAttribute("biomeStartZ") :: number?
		local depth: number? = map:GetAttribute("biomeDepthStuds") :: number?
		if not root or not root.Parent or not startZ or not depth or depth <= 0 then
			return
		end
		local index: number =
			math.clamp(math.floor((root.Position.Z - startZ) / depth) + 1, 1, #_mapConfig.biomeSequence)
		local biome: string = _mapConfig.biomeSequence[index].Name
		if biome ~= _lastBiome then
			_lastBiome = biome
			_notificationController:push("Now entering " .. biome, 4, _notificationController.PRIORITY_LOW, "Info")
		end
	end)
	timer:Start()
end

export type biomeController = typeof(biomeController)
return biomeController
