--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Trove = require(Packages.Trove)

local EntityConfig = require(ReplicatedStorage.Shared.config.EntityConfig)
local Network = require(ReplicatedStorage.Shared.network.CharacterNetwork)
local CharacterUtils = require(ReplicatedStorage.Shared.utils.CharacterUtils)

local Signals = require(ServerScriptService.Server.signals)
local SwingSession = require(ServerScriptService.Server.utils.SwingSession)
local EnemySignals = Signals.EnemySignals

type NetworkerServer = Networker.Server
type Swing = SwingSession.Swing

local _trove = Trove.new()
local _networker: NetworkerServer
local _swings: { [Player]: Swing } = {}

local CombatService = {}

local KNOCKBACK_FORCE = 95
local KNOCKBACK_UPWARD_FORCE = 15

local function _getAttackableHumanoid(target: any): Humanoid?
	if typeof(target) ~= "Instance" or not target:IsA("Model") then return nil end
	if not target:HasTag("Enemy") then return nil end

	local humanoid: Humanoid? = target:FindFirstChildWhichIsA("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	return humanoid
end

local function _applyKnockback(humanoid: Humanoid, direction: Vector3): ()
	local character = humanoid.Parent
	if not character or not character:IsA("Model") then return end

	local root: BasePart? = CharacterUtils.getRoot(character)
	if not root then return end

	local horizontalDirection = Vector3.new(direction.X, 0, direction.Z)
	if horizontalDirection.Magnitude == 0 then return end

	local impulseDirection = horizontalDirection.Unit * KNOCKBACK_FORCE
		+ Vector3.yAxis * KNOCKBACK_UPWARD_FORCE
	root:ApplyImpulse(impulseDirection * root.AssemblyMass)
end

local function _damageAfterReduction(target: Model, damage: number): number
	local entityData = EntityConfig[target:GetAttribute("entityType") :: string]
	return if entityData then damage / entityData.damageReduction else damage
end

local function _resolveEnemy(target: any): (Humanoid?, Vector3?)
	local humanoid: Humanoid? = _getAttackableHumanoid(target)
	if not humanoid then return nil, nil end
	local enemyRoot: BasePart? = CharacterUtils.getRoot(target)
	if not enemyRoot then return nil, nil end
	return humanoid, enemyRoot.Position
end

function CombatService.requestAttack(_self, player: Player, targets: { Model }?): ()
	local swing, attacker = SwingSession.begin(_swings, player, targets)
	if not swing or not attacker then return end
	local attackDirection = attacker.root.CFrame.LookVector

	local damaged: { Model } = {}
	SwingSession.eachHit(swing, attacker, targets :: { any }, _resolveEnemy, function(target: Model, humanoid: Humanoid)
		humanoid:TakeDamage(_damageAfterReduction(target, attacker.damage))
		_applyKnockback(humanoid, attackDirection)
		table.insert(damaged, target)
		EnemySignals.EnemyDamaged:Fire(target, player)
	end)

	if #damaged > 0 then
		_networker:fireAllExcept(player, "onEnemyDamaged", damaged)
	end
end

function CombatService:OnStart(): ()
	_networker = Networker.server.new(Network.Combat, CombatService, { CombatService.requestAttack })

	_trove:Connect(Players.PlayerRemoving, function(player: Player)
		_swings[player] = nil
	end)
end

export type CombatService = typeof(CombatService)
return CombatService
