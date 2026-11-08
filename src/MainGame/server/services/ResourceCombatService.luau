--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Trove = require(Packages.Trove)

local Network = require(ReplicatedStorage.Shared.network.ResourceNodeNetwork)
local ResourceNodeTypes = require(ReplicatedStorage.Shared.types.ResourceNodeTypes)

local ResourceNodeComponent = require(ServerScriptService.Server.components.ResourceNodeComponent)
local SwingSession = require(ServerScriptService.Server.utils.SwingSession)

type NetworkerServer = Networker.Server
type ResourceNodeComponentInterface = ResourceNodeTypes.ResourceNodeComponentInterface
type Swing = SwingSession.Swing

local _trove = Trove.new()
local _networker: NetworkerServer
local _swings: { [Player]: Swing } = {}

local ResourceCombatService = {}

local function _getHittableNode(target: any): ResourceNodeComponentInterface?
	if typeof(target) ~= "Instance" or not target:IsA("Model") then
		return nil
	end
	if not target:HasTag("ResourceNode") then
		return nil
	end

	local comp: ResourceNodeComponentInterface? = ResourceNodeComponent:FromInstance(target) :: ResourceNodeComponentInterface?
	if not comp or comp:isBroken() then
		return nil
	end
	return comp
end

local function _resolveNode(target: any): (ResourceNodeComponentInterface?, Vector3?)
	local comp: ResourceNodeComponentInterface? = _getHittableNode(target)
	if not comp then return nil, nil end
	return comp, comp:getPosition()
end

function ResourceCombatService.requestChop(_self: unknown, player: Player, targets: { Model }?): ()
	local swing, attacker = SwingSession.begin(_swings, player, targets)
	if not swing or not attacker then return end

	local hit: { Model } = {}
	local broken: { Model } = {}
	SwingSession.eachHit(swing, attacker, targets :: { any }, _resolveNode, function(target: Model, comp: ResourceNodeComponentInterface)
		local _crossedMid, brokeNow = comp:hit(player, attacker.damage)
		table.insert(hit, target)
		if brokeNow then
			table.insert(broken, target)
		end
	end)

	if #hit > 0 then
		_networker:fireAllExcept(player, "onResourceNodeHit", hit)
	end
	if #broken > 0 then
		_networker:fireAllExcept(player, "onResourceNodeBroken", broken)
	end
end

function ResourceCombatService:OnStart(): ()
	_networker = Networker.server.new(Network.ResourceNode, ResourceCombatService, { ResourceCombatService.requestChop })

	_trove:Connect(Players.PlayerRemoving, function(player: Player)
		_swings[player] = nil
	end)
end

export type ResourceCombatService = typeof(ResourceCombatService)
return ResourceCombatService
