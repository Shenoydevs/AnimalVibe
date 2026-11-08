--!strict
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local BadgeConfig = require(ReplicatedStorage.Common.config.BadgeConfig)
local BadgeState = require(script.Parent.Parent.Parent.states.BadgeState)
local BadgeIcon = require(script.Parent.BadgeIcon)

type Scope = typeof(Fusion.scoped(Fusion))

local _cardTemplate = ReplicatedStorage.Assets.GUIs:WaitForChild("Badges"):WaitForChild("Card")
local _revealScale = 0.6
local _headerSlide = 36

local Private = {}
local Shared = {}

-- Rarity headers slide in from the left as the popup opens, one after another.
function Private._bindHeader(wrapper: Frame, header: ImageLabel, headerLabel: TextLabel, order: number)
	local restPosition = header.Position
	local restImage = header.ImageTransparency
	local restText = headerLabel.TextTransparency
	local tweens: { Tween } = {}
	local function reset()
		for _, tween in tweens do
			tween:Cancel()
			tween:Destroy()
		end
		table.clear(tweens)
		header.Position = restPosition
		header.ImageTransparency = restImage
		headerLabel.TextTransparency = restText
	end
	wrapper:GetPropertyChangedSignal("Visible"):Connect(function()
		reset()
		if not wrapper.Visible or GuiService.ReducedMotionEnabled then
			return
		end
		local delay = 0.1 + (order - 1) * 0.06
		header.Position = restPosition - UDim2.fromOffset(_headerSlide, 0)
		header.ImageTransparency = 1
		headerLabel.TextTransparency = 1
		local info = TweenInfo.new(0.34, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, false, delay)
		table.insert(
			tweens,
			TweenService:Create(header, info, { Position = restPosition, ImageTransparency = restImage })
		)
		table.insert(tweens, TweenService:Create(headerLabel, info, { TextTransparency = restText }))
		for _, tween in tweens do
			tween:Play()
		end
	end)
	GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(reset)
end

function Shared.createGroup(
	scope: Scope,
	template: Frame,
	rarity: string,
	order: number,
	scrollingFrame: ScrollingFrame,
	wrapper: Frame
)
	local group = template:Clone()
	local header = group:WaitForChild("HeaderBg") :: ImageLabel
	local headerLabel = header:WaitForChild("HeaderLabel") :: TextLabel
	local list = group:WaitForChild("BadgesList") :: Frame

	group.Name = rarity
	group.LayoutOrder = order
	header.ImageColor3 = BadgeConfig.rarityColors[rarity]
	headerLabel.Text = string.upper(rarity)
	Private._bindHeader(wrapper, header, headerLabel, order)

	for badgeId, badge in BadgeConfig.badges do
		if badge.rarity ~= rarity then
			continue
		end

		local card = _cardTemplate:Clone()
		card.Name = badgeId
		card.LayoutOrder = badge.order
		local visual = card:WaitForChild("Visual") :: Frame
		local hitbox = card:WaitForChild("Hitbox") :: TextButton
		local guiState = scope:Value(hitbox.GuiState)
		local flash = scope:Value(false)
		scope:Hydrate(hitbox)({ [Fusion.Out("GuiState")] = guiState })
		local highlight = scope:Computed(function(use)
			if use(flash) then
				return 0.85
			end
			if use(BadgeState.selectedId) == badgeId then
				return 0.35
			end
			return if use(guiState) == Enum.GuiState.Hover then 0.2 else 0
		end)
		BadgeIcon.bind(scope, visual, badgeId, highlight)
		-- AnimatedButton owns the card's scale and lift, so feedback nudges the icon inside it.
		-- Rotation would escape the scrolling list's clipping; translation stays clipped.
		-- Fusion 0.3 ignores velocity kicks on a constant goal, so the nudge follows a state.
		local icon = visual:WaitForChild("Icon") :: ImageLabel
		local nudge = scope:Spring(scope:Value(icon.Position), 30, 0.22)
		scope:Hydrate(icon)({ Position = nudge })
		card:SetAttribute("badgeRevealDelay", (order - 1) * 0.025 + (badge.order - 1) * 0.03)
		card:SetAttribute("buttonRevealScale", _revealScale)

		local function celebrate(kick: number)
			if GuiService.ReducedMotionEnabled or not wrapper.Visible then
				return
			end
			nudge:addVelocity(UDim2.fromOffset(0, -kick))
			flash:set(true)
			task.delay(0.12, function()
				flash:set(false)
			end)
		end
		hitbox.Activated:Connect(function()
			BadgeState.selectedId:set(badgeId)
			if GuiService.ReducedMotionEnabled or not wrapper.Visible then
				return
			end
			if Fusion.peek(BadgeState.earned)[badgeId] then
				celebrate(120)
			else
				-- Locked badges shake their head instead of lighting up.
				nudge:addVelocity(UDim2.fromOffset(260, 0))
			end
		end)
		scope:Observer(BadgeState.equippedId):onChange(function()
			if Fusion.peek(BadgeState.equippedId) == badgeId then
				celebrate(200)
			end
		end)
		card.Parent = list
	end

	group.Parent = scrollingFrame
end

return Shared
