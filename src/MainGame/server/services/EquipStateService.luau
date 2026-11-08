--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Trove = require(Packages.Trove)

local Network = require(ReplicatedStorage.Shared.network.EquipStateNetwork)

type NetworkerServer = Networker.Server

local _trove = Trove.new()
local _networker: NetworkerServer
local _equipped: { [Player]: string? } = {}

local EquipStateService = {}

-- Client-reported, not cryptographically authoritative — a modified client could report
-- anything here. This only tells callers what to check; InventoryService ownership is still
-- the real authority at the point of use, same as every other item-consuming system.
function EquipStateService:setEquipped(player: Player, itemID: any): ()
	if itemID ~= nil and type(itemID) ~= "string" then
		return
	end
	_equipped[player] = itemID
end

function EquipStateService:GetEquippedItem(player: Player): string?
	return _equipped[player]
end

function EquipStateService:OnStart(): ()
	_networker = Networker.server.new(Network.EquipState, EquipStateService, { EquipStateService.setEquipped })

	_trove:Connect(Players.PlayerRemoving, function(player: Player)
		_equipped[player] = nil
	end)
end

export type EquipStateService = typeof(EquipStateService)
return EquipStateService
