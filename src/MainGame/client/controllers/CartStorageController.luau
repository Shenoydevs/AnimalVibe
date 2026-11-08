--!strict
local _collectionService = game:GetService("CollectionService")
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _fusion = require(_replicatedStorage.Packages.Fusion)
local _troveModule = require(_replicatedStorage.Packages.Trove)
local _cartController = require(script.Parent.CartController)
local _states = require(script.Parent.Parent.states)

local _trove = _troveModule.new()
local _scope = _fusion.scoped(_fusion)
local _storageTroves: { [Instance]: typeof(_troveModule.new()) } = {}
local _prompts: { [Instance]: ProximityPrompt } = {}

local cartStorageController = {}

local function _updatePromptVisibility(): ()
	local hasItem: boolean = _fusion.peek(_states.PlayerActionState.HeldItem) ~= nil
		or next(_fusion.peek(_states.InventoryState.Slots)) ~= nil
	local enabled: boolean = _cartController:isAssembled() and hasItem
	for storagePart, prompt in _prompts do
		if storagePart:IsDescendantOf(workspace) and prompt.Parent == storagePart then
			prompt.Enabled = enabled
		end
	end
end

local function _refreshStoragePart(storagePart: Instance): ()
	_prompts[storagePart] = nil
	if not _storageTroves[storagePart] or not storagePart:IsDescendantOf(workspace) then return end
	local prompt: ProximityPrompt? = storagePart:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then _prompts[storagePart] = prompt end
	_updatePromptVisibility()
end

local function _trackStoragePart(storagePart: Instance): ()
	if not storagePart:IsA("BasePart") or _storageTroves[storagePart] then return end
	local storageTrove = _trove:Extend()
	_storageTroves[storagePart] = storageTrove
	storageTrove:Connect(storagePart.AncestryChanged, function(): ()
		_refreshStoragePart(storagePart)
	end)
	storageTrove:Connect(storagePart.ChildAdded, function(child: Instance): ()
		if child:IsA("ProximityPrompt") then _refreshStoragePart(storagePart) end
	end)
	storageTrove:Connect(storagePart.ChildRemoved, function(child: Instance): ()
		if child:IsA("ProximityPrompt") then _refreshStoragePart(storagePart) end
	end)
	_refreshStoragePart(storagePart)
end

local function _untrackStoragePart(storagePart: Instance): ()
	local storageTrove = _storageTroves[storagePart]
	_storageTroves[storagePart] = nil
	_prompts[storagePart] = nil
	if storageTrove then _trove:Remove(storageTrove) end
end

function cartStorageController:OnStart(): ()
	_trove:Connect(_collectionService:GetInstanceAddedSignal("CartStorage"), _trackStoragePart)
	_trove:Connect(_collectionService:GetInstanceRemovedSignal("CartStorage"), _untrackStoragePart)
	for _, storagePart in _collectionService:GetTagged("CartStorage") do
		_trackStoragePart(storagePart)
	end
	_trove:Connect(_cartController.assemblyChanged, _updatePromptVisibility)
	_scope:Observer(_states.InventoryState.Slots):onChange(_updatePromptVisibility)
	_scope:Observer(_states.PlayerActionState.HeldItem):onChange(_updatePromptVisibility)
	_updatePromptVisibility()
end

export type cartStorageController = typeof(cartStorageController)
return cartStorageController
