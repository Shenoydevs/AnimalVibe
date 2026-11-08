--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Packages = ReplicatedStorage.Packages

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local types = require(ReplicatedStorage.Shared.types)
local InventoryTypes = require(ReplicatedStorage.Shared.types.InventoryTypes)
local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)
local Signals = require(script.Parent.Parent.Parent.signals)
local states = require(script.Parent.Parent.Parent.states)
local MovementControl = require(script.Parent.MovementControl)
local NotificationController = require(script.Parent.Parent.NotificationController)
local Trove = require(Packages.Trove)

local PlayerActionState = states.PlayerActionState
local peek = Fusion.peek

local HANDLE_NAME = "Handle"
local MOUTH_BONE_NAME = "Head.001"

type NetworkerClient = types.NetworkerClient
type ItemData = InventoryTypes.ItemData

type TrackedRig = {
	handle: BasePart,
	mouth: Bone,
}

local ItemControl = {}

local _character: Model
local _networker: NetworkerClient
local _trove = Trove.new()

local _equippedItem = -1
local _equippedItemInstance: Model?
local _trackedRigs: { [string]: TrackedRig? } = {}

local function getEquippedItemData(): (string?, ItemData?)
	if not _equippedItemInstance then return nil, nil end
	local itemID = _equippedItemInstance:GetAttribute("ItemID")
	if not itemID then
		warn(`[ItemControl] Equipped: {_equippedItemInstance.Name} is missing ItemID`)
		return nil, nil
	end
	return itemID, ItemConfig[itemID]
end

function ItemControl:WeldItem(item: Model, handle: BasePart): ()
	item.PrimaryPart.Anchored = true
	item.Parent = handle
	local weld = Instance.new("WeldConstraint")
	weld.Parent = item
	weld.Part0 = handle

	item:PivotTo(handle:GetPivot() * CFrame.new(-handle.PivotOffset.X, -handle.PivotOffset.Y, -handle.PivotOffset.Z))
	item.PrimaryPart.Anchored = false
	weld.Part1 = item.PrimaryPart
end

function ItemControl:RemoveItemReplication(player: Player, handle: Instance?): ()
	if not handle then warn("[ItemControl] No Handle") return end

	local item = handle:FindFirstChildOfClass("Model")
	if not item then warn("[ItemControl] No Model") return end

	local weld = item:FindFirstChildOfClass("WeldConstraint")
	if weld then weld:Destroy() end

	item.Parent = player.Backpack
	item.PrimaryPart.Anchored = true
end

function ItemControl:IsItemEquipped(): boolean
	return _equippedItemInstance ~= nil
end

function ItemControl:IsMouthFull(): boolean
	return peek(PlayerActionState.HeldItem) ~= nil
end

function ItemControl:DropItem(): ()
	local itemID, itemData = getEquippedItemData()
	if not itemID or not itemData then return end

	local sackEquippedInHotbar = itemData and itemData.inventoryCapacity
	if sackEquippedInHotbar then return end
	
	SoundService:PlayLocalSound(_character.PrimaryPart.DropItem)
	_networker:fire("_requestDropItem", itemID)
end

function ItemControl:UnEquip(): ()
	if not _equippedItemInstance then return end

	local weld = _equippedItemInstance:FindFirstChildOfClass("WeldConstraint")
	if weld then weld:Destroy() end

	_equippedItemInstance.Parent = Players.LocalPlayer.Backpack
	_equippedItemInstance.PrimaryPart.Anchored = true
	_equippedItemInstance = nil
	_equippedItem = -1
	Signals.CharacterSignals.UpdateShareable:Fire(false)
	PlayerActionState.EquippedTool:set(nil)

	_networker:fire("_replicateItem", false)
end

function ItemControl:EquipItem(index: number, slotData): ()
	local isUnequipOnly = _equippedItem == index

	if not isUnequipOnly and slotData and peek(PlayerActionState.HeldItem) ~= nil then
		NotificationController:push("Your mouth is full — use, store, or drop it before equipping something else.", 4, NotificationController.PRIORITY_MED, "Alert")
		return
	end

	if _equippedItem ~= -1 then
		self:UnEquip()
		if isUnequipOnly then return end
	end

	if not slotData then return end
	local itemID = slotData.itemId
	if not itemID then return end

	local itemData = ItemConfig[itemID]
	if not itemData then return end

	local handle: BasePart? = _character:FindFirstChild("Handle")
	local item: Model? = Players.LocalPlayer.Backpack:FindFirstChild(itemID)
	if not handle or not item then return end

	_equippedItem = index
	self:WeldItem(item, handle)

	_equippedItemInstance = item
	_networker:fire("_replicateItem", true, itemID)

	Signals.CharacterSignals.UpdateShareable:Fire(if itemData.canShare then true else false)
	Signals.CharacterSignals.UpdateEquipHelper:Fire(itemData)
	PlayerActionState.EquippedTool:set(itemID)
end

local function particleCapper(value: number, min: number, factor: number): number
	return if value > min then math.min(value * factor, min) else value
end

function ItemControl:OnItemVFX(name: string, hungerValue: number, healValue: number): ()
	local char = workspace.Map.Players:FindFirstChild(name)
	if not char then return end

	local vfx = ReplicatedStorage.Assets.VFX.ItemVFX:Clone()
	vfx.Parent = workspace
	vfx.Position = char.Handle.CFrame.Position

	vfx.Effect.Sparks:Emit(10)
	if name == Players.LocalPlayer.Name then
		MovementControl:ApplySlowdown()
	end

	if hungerValue and hungerValue > 0 then
		vfx.Hunger:Emit(particleCapper(hungerValue, 12, 0.8))
		vfx.Munch:Play()
	end

	if healValue and healValue > 0 then
		vfx.Heal:Emit(particleCapper(healValue, 12, 0.8))
		vfx.Healing:Play()
	end

	Debris:AddItem(vfx, 3)
end

function ItemControl:OnReplicateItem(player: Player, itemID: string?): ()
	local handle: BasePart = player.Character:FindFirstChild("Handle")
	local item: Model? = if itemID then player.Backpack:FindFirstChild(itemID) else nil
	if not handle then return end

	if item then
		for _, model in handle:GetChildren() do
			if model:IsA("Model") then
				self:RemoveItemReplication(player, handle)
			end
		end
		self:WeldItem(item, handle)
	else
		self:RemoveItemReplication(player, handle)
	end
end

local function waitForDescendant(parent: Instance, name: string, timeout: number?): Instance
	local existing = parent:FindFirstChild(name, true)
	if existing then return existing end
	
	local startTime = os.clock()
	while true do
		local descendant = parent.DescendantAdded:Wait()
		if descendant.Name == name then
			return descendant
		end
		if timeout and (os.clock() - startTime > timeout) then
			return nil
		end
	end
end

local function _findMouth(character: Model): Bone?
	local mouth: Instance? = waitForDescendant(character, MOUTH_BONE_NAME, 10)
	if mouth and mouth:IsA("Bone") then
		return mouth :: Bone
	end
	return nil
end

local function _addToTracking(player : Player, character : Model)
	if character == nil or character.Parent == nil then return end
	local mouth: Bone? = _findMouth(character)
	if not mouth then return end 
	
	local handle: Instance? = character:WaitForChild(HANDLE_NAME, 30)
	if not handle or not handle:IsA("BasePart") then return end 

	_trackedRigs[player.Name] = { handle = handle, mouth = mouth }
end

function ItemControl:Init(character: Model, networker: NetworkerClient): ()
	_character = character
	_networker = networker
	_equippedItem = -1
	_equippedItemInstance = nil

	local handle = character:FindFirstChild("Handle")
	local mouth = character:FindFirstChild("Head.001", true)
	if not mouth or not handle then
		warn("[ItemControl] Not found a mouth bone for the handle")
		return
	end

	_trove:Connect(RunService.RenderStepped, function()
		for _, rig in _trackedRigs do 
			if rig.handle == nil or rig.handle.Parent == nil then continue end
			rig.handle:PivotTo(rig.mouth.WorldCFrame)
		end
	end)

	local playersFolder : Folder = workspace:WaitForChild("Map"):WaitForChild("Players")
	
	for _, player : Player in Players:GetPlayers() do 
		_addToTracking(player, player.Character)
		player.CharacterAdded:Once(function()
			_addToTracking(player, player.Character)
		end)
	end

	playersFolder.ChildAdded:Connect(function(char)
		local player = Players:GetPlayerFromCharacter(char)
		_addToTracking(player, player.Character)
		player.CharacterAdded:Connect(function()
			_addToTracking(player, player.Character)
		end)
	end)
end

export type ItemControl = typeof(ItemControl)
return ItemControl
