--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ChestConfig = require(ReplicatedStorage.Shared.config.ChestConfig)
local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)
local NotificationConfig = require(ReplicatedStorage.Shared.config.NotificationConfig)

local EquipStateService = require(ServerScriptService.Server.services.EquipStateService)
local InventoryService = require(ServerScriptService.Server.services.InventoryService)
local NotificationService = require(ServerScriptService.Server.services.NotificationService)

local _rand = Random.new()

local ChestComponent = Component.new({ Tag = "Chest" })

local function _rollLoot(): string?
	local total: number = 0
	for _, weight in ChestConfig.lootWeights do
		total += weight
	end

	local roll: number = _rand:NextNumber(0, total)
	local acc: number = 0
	for itemId, weight in ChestConfig.lootWeights do
		acc += weight
		if roll <= acc then
			return itemId
		end
	end
	return nil
end

function ChestComponent:Construct()
	self._trove = Trove.new()
	self._opened = false

	local rootPart: BasePart? = self.Instance.PrimaryPart
	assert(rootPart, `[ChestComponent] {self.Instance.Name} is missing PrimaryPart`)
	self._rootPart = rootPart :: BasePart

	local animationController: AnimationController? = self.Instance:FindFirstChildWhichIsA("AnimationController")
	self._animator = if animationController then animationController:FindFirstChildWhichIsA("Animator") else nil
end

function ChestComponent:Start()
	local prompt: ProximityPrompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Chest"
	prompt.ObjectText = "Chest"
	prompt.HoldDuration = 0.5
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = self._rootPart
	self._prompt = prompt

	self._trove:Add(prompt)
	self._trove:Connect(prompt.Triggered, function(player: Player)
		self:_handleOpen(player)
	end)
end

function ChestComponent:Stop()
	self._trove:Clean()
	local destroyThread: thread? = self._destroyThread
	if destroyThread and coroutine.status(destroyThread) == "suspended" then
		task.cancel(destroyThread)
	end
end

function ChestComponent:_handleOpen(player: Player): ()
	if self._opened then
		return
	end

	-- Equip state is client-reported, so the key must also really be in the server inventory.
	if
		EquipStateService:GetEquippedItem(player) ~= ChestConfig.keyItemID
		or InventoryService:countItem(player, ChestConfig.keyItemID) < 1
	then
		NotificationService:notify(player, "Alert", "You need a Key to open this chest.", 3, NotificationConfig.priority.low)
		return
	end

	local itemId: string? = _rollLoot()
	if not itemId then
		warn(`[ChestComponent] Loot roll produced no item for {self.Instance:GetFullName()}`)
		return
	end

	local added: boolean = InventoryService:addItem(player, itemId)
	if not added then
		return
	end

	-- Ownership was checked above and nothing yields in between, so spending the key can't fail here.
	if not InventoryService:removeItem(player, ChestConfig.keyItemID, 1) then
		warn(`[ChestComponent] Could not spend {player.Name}'s key after granting loot`)
	end

	self._opened = true
	self._prompt:Destroy()

	NotificationService:notify(player, "Success", `You found {ItemConfig[itemId].displayName}!`, 4, NotificationConfig.priority.med)

	local animator: Animator? = self._animator
	if animator then
		local anim = Instance.new("Animation")
		anim.AnimationId = ChestConfig.openAnimationId
		local track = animator:LoadAnimation(anim)
		track:Play()
	end

	self._destroyThread = task.delay(ChestConfig.destroyDelayAfterOpen, function()
		self.Instance:Destroy()
	end)
end

return ChestComponent
