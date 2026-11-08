--!strict
local PathfindingService = game:GetService("PathfindingService")

export type PathfinderConfig = {
	agentParams: { [string]: any },
	recomputeDistance: number,
	recomputeInterval: number,
	waypointReachedDistance: number,
	minRecomputeCooldown: number,
	stuckTimeout: number,
	stuckDistance: number,
}

-- All per-hostile pathing state in one record instead of ten parallel
-- model-keyed tables.
type PathState = {
	waypoints: { PathWaypoint }?,
	index: number?,
	targetPos: Vector3?,
	computedAt: number,
	blockedConn: RBXScriptConnection?,
	forceRecompute: boolean,
	lastPos: Vector3?,
	lastProgressAt: number?,
	computing: boolean,
	computeToken: number,
}

local EnemyPathfinder = {}
EnemyPathfinder.__index = EnemyPathfinder

export type EnemyPathfinder = typeof(setmetatable(
	{} :: {
		_config: PathfinderConfig,
		_paths: { [Model]: PathState },
	},
	EnemyPathfinder
))

function EnemyPathfinder.new(config: PathfinderConfig): EnemyPathfinder
	local self = setmetatable({}, EnemyPathfinder) :: EnemyPathfinder
	self._config = config
	self._paths = {}
	return self
end

function EnemyPathfinder:_get(model: Model): PathState
	local state: PathState? = self._paths[model]
	if not state then
		state = {
			computedAt = 0,
			forceRecompute = false,
			computing = false,
			computeToken = 0,
		}
		self._paths[model] = state
	end
	return state :: PathState
end

function EnemyPathfinder:_disconnectBlocked(state: PathState): ()
	if state.blockedConn then
		state.blockedConn:Disconnect()
		state.blockedConn = nil
	end
end

function EnemyPathfinder:clear(model: Model): ()
	local state: PathState? = self._paths[model]
	if not state then return end
	-- Bump the token so any in-flight compute for this model bails on resume.
	state.computeToken += 1
	self:_disconnectBlocked(state)
	self._paths[model] = nil
end

function EnemyPathfinder:_reachedWaypoint(fromPos: Vector3, waypointPos: Vector3): boolean
	local flat: Vector3 = (waypointPos - fromPos) * Vector3.new(1, 0, 1)
	return flat.Magnitude <= self._config.waypointReachedDistance
end

function EnemyPathfinder:_updateProgress(state: PathState, fromPos: Vector3): boolean
	local now: number = os.clock()
	local lastPos: Vector3? = state.lastPos

	if not lastPos or (fromPos - lastPos).Magnitude > self._config.stuckDistance then
		state.lastPos = fromPos
		state.lastProgressAt = now
		return false
	end

	return (now - (state.lastProgressAt or now)) > self._config.stuckTimeout
end

function EnemyPathfinder:_computePath(
	state: PathState,
	humanoid: Humanoid,
	fromPos: Vector3,
	targetPos: Vector3,
	clampFn: (Vector3) -> Vector3
): ()
	self:_disconnectBlocked(state)
	state.computing = true
	state.targetPos = targetPos
	state.computedAt = os.clock()
	state.forceRecompute = false

	state.computeToken += 1
	local token: number = state.computeToken

	task.spawn(function()
		local path: Path = PathfindingService:CreatePath(self._config.agentParams)
		local ok: boolean = pcall(function()
			path:ComputeAsync(fromPos, targetPos)
		end)

		if state.computeToken ~= token then
			return
		end
		state.computing = false

		local usable: boolean = ok
			and (path.Status == Enum.PathStatus.Success or path.Status == Enum.PathStatus.ClosestNoPath)
		if not usable then
			state.waypoints = nil
			state.index = nil
			return
		end

		local waypoints: { PathWaypoint } = path:GetWaypoints()
		if #waypoints < 2 then
			state.waypoints = nil
			state.index = nil
			return
		end

		state.waypoints = waypoints
		state.index = 2

		state.blockedConn = path.Blocked:Connect(function(blockedWaypointIndex: number)
			if blockedWaypointIndex >= (state.index or 1) then
				state.forceRecompute = true
			end
		end)

		humanoid:MoveTo(clampFn(waypoints[2].Position))
	end)
end

function EnemyPathfinder:moveTo(
	model: Model,
	humanoid: Humanoid,
	fromPos: Vector3,
	targetPos: Vector3,
	clampFn: (Vector3) -> Vector3,
	immediate: boolean?
): ()
	local state: PathState = self:_get(model)
	local stuck: boolean = self:_updateProgress(state, fromPos)

	local waypoints: { PathWaypoint }? = state.waypoints
	local index: number? = state.index
	local exhausted: boolean = (not waypoints) or (not index) or (index > #(waypoints :: { PathWaypoint }))

	local lastTarget: Vector3? = state.targetPos
	local sinceCompute: number = os.clock() - state.computedAt
	local stale: boolean = immediate == true
		or (not lastTarget)
		or exhausted
		or state.forceRecompute == true
		or stuck
		or (lastTarget - targetPos).Magnitude > self._config.recomputeDistance
		or sinceCompute > self._config.recomputeInterval

	local cooldownOk: boolean = immediate == true
		or (not lastTarget)
		or sinceCompute >= self._config.minRecomputeCooldown

	if stale and cooldownOk and not state.computing then
		self:_computePath(state, humanoid, fromPos, targetPos, clampFn)
		if exhausted or immediate then
			humanoid:MoveTo(clampFn(targetPos))
		end
		return
	end

	if not waypoints or not index then return end
	if index > #waypoints then return end

	if self:_reachedWaypoint(fromPos, waypoints[index].Position) then
		index += 1
		state.index = index
		if index > #waypoints then return end
		humanoid:MoveTo(clampFn(waypoints[index].Position))
	end
end

return EnemyPathfinder
