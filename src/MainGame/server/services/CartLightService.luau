--!strict
local _runService = game:GetService("RunService")
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _serverScriptService = game:GetService("ServerScriptService")
local _timer = require(_replicatedStorage.Packages.Timer)
local _troveModule = require(_replicatedStorage.Packages.Trove)
local _cartConfig = require(_replicatedStorage.Shared.config.CartConfig)
local _cartTypes = require(_replicatedStorage.Shared.types.CartTypes)
local _safezoneUtils = require(_replicatedStorage.Shared.utils.SafezoneUtils)
local _notificationConfig = require(_replicatedStorage.Shared.config.NotificationConfig)
local _notificationService = require(script.Parent.NotificationService)
local _signals = require(_serverScriptService.Server.signals)
local _cartSignals = _signals.cartSignals
local _enemySignals = _signals.EnemySignals
local _gameSignals = _signals.GameSignals

type cartComponentInterface = _cartTypes.cartComponentInterface
type cartState = { sessionId: number, fuelLevel: number, component: cartComponentInterface }

local _trove = _troveModule.new()
local _depletionTrove = _trove:Extend()
type essenceEntry = { part: Part, expiresAt: number }
local _essences: { essenceEntry } = {}
local _cart: cartState? = nil
local _sessionId: number = 0
local cartLightService = {}

function cartLightService:_clearCart(): ()
	_sessionId += 1
	_depletionTrove:Clean()
	_cart = nil
	for _, entry in _essences do entry.part:Destroy() end
	table.clear(_essences)
end

function cartLightService:OnStart(): ()
	_trove:Connect(_cartSignals.cartReady, function(component: cartComponentInterface): ()
		self:_clearCart()
		_cart = { sessionId = _sessionId, fuelLevel = _cartConfig.maxFuel, component = component }
		component:setLightLevel(_cartConfig.maxFuel, _cartConfig.maxFuel)
	end)
	_trove:Connect(_cartSignals.cartRemoved, function(component: cartComponentInterface): ()
		if _cart and _cart.component == component then self:_clearCart() end
	end)
	_trove:Connect(_gameSignals.HuntersSpawned, function(): ()
		self:_beginDepletion()
	end)
	_trove:Connect(_gameSignals.DayCycleCompleted, function(): ()
		_depletionTrove:Clean()
	end)
	_trove:Connect(_enemySignals.EnemyDied, function(model: Model, _spawnId: string): ()
		self:_spawnEssence(model:GetPivot().Position)
	end)
	_trove:Connect(_cartSignals.lightDepleted, function(): ()
		_notificationService:notifyAll("Alert", "The cart light has gone out!", 5, _notificationConfig.priority.high)
	end)
	_trove:Connect(_cartSignals.lightRestored, function(): ()
		_notificationService:notifyAll("Success", "The cart light burns again!", 4, _notificationConfig.priority.med)
	end)
	_trove:Connect(_runService.Heartbeat, function(dt: number): ()
		self:_updateEssences(dt)
	end)
end

function cartLightService:_beginDepletion(): ()
	local cart: cartState? = _cart
	if not cart then return end

	_depletionTrove:Clean()
	local depletionTimer = _depletionTrove:Add(_timer.new(1))
	_depletionTrove:Connect(depletionTimer.Tick, function(): ()
		cartLightService:_tick(cart.sessionId)
	end)
	depletionTimer:Start()
end

function cartLightService:_tick(callerSessionId: number): ()
	local cart: cartState? = _cart
	if not cart or cart.sessionId ~= callerSessionId then return end
	if cart.fuelLevel <= 0 then return end

	local prev: number = cart.fuelLevel
	cart.fuelLevel = math.max(0, cart.fuelLevel - _cartConfig.lightDepletionRate)

	cart.component:setLightLevel(cart.fuelLevel, _cartConfig.maxFuel)

	if prev > 0 and cart.fuelLevel <= 0 then
		_cartSignals.lightDepleted:Fire()
	end
end

function cartLightService:refuel(amount: number): ()
	local cart: cartState? = _cart
	if not cart then return end

	local wasEmpty: boolean = cart.fuelLevel <= 0
	cart.fuelLevel = math.min(_cartConfig.maxFuel, cart.fuelLevel + amount)

	cart.component:setLightLevel(cart.fuelLevel, _cartConfig.maxFuel)

	if wasEmpty and cart.fuelLevel > 0 then
		_cartSignals.lightRestored:Fire()
	end
end

function cartLightService:isInSafezone(position: Vector3): boolean
	local cart: cartState? = _cart
	if not cart or cart.fuelLevel <= 0 then return false end
	return _safezoneUtils.isInside(position, cart.component:getPosition(), _cartConfig.lightRadius)
end

function cartLightService:clampOutsideSafezone(position: Vector3): Vector3
	local cart: cartState? = _cart
	if not cart or cart.fuelLevel <= 0 then return position end
	return _safezoneUtils.clampOutside(position, cart.component:getPosition(), _cartConfig.lightRadius, _cartConfig.lightRepelMargin)
end

function cartLightService:_spawnEssence(position: Vector3): ()
	if not _cart then return end
	local essence: Part = Instance.new("Part")
	essence.Name = "HunterEssence"
	essence.Shape = Enum.PartType.Ball
	essence.Size = Vector3.one * 1.5
	essence.Material = Enum.Material.Neon
	essence.Color = Color3.fromRGB(255, 170, 60)
	essence.Anchored = true
	essence.CanCollide = false
	essence.CanTouch = false
	essence.CanQuery = false
	essence.CastShadow = false

	local light: PointLight = Instance.new("PointLight")
	light.Color = essence.Color
	light.Range = 6
	light.Parent = essence

	essence.CFrame = CFrame.new(position)
	essence.Parent = workspace:FindFirstChild("Map") or workspace
	table.insert(_essences, { part = essence, expiresAt = os.clock() + _cartConfig.essenceDespawnTime })
end

function cartLightService:_updateEssences(dt: number): ()
	if #_essences == 0 then return end
	local cart: cartState? = _cart
	local target: Vector3? = if cart then cart.component:getPosition() + Vector3.new(0, 3, 0) else nil
	local now: number = os.clock()
	local absorbed: number = 0
	for index = #_essences, 1, -1 do
		local entry = _essences[index]
		local remove: boolean = not entry.part:IsDescendantOf(workspace) or now >= entry.expiresAt
		if not remove and target then
			local offset: Vector3 = target - entry.part.Position
			local distance: number = offset.Magnitude
			local step: number = _cartConfig.essenceTravelSpeed * dt
			if distance <= _cartConfig.essenceAbsorbDistance + step then
				absorbed += 1
				remove = true
			else
				entry.part.Position += offset.Unit * step
			end
		end
		if remove then
			entry.part:Destroy()
			-- Order is irrelevant; swap-remove avoids shifting the remaining orbs.
			_essences[index] = _essences[#_essences]
			table.remove(_essences)
		end
	end
	if absorbed > 0 and cart and cart.fuelLevel < _cartConfig.maxFuel then
		self:refuel(absorbed * _cartConfig.lightRefillPerEssence)
	end
end

export type cartLightService = typeof(cartLightService)
return cartLightService
