--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)

local EnemyConfig = require(ReplicatedStorage.Shared.config.EnemyConfig)
local EntityConfig = require(ReplicatedStorage.Shared.config.EntityConfig)
local signals = require(ServerScriptService.Server.signals)
local EnemySignals = signals.EnemySignals

local WeatherService = require(ServerScriptService.Server.services.WeatherService)

local States = EnemyConfig.states
local Animations = EnemyConfig.animations

local EnemyComponent = Component.new({ Tag = "Enemy" })

function EnemyComponent:Construct()
	self._trove = Trove.new()

	local spawnId: string = self.Instance:GetAttribute("spawnId") :: string or ""
	local entityType: string = self.Instance:GetAttribute("entityType") :: string or "Normal Hunter"

	self._spawnId = spawnId
	self._entityType = entityType
	self._homePos = self.Instance:GetAttribute("lootBoxPos") :: Vector3? or self.Instance:GetPivot().Position
	self._state = States.IDLE
	self._currentTarget = nil :: Player?
	self._warnedPlayers = {} :: { [Player]: boolean }

	-- AI runtime state, owned here rather than smeared across parallel
	-- model-keyed tables in EnemyAIService.
	self._lastAttackTime = 0
	self._patrolTarget = nil :: Vector3?
	self._patrolWaitUntil = 0
end

function EnemyComponent:Start()
	local entityData = EntityConfig[self._entityType]
	assert(entityData, "[EnemyComponent] Unknown entityType: " .. self._entityType)

	local humanoid: Humanoid? = self.Instance:FindFirstChildWhichIsA("Humanoid")
	assert(humanoid, "[EnemyComponent] No Humanoid found in: " .. self.Instance.Name)

	local hrp: BasePart? = self.Instance:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		pcall(function()
			hrp:SetNetworkOwner(nil)
		end)
	end

	humanoid.WalkSpeed = entityData.walkSpeed * WeatherService:GetAgileSpeedMultiplier(self._entityType)
	humanoid.MaxHealth = entityData.health
	humanoid.Health = entityData.health

	humanoid.BreakJointsOnDeath = false

	local existingAnimator: Animator? = humanoid:FindFirstChildOfClass("Animator")
	local animator: Animator = existingAnimator or Instance.new("Animator")
	if not existingAnimator then
		animator.Parent = humanoid
	end

	local walkAnimation: Animation = self._trove:Add(Instance.new("Animation"))
	walkAnimation.AnimationId = Animations.walk
	local idleAnimation: Animation = self._trove:Add(Instance.new("Animation"))
	idleAnimation.AnimationId = Animations.idle

	local walkTrack: AnimationTrack = self._trove:Add(animator:LoadAnimation(walkAnimation))
	walkTrack.Looped = true
	local idleTrack: AnimationTrack = self._trove:Add(animator:LoadAnimation(idleAnimation))
	idleTrack.Looped = true

	self._trove:Connect(humanoid.Running, function(speed: number)
		if speed > 0.5 then
			if not walkTrack.IsPlaying then
				idleTrack:Stop(0.1)
				walkTrack:Play(0.1)
			end
		else
			if not idleTrack.IsPlaying then
				walkTrack:Stop(0.1)
				idleTrack:Play(0.1)
			end
		end
	end)

	idleTrack:Play()

	self._trove:Connect(humanoid.Died, function()
		self._state = States.DEAD
		EnemySignals.EnemyDied:Fire(self.Instance, self._spawnId)
		task.defer(function()
			self.Instance:Destroy()
		end)
	end)

	self._state = States.PATROL
	EnemySignals.EnemySpawned:Fire(self.Instance, self._spawnId)
end

function EnemyComponent:Stop()
	self._trove:Clean()
end

function EnemyComponent:getState(): string
	return self._state
end

function EnemyComponent:setState(s: string): ()
	self._state = s
end

function EnemyComponent:getTarget(): Player?
	return self._currentTarget
end

function EnemyComponent:setTarget(p: Player?): ()
	self._currentTarget = p
end

function EnemyComponent:getHome(): Vector3
	return self._homePos
end

function EnemyComponent:getEntityType(): string
	return self._entityType
end

function EnemyComponent:getWarnedPlayers(): { [Player]: boolean }
	return self._warnedPlayers
end

function EnemyComponent:setWarned(player: Player, v: boolean): ()
	self._warnedPlayers[player] = v
end

function EnemyComponent:getLastAttackTime(): number
	return self._lastAttackTime
end

function EnemyComponent:setLastAttackTime(t: number): ()
	self._lastAttackTime = t
end

function EnemyComponent:getPatrolTarget(): Vector3?
	return self._patrolTarget
end

function EnemyComponent:setPatrolTarget(target: Vector3?): ()
	self._patrolTarget = target
end

function EnemyComponent:getPatrolWaitUntil(): number
	return self._patrolWaitUntil
end

function EnemyComponent:setPatrolWaitUntil(t: number): ()
	self._patrolWaitUntil = t
end

return EnemyComponent
