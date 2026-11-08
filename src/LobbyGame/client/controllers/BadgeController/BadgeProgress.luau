--!strict
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local BadgeConfig = require(ReplicatedStorage.Common.config.BadgeConfig)
local BadgeState = require(script.Parent.Parent.Parent.states.BadgeState)

local Shared = {}

type Scope = typeof(Fusion.scoped(Fusion))

local _fillInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function Shared.bind(scope: Scope, wrapper: Frame, bottom: Frame)
	local amount = bottom:WaitForChild("Amnt") :: TextLabel
	local infoLabel = bottom:WaitForChild("InfoLabel") :: TextLabel
	local progressLabel = amount.Text:split("[")[1]
	local achievements = bottom:WaitForChild("AchievementsBar") :: GuiObject
	local progress = achievements:WaitForChild("ProgressBar") :: GuiObject
	local total = 0
	for _ in BadgeConfig.badges do
		total += 1
	end

	local owned = scope:Computed(function(use)
		local earned = use(BadgeState.earned)
		local count = 0
		for badgeId in BadgeConfig.badges do
			if earned[badgeId] then
				count += 1
			end
		end
		return count
	end)

	local achievementsScale = achievements:WaitForChild("UIScale") :: UIScale
	local progressHeight = progress.Size.Y
	local progressTweens: { Tween } = {}
	-- The shown count follows the bar as it fills, so the number ticks up alongside it.
	local counter = Instance.new("NumberValue")
	counter.Value = Fusion.peek(owned)
	local shown = scope:Value(Fusion.peek(owned))
	local amountScale = Instance.new("UIScale")
	amountScale.Parent = amount
	local infoRest = { position = infoLabel.Position, transparency = infoLabel.TextTransparency }
	counter.Changed:Connect(function()
		local value = math.round(counter.Value)
		if value == Fusion.peek(shown) then
			return
		end
		shown:set(value)
		if wrapper.Visible and not GuiService.ReducedMotionEnabled then
			amountScale.Scale = 1.12
			table.insert(
				progressTweens,
				TweenService:Create(
					amountScale,
					TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Scale = 1 }
				)
			)
			progressTweens[#progressTweens]:Play()
		end
	end)
	local function updateProgress(replay)
		for _, tween in progressTweens do
			tween:Cancel()
			tween:Destroy()
		end
		table.clear(progressTweens)
		amountScale.Scale = 1
		infoLabel.Position = infoRest.position
		infoLabel.TextTransparency = infoRest.transparency
		local size = UDim2.new(Fusion.peek(owned) / total, 0, progressHeight.Scale, progressHeight.Offset)
		if not wrapper.Visible or GuiService.ReducedMotionEnabled then
			achievementsScale.Scale = 1
			progress.Size = size
			counter.Value = Fusion.peek(owned)
			return
		end
		if replay then
			achievementsScale.Scale = 0.75
			progress.Size = UDim2.new(0, 0, progressHeight.Scale, progressHeight.Offset)
			counter.Value = 0
			infoLabel.Position = infoRest.position - UDim2.fromOffset(28, 0)
			infoLabel.TextTransparency = 1
			table.insert(
				progressTweens,
				TweenService:Create(
					infoLabel,
					TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, false, 0.1),
					{ Position = infoRest.position, TextTransparency = infoRest.transparency }
				)
			)
		end
		if achievementsScale.Scale ~= 1 then
			local info = TweenInfo.new(
				0.28,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.Out,
				0,
				false,
				if replay then 0.12 else 0
			)
			table.insert(progressTweens, TweenService:Create(achievementsScale, info, { Scale = 1 }))
		end
		if progress.Size ~= size then
			local info = TweenInfo.new(
				_fillInfo.Time,
				_fillInfo.EasingStyle,
				_fillInfo.EasingDirection,
				0,
				false,
				if replay then 0.18 else 0
			)
			table.insert(progressTweens, TweenService:Create(progress, info, { Size = size }))
			table.insert(progressTweens, TweenService:Create(counter, info, { Value = Fusion.peek(owned) }))
		else
			counter.Value = Fusion.peek(owned)
		end
		for _, tween in progressTweens do
			tween:Play()
		end
	end
	GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
		updateProgress(false)
	end)
	scope:Hydrate(wrapper)({ [Fusion.OnChange("Visible")] = updateProgress })
	scope:Hydrate(amount)({
		Text = scope:Computed(function(use)
			return `{progressLabel}[{use(shown)}/{total}]`
		end),
	})
	scope:Observer(owned):onChange(function()
		updateProgress(false)
	end)
	updateProgress(false)
end

return Shared
