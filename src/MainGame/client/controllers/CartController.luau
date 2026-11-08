--!strict
local _players = game:GetService("Players")
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _runService = game:GetService("RunService")

local _packages = _replicatedStorage.Packages
local _networkerModule = require(_packages.Networker)
local _signal = require(_packages.Signal)
local _troveModule = require(_packages.Trove)

local _characterUtils = require(_replicatedStorage.Shared.utils.CharacterUtils)
local _network = require(_replicatedStorage.Shared.network.CartNetwork)

type networkerClient = _networkerModule.Client

local _trove = _troveModule.new()
local _hoverTrove = _trove:Extend()
local _networker: networkerClient? = nil
local _assemblyRevision: number = -1

local function _getNetworker(): networkerClient
	return assert(_networker, "Cart networking has not started")
end

local cartController = {
	cartAssembled = false :: boolean,
	assemblyChanged = _trove:Add(_signal.new()),
}

function cartController:onWheelPickedUp(wheelPart: BasePart): ()
	_hoverTrove:Clean()

	local player = _players.LocalPlayer
	_hoverTrove:Connect(_runService.Heartbeat, function(): ()
		if not wheelPart:IsDescendantOf(workspace) then
			_hoverTrove:Clean()
			return
		end
		local root: BasePart? = _characterUtils.getPlayerRoot(player)
		if not root then return end
		wheelPart.CFrame = root.CFrame * CFrame.new(0, -0.5, -6)
	end)
end

function cartController:onWheelDropped(): ()
	_hoverTrove:Clean()
end

function cartController:isAssembled(): boolean
	return self.cartAssembled
end

function cartController:onAssemblyChanged(assembled: boolean, revision: number): ()
	if revision <= _assemblyRevision then return end
	_assemblyRevision = revision
	self.cartAssembled = assembled
	self.assemblyChanged:Fire()
end

function cartController:OnStart(): ()
	_networker = _networkerModule.client.new(_network.cart, cartController)

	local assembled, revision = _getNetworker():fetch("getAssemblyState")
	if typeof(assembled) == "boolean" and typeof(revision) == "number" then
		self:onAssemblyChanged(assembled, revision)
	end
end

export type cartController = typeof(cartController)
return cartController
