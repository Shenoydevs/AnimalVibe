--!strict
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DataService = require(ReplicatedStorage.Packages.DataService).client
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local AnimalShopConfig = require(ReplicatedStorage.Shared.config.AnimalShopConfig)
local AnimalShopState = require(script.Parent.Parent.states.AnimalShopState)
local PopupUtils = require(script.Parent.Parent.utils.PopupUtils)
local AnimalCard = require(script.AnimalCard)
local AnimalPreview = require(script.AnimalPreview)

local _scope = Fusion.scoped(Fusion)
local _animals = ReplicatedStorage.Assets.Animals

local Private = {}
local Shared = {}

function Private._readData(): ()
	local owned: { [string]: boolean } = {}
	for name, animal in DataService:get({ "Animals" }) do
		owned[name] = animal.Unlocked == true
	end
	AnimalShopState.owned:set(owned)
	AnimalShopState.equippedAnimal:set(DataService:get({ "Inventory", "EquippedAnimal" }))
	AnimalShopState.coins:set(DataService:get({ "PlayerStats", "Nova" }))
end

function Private._readAvailable(): ()
	local available: { [string]: boolean } = {}
	for name in AnimalShopConfig do
		local rig = _animals:FindFirstChild(name)
		local root = rig and rig:FindFirstChild("HumanoidRootPart")
		available[name] = rig ~= nil
			and rig:IsA("Model")
			and root ~= nil
			and root:IsA("BasePart")
			and rig:FindFirstChildOfClass("Humanoid") ~= nil
	end
	AnimalShopState.available:set(available)
end

-- The toolbar sits in a list layout, so the search field lights up rather than resizing; its
-- icon springs while typing and wiggles when nothing matches.
function Private._bindSearch(searchBg: ImageLabel, wrapper: Frame): ()
	local search: TextBox = searchBg:WaitForChild("Search")
	local searchIcon: ImageLabel = searchBg:WaitForChild("SearchIcon")
	local gradient = searchBg:FindFirstChildOfClass("UIGradient") :: UIGradient
	local restColor = gradient.Color.Keypoints[1].Value
	local reducedMotion = _scope:Value(GuiService.ReducedMotionEnabled)
	local hovered = _scope:Value(false)
	local focused = _scope:Value(false)
	local iconScale = Instance.new("UIScale")
	iconScale.Parent = searchIcon
	local iconSpring = _scope:Spring(
		_scope:Computed(function(use): number
			if use(reducedMotion) then
				return 1
			end
			return if use(focused) then 1.15 elseif use(hovered) then 1.08 else 1
		end),
		28,
		0.5
	)
	-- Fusion ignores velocity kicks on a constant spring goal, so the wiggle follows a state.
	local iconTilt = _scope:Spring(_scope:Value(searchIcon.Rotation), 30, 0.22)
	_scope:Hydrate(iconScale)({ Scale = iconSpring })
	_scope:Hydrate(searchIcon)({ Rotation = iconTilt })
	local faceColor = _scope:Tween(
		_scope:Computed(function(use): Color3
			return if use(focused)
				then restColor:Lerp(Color3.new(1, 1, 1), 0.16)
				elseif use(hovered) then restColor:Lerp(Color3.new(1, 1, 1), 0.08)
				else restColor
		end),
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	)
	-- The authored gradient is a single colour, so a Color3 tween reproduces it at rest.
	_scope:Hydrate(gradient)({
		Color = _scope:Computed(function(use): ColorSequence
			return ColorSequence.new(use(faceColor))
		end),
	})

	searchBg.MouseEnter:Connect(function()
		hovered:set(true)
	end)
	searchBg.MouseLeave:Connect(function()
		hovered:set(false)
	end)
	searchBg.InputBegan:Connect(function(input: InputObject)
		if PopupUtils.IsClick(input) and not search:IsFocused() then
			search:CaptureFocus()
		end
	end)
	search.Focused:Connect(function()
		focused:set(true)
	end)
	search.FocusLost:Connect(function()
		focused:set(false)
	end)
	wrapper:GetPropertyChangedSignal("Visible"):Connect(function()
		hovered:set(false)
	end)
	GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
		reducedMotion:set(GuiService.ReducedMotionEnabled)
	end)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		AnimalShopState.search:set(search.Text)
		if not wrapper.Visible or GuiService.ReducedMotionEnabled then
			return
		end
		iconSpring:addVelocity(1.6)
		local query = string.lower(search.Text)
		for name in AnimalShopConfig do
			if string.find(string.lower(name), query, 1, true) then
				return
			end
		end
		iconTilt:addVelocity(if math.random() < 0.5 then -320 else 320)
	end)
end

-- Toggling a filter fades its label back in with the new wording.
function Private._crossfade(label: TextLabel, transparency: number): ()
	if GuiService.ReducedMotionEnabled then
		return
	end
	label.TextTransparency = 1
	local tween = TweenService:Create(
		label,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextTransparency = transparency }
	)
	tween.Completed:Once(function()
		tween:Destroy()
	end)
	tween:Play()
end

function Private._bindToolbar(top: Instance, wrapper: Frame): ()
	Private._bindSearch(top:WaitForChild("searchBg") :: ImageLabel, wrapper)
	for _, entry in
		{
			{ button = "includeBtn", state = AnimalShopState.includeOwned, label = "OWNED" },
			{ button = "offsaleBtn", state = AnimalShopState.includeOffsale, label = "OFFSALE" },
		}
	do
		local button: ImageButton = top:WaitForChild(entry.button)
		local label = button:WaitForChild("TitleText") :: TextLabel
		-- Read once: a toggle mid-fade must not adopt the partly faded value as its rest.
		local transparency = label.TextTransparency
		_scope:Hydrate(label)({
			Text = _scope:Computed(function(use)
				return `{if use(entry.state) then "HIDE" else "INCLUDE"} {entry.label}`
			end),
		})
		button.Activated:Connect(function()
			entry.state:set(not Fusion.peek(entry.state))
			Private._crossfade(label, transparency)
		end)
	end
end

function Private._bindGui(): ()
	local playerGui: PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui: ScreenGui = playerGui:WaitForChild("AnimalShopGui")
	local previewGui = playerGui:WaitForChild("AnimalPreviewGui") :: ScreenGui
	local openPreview = AnimalPreview.bind(_scope, previewGui, gui)
	local wrapper: Frame = gui:WaitForChild("Wrapper")
	local content = wrapper:WaitForChild("Content")
	local scrollingFrame: ScrollingFrame = content:WaitForChild("shopContainer"):WaitForChild("ScrollingFrame")
	local cards: { Frame } = {}
	for _, child in scrollingFrame:GetChildren() do
		if child:IsA("Frame") then
			table.insert(cards, child)
		end
	end
	table.sort(cards, function(a, b)
		return a.Name < b.Name
	end)
	for name, config in AnimalShopConfig do
		local card = cards[config.order] or cards[1]:Clone()
		AnimalCard.bind(_scope, card, name, openPreview, wrapper)
		card.Parent = scrollingFrame
	end
	Private._bindToolbar(content:WaitForChild("top"), wrapper)
	PopupUtils.BindHeader(wrapper)

	local closeButton: ImageButton = wrapper:WaitForChild("Elements"):WaitForChild("CloseBTN")
	closeButton.Activated:Connect(function()
		PopupUtils.HidePopup(gui)
	end)
	local menuGui: ScreenGui = playerGui:WaitForChild("AnimalMenuGui")
	menuGui:WaitForChild("OpenAnimals").Activated:Connect(function()
		PopupUtils.ShowPopup(gui)
	end)
	menuGui.Enabled = true
	if PopupUtils.GetCurrentPopup() then
		PopupUtils.HideAllGuis()
	end
end

function Shared.OnStart(): ()
	DataService:waitForData()
	for _, path in { { "Animals" }, { "Inventory" }, { "PlayerStats", "Nova" } } do
		DataService:getChangedSignal(path):Connect(Private._readData)
	end
	_animals.ChildAdded:Connect(Private._readAvailable)
	_animals.ChildRemoved:Connect(Private._readAvailable)
	Private._readData()
	Private._readAvailable()
	Private._bindGui()
end

return Shared
