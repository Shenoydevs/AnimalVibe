--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local types = require(ReplicatedStorage.Shared.types)
local utils = script.Parent.Parent.Parent.utils
local HitboxUtils = require(ReplicatedStorage.Shared.utils.HitboxUtils)
local VFXUtils = require(utils.VFXUtils)
local AbilityControl = require(script.Parent.AbilityControl)
local ResourceNodeController = require(script.Parent.Parent.ResourceNodeController)

type NetworkerClient = types.NetworkerClient

local CombatControl = {}

local _character: Model
local _humanoid: Humanoid
local _animalData
local _chosedAnimal: string
local _combatNetworker: NetworkerClient

local _hitboxPart: BasePart
local _attackAnimation: AnimationTrack
local _attackCooldown = 0
local _attackcooldownTimer = tick()
local _attackdamage = 0

function CombatControl:AnimalAttack(): ()
	local blacklist = {}
	HitboxUtils:EnemyHitboxCheck(blacklist, _hitboxPart, _animalData.hitboxData[3], function(caughtEnemies)
		local hitdamage = AbilityControl:Pack(_attackdamage, _character, _chosedAnimal)
		for _, enemyModel in caughtEnemies do
			VFXUtils:DamageFlicker(enemyModel, true)
		end
		_combatNetworker:fire("requestAttack", caughtEnemies)
	end)
	ResourceNodeController:ScanAndChop(_hitboxPart, _animalData.hitboxData[3])
end

function CombatControl:Attack(): ()
	if tick() < _attackcooldownTimer then return end

	_attackcooldownTimer = tick() + _attackCooldown
	_attackAnimation:Play(0)
end

local function setupHitbox(character: Model, animalData): BasePart
	local hitboxSize: Vector3 = animalData.hitboxData[1]
	local hitboxOffset: Vector3 = animalData.hitboxData[2]

	local weld = Instance.new("WeldConstraint")
	local hitbox = game.Workspace.Hitbox:Clone()
	hitbox.Size = hitboxSize
	hitbox.Transparency = 1

	weld.Part0 = character.PrimaryPart
	hitbox.Parent = character
	weld.Parent = hitbox
	hitbox.Anchored = false

	hitbox.CFrame = character:GetPivot() * CFrame.new(hitboxOffset.X, hitboxOffset.Y, hitboxOffset.Z)
	weld.Part1 = hitbox

	return hitbox
end

function CombatControl:Init(character: Model, animalData, chosedAnimal: string, combatNetworker: NetworkerClient): ()
	_character = character
	_humanoid = character:WaitForChild("Humanoid")
	_animalData = animalData
	_chosedAnimal = chosedAnimal
	_combatNetworker = combatNetworker

	_attackCooldown = animalData.attackCooldown
	_attackdamage = animalData.damage
	_attackcooldownTimer = tick()
	_hitboxPart = setupHitbox(character, animalData)

	local attackAnim = Instance.new("Animation")
	attackAnim.AnimationId = `http://www.roblox.com/asset/?id={animalData.attackAnim}`
	_attackAnimation = _humanoid.Animator:LoadAnimation(attackAnim)
	_attackAnimation.Priority = Enum.AnimationPriority.Idle
	_attackAnimation:AdjustWeight(10)
	_attackAnimation:GetMarkerReachedSignal("Hit"):Connect(function()
		self:AnimalAttack()
	end)

	_attackAnimation:Play(0)
end

export type CombatControl = typeof(CombatControl)
return CombatControl
