--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local Networker = require(ReplicatedStorage.Packages.Networker)
local BadgeConfig = require(ReplicatedStorage.Common.config.BadgeConfig)
local Network = require(ReplicatedStorage.Shared.network)

local _lastEquip = {}

local Private = {}
local Shared = {}

function Private._equip(_, player, badgeId)
	if player.Parent ~= Players or not DataService:hasProfile(player) then
		return
	end

	local now = workspace:GetServerTimeNow()
	local lastEquip = _lastEquip[player]
	if lastEquip and now - lastEquip < 0.15 then
		return
	end
	_lastEquip[player] = now

	-- The existing empty ID represents no equipped badge.
	if type(badgeId) ~= "string" or (badgeId ~= "" and not BadgeConfig.badges[badgeId]) then
		return
	end

	local badges = DataService:get(player, { "badges" })
	if (badgeId ~= "" and badges.earned[badgeId] ~= true) or badges.equippedId == badgeId then
		return
	end

	DataService:set(player, { "badges", "equippedId" }, badgeId)
	player:SetAttribute("equippedBadgeId", badgeId)
end

function Shared.loadPlayer(player, badges)
	local equippedId = badges.equippedId
	if not BadgeConfig.badges[equippedId] or badges.earned[equippedId] ~= true then
		equippedId = ""
	end

	player:SetAttribute("equippedBadgeId", equippedId)
end

function Shared.OnStart()
	Networker.server.new(Network.Badge, Private, { Private._equip })

	Players.PlayerRemoving:Connect(function(player)
		_lastEquip[player] = nil
	end)
end

return Shared
