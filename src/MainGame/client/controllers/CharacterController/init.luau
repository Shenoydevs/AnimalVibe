--!strict
local Players = game:GetService("Players")
local LocalPlayer = game:GetService("Players").LocalPlayer
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Trove = require(Packages.Trove)
local types = require(ReplicatedStorage.Shared.types)
local Network = require(ReplicatedStorage.Shared.network.CharacterNetwork)
local Signals = require(script.Parent.Parent.signals)

local CharacterConfig = require(ReplicatedStorage.Shared.config.CharactersConfig)
local AnimatorControl = require(script.AnimatorControl)
local AbilityControl = require(script.AbilityControl)
local SocialControl = require(script.SocialControl)
local TiltControl = require(script.TiltControl)
local CombatControl = require(script.CombatControl)
local MovementControl = require(script.MovementControl)
local ItemControl = require(script.ItemControl)
local LegIKControl = require(script.LegIKControl)
local FootsoundsControl = require(script.FootsoundsControl)
local DirectionControl = require(script.DirectionControl)

local utils = script.Parent.Parent.utils
local VFXUtils = require(utils.VFXUtils)
local KeybindUtils = require(utils.KeybindUtils)

type NetworkerClient = types.NetworkerClient

local _trove = Trove.new()
local _networker: NetworkerClient
local _combatNetworker: NetworkerClient

local ALIVE, DEAD = 1, 2
local _livingState = ALIVE

local _character: Model
local _humanoid: Humanoid
local _animalData
local _chosedAnimal = ""
local _knockoutAnimation: AnimationTrack
local _deadAnimation: AnimationTrack

local Private = {}
local PrivateCombat = {}

local CharacterController = {}

function CharacterController:OnStart(): ()
	_networker = Networker.client.new(Network.Character, Private)
	_combatNetworker = Networker.client.new(Network.Combat, PrivateCombat)
end

function CharacterController:IsAlive(): boolean
	return _livingState == ALIVE
end

function CharacterController:UnEquipItem(): ()
	ItemControl:UnEquip()
end

function CharacterController:ReceivedDamage(): ()
	Signals.CharacterSignals.DamageReceived:Fire()
	if MovementControl:GetMaxStamina() > 0 then
		return
	end

	if _livingState == ALIVE then
		_livingState = DEAD
		self:HandleDeath()
	end
end

function CharacterController:HandleDeath(): ()
	_knockoutAnimation:Play(0.05)
	_knockoutAnimation:GetMarkerReachedSignal("Dead"):Wait()

	if _livingState ~= DEAD then
		return
	end

	_deadAnimation:Play(0)
end

function CharacterController:Revive(): ()
	_knockoutAnimation:Stop(0)
	_deadAnimation:Stop(0)

	_livingState = ALIVE
	MovementControl:Revive()
	Signals.CharacterSignals.ShowLost:Fire(false)
end

function CharacterController:HandleDebuff(state: string, valueAddSub: number?): ()
	if not _character:GetAttribute(state) then
		return
	end
	MovementControl:UpdateMaxStamina()

	local damageDelivered = state == "damage" and (valueAddSub == nil or valueAddSub > 0)
	if damageDelivered or MovementControl:GetMaxStamina() <= 0 then
		self:ReceivedDamage()
	end
end

function CharacterController:HeartbeatUpdate(dt: number): ()
	if not _character then
		return
	end
	MovementControl:SprintCheck(_humanoid, dt)
	MovementControl:SpeedUpdate(_humanoid, dt, _livingState == DEAD)
end

function CharacterController:SteppedUpdate(dt: number): ()
	if not _character then
		return
	end
	TiltControl:Tick(dt)
	LegIKControl:Tick()
	DirectionControl:Tick(dt)
end

function CharacterController:DebugItem(): ()
	if not RunService:IsStudio() then
		return
	end
	local debugUI = LocalPlayer.PlayerGui:FindFirstChild("DebugItem")
	if not debugUI then
		return
	end

	_trove:Connect(KeybindUtils.getSignal("debugitem"), function(inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			debugUI.Enabled = not debugUI.Enabled
		end
	end)

	for _, item in ReplicatedStorage.Assets.Resources:GetChildren() do
		local templateButton = ReplicatedStorage.Assets.DebugItem:Clone()
		templateButton.Parent = debugUI.Main.List
		templateButton.Text = item.Name

		templateButton.MouseButton1Click:Connect(function()
			_networker:fire("_debugItem", item.Name)
		end)
	end
end

function CharacterController:InitCharacter(chosedAnimal: string): ()
	local player: Player = Players.LocalPlayer
	_character = player.Character
	_animalData = CharacterConfig[chosedAnimal]
	_chosedAnimal = chosedAnimal
	_humanoid = _character:WaitForChild("Humanoid")

	AnimatorControl:Init(_character, _animalData)

	local knockoutAnim = Instance.new("Animation")
	knockoutAnim.AnimationId = `http://www.roblox.com/asset/?id={_animalData.knockoutAnim}`
	local deadAnim = Instance.new("Animation")
	deadAnim.AnimationId = `http://www.roblox.com/asset/?id={_animalData.deadAnim}`

	_knockoutAnimation = _humanoid.Animator:LoadAnimation(knockoutAnim)
	_knockoutAnimation.Priority = Enum.AnimationPriority.Action2

	_deadAnimation = _humanoid.Animator:LoadAnimation(deadAnim)
	_deadAnimation.Priority = Enum.AnimationPriority.Action3

	_knockoutAnimation:Play(0)
	_deadAnimation:Play(0)
	_deadAnimation:Stop(0)

	MovementControl:Init(_character, _animalData)
	LegIKControl:Init(_character, _humanoid)
	FootsoundsControl:Init(_character, _humanoid)
	DirectionControl:Init(_character, _humanoid)
	CombatControl:Init(_character, _animalData, _chosedAnimal, _combatNetworker)
	TiltControl:Init(_character, _networker)
	SocialControl:Init(_character)
	ItemControl:Init(_character, _networker)

	_trove:Connect(KeybindUtils.getSignal("sprint"), function(inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			MovementControl:SetSprintInput(true)
		elseif inputState == Enum.UserInputState.End then
			MovementControl:SetSprintInput(false)
		end
	end)

	_trove:Connect(KeybindUtils.getSignal("call"), function(inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			SocialControl:Call()
		end
	end)

	_trove:Connect(KeybindUtils.getSignal("attack"), function(inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.Begin then
			return
		end
		if not self:IsAlive() then
			return
		end
		if ItemControl:IsMouthFull() or ItemControl:IsItemEquipped() then
			return
		end
		CombatControl:Attack()
	end)

	_trove:Connect(KeybindUtils.getSignal("dropItem"), function(inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			ItemControl:DropItem()
		end
	end)

	local playcd = false
	_trove:Connect(Signals.CharacterSignals.PlayAgainButton, function()
		if playcd then
			return
		end
		playcd = true
		_networker:fire("_playAgain")
		task.wait(3)
		playcd = false
	end)

	_trove:Connect(RunService.Heartbeat, function(deltaTime)
		self:HeartbeatUpdate(deltaTime)
	end)

	_trove:Connect(RunService.Stepped, function(_time, deltaTime)
		self:SteppedUpdate(deltaTime)
	end)

	_trove:Connect(Signals.CharacterSignals.ToggleEquip, function(index, item)
		ItemControl:EquipItem(index, item)
	end)

	local resetEvent = Instance.new("BindableEvent")
	resetEvent.Event:Connect(function()
		local resetPlayer = Players.LocalPlayer
		if resetPlayer.Character and resetPlayer.Character:FindFirstChild("Humanoid") then
			_character:PivotTo(_character:GetPivot() * CFrame.new(0, 5, 0))
		end
	end)

	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	CharacterController:DebugItem()

	if _animalData.passive ~= "None" and AbilityControl[_animalData.passive] then
		AbilityControl[_animalData.passive](_character, _character)
	end

	task.spawn(function()
		while true do
			local success = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", resetEvent)
			end)

			if success then
				break
			end
			task.wait()
		end
	end)
end

Private.ItemVFX = function(_, name, hungerValue, healValue)
	ItemControl:OnItemVFX(name, hungerValue, healValue)
end
Private.ReplicateItem = function(_, player, itemID)
	ItemControl:OnReplicateItem(player, itemID)
end
Private.UpdateTilt = function(_, player, tiltRotation)
	TiltControl:OnUpdateTilt(player, tiltRotation)
end
Private.onAnimalDamaged = function(_, damagedAnimal)
	VFXUtils:OwnDamageFlicker(damagedAnimal, true)
end
Private.InitCharacter = function(_, chosedAnimal: string)
	CharacterController:InitCharacter(chosedAnimal)
end
Private.SetDebuff = function(_, state: string, value: number)
	CharacterController:HandleDebuff(state, value)
end
Private.ModDebuff = function(_, state: string, valueAddSub: number)
	CharacterController:HandleDebuff(state, valueAddSub)
end
Private.Revive = function()
	CharacterController:Revive()
end
Private.ShowLost = function(_, toggle: boolean)
	Signals.CharacterSignals.ShowLost:Fire(toggle)
end
Private.ShowLostALL = function(_, toggle: boolean)
	Signals.CharacterSignals.ShowLostALL:Fire(toggle)
end
Private.ReplayCount = function(_, ready: number, total: number)
	Signals.CharacterSignals.ReplayCountChanged:Fire(ready, total)
end
Private.ReviveAllOffer = function(_, productId: number, returnSeconds: number)
	Signals.CharacterSignals.ReviveAllOffered:Fire(productId, returnSeconds)
end
Private.DownedOffer = function(_, productId: number, reviveSeconds: number, deathSeconds: number)
	Signals.CharacterSignals.DownedOffered:Fire(productId, reviveSeconds, deathSeconds)
end
Private.DiedPermanently = function()
	Signals.CharacterSignals.DiedPermanently:Fire()
end

PrivateCombat.onEnemyDamaged = function(_, damagedEnemies: { Model })
	for _, enemyModel in damagedEnemies do
		VFXUtils:DamageFlicker(enemyModel, true)
	end
end

export type CharacterController = typeof(CharacterController)

return CharacterController
