--!strict
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _signal = require(_replicatedStorage.Packages.Signal)
local _cartTypes = require(_replicatedStorage.Shared.types.CartTypes)

local cartSignals = {
	cartReady = _signal.new() :: _signal.Signal<_cartTypes.cartComponentInterface>,
	cartRemoved = _signal.new() :: _signal.Signal<_cartTypes.cartComponentInterface>,
	lightDepleted = _signal.new() :: _signal.Signal<>,
	lightRestored = _signal.new() :: _signal.Signal<>,
	wheelPickup = _signal.new() :: _signal.Signal<_cartTypes.wheelComponentInterface, Player>,
	attachRequested = _signal.new() :: _signal.Signal<Player>,
	assemblyComplete = _signal.new() :: _signal.Signal<_cartTypes.cartComponentInterface>,
	pullAttachRequested = _signal.new() :: _signal.Signal<Player, BasePart>,
}

export type cartSignals = typeof(cartSignals)
return cartSignals
