--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)

local NotificationConfig = require(ReplicatedStorage.Shared.config.NotificationConfig)
local ScavengeConfig = require(ReplicatedStorage.Shared.config.ScavengeConfig)

local NotificationService = require(ServerScriptService.Server.services.NotificationService)
local PlayerDataService = require(ServerScriptService.Server.services.PlayerDataService)
local FollowPromptUtils = require(ServerScriptService.Server.utils.FollowPromptUtils)

local _rand = Random.new()

local ScavengeComponent = Component.new({ Tag = ScavengeConfig.tag })

function ScavengeComponent:Construct()
	self._trove = Trove.new()
	assert(self.Instance:IsA("Model"), `[ScavengeComponent] {self.Instance:GetFullName()} must be a Model`)
	-- Keyed by UserId so a same-server rejoin can't search the same house twice.
	self._searched = {} :: { [number]: boolean }
end

function ScavengeComponent:Start()
	local zone: BasePart, anchor: Attachment = FollowPromptUtils.createZone(self.Instance :: Model, ScavengeConfig.zoneRadiusScale)
	self._zone = zone
	self._trove:Add(zone)

	local prompt: ProximityPrompt = FollowPromptUtils.createPrompt(anchor, {
		actionText = ScavengeConfig.actionText,
		objectText = ScavengeConfig.objectText,
		holdDuration = ScavengeConfig.holdDuration,
		maxDistance = ScavengeConfig.promptDistance,
	})
	self._trove:Connect(prompt.Triggered, function(player: Player)
		self:_search(player)
	end)
end

function ScavengeComponent:Stop()
	self._trove:Clean()
end

function ScavengeComponent:_search(player: Player): ()
	if self._searched[player.UserId] then
		NotificationService:notify(player, "Info", "You've already searched this house.", 3, NotificationConfig.priority.low)
		return
	end
	if not FollowPromptUtils.canReach(player, self._zone, ScavengeConfig.promptDistance) then
		return
	end
	local amount: number = _rand:NextInteger(ScavengeConfig.novaMin, ScavengeConfig.novaMax)
	if not PlayerDataService.awardNova(player, amount) then
		return
	end
	self._searched[player.UserId] = true
	NotificationService:notify(player, "Success", `Found {amount} NOVA while searching the house.`, 4, NotificationConfig.priority.med)
end

return ScavengeComponent
