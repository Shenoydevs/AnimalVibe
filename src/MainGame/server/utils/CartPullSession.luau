--!strict
local _replicatedStorage = game:GetService("ReplicatedStorage")

local _troveModule = require(_replicatedStorage.Packages.Trove)
local _networkerModule = require(_replicatedStorage.Packages.Networker)

local _cartConfig = require(_replicatedStorage.Shared.config.CartConfig)
local _cartTypes = require(_replicatedStorage.Shared.types.CartTypes)
local _characterUtils = require(_replicatedStorage.Shared.utils.CharacterUtils)
local _cartInteractionUtils = require(script.Parent.CartInteractionUtils)
local _cartTilt = require(script.Parent.CartTilt)

type networkerServer = _networkerModule.Server
type cartComponentInterface = _cartTypes.cartComponentInterface

type pullerState = {
	ropePart: BasePart,
	trove: typeof(_troveModule.new()),
	order: number,
	overstretchTime: number,
	isMoving: boolean,
	lastInputAt: number,
	character: Model,
}

local function _isLeadRope(ropePart: BasePart): boolean
	return ropePart.Name:match("Lead") ~= nil
end

local function _getPullModifier(player: Player): number
	local character: Model? = player.Character
	if not character then return 1 end
	return (character:GetAttribute("cartModifier") :: number?) or 1
end

local function _getSoloPullSpeed(player: Player): number
	local character: Model? = player.Character
	local walkSpeedAttribute: unknown = if character then character:GetAttribute("walkSpeed") else nil
	local walkSpeed: number = if typeof(walkSpeedAttribute) == "number"
		and walkSpeedAttribute > 0 and walkSpeedAttribute < math.huge
		then walkSpeedAttribute else _cartConfig.baseCartSpeed
	-- The weakest solo puller still needs enough headroom to recover the gap from normal walking.
	return math.max(
		walkSpeed * _cartConfig.soloWalkSpeedMultiplier,
		_getPullModifier(player) * _cartConfig.baseCartSpeed
	)
end

local function _moveTowards(current: number, target: number, maxDelta: number): number
	if current < target then
		return math.min(current + maxDelta, target)
	elseif current > target then
		return math.max(current - maxDelta, target)
	end
	return current
end


local cartPullSession = {}
cartPullSession.__index = cartPullSession

export type cartPullSession = typeof(setmetatable(
	{} :: {
		_cart: cartComponentInterface,
		_tilt: _cartTilt.cartTilt,
		_networker: networkerServer,
		_pullers: { [Player]: pullerState },
		_pullerCount: number,
		_attachOrder: number,
		_currentSpeed: number,
		_lastUnstuckAt: number,
		_destroyed: boolean,
	},
	cartPullSession
))

function cartPullSession.new(cart: cartComponentInterface, networker: networkerServer): cartPullSession
	local self = setmetatable({}, cartPullSession) :: cartPullSession
	self._cart = cart
	self._tilt = _cartTilt.new(cart:getModel())
	self._networker = networker
	self._pullers = {}
	self._pullerCount = 0
	self._attachOrder = 0
	self._currentSpeed = 0
	self._lastUnstuckAt = -math.huge
	self._destroyed = false
	return self
end

function cartPullSession._getLeadPlayer(self: cartPullSession): Player?
	local lead: Player? = nil
	local leadOrder: number = math.huge
	local leadOnHarness: boolean = false
	for player, state in self._pullers do
		local onHarness: boolean = _isLeadRope(state.ropePart)
		if (onHarness and not leadOnHarness) or (onHarness == leadOnHarness and state.order < leadOrder) then
			lead = player
			leadOrder = state.order
			leadOnHarness = onHarness
		end
	end
	return lead
end

function cartPullSession.attachPuller(self: cartPullSession, player: Player, ropePart: BasePart): ()
	if self._destroyed then return end
	if self._pullers[player] then return end
	if self._pullerCount >= _cartConfig.maxPullers then return end
	if not ropePart:IsDescendantOf(workspace) or not table.find(self._cart:getRopeParts(), ropePart) then return end
	for _, state in self._pullers do
		if state.ropePart == ropePart then return end
	end

	local character: Model? = player.Character
	if not character then return end
	if character:GetAttribute("pullingBoulder") == true then return end
	local root: BasePart? = _cartInteractionUtils.getRootWithin(player, ropePart.Position, _cartConfig.interactDistance)
	if not root then return end
	local humanoid: Humanoid? = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid:GetState() == Enum.HumanoidStateType.Jumping then return end

	local trove = _troveModule.new()
	local pullerState: pullerState = {
		ropePart = ropePart,
		trove = trove,
		order = self._attachOrder + 1,
		overstretchTime = 0,
		isMoving = false,
		lastInputAt = -math.huge,
		character = character,
	}
	trove:Connect(character:GetAttributeChangedSignal("alive"), function(): ()
		if self._pullers[player] ~= pullerState then return end
		if character:GetAttribute("alive") ~= true then
			self:detachPuller(player)
		end
	end)
	trove:Connect(player.CharacterRemoving, function(removingCharacter: Model): ()
		if removingCharacter == character and self._pullers[player] == pullerState then
			self:detachPuller(player)
		end
	end)

	self._attachOrder += 1
	self._pullers[player] = pullerState
	self._pullerCount += 1
	character:SetAttribute("pullingCart", true)
	local walkSpeed = character:GetAttribute("walkSpeed")
	if typeof(walkSpeed) == "number" then humanoid.WalkSpeed = math.min(humanoid.WalkSpeed, walkSpeed) end
	trove:Connect(humanoid.StateChanged, function(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType): ()
		if new == Enum.HumanoidStateType.Jumping and self._pullers[player] == pullerState then
			self:detachPuller(player)
		end
	end)

	self._cart:setRopePromptEnabled(ropePart, false)

	if self._pullerCount == 1 then
		self._tilt:reset()
		self._cart:setupPullRig()
		self._cart:setPulling(true)
	end

	self:_broadcastPullers()
end

function cartPullSession.setPullInput(self: cartPullSession, player: Player, isMoving: boolean): ()
	if self._destroyed then return end
	local state: pullerState? = self._pullers[player]
	if not state then return end

	local now: number = os.clock()
	if now - state.lastInputAt < _cartConfig.pullInputInterval / 2 then return end
	state.isMoving = isMoving
	state.lastInputAt = now
end

function cartPullSession.unstuckCart(self: cartPullSession, player: Player): ()
	if self._destroyed or not self._pullers[player] then return end

	local now: number = os.clock()
	if now - self._lastUnstuckAt < _cartConfig.unstuckCooldown then return end

	self._lastUnstuckAt = now
	self._currentSpeed = 0
	self._cart:unstuck()
end

function cartPullSession.detachPuller(self: cartPullSession, player: Player): ()
	if self._destroyed then return end
	local state: pullerState? = self._pullers[player]
	if not state then return end

	self._pullers[player] = nil
	self._pullerCount -= 1
	state.trove:Destroy()
	state.character:SetAttribute("pullingCart", false)

	self._cart:setRopePromptEnabled(state.ropePart, true)
	if self._pullerCount == 0 then
		self._tilt:reset()
		self._currentSpeed = 0
		self._cart:setPulling(false)
		self._cart:setWheelSpinSpeed(0)
	end

	self:_broadcastPullers()
end

function cartPullSession.destroy(self: cartPullSession): ()
	if self._destroyed then return end

	local players: { Player } = {}
	for player in self._pullers do
		table.insert(players, player)
	end
	for _, player in players do
		self:detachPuller(player)
	end
	self._destroyed = true
	self._tilt:reset()
	self._attachOrder = 0
	self._currentSpeed = 0
	self._networker:setAll("pullers", {})
end

function cartPullSession.ownsCart(self: cartPullSession, component: cartComponentInterface): boolean
	return self._cart == component
end

function cartPullSession.getPullers(self: cartPullSession): { _cartTypes.pullerEntry }
	local leadPlayer: Player? = self:_getLeadPlayer()
	local list: { _cartTypes.pullerEntry } = {}
	for player, state in self._pullers do
		table.insert(list, { player = player, ropePart = state.ropePart, isLead = player == leadPlayer })
	end
	return list
end

function cartPullSession._broadcastPullers(self: cartPullSession): ()
	self._networker:setAll("pullers", self:getPullers())
end

function cartPullSession._settle(self: cartPullSession, dt: number): ()
	local cart: cartComponentInterface = self._cart
	local maxDelta: number = (_cartConfig.maxPullSpeed / _cartConfig.brakeTime) * dt
	self._currentSpeed = _moveTowards(self._currentSpeed, 0, maxDelta)

	cart:setPullVelocity(cart:getForward() * self._currentSpeed)
	cart:setWheelSpinSpeed(self._currentSpeed * _cartConfig.wheelSpinRate)
end

function cartPullSession.tick(self: cartPullSession, dt: number): ()
	if self._destroyed or self._pullerCount == 0 then return end

	local cart: cartComponentInterface = self._cart
	local cartPos: Vector3 = cart:getPosition()
	local leadPlayer: Player? = self:_getLeadPlayer()

	local toDetach: { Player } = {}
	local helperPullPower: number = 0
	local leadRoot: BasePart? = nil
	local leadRopePos: Vector3? = nil
	local leadContributing: boolean = false
	local now: number = os.clock()

	for player, state in self._pullers do
		local root: BasePart? = _characterUtils.getPlayerRoot(player)
		if not root or player.Character ~= state.character or state.character:GetAttribute("alive") ~= true
			or not state.ropePart:IsDescendantOf(workspace) then
			table.insert(toDetach, player)
			continue
		end

		-- Overstretched ropes get a grace window instead of snapping instantly,
		-- so uneven terrain does not immediately detach a puller.
		if (root.Position - cartPos).Magnitude > _cartConfig.maxRopeDistance then
			state.overstretchTime += dt
			if state.overstretchTime >= _cartConfig.ropeBreakGraceTime then
				table.insert(toDetach, player)
				continue
			end
		else
			state.overstretchTime = 0
		end

		local contributing: boolean = state.isMoving and now - state.lastInputAt <= _cartConfig.pullInputTimeout
		local isLead: boolean = player == leadPlayer
		if isLead then
			leadRoot = root
			leadRopePos = state.ropePart.Position
			leadContributing = contributing
		end

		if contributing and not isLead then
			helperPullPower += _getPullModifier(player) * _cartConfig.helperEfficiency
		end
	end

	for _, player in toDetach do
		self:detachPuller(player)
	end

	if self._pullerCount == 0 or not leadPlayer or not leadRoot or not leadRopePos then
		self:_settle(dt)
		return
	end

	-- Steering always tracks the lead puller alone; helpers never influence heading.
	local toLead: Vector3 = Vector3.new(leadRoot.Position.X - cartPos.X, 0, leadRoot.Position.Z - cartPos.Z)
	local dir: Vector3 = if toLead.Magnitude > 0.01 then toLead.Unit else cart:getForward()
	cart:setPullDirection(dir, self._tilt:update(dir, dt))

	-- Tension is measured from the lead's own rope attach point, not the cart's
	-- center, so the cart can stop with slack remaining instead of closing the
	-- gap into the puller's body.
	local ropeDist: number = (leadRoot.Position - leadRopePos).Magnitude
	local tension: number = math.clamp(
		(ropeDist - _cartConfig.slackDistance) / (_cartConfig.tautDistance - _cartConfig.slackDistance),
		0,
		1
	)
	local strain: number = math.clamp(
		(ropeDist - _cartConfig.tautDistance) / (_cartConfig.surgeDistance - _cartConfig.tautDistance),
		0,
		1
	)
	local surgeMultiplier: number = 1 + strain * _cartConfig.surgeSpeedBonus

	local targetSpeed: number = 0
	if leadContributing and tension > 0 then
		local combinedSpeed: number = _getSoloPullSpeed(leadPlayer) + helperPullPower * _cartConfig.baseCartSpeed
		local cappedSpeed: number = math.clamp(combinedSpeed, _cartConfig.minCartSpeed, _cartConfig.maxPullSpeed)
		targetSpeed = math.min(cappedSpeed * tension * surgeMultiplier, _cartConfig.maxPullSpeed)
	end

	-- Rate-limited toward the target so the cart brakes smoothly instead of
	-- cutting to a stop or overshooting into the lead puller.
	local maxDelta: number = (_cartConfig.maxPullSpeed / _cartConfig.brakeTime) * dt
	self._currentSpeed = _moveTowards(self._currentSpeed, targetSpeed, maxDelta)

	-- Velocity is always along the cart's own forward axis, never pointed
	-- straight at the players, so it can never slide sideways or crab.
	cart:setPullVelocity(cart:getForward() * self._currentSpeed)
	cart:setWheelSpinSpeed(self._currentSpeed * _cartConfig.wheelSpinRate)
end

return cartPullSession
