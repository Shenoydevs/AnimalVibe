--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)

local EnemyConfig = require(ReplicatedStorage.Shared.config.EnemyConfig)
local EntityConfig = require(ReplicatedStorage.Shared.config.EntityConfig)

local _template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UI"):WaitForChild("EnemyHealthBar") :: BillboardGui
local _fillTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Floating HP bar above each hostile. Client-only: it reads the Humanoid's
-- replicated Health/MaxHealth, so there is no server or network work.
local EnemyHealthBarComponent = Component.new({ Tag = "Enemy", Ancestors = { workspace } })

function EnemyHealthBarComponent:Construct()
	self._trove = Trove.new()
	self._entityType = self.Instance:GetAttribute("entityType") :: string? or "Normal Hunter"

	local entityData = EntityConfig[self._entityType]
	self._maxHealth = if entityData then entityData.health else 100
end

function EnemyHealthBarComponent:Start()
	local humanoid: Humanoid? = self.Instance:WaitForChild("Humanoid", 5) :: Humanoid?
	local head: BasePart? = self.Instance:WaitForChild("Head", 5) :: BasePart?
	if not humanoid or not head then
		warn(`[EnemyHealthBarComponent] {self.Instance.Name}: missing Humanoid/Head, no health bar`)
		return
	end
	self._humanoid = humanoid

	local gui: BillboardGui = self._trove:Add(_template:Clone())
	local healthMob = gui:FindFirstChild("healthMob")
	local hpBar = healthMob and healthMob:FindFirstChild("HPBar")
	local fill = hpBar and hpBar:FindFirstChild("Bar%")
	local nameLabel = healthMob and healthMob:FindFirstChild("Name")
	if not (fill and fill:IsA("GuiObject") and nameLabel and nameLabel:IsA("TextLabel")) then
		warn("[EnemyHealthBarComponent] HealthBar template layout unexpected", fill, nameLabel)
		return
	end
	self._fill = fill

	gui.Adornee = head
	gui.StudsOffset = Vector3.new(0, EnemyConfig.healthBar.studsOffsetY, 0)
	gui.MaxDistance = EnemyConfig.healthBar.maxDistance
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Enabled = true
	nameLabel.Text = EnemyConfig.displayNames[self._entityType] or self._entityType

	self:_render()
	self._trove:Connect(humanoid.HealthChanged, function()
		self:_render()
	end)
	self._trove:Connect(humanoid:GetPropertyChangedSignal("MaxHealth"), function()
		self._maxHealth = humanoid.MaxHealth
		self:_render()
	end)

	gui.Parent = self.Instance
end

function EnemyHealthBarComponent:_render()
	local humanoid: Humanoid? = self._humanoid
	if not humanoid then return end

	local maxHealth: number = math.max(self._maxHealth, 1)
	local fraction: number = math.clamp(humanoid.Health / maxHealth, 0, 1)

	TweenService:Create(self._fill, _fillTweenInfo, { Size = UDim2.fromScale(fraction, 1) }):Play()
end

function EnemyHealthBarComponent:Stop()
	self._trove:Clean()
end

return EnemyHealthBarComponent
