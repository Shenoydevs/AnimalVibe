--!strict
local _players = game:GetService("Players")
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _serverScriptService = game:GetService("ServerScriptService")

local _packages = _replicatedStorage.Packages
local _networkerModule = require(_packages.Networker)
local _troveModule = require(_packages.Trove)

local _cartConfig = require(_replicatedStorage.Shared.config.CartConfig)
local _cartTypes = require(_replicatedStorage.Shared.types.CartTypes)
local _network = require(_replicatedStorage.Shared.network.CartNetwork)
local _signals = require(_serverScriptService.Server.signals)

local _cartInteractionUtils = require(_serverScriptService.Server.utils.CartInteractionUtils)

local _cartSignals = _signals.cartSignals

type networkerServer = _networkerModule.Server
type cartComponentInterface = _cartTypes.cartComponentInterface
type wheelComponentInterface = _cartTypes.wheelComponentInterface

type cartState = {
	socketCount: number,
	filledCount: number,
	filledSockets: { [Attachment]: boolean },
	installedWheels: { [BasePart]: boolean },
	component: cartComponentInterface,
}

type carryState = {
	component: wheelComponentInterface,
	trove: typeof(_troveModule.new()),
}

local _trove = _troveModule.new()
local _cartTrove = _trove:Extend()
local _networker: networkerServer? = nil

local function _getNetworker(): networkerServer
	return assert(_networker, "Cart networking has not started")
end
local _cart: cartState? = nil
local _carrying: { [Player]: carryState } = {}
local _wheelOwners: { [BasePart]: Player } = {}
local _assembled: boolean = false
local _assemblyRevision: number = 0

local _cartLightService = require(script.Parent.CartLightService)
local cartService = {}

local function _getClosestFreeSocket(cart: cartState, position: Vector3): Attachment?
	local closest: Attachment? = nil
	local closestDistance: number = math.huge
	for _, socket in cart.component:getSockets() do
		if cart.filledSockets[socket] then continue end
		local distance: number = (socket.WorldPosition - position).Magnitude
		if distance < closestDistance then
			closest = socket
			closestDistance = distance
		end
	end
	return closest
end

function cartService:isInSafezone(position: Vector3): boolean
	return _cartLightService:isInSafezone(position)
end

function cartService:clampOutsideSafezone(position: Vector3): Vector3
	return _cartLightService:clampOutsideSafezone(position)
end

local function _playerRootWithin(player: Player, position: Vector3): BasePart?
	return _cartInteractionUtils.getRootWithin(player, position, _cartConfig.interactDistance)
end

function cartService:isAssembled(): boolean
	return _assembled
end

function cartService:getAssemblyState(): (boolean, number)
	return _assembled, _assemblyRevision
end

local function _publishAssembly(): ()
	_assemblyRevision += 1
	_getNetworker():fireAll("onAssemblyChanged", _assembled, _assemblyRevision)
end

function cartService:ownsPart(part: BasePart): boolean
	local cart: cartState? = _cart
	return cart ~= nil and part:IsDescendantOf(workspace) and part:IsDescendantOf(cart.component:getModel())
end

function cartService:OnStart(): ()
	_networker = _networkerModule.server.new(_network.cart, cartService, { cartService.isAssembled, cartService.getAssemblyState })

	_trove:Connect(_cartSignals.cartReady, function(component: cartComponentInterface): ()
		cartService:_setupCart(component)
	end)

	_trove:Connect(_cartSignals.cartRemoved, function(component: cartComponentInterface): ()
		if not _cart or _cart.component ~= component then return end
		cartService:_clearCart()
	end)

	_trove:Connect(_cartSignals.wheelPickup, function(wheelComponent: wheelComponentInterface, player: Player): ()
		cartService:_pickupWheel(wheelComponent, player)
	end)

	_trove:Connect(_cartSignals.attachRequested, function(player: Player): ()
		cartService:_attachWheel(player)
	end)

	_trove:Connect(_cartSignals.assemblyComplete, function(component: cartComponentInterface): ()
		local cart: cartState? = _cart
		if not cart or cart.component ~= component then return end
		cart.component:setRopePromptsEnabled(true)
		_assembled = true
		_publishAssembly()
	end)

	_trove:Connect(_players.PlayerRemoving, function(player: Player): ()
		cartService:_dropWheel(player)
	end)
end

function cartService:_clearCart(): ()
	_cartTrove:Clean()
	for player in _carrying do
		cartService:_dropWheel(player)
	end
	table.clear(_wheelOwners)
	_cart = nil
	_assembled = false
	_publishAssembly()
end

function cartService:_setupCart(component: cartComponentInterface): ()
	cartService:_clearCart()

	_cart = {
		socketCount = #component:getSockets(),
		filledCount = 0,
		filledSockets = {},
		installedWheels = {},
		component = component,
	}

end

function cartService:_pickupWheel(wheelComponent: wheelComponentInterface, player: Player): ()
	if _carrying[player] then return end
	local cart: cartState? = _cart
	if not cart or _assembled then return end

	local wheelPart: BasePart = wheelComponent:getPart()
	if not self:ownsPart(wheelPart) or _wheelOwners[wheelPart] or cart.installedWheels[wheelPart] then return end
	if not _playerRootWithin(player, wheelPart.Position) then return end
	if not wheelPart:CanSetNetworkOwnership() then return end

	local carryTrove = _troveModule.new()
	local carryState: carryState = { component = wheelComponent, trove = carryTrove }
	local character: Model? = player.Character
	if character then
		carryTrove:Connect(character:GetAttributeChangedSignal("alive"), function(): ()
			if _carrying[player] ~= carryState then return end
			if character:GetAttribute("alive") ~= true then
				cartService:_dropWheel(player)
			end
		end)
		carryTrove:Connect(player.CharacterRemoving, function(removingCharacter: Model): ()
			if removingCharacter == character and _carrying[player] == carryState then
				cartService:_dropWheel(player)
			end
		end)
	end

	_carrying[player] = carryState
	_wheelOwners[wheelPart] = player
	carryTrove:Connect(wheelPart.AncestryChanged, function(): ()
		if _carrying[player] == carryState and not cartService:ownsPart(wheelPart) then
			cartService:_dropWheel(player)
		end
	end)
	wheelComponent:setPromptEnabled(false)
	wheelPart:SetNetworkOwner(player)

	_getNetworker():fire(player, "onWheelPickedUp", wheelPart)
end

function cartService:_dropWheel(player: Player): ()
	local state: carryState? = _carrying[player]
	if not state then return end

	_carrying[player] = nil
	state.trove:Destroy()

	local wheelPart: BasePart = state.component:getPart()
	_wheelOwners[wheelPart] = nil
	if wheelPart:IsDescendantOf(workspace) then
		if wheelPart:CanSetNetworkOwnership() then wheelPart:SetNetworkOwner(nil) end
		state.component:setPromptEnabled(true)
	end

	if player.Parent == _players then _getNetworker():fire(player, "onWheelDropped") end
end

function cartService:_attachWheel(player: Player): ()
	local cart: cartState? = _cart
	if not cart then return end

	local state: carryState? = _carrying[player]
	if not state then return end
	local wheelComponent: wheelComponentInterface = state.component

	local cartPosition: Vector3 = cart.component:getPosition()
	local root: BasePart? = _playerRootWithin(player, cartPosition)
	if not root then return end

	local wheelPart: BasePart = wheelComponent:getPart()
	if _wheelOwners[wheelPart] ~= player or cart.installedWheels[wheelPart] then return end
	if not self:ownsPart(wheelPart) then return end
	if not wheelPart:CanSetNetworkOwnership() then return end
	if (wheelPart.Position - cartPosition).Magnitude > _cartConfig.maxRopeDistance then return end

	local socket: Attachment? = _getClosestFreeSocket(cart, root.Position)
	if not socket then return end

	local wheelAxle: Attachment = wheelComponent:getAxle()

	_carrying[player] = nil
	_wheelOwners[wheelPart] = nil
	cart.installedWheels[wheelPart] = true
	state.trove:Destroy()
	wheelPart:SetNetworkOwner(nil)
	wheelComponent:setPromptEnabled(false)

	local constraint: HingeConstraint = _cartTrove:Add(Instance.new("HingeConstraint"))
	constraint.Attachment0 = wheelAxle
	constraint.Attachment1 = socket
	constraint.Parent = wheelPart

	cart.filledSockets[socket] = true

	cart.filledCount += 1

	_getNetworker():fire(player, "onWheelDropped")

	if cart.filledCount >= cart.socketCount then
		cart.component:setAttachPromptsEnabled(false)
		_cartSignals.assemblyComplete:Fire(cart.component)
	end
end

function cartService:getPosition(): Vector3?
	local cart: cartState? = _cart
	if not cart then return nil end
	return cart.component:getPosition()
end

export type cartService = typeof(cartService)

return cartService
