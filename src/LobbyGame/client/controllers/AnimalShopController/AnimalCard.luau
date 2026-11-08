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

local Private = {}
local Shared = {}

function Private._bindMotion(
	scope: Fusion.Scope,
	card: Frame,
	wrapper: Frame,
	buttons: { GuiButton },
	order: number
): (success: boolean) -> ()
	local content: Frame = card.content
	local icon: ImageLabel = content.itemIcon
	local face: ImageLabel = card.slotBG
	local nameLabel: TextLabel = content.Name1
	local ribbon: ImageLabel = content.ImageLabel
	local ribbonLabel: TextLabel = ribbon.TextNew
	-- Rotated artwork bypasses ScrollingFrame clipping; keep this motion unrotated.
	local rest = {
		[content] = { Position = content.Position },
		[icon] = {
			Position = icon.Position,
			Size = icon.Size,
			ImageTransparency = icon.ImageTransparency,
		},
		[face] = { Size = face.Size, ImageColor3 = face.ImageColor3, ImageTransparency = face.ImageTransparency },
		[nameLabel] = { Position = nameLabel.Position, TextTransparency = nameLabel.TextTransparency },
		[ribbon] = {
			Position = ribbon.Position,
			ImageTransparency = ribbon.ImageTransparency,
		},
		[ribbonLabel] = { TextTransparency = ribbonLabel.TextTransparency },
	}
	local tweens: { Tween } = {}
	local hovered = false
	local pointerX, pointerY = 0, 0
	local screen = wrapper:FindFirstAncestorOfClass("ScreenGui")

	local function cancel(): ()
		for _, tween in tweens do
			tween:Cancel()
			tween:Destroy()
		end
		table.clear(tweens)
	end
	local function reset(): ()
		cancel()
		for target, properties in rest do
			for property, value in properties do
				target[property] = value
			end
		end
	end
	local function play(target: Instance, info: TweenInfo, goals: { [string]: any }): ()
		local tween = TweenService:Create(target, info, goals)
		table.insert(tweens, tween)
		tween:Play()
	end
	local function update(reveal: boolean): ()
		if not card.Visible or not wrapper.Visible or not screen.Enabled then
			hovered = false
			pointerX, pointerY = 0, 0
			reset()
			return
		end
		if GuiService.ReducedMotionEnabled or not buttons[1].Interactable or not buttons[1].Active then
			reset()
			return
		end
		cancel()
		local pressed = false
		local focused = hovered
		for _, button in buttons do
			pressed = pressed or button.GuiState == Enum.GuiState.Press
			focused = focused or GuiService.SelectedObject == button
		end
		local delay = if reveal then math.min((order - 1) * 0.035, 0.16) else 0
		local info = TweenInfo.new(
			if pressed then 0.09 else 0.24,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out,
			0,
			false,
			delay
		)
		local moveInfo = TweenInfo.new(
			if pressed then 0.09 else 0.28,
			if pressed then Enum.EasingStyle.Quad else Enum.EasingStyle.Back,
			Enum.EasingDirection.Out,
			0,
			false,
			delay
		)
		local textInfo = TweenInfo.new(
			0.24,
			Enum.EasingStyle.Quart,
			Enum.EasingDirection.Out,
			0,
			false,
			delay + (if reveal then 0.07 else 0)
		)
		local ribbonInfo = TweenInfo.new(
			0.3,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out,
			0,
			false,
			delay + (if reveal then 0.11 else 0)
		)
		local ribbonFadeInfo = TweenInfo.new(
			0.22,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out,
			0,
			false,
			delay + (if reveal then 0.11 else 0)
		)
		local size = rest[icon].Size
		local scale = if pressed then 0.96 elseif focused then 1.12 else 1
		local faceSize = rest[face].Size
		local faceScale = if pressed then 0.985 elseif focused then 1.015 else 1
		local x = if focused and not pressed then pointerX else 0
		local y = if focused and not pressed then pointerY else 0
		if reveal then
			content.Position = rest[content].Position + UDim2.fromOffset(0, 18)
			icon.Size = UDim2.new(size.X.Scale * 0.84, size.X.Offset * 0.84, size.Y.Scale * 0.84, size.Y.Offset * 0.84)
			icon.Position = rest[icon].Position + UDim2.fromOffset(0, 10)
			icon.ImageTransparency = 1
			face.ImageTransparency = 1
			nameLabel.Position = rest[nameLabel].Position + UDim2.fromOffset(-12, 7)
			nameLabel.TextTransparency = 1
			ribbon.Position = rest[ribbon].Position + UDim2.fromOffset(-10, -6)
			ribbon.ImageTransparency = 1
			ribbonLabel.TextTransparency = 1
		end
		play(
			content,
			moveInfo,
			{ Position = rest[content].Position + UDim2.fromOffset(0, if pressed then 2 elseif focused then -4 else 0) }
		)
		play(icon, moveInfo, {
			Size = UDim2.new(size.X.Scale * scale, size.X.Offset * scale, size.Y.Scale * scale, size.Y.Offset * scale),
			Position = rest[icon].Position
				+ UDim2.fromOffset(x * 6, y * 4 - (if focused and not pressed then 4 else 0)),
		})
		play(icon, info, { ImageTransparency = rest[icon].ImageTransparency })
		play(face, info, {
			Size = UDim2.new(
				faceSize.X.Scale * faceScale,
				faceSize.X.Offset * faceScale,
				faceSize.Y.Scale * faceScale,
				faceSize.Y.Offset * faceScale
			),
			ImageColor3 = if pressed
				then rest[face].ImageColor3:Lerp(Color3.new(0, 0, 0), 0.22)
				elseif focused then rest[face].ImageColor3:Lerp(Color3.fromRGB(255, 214, 130), 0.38)
				else rest[face].ImageColor3,
			ImageTransparency = rest[face].ImageTransparency,
		})
		play(nameLabel, textInfo, {
			Position = rest[nameLabel].Position + UDim2.fromOffset(-x * 2, if focused and not pressed then -2 else 0),
			TextTransparency = rest[nameLabel].TextTransparency,
		})
		play(ribbon, ribbonInfo, {
			Position = rest[ribbon].Position + UDim2.fromOffset(-x * 3, if focused and not pressed then -2 else 0),
		})
		play(ribbon, ribbonFadeInfo, { ImageTransparency = rest[ribbon].ImageTransparency })
		play(ribbonLabel, ribbonFadeInfo, rest[ribbonLabel])
	end

	table.insert(
		scope,
		card.MouseEnter:Connect(function(): ()
			hovered = true
			update(false)
		end)
	)
	table.insert(
		scope,
		card.MouseLeave:Connect(function(): ()
			hovered = false
			pointerX, pointerY = 0, 0
			update(false)
		end)
	)
	table.insert(
		scope,
		card.MouseMoved:Connect(function(mouseX: number, mouseY: number): ()
			if not hovered or GuiService.ReducedMotionEnabled then
				return
			end
			local inset = GuiService:GetGuiInset()
			local position = card.AbsolutePosition
			local size = card.AbsoluteSize
			local x = math.clamp((mouseX - position.X - inset.X) / size.X * 2 - 1, -1, 1)
			local y = math.clamp((mouseY - position.Y - inset.Y) / size.Y * 2 - 1, -1, 1)
			-- Ignore pointer changes that would move the artwork less than a pixel.
			if math.abs(x - pointerX) < 0.08 and math.abs(y - pointerY) < 0.08 then
				return
			end
			pointerX, pointerY = x, y
			update(false)
		end)
	)
	for _, button in buttons do
		for _, property in { "GuiState", "Active", "Interactable" } do
			table.insert(
				scope,
				button:GetPropertyChangedSignal(property):Connect(function(): ()
					update(false)
				end)
			)
		end
	end
	for _, entry in { { card, "Visible" }, { wrapper, "Visible" }, { screen, "Enabled" } } do
		table.insert(
			scope,
			entry[1]:GetPropertyChangedSignal(entry[2]):Connect(function(): ()
				update(true)
			end)
		)
	end
	table.insert(
		scope,
		GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function(): ()
			update(false)
		end)
	)
	table.insert(
		scope,
		GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function(): ()
			update(false)
		end)
	)
	table.insert(scope, reset)
	update(false)

	-- Equip results start the card from a flash or a sideways nudge, then the normal update
	-- eases it back; nothing rotates inside the clipped list.
	return function(success: boolean): ()
		if not card.Visible or not wrapper.Visible or GuiService.ReducedMotionEnabled then
			return
		end
		if success then
			face.ImageColor3 = rest[face].ImageColor3:Lerp(Color3.fromRGB(255, 214, 130), 0.85)
			content.Position = rest[content].Position + UDim2.fromOffset(0, -10)
		else
			content.Position = rest[content].Position + UDim2.fromOffset(10, 0)
		end
		update(false)
	end
end

function Shared.bind(
	scope: Fusion.Scope,
	card: Frame,
	animalName: string,
	openPreview: (string) -> (),
	wrapper: Frame
): ()
	local config = AnimalShopConfig[animalName]
	local content = card:WaitForChild("content")
	local nameLabel: TextLabel = content:WaitForChild("Name1")
	local icon: ImageLabel = content:WaitForChild("itemIcon")
	local tag: ImageLabel = content:WaitForChild("ImageLabel")
	local tagLabel: TextLabel = tag:WaitForChild("TextNew")
	local equipButton: ImageButton = card:WaitForChild("buyBtn")
	local buttons: Frame = card:WaitForChild("Btns")
	local robuxButton: ImageButton = buttons:WaitForChild("robuxButton")
	local levels = buttons:WaitForChild("levels")
	local coinButton: ImageButton = levels:WaitForChild("buyButton")
	local levelButton: ImageButton = levels:WaitForChild("level")
	local owned = scope:Computed(function(use)
		return use(AnimalShopState.owned)[animalName] == true
	end)
	local available = scope:Computed(function(use)
		return use(AnimalShopState.available)[animalName] == true
	end)
	local equipped = scope:Computed(function(use)
		return use(AnimalShopState.equippedAnimal) == animalName
	end)
	local levelLocked = scope:Computed(function(use)
		return use(available) and use(PlayerState.Level) < config.requiredLevel
	end)
	local busy = scope:Value(false)
	local message = scope:Value("")
	local canEquip = scope:Computed(function(use)
		return use(owned) and use(available) and not use(equipped) and not use(busy)
	end)

	card.Name = animalName
	card.LayoutOrder = config.order
	nameLabel.Text = if config.starter
		then string.upper(animalName)
		else `{string.upper(animalName)} · L{config.requiredLevel}`
	local stats = AnimalConfig[animalName]
	icon.Visible = stats ~= nil
	if stats then
		icon.Image = `rbxassetid://{stats.icon}`
	end
	robuxButton:WaitForChild("TitleText").Text = `\u{E002}{config.robuxPrice}`
	coinButton:WaitForChild("btnLabel").Text = `$ {config.coinPrice}`
	levelButton:WaitForChild("btnLabel").Text = `Lvl. {config.requiredLevel}`

	scope:Hydrate(card)({
		Visible = scope:Computed(function(use)
			return (not use(owned) or use(AnimalShopState.includeOwned))
				and (use(available) or use(AnimalShopState.includeOffsale))
				and string.find(string.lower(animalName), string.lower(use(AnimalShopState.search)), 1, true) ~= nil
		end),
	})
	scope:Hydrate(tag)({
		Visible = scope:Computed(function(use)
			return not use(available) or use(owned)
		end),
	})
	scope:Hydrate(tagLabel)({
		Text = scope:Computed(function(use)
			return if not use(available) then "OFFSALE" else "OWNED"
		end),
	})
	-- Keep inactive equip clicks from falling through to the card's preview hitbox.
	scope:Hydrate(equipButton)({
		Visible = owned,
		Interactable = true,
		Selectable = canEquip,
	})
	scope:Hydrate(equipButton:WaitForChild("TitleText"))({
		Text = scope:Computed(function(use)
			return if use(equipped)
				then "EQUIPPED"
				elseif use(busy) then "EQUIPPING..."
				elseif not use(available) then "OFFSALE"
				elseif use(message) ~= "" then use(message)
				else "EQUIP"
		end),
	})
	scope:Hydrate(buttons)({ Visible = scope:Computed(function(use)
		return not use(owned)
	end) })
	scope:Hydrate(levelButton)({ Visible = levelLocked })
	scope:Hydrate(coinButton)({
		Visible = scope:Computed(function(use)
			return not use(levelLocked)
		end),
		Interactable = true,
	})

	local hitbox = content:WaitForChild("PreviewButton") :: ImageButton
	local cardButtons = { hitbox, equipButton, coinButton }
	for _, button in { equipButton, coinButton } do
		button:SetAttribute("buttonRevealDelay", math.min((config.order - 1) * 0.035, 0.16) + 0.08)
		button:SetAttribute("buttonRevealScale", 0.82)
	end
	local playResult = Private._bindMotion(scope, card, wrapper, cardButtons, config.order)
	table.insert(
		scope,
		equipButton.Activated:Connect(function()
			if not Fusion.peek(canEquip) then
				return
			end
			busy:set(true)
			message:set("")
			local success, result = pcall(FirstAnimalNetwork.equip, animalName)
			busy:set(false)
			local equippedNow = success and type(result) == "table" and result.status == "equipped"
			if not equippedNow then
				message:set("TRY AGAIN")
			end
			playResult(equippedNow)
		end)
	)
	for _, button in { hitbox, coinButton } do
		button.Interactable = true
		button.Activated:Connect(function()
			openPreview(animalName)
		end)
	end
end

return Shared
