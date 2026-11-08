--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Signals = require(ServerScriptService.Server.signals)

local CharacterSignals = Signals.CharacterSignals
local PricingRevive = require(ReplicatedStorage.Shared.config.RevivePricingConfig)

local ReviveService = {}

function ReviveService:RemainingAlive()
	for _, v in ipairs(Players:GetPlayers()) do
		if v.Character and v.Character:GetAttribute("alive") then
			return true
		end
	end
	return false
end

function ReviveService:OnStart()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

		local productId = receiptInfo.ProductId

		for _, id in ipairs(PricingRevive.ReviveMe) do
			if id ~= productId then continue end

			local char = player.Character
			if not char then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			if char:GetAttribute("alive") == true or ReplicatedStorage.ComingBack.Value == true then
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
			-- The personal revive is offered while teammates are still alive (GameManagerService:LostPlayer),
			-- so only the offer window decides it.
			if not char:GetAttribute("canBuyRevive") then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			CharacterSignals.IFrames:Fire(player, 5)
			CharacterSignals.SetDebuff:Fire(player, "damage", 0)
			CharacterSignals.SetDebuff:Fire(player, "hunger", 0)
			CharacterSignals.SetDebuff:Fire(player, "thirst", 0)
			CharacterSignals.SetDebuff:Fire(player, "sickness", 0)
			char:SetAttribute("canBuyRevive", nil)
			CharacterSignals.Revived:Fire(player, false)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		for _, id in ipairs(PricingRevive.ReviveAll) do
			if id ~= productId then continue end

			local character = player.Character
			if not character then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			if not character:GetAttribute("canReviveAll") or ReplicatedStorage.ComingBack.Value == true then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end

			local targets = Players:GetPlayers()
			if #targets == 0 then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			-- Skip players without a character rather than bailing out: returning NotProcessedYet after
			-- reviving some players would make Roblox retry the receipt and revive them again.
			for _, p in targets do
				local char = p.Character
				if not char or char:GetAttribute("alive") == true then continue end

				CharacterSignals.IFrames:Fire(p, 5)
				CharacterSignals.SetDebuff:Fire(p, "damage", 0)
				CharacterSignals.SetDebuff:Fire(p, "hunger", 0)
				CharacterSignals.SetDebuff:Fire(p, "thirst", 0)
				CharacterSignals.SetDebuff:Fire(p, "sickness", 0)
				char:SetAttribute("canRevive", true)
				char:SetAttribute("canReviveAll", nil)
				CharacterSignals.Revived:Fire(p, true)
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

export type ReviveService = typeof(ReviveService)
return ReviveService
