--!strict
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DataService = require(ReplicatedStorage.Packages.DataService).client
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ChallengeConfig = require(ReplicatedStorage.Shared.config.ChallengeConfig)
local ChallengeTypes = require(ReplicatedStorage.Shared.types.ChallengeTypes)
local PopupUtils = require(script.Parent.Parent.utils.PopupUtils)
local ChallengeCard = require(script.ChallengeCard)

type Category = ChallengeTypes.Category
type Card = ChallengeCard.Card

local _urgentTimer = Color3.fromRGB(255, 196, 120)
local _colorTween = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local _shimmerInterval = 3.2

local _scope = Fusion.scoped(Fusion)
local _progress = _scope:Value({} :: { [string]: number })
local _category = _scope:Value("weekly" :: Category)
local _reducedMotion = _scope:Value(GuiService.ReducedMotionEnabled)
local _colorInfo = _scope:Computed(function(use): TweenInfo
	return if use(_reducedMotion) then TweenInfo.new(0) else _colorTween
end)
local _resetAt: number = 0
local _cards: { Card } = {}

local Private = {}
local Shared = {}

function Private._readData(): ()
	local challenges = DataService:get({ "Challenges" })
	_resetAt = challenges.Timer
	-- The data package mutates nested paths in place; Fusion owns its snapshot.
	_progress:set(table.clone(challenges.Progress))
end

-- Springs a runtime UIScale back to its authored size of 1.
function Private._pop(scale: UIScale, from: number, duration: number, style: Enum.EasingStyle): ()
	if GuiService.ReducedMotionEnabled then
		scale.Scale = 1
		return
	end
	scale.Scale = from
	local tween = TweenService:Create(scale, TweenInfo.new(duration, style, Enum.EasingDirection.Out), { Scale = 1 })
	tween.Completed:Once(function(): ()
		tween:Destroy()
	end)
	tween:Play()
end

-- Authored gradients are single-colour sequences, so a Color3 tween reproduces them at rest.
function Private._sequence(color: Fusion.UsedAs<Color3>): Fusion.StateObject<ColorSequence>
	local tween = _scope:Tween(color, _colorInfo)
	return _scope:Computed(function(use): ColorSequence
		return ColorSequence.new(use(tween))
	end)
end

function Private._bindGui(): ()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("ChallengeGui") :: ScreenGui
	local wrapper = gui:WaitForChild("Wrapper") :: Frame
	local content = wrapper:WaitForChild("Content")
	local elements = wrapper:WaitForChild("Elements")
	local tabs = content:WaitForChild("Weekly/Milestones")
	local weeklyButton = tabs:WaitForChild("WeeklyBTN") :: ImageButton
	local milestoneButton = tabs:WaitForChild("MilestonesBTN") :: ImageButton
	local weeklyGradient = weeklyButton.Base:FindFirstChildOfClass("UIGradient") :: UIGradient
	local milestoneGradient = milestoneButton:FindFirstChildOfClass("UIGradient") :: UIGradient
	local selectedColor = weeklyGradient.Color.Keypoints[1].Value
	local idleColor = milestoneGradient.Color.Keypoints[1].Value
	local glowTransparency = weeklyButton.ImageTransparency
	_scope:Hydrate(weeklyButton)({
		ImageTransparency = _scope:Tween(
			_scope:Computed(function(use): number
				return if use(_category) == "weekly" then glowTransparency else 1
			end),
			_colorInfo
		),
	})
	_scope:Hydrate(weeklyGradient)({
		Color = Private._sequence(_scope:Computed(function(use): Color3
			return if use(_category) == "weekly" then selectedColor else idleColor
		end)),
	})
	_scope:Hydrate(milestoneGradient)({
		Color = Private._sequence(_scope:Computed(function(use): Color3
			return if use(_category) == "milestone" then selectedColor else idleColor
		end)),
	})
	local timer = weeklyButton:WaitForChild("ResetTimer") :: TextLabel
	local timerColor = timer.TextColor3
	local timerScale = Instance.new("UIScale")
	timerScale.Parent = timer
	local divider = elements:WaitForChild("DividerLine") :: ImageLabel
	local dividerGradient = divider:FindFirstChildOfClass("UIGradient") :: UIGradient
	local dividerOffset = dividerGradient.Offset
	local dividerTween: Tween? = nil
	local scroll = content:WaitForChild("Slots"):WaitForChild("Slots") :: ScrollingFrame
	local slots: { Frame } = {}
	for _, child in scroll:GetChildren() do
		if child:IsA("Frame") and child.Name == "Slot" then
			table.insert(slots, child)
		end
	end
	for order, frame in slots do
		local challenge = ChallengeConfig[order]
		if challenge then
			frame.Name = challenge.id
			frame.LayoutOrder = order
			_scope:Hydrate(frame)({
				Visible = _scope:Computed(function(use): boolean
					return use(_category) == challenge.category
				end),
			})
			table.insert(
				_cards,
				ChallengeCard.bind(_scope, frame, challenge, _progress, wrapper, _reducedMotion, _colorInfo)
			)
		else
			frame.Visible = false
		end
	end

	local function reveal(direction: number): ()
		local order = 0
		for _, card in _cards do
			ChallengeCard.reveal(card, direction, math.min(order * 0.035, 0.16))
			if card.frame.Visible then
				order += 1
			end
		end
	end
	local labelScales: { [Category]: UIScale } = {}
	local function selectCategory(category: Category): ()
		if Fusion.peek(_category) == category then
			return
		end
		_category:set(category)
		scroll.CanvasPosition = Vector2.zero
		Private._pop(labelScales[category], 0.82, 0.32, Enum.EasingStyle.Back)
		reveal(if category == "weekly" then -1 else 1)
	end
	for _, entry in
		{ { button = weeklyButton, category = "weekly" }, { button = milestoneButton, category = "milestone" } }
	do
		local label: TextLabel = entry.button.BtnLabel
		local transparency = label.TextTransparency
		local labelScale = Instance.new("UIScale")
		labelScale.Parent = label
		labelScales[entry.category :: Category] = labelScale
		_scope:Hydrate(label)({
			TextTransparency = _scope:Tween(
				_scope:Computed(function(use): number
					return if use(_category) == entry.category then transparency else 0.45
				end),
				_colorInfo
			),
		})
		entry.button.Activated:Connect(function(): ()
			selectCategory(entry.category :: Category)
		end)
	end

	local function updateTimer(): ()
		local remaining = math.max(0, math.ceil(_resetAt - workspace:GetServerTimeNow()))
		local days = math.floor(remaining / 86400)
		local hours = math.floor(remaining % 86400 / 3600)
		local minutes = math.floor(remaining % 3600 / 60)
		local urgent = remaining < 86400
		timer.Text = `RESETS IN {days}D {hours}H {minutes}M {remaining % 60}S`
		-- The last day before reset reads warmer and ticks harder.
		timer.TextColor3 = if urgent then _urgentTimer else timerColor
		if wrapper.Visible then
			Private._pop(timerScale, if urgent then 1.1 else 1.04, 0.3, Enum.EasingStyle.Quad)
		end
	end
	task.spawn(function(): ()
		while true do
			updateTimer()
			task.wait(1)
		end
	end)
	task.spawn(function(): ()
		while true do
			task.wait(_shimmerInterval)
			if not wrapper.Visible or GuiService.ReducedMotionEnabled then
				continue
			end
			local order = 0
			for _, card in _cards do
				if ChallengeCard.visible(card) and Fusion.peek(card.complete) then
					ChallengeCard.sweep(card, order * 0.12)
					order += 1
				end
			end
		end
	end)

	wrapper:GetPropertyChangedSignal("Visible"):Connect(function(): ()
		reveal(0)
		if dividerTween then
			dividerTween:Cancel()
			dividerTween:Destroy()
			dividerTween = nil
		end
		dividerGradient.Offset = dividerOffset
		if not wrapper.Visible or GuiService.ReducedMotionEnabled then
			return
		end
		-- The divider's authored highlights slide into place as the panel opens.
		dividerGradient.Offset = dividerOffset - Vector2.new(1, 0)
		local tween = TweenService:Create(
			dividerGradient,
			TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, false, 0.1),
			{ Offset = dividerOffset }
		)
		dividerTween = tween
		tween:Play()
	end)
	GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function(): ()
		_reducedMotion:set(GuiService.ReducedMotionEnabled)
		for _, card in _cards do
			ChallengeCard.settle(card)
			if GuiService.ReducedMotionEnabled then
				-- Settling stops any pending count-up, so the shown count jumps to the real one.
				card.shown:set(Fusion.peek(card.count))
			end
		end
	end)
	local closeButton: ImageButton = elements:WaitForChild("CloseBTN")
	closeButton.Activated:Connect(function(): ()
		for _, card in _cards do
			ChallengeCard.settle(card)
		end
		PopupUtils.HidePopup(gui)
	end)
	local menu = playerGui:WaitForChild("ChallengeMenuGui") :: ScreenGui
	local openButton = menu:WaitForChild("OpenChallenges") :: ImageButton
	openButton.Activated:Connect(function(): ()
		PopupUtils.ShowPopup(gui)
	end)
	menu.Enabled = true
	if PopupUtils.GetCurrentPopup() then
		PopupUtils.HideAllGuis()
	end
end

function Shared.OnStart(): ()
	DataService:waitForData()
	DataService:getChangedSignal({ "Challenges" }):Connect(Private._readData)
	Private._readData()
	Private._bindGui()
end

return Shared
