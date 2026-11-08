local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require(ReplicatedStorage.Packages.Component)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local states = require(script.Parent.Parent.states)
local network = require(script.Parent.Parent.network)

local PartyState = states.PartyState
local PartyNetwork = network.PartyNetwork

local ExitButtonComponent = Component.new({ Tag = "ExitButton" })

function ExitButtonComponent:Construct()
	self._scope = Fusion.scoped(Fusion)
	self._button = self.Instance.Button.Hitbox
end

function ExitButtonComponent:Start()
	self._button.Activated:Connect(function()
		self:_onActivated()
	end)

	self._scope:Observer(PartyState.InParty):onChange(function()
		self:_toggleVisibility(Fusion.peek(PartyState.InParty))
	end)

	self:_toggleVisibility(Fusion.peek(PartyState.InParty))
end

function ExitButtonComponent:Stop()
	Fusion.doCleanup(self._scope)
end

function ExitButtonComponent:_toggleVisibility(value: boolean)
	self.Instance.Visible = value
end

function ExitButtonComponent:_onActivated()
	if not Fusion.peek(PartyState.InParty) then
		return
	end
	PartyNetwork.fire("_exitParty")
end

return ExitButtonComponent
