--!strict
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local AnimalConfig = require(ReplicatedStorage.Common.config.AnimalConfig)
local AnimalShopConfig = require(ReplicatedStorage.Shared.config.AnimalShopConfig)
local AnimalShopState = require(script.Parent.Parent.Parent.states.AnimalShopState)
local PlayerState = require(script.Parent.Parent.Parent.states.PlayerState)
local FirstAnimalNetwork = require(script.Parent.Parent.Parent.network.FirstAnimalNetwork)
local PopupUtils = require(script.Parent.Parent.Parent.utils.PopupUtils)

type StatBar = { fill: ImageLabel, baseline: UDim2, field: string }

local _animals: { string } = {}
for name in AnimalShopConfig do
	table.insert(_animals, name)
end
table.sort(_animals, function(a: string, b: string): boolean
	return AnimalShopConfig[a].order < AnimalShopConfig[b].order
end)

local Private = {}
local Shared = {}

function Private._getIcon(animalName: string?): string
	local stats = if animalName then AnimalConfig[animalName] else nil
	return if stats then `rbxassetid://{stats.icon}` else ""
end

function Private._getNeighbor(animalName: string, owned: { [string]: boolean }, direction: number): string?
	local index = table.find(_animals, animalName)
	if not index then
		return nil
	end
	for step = 1, #_animals do
		local name = _animals[(index - 1 + direction * step) % #_animals + 1]
		if name ~= animalName and owned[name] == true then
			return name
		end
	end
	return nil
end

function Private._bindMotion(
	scope: Fusion.Scope,
	wrapper: Frame,
	selected: Fusion.Value<string>,
	statBars: { StatBar }
): (number) -> ()
	local content = wrapper.Content
	local elements = wrapper.Elements
	local icon: ImageLabel = content.slot4.content.AnimalIcon
	local title: TextLabel = elements.TitleText
	local subtitle: TextLabel = elements.Description
	local details: ImageLabel = content.descriptionBase
	local barBase: ImageLabel = content.barBase
	local bottom: Frame = content.bottom
	local screen = wrapper:FindFirstAncestorOfClass("ScreenGui")
	local rest = {
		[icon] = {
			Position = icon.Position,
			Size = icon.Size,
			Rotation = icon.Rotation,
			ImageTransparency = icon.ImageTransparency,
		},
		[details] = { Position = details.Position },
		[barBase] = { Position = barBase.Position },
		[bottom] = { Position = bottom.Position },
	}
	local labels = { title, subtitle, elements.buyText, content.TextSwitch }
	for _, child in details:GetDescendants() do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	for _, label in labels do
		rest[label] = { TextTransparency = label.TextTransparency }
		if label == title or label == subtitle then
			rest[label].Position = label.Position
		end
	end
	local pickerButtons = { bottom.container.pufferFish, bottom.container.Ants, bottom.container.bird }
	for _, button in pickerButtons do
		local thumbnail: ImageLabel = button.icon
		local nameLabel: TextLabel = button.nameLabel
		rest[thumbnail] = {
			Position = thumbnail.Position,
			Size = thumbnail.Size,
			Rotation = thumbnail.Rotation,
			ImageTransparency = thumbnail.ImageTransparency,
		}
		rest[nameLabel] = { Position = nameLabel.Position, TextTransparency = nameLabel.TextTransparency }
	end
	local tweens: { Tween } = {}
	local function fillSize(entry: StatBar): UDim2
		local stats = AnimalConfig[Fusion.peek(selected)]
		local ratio = if stats then math.clamp(stats[entry.field] / 100, 0, 1) else 0
		return UDim2.new(ratio, 0, entry.baseline.Y.Scale, entry.baseline.Y.Offset)
	end
	local function reset(): ()
		for _, tween in tweens do
			tween:Cancel()
			tween:Destroy()
		end
		table.clear(tweens)
		for target, properties in rest do
			for property, value in properties do
				target[property] = value
			end
		end
		for _, entry in statBars do
			entry.fill.Size = fillSize(entry)
		end
	end
	local function play(target: Instance, info: TweenInfo, goals: { [string]: any }): ()
		local tween = TweenService:Create(target, info, goals)
		table.insert(tweens, tween)
		tween:Play()
	end
	local function animate(direction: number): ()
		reset()
		if not wrapper.Visible or not screen.Enabled or GuiService.ReducedMotionEnabled then
			return
		end
		local size = rest[icon].Size
		icon.Size = UDim2.new(size.X.Scale * 0.76, size.X.Offset * 0.76, size.Y.Scale * 0.76, size.Y.Offset * 0.76)
		icon.Position = rest[icon].Position + UDim2.fromOffset(direction * 36, if direction == 0 then 18 else 0)
		icon.Rotation = rest[icon].Rotation + (if direction == 0 then -3 else direction * 5)
		icon.ImageTransparency = 1
		play(icon, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = rest[icon].Size,
			Position = rest[icon].Position,
			Rotation = rest[icon].Rotation,
		})
		play(icon, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			ImageTransparency = rest[icon].ImageTransparency,
		})
		for index, button in pickerButtons do
			local thumbnail: ImageLabel = button.icon
			local nameLabel: TextLabel = button.nameLabel
			local baseline = rest[thumbnail]
			local scale = if index == 2 then 0.84 else 0.92
			local thumbnailSize = baseline.Size
			thumbnail.Position = baseline.Position + UDim2.fromOffset(direction * 14, 4)
			thumbnail.Size = UDim2.new(
				thumbnailSize.X.Scale * scale,
				thumbnailSize.X.Offset * scale,
				thumbnailSize.Y.Scale * scale,
				thumbnailSize.Y.Offset * scale
			)
			thumbnail.Rotation = baseline.Rotation + direction * 4
			thumbnail.ImageTransparency = 1
			nameLabel.Position = rest[nameLabel].Position + UDim2.fromOffset(0, 4)
			nameLabel.TextTransparency = 1
			local delay = (index - 1) * 0.025
			play(thumbnail, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay), {
				Position = baseline.Position,
				Size = baseline.Size,
				Rotation = baseline.Rotation,
			})
			play(thumbnail, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay), {
				ImageTransparency = baseline.ImageTransparency,
			})
			play(
				nameLabel,
				TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, false, delay + 0.08),
				rest[nameLabel]
			)
		end
		for _, label in labels do
			label.TextTransparency = 1
			local delay = if label == title
				then 0
				elseif label == subtitle then 0.04
				elseif label:IsDescendantOf(details) then 0.14
				else 0.1
			if label == title or label == subtitle then
				label.Position = rest[label].Position
					+ UDim2.fromOffset(if direction == 0 then -18 else direction * 18, 0)
			end
			play(
				label,
				TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, false, delay),
				rest[label]
			)
		end
		for index, target in { barBase, details, bottom } do
			target.Position = rest[target].Position
				+ UDim2.fromOffset(if target == bottom then 0 else direction * 14, 10)
			play(
				target,
				TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, false, index * 0.04),
				rest[target]
			)
		end
		for index, entry in statBars do
			entry.fill.Size = UDim2.new(0, 0, entry.baseline.Y.Scale, entry.baseline.Y.Offset)
			play(
				entry.fill,
				TweenInfo.new(
					0.32,
					Enum.EasingStyle.Quart,
					Enum.EasingDirection.Out,
					0,
					false,
					0.12 + (index - 1) * 0.055
				),
				{
					Size = fillSize(entry),
				}
			)
		end
	end
	for _, entry in { { wrapper, "Visible" }, { screen, "Enabled" } } do
		table.insert(
			scope,
			entry[1]:GetPropertyChangedSignal(entry[2]):Connect(function(): ()
				animate(0)
			end)
		)
	end
	table.insert(scope, GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(reset))
	table.insert(scope, reset)
	reset()
	return animate
end

function Shared.bind(scope: Fusion.Scope, gui: ScreenGui, shopGui: ScreenGui): (string) -> ()
	local wrapper = gui:WaitForChild("Wrapper")
	local elements = wrapper:WaitForChild("Elements")
	local content = wrapper:WaitForChild("Content")
	local buttons = content:WaitForChild("Btns")
	local levels = buttons:WaitForChild("levels")
	local coinButton = levels:WaitForChild("buyButton") :: ImageButton
	local levelButton = levels:WaitForChild("level") :: ImageButton
	local robuxButton = buttons:WaitForChild("robuxButton") :: ImageButton
	local bottom = content:WaitForChild("bottom")
	local selected = scope:Value(_animals[1])
	local busy = scope:Value(false)
	local message = scope:Value("")
	local config = scope:Computed(function(use)
		return AnimalShopConfig[use(selected)]
	end)
	local owned = scope:Computed(function(use)
		return use(AnimalShopState.owned)[use(selected)] == true
	end)
	local available = scope:Computed(function(use)
		return use(AnimalShopState.available)[use(selected)] == true
	end)
	local equipped = scope:Computed(function(use)
		return use(AnimalShopState.equippedAnimal) == use(selected)
	end)
	local levelLocked = scope:Computed(function(use)
		return not use(owned) and use(PlayerState.Level) < use(config).requiredLevel
	end)
	local canAct = scope:Computed(function(use)
		return use(available)
			and not use(busy)
			and not use(equipped)
			and (use(owned) or (not use(levelLocked) and use(AnimalShopState.coins) >= use(config).coinPrice))
	end)

	scope:Hydrate(elements:WaitForChild("TitleText"))({
		Text = scope:Computed(function(use)
			return string.upper(use(selected))
		end),
	})
	scope:Hydrate(elements:WaitForChild("Description"))({
		Text = scope:Computed(function(use)
			return if not use(available)
				then "Not available yet."
				elseif use(config).starter then "Starter animal"
				else `Unlock with {use(config).coinPrice} coins at level {use(config).requiredLevel}.`
		end),
	})
	scope:Hydrate(elements:WaitForChild("buyText"))({
		Text = scope:Computed(function(use)
			return if use(owned) then "EQUIP ANIMAL" else "BUY ANIMAL"
		end),
	})
	scope:Hydrate(content:WaitForChild("TextSwitch"))({
		Text = scope:Computed(function(use)
			return if use(message) ~= ""
				then use(message)
				elseif not use(available) then "OFFSALE"
				elseif use(equipped) then "EQUIPPED"
				elseif use(owned) then "OWNED"
				elseif use(levelLocked) then `LEVEL {use(config).requiredLevel} REQUIRED`
				elseif use(AnimalShopState.coins) < use(config).coinPrice then "NOT ENOUGH COINS"
				else "AVAILABLE"
		end),
	})
	local icon = content:WaitForChild("slot4"):WaitForChild("content"):WaitForChild("AnimalIcon")
	scope:Hydrate(icon)({
		Image = scope:Computed(function(use: Fusion.Use): string
			return Private._getIcon(use(selected))
		end),
	})
	local bars = content:WaitForChild("barBase"):WaitForChild("bars")
	local statBars: { StatBar } = {}
	for _, entry in
		{
			{ name = "HealthBar", field = "health" },
			{ name = "SpeedBar", field = "walkSpeed" },
			{ name = "DamageBar", field = "damage" },
		}
	do
		local bar = bars:WaitForChild(entry.name)
		local fill = bar:WaitForChild("barBg"):WaitForChild("barFg") :: ImageLabel
		local baseline = fill.Size
		scope:Hydrate(bar:WaitForChild("BarProg"))({
			Text = scope:Computed(function(use)
				local stats = AnimalConfig[use(selected)]
				return if stats then tostring(stats[entry.field]) else "—"
			end),
		})
		table.insert(statBars, { fill = fill, baseline = baseline, field = entry.field })
	end
	local description = content:WaitForChild("descriptionBase")
	local descriptions: { TextLabel } = {}
	for _, child in description:WaitForChild("textList"):GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(descriptions, child)
		end
	end
	table.sort(descriptions, function(a: TextLabel, b: TextLabel): boolean
		return a.LayoutOrder < b.LayoutOrder
	end)
	local detailText = {
		"Select a tile or arrow to browse owned animals.",
		"Equip animals you own.",
		"Robux purchases are not available yet.",
	}
	for index, label in descriptions do
		label.Text = detailText[index] or ""
	end

	scope:Hydrate(coinButton)({
		Visible = scope:Computed(function(use)
			return not use(levelLocked)
		end),
		Interactable = canAct,
	})
	scope:Hydrate(coinButton:WaitForChild("btnLabel"))({
		Text = scope:Computed(function(use)
			return if use(busy)
				then "SAVING..."
				elseif use(equipped) then "EQUIPPED"
				elseif use(owned) then "EQUIP"
				else `$ {use(config).coinPrice}`
		end),
	})
	scope:Hydrate(levelButton)({ Visible = levelLocked })
	scope:Hydrate(levelButton:WaitForChild("btnLabel"))({
		Text = scope:Computed(function(use)
			return `Lvl. {use(config).requiredLevel}`
		end),
	})
	scope:Hydrate(robuxButton)({ Visible = scope:Computed(function(use)
		return not use(owned)
	end) })
	scope:Hydrate(robuxButton:WaitForChild("TitleText"))({
		Text = scope:Computed(function(use)
			return `\u{E002}{use(config).robuxPrice}`
		end),
	})

	local playSelection = Private._bindMotion(scope, wrapper, selected, statBars)
	local function selectAnimal(animalName: string, direction: number?): ()
		selected:set(animalName)
		message:set("")
		playSelection(direction or 0)
	end
	local picker = bottom:WaitForChild("container")
	for _, entry in
		{
			{ slot = "pufferFish", arrow = "leftButton", direction = -1 },
			{ slot = "bird", arrow = "rightButton", direction = 1 },
		}
	do
		local button = picker:WaitForChild(entry.slot) :: ImageButton
		local arrow = bottom:WaitForChild(entry.arrow) :: ImageButton
		local neighbor = scope:Computed(function(use: Fusion.Use): string?
			return Private._getNeighbor(use(selected), use(AnimalShopState.owned), entry.direction)
		end)
		local enabled = scope:Computed(function(use: Fusion.Use): boolean
			return use(neighbor) ~= nil
		end)
		scope:Hydrate(button:WaitForChild("icon"))({
			Image = scope:Computed(function(use: Fusion.Use): string
				return Private._getIcon(use(neighbor))
			end),
		})
		scope:Hydrate(button:WaitForChild("nameLabel"))({
			Text = scope:Computed(function(use: Fusion.Use): string
				local name = use(neighbor)
				return if name then string.upper(name) else ""
			end),
		})
		for _, control in { button, arrow } do
			local alpha = control.ImageTransparency
			scope:Hydrate(control)({
				Interactable = enabled,
				Selectable = enabled,
				ImageTransparency = scope:Computed(function(use: Fusion.Use): number
					return if use(enabled) then alpha else math.max(alpha, 0.6)
				end),
			})
			table.insert(
				scope,
				control.Activated:Connect(function(): ()
					local name = Fusion.peek(neighbor)
					if name then
						selectAnimal(name, entry.direction)
					end
				end)
			)
		end
	end
	local currentButton = picker:WaitForChild("Ants") :: ImageButton
	scope:Hydrate(currentButton)({ Interactable = true })
	scope:Hydrate(currentButton:WaitForChild("icon"))({
		Image = scope:Computed(function(use: Fusion.Use): string
			return Private._getIcon(use(selected))
		end),
	})
	scope:Hydrate(currentButton:WaitForChild("nameLabel"))({
		Text = scope:Computed(function(use: Fusion.Use): string
			return string.upper(use(selected))
		end),
	})
	table.insert(
		scope,
		currentButton.Activated:Connect(function(): ()
			selectAnimal(Fusion.peek(selected))
		end)
	)
	local closeButton = elements:WaitForChild("CloseBTN") :: ImageButton
	closeButton.Activated:Connect(function()
		PopupUtils.ShowPopup(shopGui)
	end)
	coinButton.Activated:Connect(function()
		if not Fusion.peek(canAct) then
			return
		end
		local animalName = Fusion.peek(selected)
		local action = if Fusion.peek(owned) then FirstAnimalNetwork.equip else FirstAnimalNetwork.buy
		busy:set(true)
		message:set("")
		local success, result = pcall(action, animalName)
		busy:set(false)
		-- Browsing can continue while a request is in flight; feedback belongs to its animal.
		if Fusion.peek(selected) ~= animalName then
			return
		end
		if not success or type(result) ~= "table" then
			message:set("TRY AGAIN")
		elseif result.status == "purchased" or result.status == "equipped" then
			if result.status == "purchased" then
				message:set("PURCHASED")
			end
			playSelection(0)
		else
			message:set(if result.status == "unavailable" then "OFFSALE" else "TRY AGAIN")
		end
	end)

	return function(animalName: string): ()
		if not AnimalShopConfig[animalName] then
			return
		end
		selectAnimal(animalName)
		PopupUtils.ShowPopup(gui)
	end
end

return Shared
