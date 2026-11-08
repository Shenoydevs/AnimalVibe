--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Trove = require(Packages.Trove)

local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)
local NotificationConfig = require(ReplicatedStorage.Shared.config.NotificationConfig)
local Network = require(ReplicatedStorage.Shared.network.HeldItemNetwork)
local EquipStateService = require(ServerScriptService.Server.services.EquipStateService)
local InventoryService = require(ServerScriptService.Server.services.InventoryService)
local NotificationService = require(ServerScriptService.Server.services.NotificationService)
local AssetUtils = require(ServerScriptService.Server.utils.AssetUtils)
local GroundItemUtils = require(ServerScriptService.Server.utils.GroundItemUtils)
local signals = require(ServerScriptService.Server.signals)

type NetworkerServer = Networker.Server

local _trove = Trove.new()
local _playerTroves: { [Player]: typeof(Trove.new()) } = {}
local _networker: NetworkerServer? = nil
local _heldItems: { [Player]: string? } = {}
local _heldModels: { [Player]: Model? } = {}
local _shareEnabled: boolean = false

local HeldItemService = {}
local Private = {}

-- Mirrors ItemControl:WeldItem's technique so the model is a real, server-owned instance
-- (visible in the server's own view, replicating to every client the normal way) instead of
-- a client-only cosmetic clone that only the creating client could ever see.
local function _buildHeldModel(itemId: string): Model?
	local model: Model? = AssetUtils.cloneResource(itemId, true)
	if not model then
		warn(`[HeldItemService] "{itemId}" has no usable Resources model to attach`)
	end
	return model
end

local function _detachModel(player: Player): ()
	local model: Model? = _heldModels[player]
	if model then
		model:Destroy()
	end
	_heldModels[player] = nil
end

local function _attachModel(player: Player, itemId: string): ()
	local character: Model? = player.Character
	if not character then return end

	local handle: Instance? = character:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return end

	local handlePart: BasePart = handle :: BasePart
	local model: Model? = _buildHeldModel(itemId)
	if not model or not model.PrimaryPart then return end

	model.PrimaryPart.Anchored = true
	model.Parent = handlePart
	local weld = Instance.new("WeldConstraint")
	weld.Parent = model
	weld.Part0 = handlePart
	model:PivotTo(handlePart:GetPivot() * CFrame.new(-handlePart.PivotOffset.Position))
	model.PrimaryPart.Anchored = false
	weld.Part1 = model.PrimaryPart

	_heldModels[player] = model
end

-- Server-side answer to "is a Sack equipped": the client-reported equip must also be an owned item.
local function _isSackEquipped(player: Player): boolean
	local equippedId: string? = EquipStateService:GetEquippedItem(player)
	local equippedData = if equippedId then ItemConfig[equippedId] else nil
	if not equippedId or not equippedData or equippedData.inventoryCapacity == nil then return false end
	return InventoryService:countItem(player, equippedId) > 0
end

local function _syncModel(player: Player, itemId: string?): ()
	_detachModel(player)
	if itemId then
		_attachModel(player, itemId)
	end
end

function HeldItemService:_replicate(player: Player): ()
	local itemId: string? = _heldItems[player]
	_syncModel(player, itemId)

	local networker: NetworkerServer? = _networker
	if not networker then return end
	networker:fire(player, "heldItemUpdated", itemId)
end

function HeldItemService:getItem(player: Player): string?
	return _heldItems[player]
end

function HeldItemService:take(player: Player): string?
	local itemId: string? = _heldItems[player]
	if not itemId then return nil end

	_heldItems[player] = nil
	self:_replicate(player)
	return itemId
end

function HeldItemService:pickup(player: Player, itemId: string): boolean
	local itemData = ItemConfig[itemId]
	if not itemData or itemData.slot ~= "Mouth" then return false end

	if _heldItems[player] ~= nil then
		NotificationService:notify(player, "Alert", "Your mouth is full — use, store, or drop what you're carrying first.", 4, NotificationConfig.priority.med)
		return false
	end

	local equippedId: string? = EquipStateService:GetEquippedItem(player)
	local equippedData = if equippedId then ItemConfig[equippedId] else nil
	if equippedData then
		if equippedData.inventoryCapacity == nil then
			NotificationService:notify(player, "Alert", "Unequip your tool before picking that up — you can only hold one thing at a time.", 4, NotificationConfig.priority.med)
			return false
		end
		-- A Sack is equipped: the pickup goes straight into it (addToSack checks real capacity).
		return InventoryService:addToSack(player, itemId)
	end

	_heldItems[player] = itemId
	self:_replicate(player)

	return true
end

function Private.requestSnapshot(_: any, player: Player): ()
	HeldItemService:_replicate(player)
end

function Private.requestDrop(_: any, player: Player): ()
	local itemId: string? = _heldItems[player]
	if not itemId then return end

	local char: Model? = player.Character
	if not char then return end

	_heldItems[player] = nil
	HeldItemService:_replicate(player)
	GroundItemUtils.spawn(itemId, char)
end

function HeldItemService:consume(player: Player, targetPlayer: Player?): ()
	local itemId: string? = _heldItems[player]
	if not itemId then return end

	local itemData = ItemConfig[itemId]
	if not itemData then return end

	local eater: Player = player
	if targetPlayer ~= nil and targetPlayer ~= player then
		if not itemData.canShare then
			NotificationService:notify(player, "Alert", `{itemId} can't be shared.`, 3, NotificationConfig.priority.low)
			return
		end
		local targetChar: Model? = targetPlayer.Character
		if not targetChar or not targetChar:GetAttribute("canRevive") then return end
		eater = targetPlayer
	end

	local eaterChar: Model? = eater.Character
	if not eaterChar then return end

	if itemData.useType == "Eat" then
		if itemData.hungerValue then signals.CharacterSignals.ModDebuff:Fire(eater, "hunger", -itemData.hungerValue) end
		if itemData.healValue then signals.CharacterSignals.ModDebuff:Fire(eater, "damage", -itemData.healValue) end
	elseif itemData.useType == "Heal" then
		if itemData.healAmount then signals.CharacterSignals.ModDebuff:Fire(eater, "damage", -itemData.healAmount) end
	else
		return
	end

	_heldItems[player] = nil
	HeldItemService:_replicate(player)

	signals.CharacterSignals.ConsumeVFX:Fire(eaterChar.Name, itemData.hungerValue, itemData.healValue or itemData.healAmount)
end

function Private.requestUse(_: any, player: Player): ()
	HeldItemService:consume(player, nil)
end

-- The client also sends its own "sack equipped" flag; it is ignored in favour of server state.
function Private.requestStore(_: any, player: Player, _clientSackEquipped: any): ()
	if _isSackEquipped(player) then
		InventoryService:emptyBag(player)
		return
	end

	local itemId: string? = _heldItems[player]
	if not itemId then return end

	if InventoryService:getSackCapacity(player) <= 0 then
		NotificationService:notify(player, "Alert", "You need a Sack to store items.", 3, NotificationConfig.priority.low)
		return
	end

	if not InventoryService:addToSack(player, itemId) then return end

	_heldItems[player] = nil
	HeldItemService:_replicate(player)
end

function Private.requestUnstore(_: any, player: Player, slotIndex: any, _clientSackEquipped: any): ()
	if type(slotIndex) ~= "number" or slotIndex % 1 ~= 0 then return end
	local sackEquipped: boolean = _isSackEquipped(player)
	if _heldItems[player] ~= nil then
		NotificationService:notify(player, "Alert", "Your mouth is full — use, store, or drop what you're carrying first.", 4, NotificationConfig.priority.med)
		return
	end
	if EquipStateService:GetEquippedItem(player) ~= nil and not sackEquipped then
		NotificationService:notify(player, "Alert", "Unequip your tool before taking something out of your Sack.", 4, NotificationConfig.priority.med)
		return
	end

	local itemId: string? = InventoryService:removeSackSlot(player, slotIndex)
	if not itemId then return end
	-- No item id: tells the client to unequip the Sack so the item can go in the mouth.
	if sackEquipped then signals.CharacterSignals.ItemConsumed:Fire(player) end

	_heldItems[player] = itemId
	HeldItemService:_replicate(player)
end

function HeldItemService:OnStart(): ()
	_networker = Networker.server.new(Network.HeldItem, Private, { Private.requestSnapshot, Private.requestDrop, Private.requestUse, Private.requestStore, Private.requestUnstore })

	_trove:Connect(signals.CharacterSignals.ShareItem, function(player: Player, targetPlayer: Player)
		HeldItemService:consume(player, targetPlayer)
	end)

	local function watchPlayer(player: Player): ()
		local playerTrove = Trove.new()
		_playerTroves[player] = playerTrove
		playerTrove:Connect(player.CharacterAdded, function()
			local itemId: string? = _heldItems[player]
			if itemId then
				_syncModel(player, itemId)
			end
		end)
	end

	_trove:Connect(Players.PlayerAdded, watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	_trove:Connect(Players.PlayerRemoving, function(player: Player)
		_heldItems[player] = nil
		_detachModel(player)
		local playerTrove = _playerTroves[player]
		if playerTrove then
			playerTrove:Destroy()
			_playerTroves[player] = nil
		end
	end)
end

export type HeldItemService = typeof(HeldItemService)
return HeldItemService
