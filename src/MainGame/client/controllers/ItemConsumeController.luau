--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)

local Network = require(ReplicatedStorage.Shared.network.ItemConsumeNetwork)
local CharacterController = require(script.Parent.CharacterController)

local ItemConsumeController = {}

-- The server already removed this item from the real inventory; UnEquipItem() only
-- clears the client's private equip state and returns the (now-redundant) physical
-- prop to Backpack, so destroy that leftover copy immediately after to avoid a duplicate.
function ItemConsumeController:discardClientCopy(itemID: string): ()
	CharacterController:UnEquipItem()
	if not itemID then return end
	
	local duplicate: Instance? = Players.LocalPlayer.Backpack:FindFirstChild(itemID)
	if duplicate then
		duplicate:Destroy()
	end
end

function ItemConsumeController:onItemConsumed(itemID: string): ()
	self:discardClientCopy(itemID)
end

function ItemConsumeController:OnStart(): ()
	Networker.client.new(Network.ItemConsume, ItemConsumeController)
end

export type ItemConsumeController = typeof(ItemConsumeController)
return ItemConsumeController
