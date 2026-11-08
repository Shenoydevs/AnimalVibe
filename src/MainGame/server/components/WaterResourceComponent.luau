--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)

local WaterResourceConfig = require(ReplicatedStorage.Shared.config.WaterResourceConfig)

local InventoryService = require(ServerScriptService.Server.services.InventoryService)
local FollowPromptUtils = require(ServerScriptService.Server.utils.FollowPromptUtils)
local signals = require(ServerScriptService.Server.signals)
local CharacterSignals = signals.CharacterSignals

local _rand = Random.new()

local WaterResourceComponent = Component.new({ Tag = "WaterResource" })

function WaterResourceComponent:Construct()
	self._trove = Trove.new()
	self._gatherCooldowns = {} :: { [Player]: number }
	self._drinkCooldowns = {} :: { [Player]: number }

	local zone: Instance = self.Instance
	assert(zone:IsA("BasePart"), `[WaterResourceComponent] {zone.Name} must be a BasePart`)
	self._zone = zone :: BasePart
end

function WaterResourceComponent:Start()
	local shoreRadius: number = (self._zone:GetAttribute("shoreRadius") :: number?) or self._zone.Size.X / 2
	local anchor: Attachment = self._trove:Add(
		FollowPromptUtils.attach(self._zone, shoreRadius, WaterResourceConfig.promptHeightAboveWater)
	)

	local drinkPrompt: ProximityPrompt = FollowPromptUtils.createPrompt(anchor, {
		actionText = "Drink",
		objectText = "Water",
		holdDuration = WaterResourceConfig.drinkHoldDuration,
		maxDistance = WaterResourceConfig.promptDistance,
		keyboardKeyCode = WaterResourceConfig.drinkKeys.keyboard,
		gamepadKeyCode = WaterResourceConfig.drinkKeys.gamepad,
	})
	local gatherPrompt: ProximityPrompt = FollowPromptUtils.createPrompt(anchor, {
		actionText = "Gather",
		objectText = "Water",
		holdDuration = WaterResourceConfig.gatherHoldDuration,
		maxDistance = WaterResourceConfig.promptDistance,
		keyboardKeyCode = WaterResourceConfig.gatherKeys.keyboard,
		gamepadKeyCode = WaterResourceConfig.gatherKeys.gamepad,
		offset = WaterResourceConfig.gatherPromptOffset,
	})

	self._trove:Connect(drinkPrompt.Triggered, function(player: Player)
		self:_handleDrink(player)
	end)
	self._trove:Connect(gatherPrompt.Triggered, function(player: Player)
		self:_handleGather(player)
	end)
	self._trove:Connect(Players.PlayerRemoving, function(player: Player)
		self._gatherCooldowns[player] = nil
		self._drinkCooldowns[player] = nil
	end)
end

function WaterResourceComponent:Stop()
	self._trove:Clean()
end

function WaterResourceComponent:_handleDrink(player: Player): ()
	local now: number = os.clock()
	local readyAt: number? = self._drinkCooldowns[player]
	if readyAt and now < readyAt then
		return
	end
	if not FollowPromptUtils.canReach(player, self._zone, WaterResourceConfig.promptDistance) then
		return
	end
	self._drinkCooldowns[player] = now + WaterResourceConfig.drinkCooldown
	CharacterSignals.ModDebuff:Fire(player, "thirst", -WaterResourceConfig.drinkAmount)
end

function WaterResourceComponent:_handleGather(player: Player): ()
	local now: number = os.clock()
	local readyAt: number? = self._gatherCooldowns[player]
	if readyAt and now < readyAt then
		return
	end
	if not FollowPromptUtils.canReach(player, self._zone, WaterResourceConfig.promptDistance) then
		return
	end

	local pool: { string } = WaterResourceConfig.itemPool
	local itemId: string = pool[_rand:NextInteger(1, #pool)]

	local added: boolean = InventoryService:addItem(player, itemId)
	if not added then
		return
	end

	self._gatherCooldowns[player] = now + WaterResourceConfig.gatherCooldown
end

return WaterResourceComponent
