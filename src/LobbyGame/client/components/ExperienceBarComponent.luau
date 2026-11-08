--!strict
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Component = require(ReplicatedStorage.Packages.Component)
local LevelingConfig = require(ReplicatedStorage.Common.config.LevelingConfig)
local PlayerState = require(script.Parent.Parent.states.PlayerState)

local _fillTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local ExperienceBarComponent = Component.new({ Tag = "ExperienceBar" })

function ExperienceBarComponent:Construct(): ()
	self._currentLevel = self.Instance.Star.CurrentLevel
	self._xpAmount = self.Instance.XPAmount
	self._fill = self.Instance.Bar.Fill
	self._fillSize = self._fill.Size
	self._fillTween = nil :: Tween?
	self._scope = Fusion.scoped(Fusion)
end

function ExperienceBarComponent:_cancelTween(): ()
	if self._fillTween then
		self._fillTween:Cancel()
		self._fillTween:Destroy()
		self._fillTween = nil
	end
end

function ExperienceBarComponent:_refresh(animate: boolean): ()
	local level = Fusion.peek(PlayerState.Level)
	local xp = Fusion.peek(PlayerState.Xp)
	self._currentLevel.Text = tostring(level)
	self._xpAmount.Text = tostring(xp)

	local ratio = math.clamp(xp / LevelingConfig.xpForLevel(level), 0, 1)
	local size = self._fillSize
	local target = UDim2.new(size.X.Scale * ratio, size.X.Offset * ratio, size.Y.Scale, size.Y.Offset)
	self:_cancelTween()
	if not animate or GuiService.ReducedMotionEnabled then
		self._fill.Size = target
		return
	end
	self._fillTween = TweenService:Create(self._fill, _fillTweenInfo, { Size = target })
	self._fillTween:Play()
end

function ExperienceBarComponent:Start(): ()
	self:_refresh(false)
	self._scope:Observer(PlayerState.Level):onChange(function(): ()
		self:_refresh(true)
	end)
	self._scope:Observer(PlayerState.Xp):onChange(function(): ()
		self:_refresh(true)
	end)
	table.insert(
		self._scope,
		GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function(): ()
			self:_refresh(false)
		end)
	)
end

function ExperienceBarComponent:Stop(): ()
	Fusion.doCleanup(self._scope)
	self:_cancelTween()
	self._fill.Size = self._fillSize
end

return ExperienceBarComponent
