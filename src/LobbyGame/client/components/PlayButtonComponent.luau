local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require(ReplicatedStorage.Packages.Component)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local states = require(script.Parent.Parent.states)

local PartyState = states.PartyState

local player = Players.LocalPlayer

local PlayButtonComponent = Component.new({ Tag = "PlayButton" })

function PlayButtonComponent:Construct()
	self._targetCFrame = workspace.Zones.ZoneEntry.CFrame
	self._scope = Fusion.scoped(Fusion)

	self._button = self.Instance.Button.Hitbox
end

function PlayButtonComponent:Start()
	table.insert(
		self._scope,
		self._button.Activated:Connect(function()
			self:_onActivated()
		end)
	)

	self._scope:Observer(PartyState.InParty):onChange(function()
		self:_toggleVisibility(Fusion.peek(PartyState.InParty))
	end)

	self:_toggleVisibility(Fusion.peek(PartyState.InParty))
end

function PlayButtonComponent:Stop()
	Fusion.doCleanup(self._scope)
end

function PlayButtonComponent:_toggleVisibility(value)
	self.Instance.Visible = not value
end

function PlayButtonComponent:_onActivated()
	local character = player.Character
	if not character then
		return
	end

	character:PivotTo(self._targetCFrame)
end

return PlayButtonComponent
