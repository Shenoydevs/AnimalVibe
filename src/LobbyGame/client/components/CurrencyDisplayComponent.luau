--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Component = require(ReplicatedStorage.Packages.Component)
local PlayerState = require(script.Parent.Parent.states.PlayerState)

local CurrencyDisplayComponent = Component.new({ Tag = "CurrencyDisplay" })

function CurrencyDisplayComponent:Construct(): ()
	self._scope = Fusion.scoped(Fusion)
end

function CurrencyDisplayComponent:Start(): ()
	self._scope:Observer(PlayerState.Coins):onBind(function()
		self.Instance.Text = tostring(Fusion.peek(PlayerState.Coins))
	end)
end

function CurrencyDisplayComponent:Stop(): ()
	Fusion.doCleanup(self._scope)
end

return CurrencyDisplayComponent
