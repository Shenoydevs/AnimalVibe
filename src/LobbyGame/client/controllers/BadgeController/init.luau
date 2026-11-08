--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ReplicatedStorage.Packages.DataService).client
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local BadgeConfig = require(ReplicatedStorage.Common.config.BadgeConfig)
local BadgeState = require(script.Parent.Parent.states.BadgeState)
local PopupUtils = require(script.Parent.Parent.utils.PopupUtils)
local BadgeDetails = require(script.BadgeDetails)
local BadgeList = require(script.BadgeList)
local BadgeProgress = require(script.BadgeProgress)

local _scope = Fusion.scoped(Fusion)

local Private = {}
local Shared = {}

function Private._readData(badges)
	-- DataService mutates nested tables in place; Fusion receives its own snapshot.
	BadgeState.earned:set(table.clone(badges.earned))
	BadgeState.equippedId:set(badges.equippedId)
end

function Private._bindGui()
	local playerGui: PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui: ScreenGui = playerGui:WaitForChild("BadgeGui")
	local wrapper: Frame = gui:WaitForChild("Wrapper")

	local content: Frame = wrapper:WaitForChild("Content")
	local categories: CanvasGroup = content:WaitForChild("Categories")
	local scrollingFrame: ScrollingFrame = categories:WaitForChild("ScrollingFrame")
	local groupTemplate: Frame = ReplicatedStorage.Assets.GUIs:WaitForChild("Badges"):WaitForChild("Group")
	for order, rarity in BadgeConfig.rarities do
		BadgeList.createGroup(_scope, groupTemplate, rarity, order, scrollingFrame, wrapper)
	end
	PopupUtils.BindHeader(wrapper)
	BadgeDetails.bind(_scope, wrapper)
	BadgeProgress.bind(_scope, wrapper, content:WaitForChild("Bottom"))

	local closeButton: ImageButton = wrapper:WaitForChild("Elements"):WaitForChild("CloseBTN")
	closeButton.Activated:Connect(function()
		PopupUtils.HidePopup(gui)
	end)

	local menuGui: ScreenGui = playerGui:WaitForChild("BadgeMenuGui")
	menuGui:WaitForChild("OpenBadges").Activated:Connect(function()
		PopupUtils.ShowPopup(gui)
	end)
	menuGui.Enabled = true
	if PopupUtils.GetCurrentPopup() then
		PopupUtils.HideAllGuis()
	end
end

function Shared.OnStart()
	DataService:waitForData()
	DataService:getChangedSignal({ "badges" }):Connect(Private._readData)
	Private._readData((DataService:get({ "badges" })))
	local equippedId = Fusion.peek(BadgeState.equippedId)
	if BadgeConfig.badges[equippedId] then
		BadgeState.selectedId:set(equippedId)
	end
	Private._bindGui()
end

return Shared
