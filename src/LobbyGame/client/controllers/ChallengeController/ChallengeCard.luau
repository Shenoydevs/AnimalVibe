--!strict
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ChallengeTypes = require(ReplicatedStorage.Shared.types.ChallengeTypes)
local PopupUtils = require(script.Parent.Parent.Parent.utils.PopupUtils)

type Challenge = ChallengeTypes.Challenge
export type Card = {
	frame: Frame,
	wrapper: Frame,
	content: Frame,
	labels: { TextLabel },
	icons: { ImageLabel },
	statusScale: UIScale,
	descriptionScale: UIScale,
	baseGradient: UIGradient,
	innerStroke: UIStroke,
	count: Fusion.StateObject<number>,
	shown: Fusion.Value<number>,
	complete: Fusion.StateObject<boolean>,
	hovered: Fusion.Value<boolean>,
	flash: Fusion.Value<boolean>,
	pressed: Fusion.Value<boolean>,
	countToken: {}?,
	rest: { [Instance]: { [string]: any } },
	tweens: { Tween },
}

local _white = Color3.new(1, 1, 1)
local _completeBase = Color3.fromRGB(250, 228, 166)
local _completeStroke = Color3.fromRGB(196, 150, 60)
local _completeGlow = Color3.fromRGB(255, 236, 160)
local _completeStatus = Color3.fromRGB(70, 100, 48)
local _hiddenShine = Vector2.new(-1, 0)
local _passedShine = Vector2.new(1, 0)
local _hoverScale = 1.025
local _pressScale = 0.97
local _springSpeed = 28
local _springDamping = 0.55

local Private = {}
local Shared = {}

function Private._info(duration: number, style: Enum.EasingStyle, delay: number?): TweenInfo
	return TweenInfo.new(duration, style, Enum.EasingDirection.Out, 0, false, delay or 0)
end

function Private._tween(list: { Tween }, target: Instance, info: TweenInfo, goals: { [string]: any }): ()
	local tween = TweenService:Create(target, info, goals)
	table.insert(list, tween)
	tween.Completed:Once(function(state: Enum.PlaybackState): ()
		if state ~= Enum.PlaybackState.Completed then
			return
		end
		local index = table.find(list, tween)
		if index then
			table.remove(list, index)
		end
		tween:Destroy()
	end)
	tween:Play()
end

function Private._cancel(list: { Tween }): ()
	for _, tween in list do
		tween:Cancel()
		tween:Destroy()
	end
	table.clear(list)
end

function Private._flash(card: Card, delay: number): ()
	task.delay(delay, function(): ()
		card.flash:set(true)
		task.wait(0.1)
		card.flash:set(false)
	end)
end

function Private._breathe(card: Card, delay: number): ()
	if not Fusion.peek(card.complete) then
		return
	end
	Private._tween(
		card.tweens,
		card.innerStroke,
		TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, delay),
		{ Color = _completeGlow }
	)
end

function Private._celebrate(card: Card): ()
	Private._flash(card, 0)
	card.statusScale.Scale = 0.5
	Private._tween(card.tweens, card.statusScale, Private._info(0.45, Enum.EasingStyle.Back), { Scale = 1 })
	card.descriptionScale.Scale = 1.12
	Private._tween(card.tweens, card.descriptionScale, Private._info(0.35, Enum.EasingStyle.Back), { Scale = 1 })
	Shared.sweep(card, 0.08)
	Private._breathe(card, 0.4)
end

-- Progress gained while the popup was closed ticks up when the card is next seen.
function Private._countUp(card: Card, delay: number): ()
	local token = {}
	card.countToken = token
	task.delay(delay, function(): ()
		while card.countToken == token do
			local target = Fusion.peek(card.count)
			local shown = Fusion.peek(card.shown)
			if shown > target or GuiService.ReducedMotionEnabled then
				card.shown:set(target)
				return
			end
			if shown == target or not Shared.visible(card) then
				return
			end
			card.shown:set(shown + 1)
			card.descriptionScale.Scale = 1.1
			Private._tween(
				card.tweens,
				card.descriptionScale,
				Private._info(0.18, Enum.EasingStyle.Back),
				{ Scale = 1 }
			)
			task.wait(0.12)
		end
	end)
end

function Shared.visible(card: Card): boolean
	return card.wrapper.Visible and card.frame.Visible
end

function Shared.settle(card: Card): ()
	Private._cancel(card.tweens)
	card.countToken = nil
	for target, properties in card.rest do
		for property, value in properties do
			(target :: any)[property] = value
		end
	end
end

function Shared.sweep(card: Card, delay: number): ()
	card.baseGradient.Offset = _hiddenShine
	Private._tween(
		card.tweens,
		card.baseGradient,
		TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, delay),
		{ Offset = _passedShine }
	)
end

function Shared.reveal(card: Card, direction: number, delay: number): ()
	Shared.settle(card)
	if not Shared.visible(card) then
		card.hovered:set(false)
		card.pressed:set(false)
		return
	end
	if GuiService.ReducedMotionEnabled then
		card.shown:set(Fusion.peek(card.count))
		return
	end
	local content = card.content
	content.Position = card.rest[content].Position + UDim2.fromOffset(direction * 10, 18)
	Private._tween(
		card.tweens,
		content,
		Private._info(0.32, Enum.EasingStyle.Back, delay),
		{ Position = card.rest[content].Position }
	)
	for _, label in card.labels do
		label.TextTransparency = 1
		Private._tween(
			card.tweens,
			label,
			Private._info(0.24, Enum.EasingStyle.Quart, delay + 0.07),
			{ TextTransparency = card.rest[label].TextTransparency }
		)
	end
	for index, icon in card.icons do
		icon.ImageTransparency = 1
		Private._tween(
			card.tweens,
			icon,
			Private._info(0.22, Enum.EasingStyle.Quad, delay + 0.11 + (index - 1) * 0.04),
			{ ImageTransparency = card.rest[icon].ImageTransparency }
		)
	end
	card.statusScale.Scale = 0.6
	Private._tween(
		card.tweens,
		card.statusScale,
		Private._info(0.3, Enum.EasingStyle.Back, delay + 0.11),
		{ Scale = 1 }
	)
	Private._countUp(card, delay + 0.3)
	if Fusion.peek(card.complete) then
		Shared.sweep(card, delay + 0.25)
		Private._breathe(card, delay + 0.4)
	end
end

function Shared.bind(
	scope: Fusion.Scope,
	frame: Frame,
	challenge: Challenge,
	progress: Fusion.StateObject<{ [string]: number }>,
	wrapper: Frame,
	reducedMotion: Fusion.StateObject<boolean>,
	colorInfo: Fusion.StateObject<TweenInfo>
): Card
	local content: Frame = frame.Content
	local status: ImageLabel = content.ChallengeCompletion
	local description: TextLabel = content.DescriptionText
	local base: Frame = frame.Base
	local baseGradient = base:FindFirstChildOfClass("UIGradient") :: UIGradient
	local outerStroke: UIStroke = base.UIStroke1
	local innerStroke: UIStroke = base.UIStroke2
	local statusGradient = status:FindFirstChildOfClass("UIGradient") :: UIGradient
	local baseColor = baseGradient.Color.Keypoints[1].Value
	local strokeColor = outerStroke.Color
	local statusColor = statusGradient.Color.Keypoints[1].Value
	local statusScale = Instance.new("UIScale")
	statusScale.Parent = status
	local descriptionScale = Instance.new("UIScale")
	descriptionScale.Parent = description
	-- Base and Content are both centred in the slot, so one shared scale moves the card as a
	-- whole without resizing the slot inside its list layout.
	local baseScale = Instance.new("UIScale")
	baseScale.Parent = base
	local contentScale = Instance.new("UIScale")
	contentScale.Parent = content
	baseGradient.Offset = _hiddenShine

	local function tweenColor(color: Fusion.UsedAs<Color3>): Fusion.StateObject<Color3>
		return scope:Tween(color, colorInfo)
	end
	local count = scope:Computed(function(use): number
		return math.clamp(use(progress)[challenge.id] or 0, 0, challenge.target)
	end)
	local shown = scope:Value(Fusion.peek(count))
	-- Completion styling follows the displayed count so it lands as the count ticks over.
	local complete = scope:Computed(function(use): boolean
		return use(shown) >= challenge.target
	end)
	local icons = { content.Stars, content.Money }
	local rest: { [Instance]: { [string]: any } } = {
		[content] = { Position = content.Position },
		[content.ChallengeName] = { TextTransparency = content.ChallengeName.TextTransparency },
		[description] = { TextTransparency = description.TextTransparency },
		[statusScale] = { Scale = 1 },
		[descriptionScale] = { Scale = 1 },
		[baseGradient] = { Offset = _hiddenShine },
		[innerStroke] = { Color = innerStroke.Color },
	}
	for _, icon in icons do
		rest[icon] = { ImageTransparency = icon.ImageTransparency }
	end
	local card: Card = {
		frame = frame,
		wrapper = wrapper,
		content = content,
		labels = { content.ChallengeName, description },
		icons = icons,
		statusScale = statusScale,
		descriptionScale = descriptionScale,
		baseGradient = baseGradient,
		innerStroke = innerStroke,
		count = count,
		shown = shown,
		complete = complete,
		hovered = scope:Value(false),
		flash = scope:Value(false),
		pressed = scope:Value(false),
		countToken = nil,
		rest = rest,
		tweens = {},
	}
	-- The underdamped spring overshoots on release, so letting go reads as a bounce.
	local cardScale = scope:Spring(
		scope:Computed(function(use): number
			if use(reducedMotion) then
				return 1
			end
			return if use(card.pressed) then _pressScale elseif use(card.hovered) then _hoverScale else 1
		end),
		_springSpeed,
		_springDamping
	)
	scope:Hydrate(baseScale)({ Scale = cardScale })
	scope:Hydrate(contentScale)({ Scale = cardScale })

	scope:Hydrate(content.ChallengeName)({ Text = string.upper(challenge.title) })
	scope:Hydrate(description)({
		Text = scope:Computed(function(use): string
			return `{challenge.description} [{use(shown)}/{challenge.target}]`
		end),
	})
	scope:Hydrate(status.CompleteText)({ Visible = complete })
	scope:Hydrate(status.IncompleteText)({
		Visible = scope:Computed(function(use): boolean
			return not use(complete)
		end),
	})
	-- Completed cards warm to gold; incomplete cards keep the authored palette. The highlight
	-- band sits outside the card at rest, so the card still reads as its flat colour.
	local baseTween = tweenColor(scope:Computed(function(use): Color3
		if use(card.flash) then
			return _white
		end
		local color = if use(complete) then _completeBase else baseColor
		return if use(card.hovered) then color:Lerp(_white, 0.3) else color
	end))
	scope:Hydrate(baseGradient)({
		Color = scope:Computed(function(use): ColorSequence
			return PopupUtils.ShineSequence(use(baseTween))
		end),
	})
	scope:Hydrate(outerStroke)({
		Color = tweenColor(scope:Computed(function(use): Color3
			return if use(complete) then _completeStroke else strokeColor
		end)),
	})
	-- Authored gradients are single-colour sequences, so a Color3 tween reproduces them at rest.
	local statusTween = tweenColor(scope:Computed(function(use): Color3
		return if use(complete) then _completeStatus else statusColor
	end))
	scope:Hydrate(statusGradient)({
		Color = scope:Computed(function(use): ColorSequence
			return ColorSequence.new(use(statusTween))
		end),
	})
	-- Reward amounts are intentionally unset; keep the authored artwork and geometry.
	content.Stars.Amnt.Text = ""
	content.Money.Amnt.Text = ""
	frame.Hitbox.Selectable = false
	frame.Hitbox.Interactable = false

	frame.MouseEnter:Connect(function(): ()
		card.hovered:set(true)
	end)
	frame.MouseLeave:Connect(function(): ()
		card.hovered:set(false)
		card.pressed:set(false)
	end)
	frame.InputBegan:Connect(function(input: InputObject): ()
		if PopupUtils.IsClick(input) then
			card.pressed:set(true)
		end
	end)
	frame.InputEnded:Connect(function(input: InputObject): ()
		if not Fusion.peek(card.pressed) or not PopupUtils.IsClick(input) then
			return
		end
		card.pressed:set(false)
		if input.UserInputType == Enum.UserInputType.Touch then
			-- Touch has no hover exit, so release ends the hover state too.
			card.hovered:set(false)
		end
		-- Clicking a card has no action; completed cards glint as the card springs back.
		if Fusion.peek(card.complete) and not GuiService.ReducedMotionEnabled then
			Private._flash(card, 0)
		end
	end)
	scope:Observer(count):onChange(function(): ()
		local target = Fusion.peek(count)
		if GuiService.ReducedMotionEnabled or target < Fusion.peek(shown) then
			shown:set(target)
		elseif Shared.visible(card) then
			Private._countUp(card, 0)
		end
	end)
	scope:Observer(complete):onChange(function(): ()
		if not Fusion.peek(complete) then
			Shared.settle(card)
		elseif Shared.visible(card) and not GuiService.ReducedMotionEnabled then
			Private._celebrate(card)
		end
	end)
	return card
end

return Shared
