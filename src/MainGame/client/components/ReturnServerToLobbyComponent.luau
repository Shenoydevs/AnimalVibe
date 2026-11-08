local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require(ReplicatedStorage.Packages.Component)
local Signals = require(script.Parent.Parent.signals)

local ReturnServerToLobbyComponent = Component.new({ Tag = "PlayAgainButton" })

function ReturnServerToLobbyComponent:Construct()
	local button = self.Instance:IsA("ImageButton") and self.Instance or self.Instance:FindFirstChild("Hitbox", true)
	self._button = button
end

function ReturnServerToLobbyComponent:Start()
	self._button.Activated:Connect(function()
		self:_onActivated()
	end)
end

function ReturnServerToLobbyComponent:Stop() end

function ReturnServerToLobbyComponent:_onActivated()
	Signals.CharacterSignals.PlayAgainButton:Fire()
end

return ReturnServerToLobbyComponent
