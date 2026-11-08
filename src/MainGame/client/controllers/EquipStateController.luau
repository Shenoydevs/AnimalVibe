--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Trove = require(Packages.Trove)

local Network = require(ReplicatedStorage.Shared.network.EquipStateNetwork)

type NetworkerClient = Networker.Client

local HANDLE_WAIT_TIMEOUT = 10

local _networker: NetworkerClient
local _characterTrove = Trove.new()

local EquipStateController = {}

local function _resolveItemID(handle: Instance): string?
	local item: Instance? = handle:FindFirstChildWhichIsA("Model")
	if not item then
		return nil
	end
	return if item:GetAttribute("ItemID") then item:GetAttribute("ItemID") else item.Name
end

local function _reportEquip(handle: Instance): ()
	_networker:fire("setEquipped", _resolveItemID(handle))
end

local function _watchCharacter(character: Model): ()
	_characterTrove:Clean()

	local handle: Instance? = character:WaitForChild("Handle", HANDLE_WAIT_TIMEOUT)
	if not handle then
		return
	end

	_reportEquip(handle)
	_characterTrove:Connect(handle.ChildAdded, function()
		_reportEquip(handle :: Instance)
	end)
	_characterTrove:Connect(handle.ChildRemoved, function()
		_reportEquip(handle :: Instance)
	end)
end

function EquipStateController:OnStart(): ()
	_networker = Networker.client.new(Network.EquipState, EquipStateController)

	local player = Players.LocalPlayer
	if player.Character then
		_watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(_watchCharacter)
end

export type EquipStateController = typeof(EquipStateController)
return EquipStateController
