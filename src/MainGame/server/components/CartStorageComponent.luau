--!strict
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _serverScriptService = game:GetService("ServerScriptService")
local _component = require(_replicatedStorage.Packages.Component)
local _troveModule = require(_replicatedStorage.Packages.Trove)
local _cartConfig = require(_replicatedStorage.Shared.config.CartConfig)
local _cartTypes = require(_replicatedStorage.Shared.types.CartTypes)
local _cartStorageService = require(_serverScriptService.Server.services.CartStorageService)

export type cartStorageComponent = _cartTypes.cartStorageInterface & {
	Instance: BasePart,
	_trove: typeof(_troveModule.new()),
	_storagePart: BasePart,
	_prompt: ProximityPrompt,
	_storageSlots: { CFrame },
	_slotTroves: { [number]: typeof(_troveModule.new()) },
}

local cartStorageComponent = _component.new({ Tag = "CartStorage" })

function cartStorageComponent.Construct(self: cartStorageComponent): ()
	self._trove = _troveModule.new()
	local storagePart: Instance = self.Instance
	assert(storagePart:IsA("BasePart"), "CartStorage must be a BasePart")
	local prompt: ProximityPrompt? = storagePart:FindFirstChildWhichIsA("ProximityPrompt")
	assert(prompt, "CartStorage is missing a ProximityPrompt")
	local slotCount: number = _cartConfig.storageSlotCount
	assert(slotCount > 0 and slotCount % 1 == 0, "Cart storage slot count must be a positive integer")
	local columns: number = math.ceil(math.sqrt(slotCount))
	local rows: number = math.ceil(slotCount / columns)
	local spacingX: number = storagePart.Size.X / columns
	local spacingZ: number = storagePart.Size.Z / rows
	local storageSlots: { CFrame } = {}
	for index = 0, slotCount - 1 do
		local column: number = index % columns
		local row: number = math.floor(index / columns)
		table.insert(storageSlots, CFrame.new(
			(column - (columns - 1) / 2) * spacingX,
			-storagePart.Size.Y / 2,
			(row - (rows - 1) / 2) * spacingZ
		))
	end
	self._storagePart = storagePart
	self._prompt = prompt
	self._storageSlots = storageSlots
	self._slotTroves = {}
end

function cartStorageComponent.Start(self: cartStorageComponent): ()
	_cartStorageService:register(self)
	self._trove:Connect(self._prompt.Triggered, function(player: Player): ()
		_cartStorageService:deposit(self, player)
	end)
end

function cartStorageComponent.Stop(self: cartStorageComponent): ()
	_cartStorageService:unregister(self)
	self._trove:Clean()
	table.clear(self._slotTroves)
	table.clear(self._storageSlots)
end

function cartStorageComponent.getPart(self: cartStorageComponent): BasePart
	return self._storagePart
end

function cartStorageComponent.getDepositDistance(self: cartStorageComponent): number
	return self._prompt.MaxActivationDistance
end

function cartStorageComponent.getSlotCount(self: cartStorageComponent): number
	return #self._storageSlots
end

function cartStorageComponent.clearSlot(self: cartStorageComponent, slotIndex: number): ()
	local slotTrove = self._slotTroves[slotIndex]
	self._slotTroves[slotIndex] = nil
	if slotTrove then self._trove:Remove(slotTrove) end
end

function cartStorageComponent.showItem(self: cartStorageComponent, slotIndex: number, clone: Model, onRetrieve: (Player) -> ()): ()
	self:clearSlot(slotIndex)
	local slotTrove = self._trove:Extend()
	self._slotTroves[slotIndex] = slotTrove
	for _, descendant in clone:GetDescendants() do
		if not descendant:IsA("BasePart") then continue end
		descendant.Anchored = false
		descendant.Massless = true
		descendant.CanCollide = false
		descendant.CanTouch = false
		descendant.CanQuery = false
	end
	local worldSlotCFrame: CFrame = self._storagePart.CFrame * self._storageSlots[slotIndex]
	clone:PivotTo(worldSlotCFrame)
	local boxCFrame: CFrame, boxSize: Vector3 = clone:GetBoundingBox()
	local liftY: number = worldSlotCFrame.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
	clone:PivotTo(worldSlotCFrame + Vector3.new(0, liftY, 0))
	clone.Parent = self._storagePart
	local weld: WeldConstraint = slotTrove:Add(Instance.new("WeldConstraint"))
	weld.Part0 = self._storagePart
	weld.Part1 = clone.PrimaryPart
	weld.Parent = clone
	local prompt: ProximityPrompt = slotTrove:Add(Instance.new("ProximityPrompt"))
	prompt.ActionText = "Unstore Item!"
	prompt.HoldDuration = _cartConfig.storageRetrieveHoldTime
	prompt.MaxActivationDistance = _cartConfig.storageRetrieveDistance
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = clone.PrimaryPart
	slotTrove:Connect(prompt.Triggered, onRetrieve)
end

return cartStorageComponent
