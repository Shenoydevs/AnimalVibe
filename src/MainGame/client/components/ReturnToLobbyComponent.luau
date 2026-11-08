local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Component = require(ReplicatedStorage.Packages.Component)
local PlaceConfig = require(ReplicatedStorage.Common.config.PlaceConfig)

local _player = Players.LocalPlayer

local ReturnToLobbyComponent = Component.new({ Tag = "ReturnToLobby" })

function ReturnToLobbyComponent:Construct()
	local button = self.Instance:IsA("ImageButton") and self.Instance or self.Instance:FindFirstChild("Hitbox", true)
	self._button = button
end

function ReturnToLobbyComponent:Start()
	self._button.Activated:Connect(function()
		self:_onActivated()
	end)
end

function ReturnToLobbyComponent:Stop() end

function ReturnToLobbyComponent:_onActivated()
	-- TeleportAsync is server-only; Teleport is the client-side call.
	TeleportService:Teleport(PlaceConfig.lobbyId, _player)
end

return ReturnToLobbyComponent
