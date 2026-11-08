--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Networker = require(ReplicatedStorage.Packages.Networker)
local Config = require(ReplicatedStorage.Shared.config.BoulderConfig)
local Session = require(script.Parent.Parent.utils.BoulderPullSession)

local sessions: { [Model]: Session.Session } = {}
local players: { [Player]: Session.Session } = {}
local networker: Networker.Server
local BoulderPullService = {}

local function register(instance: Instance): ()
	if not instance:IsA("Model") or not instance:IsDescendantOf(workspace) or sessions[instance] then return end
	if instance:GetAttribute("cleared") == true then return end
	local session = Session.new(instance, function(player: Player, attached: boolean)
		players[player] = if attached then sessions[instance] else nil
		networker:set(player, "boulder", if attached then instance else nil)
	end)
	sessions[instance] = session
end

function BoulderPullService:releaseRope(player: Player): ()
	local session = players[player]
	if session then session:detach(player) end
end

function BoulderPullService:setPullInput(player: Player, direction: unknown): ()
	if typeof(direction) ~= "Vector3" then return end
	-- Magnitude also rejects NaN, infinity, and oversized input vectors.
	if not (direction.Magnitude <= 1.05) then return end
	local session = players[player]
	if session then session:setInput(player, direction) end
end

function BoulderPullService:OnStart(): ()
	networker = Networker.server.new(Config.network, self, { self.releaseRope, self.setPullInput })
	CollectionService:GetInstanceAddedSignal(Config.tag):Connect(register)
	CollectionService:GetInstanceRemovedSignal(Config.tag):Connect(function(instance: Instance)
		local session = sessions[instance :: Model]
		if session then
			session:destroy()
			sessions[instance :: Model] = nil
		end
	end)
	for _, instance in CollectionService:GetTagged(Config.tag) do register(instance) end
	Players.PlayerRemoving:Connect(function(player: Player) self:releaseRope(player) end)
	RunService.Heartbeat:Connect(function(dt: number)
		for _, session in sessions do session:tick(dt) end
	end)
end

return BoulderPullService
