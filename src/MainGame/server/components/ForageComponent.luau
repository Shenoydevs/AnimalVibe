--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)

local ForageConfig = require(ReplicatedStorage.Shared.config.ForageConfig)

local FollowPromptUtils = require(ServerScriptService.Server.utils.FollowPromptUtils)
local GroundItemUtils = require(ServerScriptService.Server.utils.GroundItemUtils)

type ForageKind = ForageConfig.ForageKind

local _rand = Random.new()

local ForageComponent = Component.new({ Tag = ForageConfig.tag })

function ForageComponent:Construct()
	self._trove = Trove.new()
	assert(self.Instance:IsA("Model"), `[ForageComponent] {self.Instance:GetFullName()} must be a Model`)
	local kindName: string? = self.Instance:GetAttribute(ForageConfig.kindAttribute) :: string?
	local kind: ForageKind? = if kindName then ForageConfig.kinds[kindName] else nil
	assert(kind, `[ForageComponent] {self.Instance:GetFullName()} has unknown forage kind "{kindName}"`)
	self._kind = kind :: ForageKind
	self._remaining = (kind :: ForageKind).harvests
	self._readyAt = 0
end

function ForageComponent:Start()
	local zone: BasePart, anchor: Attachment = FollowPromptUtils.createZone(self.Instance :: Model, ForageConfig.zoneRadiusScale)
	self._zone = zone
	self._trove:Add(zone)

	local prompt: ProximityPrompt = FollowPromptUtils.createPrompt(anchor, {
		actionText = self._kind.actionText,
		objectText = self._kind.objectText,
		holdDuration = self._kind.holdDuration,
		maxDistance = ForageConfig.promptDistance,
	})
	self._trove:Connect(prompt.Triggered, function(player: Player)
		self:_harvest(player)
	end)
end

function ForageComponent:Stop()
	self._trove:Clean()
end

function ForageComponent:_harvest(player: Player): ()
	local now: number = os.clock()
	if self._remaining <= 0 or now < self._readyAt then
		return
	end
	if not FollowPromptUtils.canReach(player, self._zone, ForageConfig.promptDistance) then
		return
	end
	local character: Model? = player.Character
	if not character then
		return
	end
	self._readyAt = now + ForageConfig.harvestCooldown
	self._remaining -= 1

	local drop = self._kind.drops[_rand:NextInteger(1, #self._kind.drops)]
	for _ = 1, _rand:NextInteger(drop.minCount, drop.maxCount) do
		GroundItemUtils.spawn(drop.itemID, character, true)
	end

	if self._remaining > 0 then
		return
	end
	if self._kind.destroyWhenDepleted then
		task.defer(function()
			self.Instance:Destroy()
		end)
	else
		self._trove:Clean()
	end
end

return ForageComponent
