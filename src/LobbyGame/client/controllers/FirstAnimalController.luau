--!strict
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DataService = require(ReplicatedStorage.Packages.DataService).client
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Trove = require(ReplicatedStorage.Packages.Trove)
local states = require(script.Parent.Parent.states)
local utils = require(script.Parent.Parent.utils)
local FirstAnimalNetwork = require(script.Parent.Parent.network.FirstAnimalNetwork)
local AnimalConfig = require(ReplicatedStorage.Common.config.AnimalConfig)
local AnimalShopConfig = require(ReplicatedStorage.Shared.config.AnimalShopConfig)

local FirstAnimalState = states.FirstAnimalState
local PopupUtils = utils.PopupUtils
local AnimalSlot = ReplicatedStorage.Assets.GUIs.FirstAnimal.AnimalSlot

local _player = Players.LocalPlayer
local _firstAnimalGui = _player.PlayerGui:WaitForChild("FirstAnimalGui")

local _wrapper = _firstAnimalGui.Wrapper
local _content = _wrapper.Content
local _elements = _wrapper.Elements
local _selectContainer = _content.SelectContainer
local _confirmButton = _content.ConfirmButton
local _hint = _content.TitleText
local _revealScale = 0.82

local _scope = Fusion.scoped(Fusion)
-- Fusion ignores velocity kicks on a constant spring goal, so the shake follows a state.
local _confirmShake = _scope:Spring(_scope:Value(_confirmButton.Rotation), 34, 0.22)
local _trove = Trove.new()
local _confirming = false

local Private = {}
local Shared = {}

function Private._followCharacter(character)
	if not character:GetAttribute("animalName") then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if humanoid and camera and _player.Character == character then
		camera.CameraSubject = humanoid
	end
end

-- The reassurance line fades in once the animals have arrived.
function Private._revealHint()
	local transparency = _hint.TextTransparency
	if GuiService.ReducedMotionEnabled then
		return
	end
	_hint.TextTransparency = 1
	local tween = TweenService:Create(
		_hint,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.45),
		{ TextTransparency = transparency }
	)
	_trove:Add(function()
		tween:Cancel()
		_hint.TextTransparency = transparency
	end)
	tween:Play()
end

function Private._open()
	_trove:Connect(_confirmButton.Activated, Private._onConfirm)
	_confirmButton:SetAttribute("buttonRevealDelay", 0.38)
	_confirmButton:SetAttribute("buttonRevealScale", _revealScale)

	for name, config in AnimalConfig do
		if AnimalShopConfig[name] and AnimalShopConfig[name].starter then
			Private._createSlot(name, config)
		end
	end

	local equippedAnimal = DataService:get({ "Inventory", "EquippedAnimal" })
	local equippedSlot = _selectContainer:FindFirstChild(equippedAnimal)
	if equippedSlot then
		FirstAnimalState.SelectedAnimal:set(equippedSlot)
	end

	PopupUtils.ShowPopup(_firstAnimalGui)
	Private._revealHint()
end

function Private._onConfirm()
	local selectedAnimal = Fusion.peek(FirstAnimalState.SelectedAnimal)
	if not selectedAnimal or _confirming then
		return
	end

	_confirming = true
	_confirmButton.Interactable = false
	_confirmButton.TitleText.Text = "SAVING..."
	local success, result = pcall(FirstAnimalNetwork.confirm, selectedAnimal.Name)
	_confirming = false
	_confirmButton.Interactable = true
	if not success or (result.status ~= "selected" and result.status ~= "alreadySelected") then
		_confirmButton.TitleText.Text = "TRY AGAIN"
		if not GuiService.ReducedMotionEnabled then
			_confirmShake:addVelocity(260)
		end
		return
	end

	_confirmButton.TitleText.Text = "CONFIRM"
	local closing = PopupUtils.HidePopup(_firstAnimalGui)
	if closing then
		closing:finally(function()
			FirstAnimalState.SelectedAnimal:set(nil)
			_trove:Clean()
		end)
	else
		FirstAnimalState.SelectedAnimal:set(nil)
		_trove:Clean()
	end
end

function Private._createSlot(name, config)
	local slot = _trove:Clone(AnimalSlot)
	local content = slot.Content
	local bars = slot.Stats.bars

	slot.Name = name
	slot.LayoutOrder = AnimalShopConfig[name].order
	content.Icon.Image = `rbxassetid://{config.icon}`
	content.DisplayName.Text = string.upper(config.displayName)
	slot.SelectButton:SetAttribute("buttonRevealDelay", 0.16 + (slot.LayoutOrder - 1) * 0.07)
	slot.SelectButton:SetAttribute("buttonRevealScale", _revealScale)

	Private._setupStatBar(bars.health, config.health, 100)
	Private._setupStatBar(bars.damage, config.damage, 100)
	Private._setupStatBar(bars.walkSpeed, config.walkSpeed, 100)

	slot.Parent = _selectContainer
end

function Private._setupStatBar(bar, value, maxValue)
	local percentage = (value / maxValue)

	bar.BarProg.Text = `{percentage * 100}%`
	bar.Background.Fill.Size = UDim2.fromScale(percentage, 1)
end

function Shared.OnStart()
	_scope:Hydrate(_confirmButton)({ Rotation = _confirmShake })
	PopupUtils.BindHeader(_wrapper)
	_player.CharacterAdded:Connect(Private._followCharacter)
	if _player.Character then
		Private._followCharacter(_player.Character)
	end
	DataService:waitForData()
	if not DataService:get({ "Inventory", "HasSelectedFirstAnimal" }) then
		Private._open()
	end
end

return Shared
