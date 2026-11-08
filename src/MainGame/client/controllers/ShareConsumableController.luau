--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Signals = require(script.Parent.Parent.signals)
local Trove = require(Packages.Trove)

local _shareEnabled: boolean = false
local _trove = Trove.new()

local ShareConsumableController = {}

function ShareConsumableController:ToggleOnUseAnimals(toggle : boolean): ()
	if toggle == _shareEnabled then return end
	for _,char in game.Workspace.Map.Players:GetChildren() do
		if char.Name == Players.LocalPlayer.Character.Name then continue end
		if not char:GetAttribute("canRevive") then char.PrimaryPart.ProximityPrompt.Enabled = false continue end
		char.PrimaryPart.ProximityPrompt.Enabled = toggle
	end
	_shareEnabled = toggle
end

function ShareConsumableController:OnStart(): ()
	_trove:Connect(Signals.CharacterSignals.UpdateShareable, function(val)
		ShareConsumableController:ToggleOnUseAnimals(val)
	end)
end

export type ShareConsumableController = typeof(ShareConsumableController)
return ShareConsumableController
