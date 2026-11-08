--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local Timer = require(ReplicatedStorage.Packages.Timer)
local Trove = require(ReplicatedStorage.Packages.Trove)

local EnemyConfig = require(ReplicatedStorage.Shared.config.EnemyConfig)
local EntityConfig = require(ReplicatedStorage.Shared.config.EntityConfig)
local EnemyNetwork = require(ReplicatedStorage.Shared.network.EnemyNetwork)
local EnemyTypes = require(ReplicatedStorage.Shared.types.EnemyTypes)
local CharacterUtils = require(ReplicatedStorage.Shared.utils.CharacterUtils)

local Signals = require(ServerScriptService.Server.signals)
local EnemySignals = Signals.EnemySignals
local CharacterSignals = Signals.CharacterSignals

local EnemyComponent = require(ServerScriptService.Server.components.EnemyComponent)
local _campfireService = require(ServerScriptService.Server.services.CampfireService)
local CartService = require(ServerScriptService.Server.services.CartService)
local EnemyPathfinder = require(ServerScriptService.Server.utils.EnemyPathfinder)

type NetworkerServer = Networker.Server
type EnemyComponentInterface = EnemyTypes.EnemyComponentInterface

local States = EnemyConfig.states

local _trove = Trove.new()
local _activeEnemies: { [Model]: EnemyComponentInterface } = {}

local _pathfinder = EnemyPathfinder.new({
	agentParams = EnemyConfig.agentParams,
	recomputeDistance = EnemyConfig.pathRecomputeDistance,
	recomputeInterval = EnemyConfig.pathRecomputeInterval,
	waypointReachedDistance = EnemyConfig.waypointReachedDistance,
	minRecomputeCooldown = EnemyConfig.pathMinRecomputeCooldown,
	stuckTimeout = EnemyConfig.pathStuckTimeout,
	stuckDistance = EnemyConfig.pathStuckDistance,
})

local _rand = Random.new()

local EnemyAIService = {}

local function _clearEnemyState(model: Model): ()
	_activeEnemies[model] = nil
	_pathfinder:clear(model)
end

local function _nearAnyPlayer(position: Vector3, radius: number): boolean
	for _, player in Players:GetPlayers() do
		local hrp: BasePart? = CharacterUtils.getPlayerRoot(player)
		if hrp and (hrp.Position - position).Magnitude <= radius then
			return true
		end
	end
	return false
end

local function _isProtected(position: Vector3): boolean
	return _campfireService:isPositionSafe(position) or CartService:isInSafezone(position)
end

local function _clampOutsideProtection(position: Vector3): Vector3
	return CartService:clampOutsideSafezone(_campfireService:clampOutsideZones(position))
end

local function _disengage(comp: EnemyComponentInterface): ()
	comp:setState(States.PATROL)
	comp:setTarget(nil)
	comp:setPatrolTarget(comp:getHome())
	comp:setPatrolWaitUntil(0)
end

function EnemyAIService:_moveToward(model: Model, targetPos: Vector3, immediate: boolean?, direct: boolean?): ()
	local enemyHRP: BasePart? = CharacterUtils.getRoot(model)
	local humanoid: Humanoid? = model:FindFirstChildWhichIsA("Humanoid")
	if not enemyHRP or not humanoid then return end

	if _isProtected(enemyHRP.Position) then
		_pathfinder:clear(model)
		humanoid:MoveTo(_clampOutsideProtection(enemyHRP.Position))
		return
	end

	if direct then
		humanoid:MoveTo(_clampOutsideProtection(targetPos))
		return
	end

	_pathfinder:moveTo(model, humanoid, enemyHRP.Position, _clampOutsideProtection(targetPos), _clampOutsideProtection, immediate)
end

function EnemyAIService:_scanDetection(networker: NetworkerServer): ()
	for model, comp in _activeEnemies do
		if comp:getState() ~= States.PATROL then continue end

		local enemyHRP: BasePart? = CharacterUtils.getRoot(model)
		if not enemyHRP then continue end
		local enemyPos: Vector3 = enemyHRP.Position
		if not _nearAnyPlayer(enemyPos, EnemyConfig.simulationRadius) then continue end

		local closestPlayer: Player? = nil
		local closestHRP: BasePart? = nil
		local closestDist: number = math.huge
		local warned: { [Player]: boolean } = comp:getWarnedPlayers()
		for _, player in Players:GetPlayers() do
			local hrp: BasePart? = CharacterUtils.getPlayerRoot(player)
			if not hrp then continue end
			if _isProtected(hrp.Position) then continue end
			local dist: number = (hrp.Position - enemyPos).Magnitude
			if dist < EnemyConfig.detectionRange and dist < closestDist then
				closestPlayer = player
				closestHRP = hrp
				closestDist = dist
			end
			if dist <= EnemyConfig.warningRange and not warned[player] then
				comp:setWarned(player, true)
				networker:fire(player, "onEnemyWarning", comp:getEntityType())
			elseif dist > EnemyConfig.warningRange + 10 and warned[player] then
				comp:setWarned(player, false)
			end
		end
		if closestPlayer and closestHRP then
			comp:setState(States.ALERTED)
			comp:setTarget(closestPlayer)
			EnemySignals.EnemyAggro:Fire(model, closestPlayer)
			EnemyAIService:_moveToward(model, closestHRP.Position, true, closestDist <= EnemyConfig.directChaseRange)
		end
	end
end

function EnemyAIService:_tickAlerted(): ()
	for model, comp in _activeEnemies do
		if comp:getState() ~= States.ALERTED then continue end

		local target: Player? = comp:getTarget()
		local targetHRP: BasePart? = if target then CharacterUtils.getPlayerRoot(target) else nil
		if not targetHRP or _isProtected(targetHRP.Position) then
			_disengage(comp)
			continue
		end
		local enemyHRP: BasePart? = CharacterUtils.getRoot(model)
		if not enemyHRP then continue end

		if (enemyHRP.Position - comp:getHome()).Magnitude > EnemyConfig.chaseLeashRadius then
			_disengage(comp)
			continue
		end

		local dist: number = (targetHRP.Position - enemyHRP.Position).Magnitude
		if dist <= EnemyConfig.attackRange then
			comp:setState(States.ATTACKING)
			continue
		end

		EnemyAIService:_moveToward(model, targetHRP.Position, nil, dist <= EnemyConfig.directChaseRange)
	end
end

function EnemyAIService:_tickAttacking(): ()
	for model, comp in _activeEnemies do
		if comp:getState() ~= States.ATTACKING then continue end

		local target: Player? = comp:getTarget()
		local targetHRP: BasePart? = if target then CharacterUtils.getPlayerRoot(target) else nil
		local enemyHRP: BasePart? = CharacterUtils.getRoot(model)
		if not target or not targetHRP or not enemyHRP then
			comp:setState(States.ALERTED)
			continue
		end
		if _isProtected(targetHRP.Position) then
			_disengage(comp)
			continue
		end

		local dist: number = (targetHRP.Position - enemyHRP.Position).Magnitude
		if dist > EnemyConfig.attackRange then
			comp:setState(States.ALERTED)
			continue
		end

		local entityData = EntityConfig[comp:getEntityType()]
		if not entityData then continue end

		local now: number = os.clock()
		local last: number = comp:getLastAttackTime()
		if now - last >= entityData.attackCooldown then
			comp:setLastAttackTime(now)
			local targetChar: Model? = target.Character
			if targetChar and targetChar:GetAttribute("alive") == true then
				CharacterSignals.ModDebuff:Fire(target, "damage", entityData.damage)
			end
		end
	end
end

function EnemyAIService:_tickPatrol(): ()
	local now: number = os.clock()
	for model, comp in _activeEnemies do
		if comp:getState() ~= States.PATROL then continue end

		local enemyHRP: BasePart? = CharacterUtils.getRoot(model)
		if not enemyHRP then continue end
		if not _nearAnyPlayer(enemyHRP.Position, EnemyConfig.simulationRadius) then continue end

		if now < comp:getPatrolWaitUntil() then continue end

		local target: Vector3? = comp:getPatrolTarget()
		if target and ((target - enemyHRP.Position) * Vector3.new(1, 0, 1)).Magnitude > 3 then
			EnemyAIService:_moveToward(model, target)
		else
			local waitDuration: number = _rand:NextNumber(EnemyConfig.patrolWaitMin, EnemyConfig.patrolWaitMax)
			comp:setPatrolWaitUntil(now + waitDuration)
			local home: Vector3 = comp:getHome()
			local angle: number = _rand:NextNumber(0, math.pi * 2)
			local radius: number = _rand:NextNumber(0, EnemyConfig.patrolRadius)
			comp:setPatrolTarget(Vector3.new(
				home.X + math.cos(angle) * radius,
				enemyHRP.Position.Y,
				home.Z + math.sin(angle) * radius
			))
		end
	end
end

function EnemyAIService:OnStart(): ()
	local networker: NetworkerServer = Networker.server.new(EnemyNetwork.Enemy)

	_trove:Connect(EnemySignals.EnemySpawned, function(model: Model, _: string)
		local comp: EnemyComponentInterface? = EnemyComponent:FromInstance(model) :: EnemyComponentInterface?
		if not comp then return end
		_activeEnemies[model] = comp
	end)

	_trove:Connect(EnemySignals.EnemyDied, function(model: Model, _: string)
		_clearEnemyState(model)
	end)

	_trove:Connect(EnemySignals.EnemyDamaged, function(model: Model, attacker: Player)
		local comp: EnemyComponentInterface? = _activeEnemies[model]
		if not comp or comp:getState() ~= States.PATROL then return end

		local attackerHRP: BasePart? = CharacterUtils.getPlayerRoot(attacker)
		if not attackerHRP or _isProtected(attackerHRP.Position) then return end

		comp:setState(States.ALERTED)
		comp:setTarget(attacker)
		EnemySignals.EnemyAggro:Fire(model, attacker)
		EnemyAIService:_moveToward(model, attackerHRP.Position, true)
	end)

	_trove:Connect(CollectionService:GetInstanceRemovedSignal("Enemy"), function(instance: Instance)
		_clearEnemyState(instance :: Model)
	end)

	local detectionTimer = _trove:Add(Timer.new(0.25))
	detectionTimer.Tick:Connect(function()
		EnemyAIService:_scanDetection(networker)
	end)
	detectionTimer:Start()

	local pathTimer = _trove:Add(Timer.new(0.2))
	pathTimer.Tick:Connect(function()
		EnemyAIService:_tickPatrol()
		EnemyAIService:_tickAlerted()
	end)
	pathTimer:Start()

	local attackTimer = _trove:Add(Timer.new(0.5))
	attackTimer.Tick:Connect(function()
		EnemyAIService:_tickAttacking()
	end)
	attackTimer:Start()
end

export type EnemyAIService = typeof(EnemyAIService)
return EnemyAIService
