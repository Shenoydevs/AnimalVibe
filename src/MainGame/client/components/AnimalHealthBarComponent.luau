--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)

local _template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UI"):WaitForChild("AnimalHealthBar") :: BillboardGui
local _fillTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local AnimalHealthBarComponent = Component.new({ Tag = "AnimalHealth", Ancestors = { workspace } })

function AnimalHealthBarComponent:Construct()
	self._trove = Trove.new()
	self._character = self.Instance :: Model
end

function AnimalHealthBarComponent:Start()
	local gui: BillboardGui = self._trove:Add(_template:Clone())
	local healthMob = gui:FindFirstChild("healthMob")
	local hpBar = healthMob and healthMob:FindFirstChild("HPBar")
	local fill = hpBar and hpBar:FindFirstChild("Bar%")
	local nameLabel = healthMob and healthMob:FindFirstChild("AnimalName")
	if not (fill and fill:IsA("GuiObject") and nameLabel and nameLabel:IsA("TextLabel")) then
		warn("[AnimalHealthBarComponent] HealthBar template layout unexpected", fill, nameLabel)
		return
	end
	self._fill = fill

	-- The owning player and final name can arrive after the model streams in, so both are kept live
	-- instead of waiting a fixed delay.
	local function updateOwner(): ()
		gui.PlayerToHideFrom = Players:GetPlayerFromCharacter(self._character)
	end
	local function updateName(): ()
		nameLabel.Text = `<b>{string.upper(self._character.Name)}</b> > <i><font size="10">{self._character:GetAttribute("animalClass")}</font></i>`
	end
	updateOwner()
	updateName()
	self._trove:Connect(Players.LocalPlayer:GetPropertyChangedSignal("Character"), updateOwner)
	self._trove:Connect(self._character:GetPropertyChangedSignal("Name"), updateName)

	gui.Adornee = self._character.PrimaryPart
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Enabled = true

	self:_render()
	self._trove:Connect(self._character:GetAttributeChangedSignal("sickness"), function() self:_render() end)
	self._trove:Connect(self._character:GetAttributeChangedSignal("damage"), function() self:_render() end)
	self._trove:Connect(self._character:GetAttributeChangedSignal("hunger"), function() self:_render() end)
	self._trove:Connect(self._character:GetAttributeChangedSignal("thirst"), function() self:_render() end)
	self._trove:Connect(self._character:GetAttributeChangedSignal("weight"), function() self:_render() end)

	gui.Parent = self.Instance
end

function AnimalHealthBarComponent:_render()
	local maxHealth: number = math.max(self._character:GetAttribute("baseStamina"), 1)

	local fraction: number = math.clamp((maxHealth +
	(-self._character:GetAttribute("sickness")
	-self._character:GetAttribute("damage")
	-self._character:GetAttribute("hunger")
	-self._character:GetAttribute("thirst")
	-self._character:GetAttribute("weight"))) / maxHealth, 0, 1)

	TweenService:Create(self._fill, _fillTweenInfo, { Size = UDim2.fromScale(fraction, 1) }):Play()
end

function AnimalHealthBarComponent:Stop()
	self._trove:Clean()
end

return AnimalHealthBarComponent
