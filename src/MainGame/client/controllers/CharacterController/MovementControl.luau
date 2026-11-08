--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage.Packages
local Fusion = require(Packages.Fusion)
local states = require(script.Parent.Parent.Parent.states)
local Signals = require(script.Parent.Parent.Parent.signals)

local CharacterState = states.CharacterState

local MovementControl = {}

local _scope = Fusion.scoped(Fusion)
local _camera: Camera = workspace.CurrentCamera
local _springVal = _scope:Value(60)
local _springValue = _scope:Spring(_springVal, 7, 1)

local _character: Model
local _animalData

local _inputingSprinting = false
local _sprinting = false
local _deadMult = 1
local _stamina = 0
local _maxstamina = 0
local _basemaxstamina = 0
local _staminaModifier = 0
local _healthModifier = 0
local _staminaRechargeCooldown = 0
local _speed = 0

local _hunger, _thirst, _damage, _weight, _sickness = 0, 0, 0, 0, 0

local _runningAnimation: AnimationTrack
local _runningVFX: ParticleEmitter?

local _speedInterpolationObj = Instance.new("NumberValue")
_speedInterpolationObj.Value = 0
local _itemslowdownInterpolationObj = Instance.new("NumberValue")
_itemslowdownInterpolationObj.Value = 1
local _slowdownTween: Tween?

function MovementControl:ToggleSprint(toggle: boolean): ()
	if toggle then
		if _sprinting then return end
		TweenService:Create(_speedInterpolationObj, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 }):Play()
		_springVal:set(72)
		_sprinting = true
		_runningAnimation:Play(0.25)
	else
		if not _sprinting then return end
		TweenService:Create(_speedInterpolationObj, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Value = 0 }):Play()
		_springVal:set(60)
		_sprinting = false
		_runningAnimation:Stop(0.5)
		if _runningVFX then _runningVFX.Enabled = false end
	end
end

function MovementControl:SetSprintInput(pressed: boolean): ()
	if pressed then
		_inputingSprinting = true
	else
		_inputingSprinting = false
		if _stamina > 0 then
			_staminaRechargeCooldown = tick() + 0.45
		end
	end
end

function MovementControl:SprintCheck(humanoid: Humanoid, deltaTime: number): ()
	local pullingCart = _character:GetAttribute("pullingCart") == true or _character:GetAttribute("pullingBoulder") == true
	if not pullingCart and _inputingSprinting and humanoid.MoveDirection.Magnitude >= 0.5 and _stamina > 0 then
		_stamina -= (10 * (1 - _staminaModifier)) * deltaTime
		if humanoid.WalkSpeed == 0 then
			self:ToggleSprint(false)
			_staminaRechargeCooldown = tick() + 1
		elseif _stamina <= 0 then
			self:ToggleSprint(false)
			_staminaRechargeCooldown = tick() + 1
			Signals.CharacterSignals.StaminaZeroed:Fire()
		else
			self:ToggleSprint(true)
		end
	elseif pullingCart or (not _inputingSprinting) or (_sprinting and humanoid.MoveDirection.Magnitude <= 0.5) then
		if tick() >= _staminaRechargeCooldown then
			_stamina = math.min(_maxstamina, _stamina + (14 * (1 - _staminaModifier)) * deltaTime)
		end
		self:ToggleSprint(false)
	end

	_stamina = math.clamp(_stamina, 0, _maxstamina)
	_character:SetAttribute("stamina", _stamina)
end

function MovementControl:SpeedUpdate(humanoid: Humanoid, deltaTime: number, isDead: boolean): ()
	local sprintingBoost = _animalData.sprintSpeed - _animalData.walkSpeed
	local sprintBlend = if _character:GetAttribute("pullingCart") == true or _character:GetAttribute("pullingBoulder") == true then 0 else _speedInterpolationObj.Value
	_speed = (_animalData.walkSpeed + (sprintingBoost * sprintBlend)) * _itemslowdownInterpolationObj.Value

	_runningAnimation:AdjustSpeed(_animalData.runningBaseAnimSpeed + (_speedInterpolationObj.Value * 0.9))
	local finalSpeed = math.clamp(_speed, 0, math.huge) * _deadMult
	if isDead and finalSpeed > 0 then
		_deadMult = math.max(_deadMult * 0.945, 0)
	end

	humanoid.WalkSpeed = finalSpeed
	CharacterState.Stamina:set(math.max(_stamina, 0))

	if not _runningVFX then return end
	if _sprinting and _speedInterpolationObj.Value > 0.7 and not _runningVFX.Enabled then
		_runningVFX.Enabled = true
	end
end

function MovementControl:UpdateMaxStamina(): ()
	_damage = _character:GetAttribute("damage")
	_thirst = _character:GetAttribute("thirst")
	_hunger = _character:GetAttribute("hunger")
	_weight = _character:GetAttribute("weight")
	_sickness = _character:GetAttribute("sickness")

	_maxstamina = math.max(_basemaxstamina - (_hunger + _weight + _damage + _thirst + _sickness), 0)
	_stamina = math.clamp(_stamina, 0, _basemaxstamina)

	CharacterState.Damage:set(_damage)
	CharacterState.Hunger:set(_hunger)
	CharacterState.Thirst:set(_thirst)
	CharacterState.Weight:set(_weight)
	CharacterState.Sickness:set(_sickness)
end

function MovementControl:GetMaxStamina(): number
	return _maxstamina
end

function MovementControl:ApplySlowdown(): ()
	if _slowdownTween and _slowdownTween.PlaybackState == Enum.PlaybackState.Playing then
		_slowdownTween:Cancel()
	end
	_itemslowdownInterpolationObj.Value = 0.2
	_sprinting = false
	_slowdownTween = TweenService:Create(_itemslowdownInterpolationObj, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Value = 1 })
	_slowdownTween:Play()
end

function MovementControl:Revive(): ()
	_deadMult = 1
end

function MovementControl:Init(character: Model, animalData): ()
	_character = character
	_animalData = animalData

	_staminaModifier = 1 - animalData.staminaModifier
	_healthModifier = animalData.healthModifier
	_stamina = 100 * _healthModifier
	_maxstamina = 100 * _healthModifier
	_basemaxstamina = _maxstamina
	_speed = animalData.walkSpeed
	_deadMult = 1

	CharacterState.BaseStamina:set(100 * _healthModifier)

	_camera.FieldOfView = 60
	_scope:Hydrate(_camera) {
		FieldOfView = _springValue,
	}

	local runVFXHolder = character.PrimaryPart:WaitForChild("RunVFX", 1)
	_runningVFX = if runVFXHolder then runVFXHolder:WaitForChild("Running", 1) :: ParticleEmitter? else nil
	if not _runningVFX then
		warn(`[MovementControl] {character.Name} is missing RunVFX`)
	end

	local runAnim = Instance.new("Animation")
	runAnim.AnimationId = `http://www.roblox.com/asset/?id={animalData.runningAnim}`
	_runningAnimation = character:WaitForChild("Humanoid").Animator:LoadAnimation(runAnim)
	_runningAnimation.Priority = Enum.AnimationPriority.Idle
end

export type MovementControl = typeof(MovementControl)
return MovementControl
