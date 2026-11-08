--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Signals = require(script.Parent.Parent.signals)

local player = Players.LocalPlayer

local LoseScreenComponent = Component.new({ Tag = "LoseScreen", Ancestors = { player }})

-- Counts down once per second from `seconds` to 0, then calls `onDone`. Cleaning `trove` stops it.
local function _countdown(trove: typeof(Trove.new()), seconds: number, onTick: (number) -> (), onDone: (() -> ())?): ()
	trove:Add(task.spawn(function()
		for remaining = math.max(math.floor(seconds), 0), 0, -1 do
			onTick(remaining)
			task.wait(1)
		end
		if onDone then
			onDone()
		end
	end))
end

function LoseScreenComponent:Construct()
	self._scope = Fusion.scoped(Fusion)
	self._trove = Trove.new()
	self._downedTrove = self._trove:Extend()
	self._returningTrove = self._trove:Extend()

	self.UILostGame = self.Instance.ContentLost
	self.UILostMe = self.Instance.ContentLostMe

	self._playAgainLabel = self.UILostGame.Buttons.PlayAgainBTN.BTNTilte
	self._reviveAllButton = self.UILostGame.Buttons.ReviveEveryoneBTN
	self._returningTimer = self.UILostGame.ReturningTimer
	self._reviveMeButton = self.UILostMe.Buttons.ReviveEveryoneBTN
	self._deathTimer = self.UILostMe.DeathTimer
	self._deathBar = self.UILostMe.DeathTimer.DeathHolder.Bar
end

function LoseScreenComponent:Start()
	self._trove:Connect(Signals.CharacterSignals.ShowLost, function(toggle : boolean)
		if not toggle then
			self._downedTrove:Clean()
		end
		self.UILostMe.DiedBase.Visible = false
		self.UILostMe.DownedBase.Visible = true
		self.UILostMe.Visible = toggle
	end)

	self._trove:Connect(Signals.CharacterSignals.ShowLostALL, function(toggle : boolean)
		if not toggle then
			self._returningTrove:Clean()
		end
		self.UILostGame.Visible = toggle
		self.Instance.Parent.Parent.Background.Enabled = if toggle then true else false

		self.Instance.Parent.GameHud.Visible = if toggle then false else true
		self.Instance.Parent.HudCompass.Visible = if toggle then false else true
	end)

	self._trove:Connect(Signals.CharacterSignals.ReplayCountChanged, function(ready: number, total: number)
		self._playAgainLabel.Text = `PLAY AGAIN WITH THE SAME TEAM [{ready}/{total}]`
	end)

	self._trove:Connect(Signals.CharacterSignals.ReviveAllOffered, function(productId: number, returnSeconds: number)
		self._returningTrove:Clean()
		self._reviveAllButton:SetAttribute("Id", productId)
		_countdown(self._returningTrove, returnSeconds, function(remaining: number)
			self._returningTimer.Text = `RETURNING IN {remaining} SECONDS`
		end)
	end)

	self._trove:Connect(Signals.CharacterSignals.DownedOffered, function(productId: number, reviveSeconds: number, deathSeconds: number)
		self._downedTrove:Clean()

		local button = self._reviveMeButton
		button:SetAttribute("Id", productId)
		button.Visible = true
		_countdown(self._downedTrove, reviveSeconds, function(remaining: number)
			button.BTNTilte.Text = `Revive - {remaining}s`
		end, function()
			button.Visible = false
		end)

		self._deathTimer.Visible = true
		self._deathBar.Size = UDim2.fromScale(1, 1)
		local tween = TweenService:Create(self._deathBar, TweenInfo.new(deathSeconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
		self._downedTrove:Add(function()
			tween:Cancel()
			tween:Destroy()
		end)
		tween:Play()
	end)

	self._trove:Connect(Signals.CharacterSignals.DiedPermanently, function()
		self._downedTrove:Clean()
		self.UILostMe.DiedBase.Visible = true
		self.UILostMe.DownedBase.Visible = false
		self._deathTimer.Visible = false
	end)

	self.Instance.Visible = true
end

function LoseScreenComponent:Stop()
	self.Instance.Visible = false
	self._trove:Clean()
	Fusion.doCleanup(self._scope)
end

return LoseScreenComponent
