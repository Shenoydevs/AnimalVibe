--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local Networker = require(ReplicatedStorage.Packages.Networker)
local CodeConfig = require(script.Parent.Parent.config.CodeConfig)
local Network = require(ReplicatedStorage.Shared.network)

local _lastRedeem = {}

local Private = {}
local Shared = {}

function Private._redeem(_, player, code)
	if player.Parent ~= Players or not DataService:hasProfile(player) then
		return { status = "notReady" }
	end

	local now = workspace:GetServerTimeNow()
	local lastRedeem = _lastRedeem[player]
	if lastRedeem and now - lastRedeem < 0.5 then
		return { status = "rateLimited" }
	end
	_lastRedeem[player] = now

	if type(code) ~= "string" or #code == 0 or #code > 64 then
		return { status = "invalid" }
	end

	local coins = CodeConfig[code]
	if not coins then
		return { status = "invalid" }
	end

	local redeemedCodes: { [string]: boolean } = DataService:get(player, { "redeemedCodes" })
	if redeemedCodes[code] then
		return { status = "alreadyRedeemed" }
	end

	-- Both writes use the same session-locked profile and do not yield.
	DataService:set(player, { "redeemedCodes", code }, true)
	DataService:update(player, { "PlayerStats", "Nova" }, function(currentCoins)
		return currentCoins + coins
	end)

	return { status = "redeemed", coins = coins }
end

function Shared.OnStart()
	Networker.server.new(Network.Codes, Private, { Private._redeem })

	Players.PlayerRemoving:Connect(function(player)
		_lastRedeem[player] = nil
	end)
end

return Shared
