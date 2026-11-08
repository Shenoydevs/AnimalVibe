--!strict
local _players = game:GetService("Players")
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _runService = game:GetService("RunService")
local _serverScriptService = game:GetService("ServerScriptService")

local _packages = _replicatedStorage.Packages
local _networkerModule = require(_packages.Networker)
local _troveModule = require(_packages.Trove)

local _cartPullSession = require(_serverScriptService.Server.utils.CartPullSession)
local _cartService = require(_serverScriptService.Server.services.CartService)
local _cartTypes = require(_replicatedStorage.Shared.types.CartTypes)
local _network = require(_replicatedStorage.Shared.network.CartNetwork)
local _signals = require(_serverScriptService.Server.signals)

local _cartSignals = _signals.cartSignals

type networkerServer = _networkerModule.Server
type cartComponentInterface = _cartTypes.cartComponentInterface
type cartPullSessionType = _cartPullSession.cartPullSession

local _trove = _troveModule.new()
local _networker: networkerServer? = nil

local function _getNetworker(): networkerServer
	return assert(_networker, "Cart networking has not started")
end
local _session: cartPullSessionType? = nil
local _snapshotRequests: { [Player]: number } = {}

local cartPullService = {}

function cartPullService:OnStart(): ()
	_networker = _networkerModule.server.new(_network.cartPull, cartPullService, {
		cartPullService.releaseRope,
		cartPullService.unstuckCart,
		cartPullService.setPullInput,
		cartPullService.requestPullers,
	})

	_trove:Connect(_cartSignals.cartReady, function(component: cartComponentInterface): ()
		cartPullService:_startSession(component)
	end)

	_trove:Connect(_cartSignals.pullAttachRequested, function(player: Player, ropePart: BasePart): ()
		if not _session or not _cartService:isAssembled() then return end
		_session:attachPuller(player, ropePart)
	end)

	_trove:Connect(_cartSignals.cartRemoved, function(component: cartComponentInterface): ()
		if not _session or not _session:ownsCart(component) then return end
		_session:destroy()
		_session = nil
	end)

	_trove:Connect(_players.PlayerRemoving, function(player: Player): ()
		_snapshotRequests[player] = nil
		if not _session then return end
		_session:detachPuller(player)
	end)

	_trove:Connect(_runService.Heartbeat, function(dt: number): ()
		if not _session then return end
		_session:tick(dt)
	end)
end

function cartPullService:releaseRope(player: Player): ()
	if not _session then return end
	_session:detachPuller(player)
end

function cartPullService:setPullInput(player: Player, isMoving: unknown): ()
	if typeof(isMoving) ~= "boolean" then return end
	if not _session then return end
	_session:setPullInput(player, isMoving)
end

function cartPullService:unstuckCart(player: Player): ()
	if not _session then return end
	_session:unstuckCart(player)
end

function cartPullService:requestPullers(player: Player): ()
	local now: number = os.clock()
	local lastRequest: number? = _snapshotRequests[player]
	if lastRequest and now - lastRequest < 0.5 then return end
	_snapshotRequests[player] = now
	local pullers: { _cartTypes.pullerEntry } = if _session then _session:getPullers() else {}
	_getNetworker():set(player, "pullers", pullers)
end

function cartPullService:_startSession(component: cartComponentInterface): ()
	if _session then
		_session:destroy()
	end
	_session = _cartPullSession.new(component, _getNetworker())
	_getNetworker():setAll("pullers", _session:getPullers())
end

export type cartPullService = typeof(cartPullService)
return cartPullService
