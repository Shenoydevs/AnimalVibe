--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)
local NotificationConfig = require(ReplicatedStorage.Shared.config.NotificationConfig)
local InventoryService = require(ServerScriptService.Server.services.InventoryService)
local HeldItemService = require(ServerScriptService.Server.services.HeldItemService)
local NotificationService = require(ServerScriptService.Server.services.NotificationService)

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)

local _templateWaitTimeout: number = 120

local ResourcePropComponent = Component.new({ Tag = "ResourceProp" })

function ResourcePropComponent:Construct()
	self._trove = Trove.new()

	local primaryPart : BasePart? = self.Instance.PrimaryPart
	assert(primaryPart, `[ResourcePropComponent] {self.Instance.Name} is missing PrimaryPart`)

	local prompt : ProximityPrompt? = primaryPart:FindFirstChildWhichIsA("ProximityPrompt")
	assert(prompt, `[ResourcePropComponent] {self.Instance.Name} Part is missing ProximityPrompt`)

	prompt.ActionText = `Pick up {self.Instance.Name}!`

	self._staticProp = self.Instance:HasTag("StaticResource")
	self._prompt = prompt :: ProximityPrompt
	self._itemID = self.Instance:GetAttribute("ItemID")
	self._claimcd = false

	self._despawnThread = task.delay(_templateWaitTimeout, function()
		if not self.Instance:IsDescendantOf(game) then return end
		self:Despawn()
	end)
end

function ResourcePropComponent:Despawn()
	if self._claimcd then return end
	self:Clean()
	self:Stop()
end

function ResourcePropComponent:Clean()
	self._prompt:Destroy()
	if not self._staticProp then self.Instance:Destroy() return end

	for _, instance in self.Instance:GetDescendants() do
		if not instance:HasTag("ResourceClear") then continue end
		instance:Destroy()
	end
end

function ResourcePropComponent:Start()
	self._trove:Connect(self._prompt.Triggered, function(player: Player)
		if self._claimcd then return end
		self._claimcd = true

		local itemData = ItemConfig[self._itemID]
		local added: boolean = if itemData and itemData.slot == "Hotbar"
			then InventoryService:addTool(player, self._itemID)
			else HeldItemService:pickup(player, self._itemID)

		if not added then
			self._claimcd = false
			return
		end

		NotificationService:notify(player, "Success", `You picked up {self._itemID}.`, 3, NotificationConfig.priority.low)
		self:Clean()
		self:Stop()
	end)
end

function ResourcePropComponent:Stop()
	self._trove:Clean()
	if coroutine.status(self._despawnThread) == "suspended" then
		task.cancel(self._despawnThread)
	end
end

return ResourcePropComponent
