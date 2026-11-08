--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local GachaTypes = require(ReplicatedStorage.Shared.types.GachaTypes)
local Network = require(ReplicatedStorage.Shared.network)

type SpinResult = GachaTypes.SpinResult
type ActionResult = GachaTypes.ActionResult

local _handlers: { [string]: (...any) -> () } = {}
local _networker = Networker.client.new(Network.Gacha, _handlers)

local Shared = {
	handlers = _handlers,
}

function Shared.spin(lucky: boolean, slot: number): SpinResult
	return _networker:fetch("_spin", lucky, slot)
end

function Shared.equip(slot: number): ActionResult
	return _networker:fetch("_equip", slot)
end

function Shared.leave(): ActionResult
	return _networker:fetch("_leave")
end

return Shared
