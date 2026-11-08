--!strict
-- Shared by both places; each client re-exports it from client/components so Loader picks it up.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require(ReplicatedStorage.Packages.Component)

local _player = Players.LocalPlayer

local MonetizationButtonComponent = Component.new({ Tag = "MonetizationButton" })

function MonetizationButtonComponent:Construct()
	local button = if self.Instance:IsA("ImageButton") then self.Instance else self.Instance:FindFirstChild("Hitbox", true)
	local itemType = self.Instance:GetAttribute("ItemType")

	assert(button, `[MonetizationButtonComponent] {self.Instance.Name} must be an ImageButton or contain a Hitbox`)
	assert(
		itemType == "DeveloperProduct" or itemType == "Gamepass",
		`[MonetizationButtonComponent] {self.Instance.Name} ItemType must be "DeveloperProduct" or "Gamepass", got "{itemType}"`
	)
	assert(
		type(self.Instance:GetAttribute("Id")) == "number",
		`[MonetizationButtonComponent] {self.Instance.Name} Id must be a number, got {type(self.Instance:GetAttribute("Id"))}`
	)

	self._button = button
	self._itemType = itemType
end

function MonetizationButtonComponent:Start()
	self._button.Activated:Connect(function()
		self:_onActivated()
	end)
end

function MonetizationButtonComponent:Stop() end

function MonetizationButtonComponent:_onActivated()
	-- MainGame only: no purchases once the server is sending everyone away.
	local comingBack: Instance? = ReplicatedStorage:FindFirstChild("ComingBack")
	if comingBack and comingBack:IsA("BoolValue") and comingBack.Value then
		return
	end

	-- Read on click: some buttons (revive offers) get their product Id set at runtime.
	local id = self.Instance:GetAttribute("Id")
	if type(id) ~= "number" then
		return
	end
	if self._itemType == "DeveloperProduct" then
		MarketplaceService:PromptProductPurchase(_player, id)
	else
		MarketplaceService:PromptGamePassPurchase(_player, id)
	end
end

return MonetizationButtonComponent
