--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Networker = require(ReplicatedStorage.Packages.Networker)
local Config = require(ReplicatedStorage.Shared.config.BoulderConfig)
local KeybindUtils = require(script.Parent.Parent.utils.KeybindUtils)

local player = Players.LocalPlayer
local networker: Networker.Client
local BoulderPullController = { boulder = nil :: Model? }

local function release(): ()
	if BoulderPullController.boulder then networker:fire("releaseRope") end
end

function BoulderPullController:OnStart(): ()
	networker = Networker.client.new(Config.network, self)
	KeybindUtils.getSignal("releaseRope"):Connect(function(state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then release() end
	end)
	UserInputService.JumpRequest:Connect(release)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < Config.pullInputInterval then return end
		elapsed = 0
		local boulder = self.boulder
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not boulder then return end
		networker:fire("setPullInput", if humanoid then humanoid.MoveDirection else Vector3.zero)
	end)
end

return BoulderPullController
