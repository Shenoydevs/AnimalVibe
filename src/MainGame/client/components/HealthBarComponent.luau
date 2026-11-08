local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Shake = require(ReplicatedStorage.Packages.Shake)
local states = require(script.Parent.Parent.states)
local Signals = require(script.Parent.Parent.signals)

local player = Players.LocalPlayer
local CharacterState = states.CharacterState

local HealthBarComponent = Component.new({ Tag = "HealthBar", Ancestors = { player }})

local _damp = 0.65
local _speed = 12

function HealthBarComponent:Construct()
	self._scope = Fusion.scoped(Fusion)
	self._trove = Trove.new()

	self._stamina = 100
	self._maxStamina = 100
	self._shake = nil
	-- Depends on BaseStamina so the ratio recomputes when max stamina changes.
	self._totalstaminaRatio = self._scope:Computed(function(use)
		local maxStamina = math.max(use(CharacterState.BaseStamina), 1)
		local debuffs = use(CharacterState.Hunger) + use(CharacterState.Thirst) + use(CharacterState.Damage) + use(CharacterState.Weight) + use(CharacterState.Sickness)
		return (maxStamina - debuffs) / maxStamina
	end)

	self._statsSprings = {
		healthSize = self._scope:Spring(self._totalstaminaRatio, _speed, _damp),
		staminaSize = self._scope:Spring(self._scope:Computed(function(use)
			return math.clamp(use(CharacterState.Stamina)/(self._maxStamina*use(self._totalstaminaRatio)),0,1)
		end), 15, 0.75),
		hunger = self._scope:Spring(CharacterState.Hunger, _speed, _damp),
		thirst = self._scope:Spring(CharacterState.Thirst, _speed, _damp),
		damage = self._scope:Spring(CharacterState.Damage, _speed, _damp),
		weight = self._scope:Spring(CharacterState.Weight, _speed, _damp),
		sickness = self._scope:Spring(CharacterState.Sickness, _speed, _damp)
	}

	self._staminaBar = self.Instance.HPBar :: Frame
	self._damageBar = self.Instance.RedBar :: Frame
	self._hungerBar = self.Instance.HungerBar :: Frame
	self._thirstBar = self.Instance.ThirstBar :: Frame
	self._weightBar = self.Instance.WeightBar :: Frame
	self._sicknessBar = self.Instance.SicknessBar :: Frame
	self._healthBar = self.Instance.Parent

	self._healthinitPosition = self._healthBar.Position
end

function HealthBarComponent:Start()	
	self._scope:Hydrate(self._staminaBar) {
		Name = "HealthBar",
		Size = self._scope:Computed(function(use) return UDim2.fromScale(math.max(use(self._statsSprings.healthSize),0), 1) end),
		Visible = self._scope:Computed(function(use)
			return use(self._statsSprings.healthSize) > 0
		end)
	}

	self._scope:Hydrate(self._staminaBar.Bar) {
		Name = "StaminaBar",
		Size = self._scope:Computed(function(use) return UDim2.fromScale(use(self._statsSprings.staminaSize), 1) end)
	}

	self._scope:Hydrate(self._damageBar) {
		Name = "RedBar",
		Size = self._scope:Computed(function(use) return UDim2.fromScale(use(self._statsSprings.damage)/self._maxStamina, 1) end),
		Visible = self._scope:Computed(function(use)
			return use(CharacterState.Damage) > 0
		end)
	}

	self._scope:Hydrate(self._hungerBar) {
		Name = "OrangeBar",
		Size = self._scope:Computed(function(use) return UDim2.fromScale(use(self._statsSprings.hunger)/self._maxStamina, 1) end),
		Visible = self._scope:Computed(function(use)
			return use(CharacterState.Hunger) > 0
		end)
	}

	self._scope:Hydrate(self._thirstBar) {
		Name = "BlueBar",
		Size = self._scope:Computed(function(use) return UDim2.fromScale(use(self._statsSprings.thirst)/self._maxStamina, 1) end),
		Visible = self._scope:Computed(function(use)
			return use(CharacterState.Thirst) > 0
		end)
	}
	
	self._scope:Hydrate(self._weightBar) {
		Name = "BrownBar",
		Size = self._scope:Computed(function(use) return UDim2.fromScale(use(self._statsSprings.weight)/self._maxStamina, 1) end),
		Visible = self._scope:Computed(function(use)
			return use(CharacterState.Weight) > 0
		end)
	}

	self._scope:Hydrate(self._sicknessBar) {
		Name = "SicknessBar",
		Size = self._scope:Computed(function(use) return UDim2.fromScale(use(self._statsSprings.sickness)/self._maxStamina, 1) end),
		Visible = self._scope:Computed(function(use)
			return use(CharacterState.Sickness) > 0
		end)
	}

	self._trove:Connect(Signals.CharacterSignals.DamageReceived, function()
		self:ShakeHealthBar(0,1,0.1,0.2,-0.2)
	end)

	self._trove:Connect(Signals.CharacterSignals.StaminaZeroed, function()
		self:ShakeHealthBar(0,1,0.1,0.1,0)
	end)

	CharacterState.Stamina:set(self._stamina)
	self._scope:Observer(CharacterState.BaseStamina):onBind(function() local stm = Fusion.peek(CharacterState.BaseStamina) self._stamina = stm self._maxStamina = stm CharacterState.Stamina:set(self._stamina) end)

	self.Instance.Visible = true
end

function HealthBarComponent:ShakeHealthBar(fadeIn, fadeOut, freq, amplitude, times)
	local priority = Enum.RenderPriority.Last.Value

	-- Only one shake drives the bar at a time; a new hit replaces the running one.
	if self._shake then
		self._shake:Stop()
		self._healthBar.Position = self._healthinitPosition
	end
	local shake = Shake.new()
	self._shake = shake
	shake.FadeInTime = fadeIn
	shake.FadeOutTime = fadeOut
	shake.Frequency = freq
	shake.Amplitude = amplitude
	shake.SustainTime = times

	shake:Start()
	shake:BindToRenderStep(Shake.NextRenderName(), priority, function(pos: Vector3, rot: Vector3)
		self._healthBar.Position = UDim2.fromScale(self._healthinitPosition.X.Scale + pos.X,self._healthinitPosition.Y.Scale + pos.Z)
	end)
end

function HealthBarComponent:Stop()
	if self._shake then
		self._shake:Stop()
		self._shake = nil
		self._healthBar.Position = self._healthinitPosition
	end
	self.Instance.Visible = false
	self._trove:Clean()
	Fusion.doCleanup(self._scope)
end

return HealthBarComponent