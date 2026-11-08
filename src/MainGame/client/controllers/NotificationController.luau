--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Trove = require(Packages.Trove)
local WaitFor = require(Packages.WaitFor)

local NotificationConfig = require(ReplicatedStorage.Shared.config.NotificationConfig)
local NotificationNetwork = require(ReplicatedStorage.Shared.network.NotificationNetwork)
local NotificationTypes = require(ReplicatedStorage.Shared.types.NotificationTypes)

type NotificationKind = NotificationTypes.NotificationKind
type NotificationPayload = NotificationTypes.NotificationPayload
type TransitionPayload = NotificationTypes.TransitionPayload

local MAX_QUEUE: number = NotificationConfig.maxQueue

type Notification = {
	message: string,
	duration: number,
	priority: number,
	kind: NotificationKind,
}

local _queue: { Notification } = {}
local _current: Notification? = nil
local _currentPriority: number = 0

local _dismissTrove = Trove.new()
local _transitionTrove = Trove.new()

local _notificationFrame: Frame? = nil
local _titleText: TextLabel? = nil
local _descriptionText: TextLabel? = nil

local _transitionFrame: Frame? = nil
local _transitionText: TextLabel? = nil

local NotificationController = {
	PRIORITY_HIGH = NotificationConfig.priority.high,
	PRIORITY_MED = NotificationConfig.priority.med,
	PRIORITY_LOW = NotificationConfig.priority.low,
}

local function _getPlayerGui(): PlayerGui
	return Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
end

local function _resolveToast(): ()
	local playerGui: PlayerGui = _getPlayerGui()
	WaitFor.Descendant(playerGui, "Notification")
		:andThen(function(notification: Instance)
			_notificationFrame = notification :: Frame
			(notification :: Frame).Visible = false
			return WaitFor.Child(notification, "notificationBG")
		end)
		:andThen(function(bg: Instance)
			return WaitFor.Children(bg, { "TitleText", "descriptionText" })
		end)
		:andThen(function(labels: { Instance })
			_titleText = labels[1] :: TextLabel
			_descriptionText = labels[2] :: TextLabel
		end)
		:catch(warn)
end

local function _buildTransitionUI(): ()
	local playerGui: PlayerGui = _getPlayerGui()
	local transitionConfig = NotificationConfig.transition

	local screenGui: ScreenGui = Instance.new("ScreenGui")
	screenGui.Name = "NotificationTransition"
	screenGui.DisplayOrder = 100
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false

	local frame: Frame = Instance.new("Frame")
	frame.Name = "TransitionFrame"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = transitionConfig.backgroundColor
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 100
	frame.Parent = screenGui

	local text: TextLabel = Instance.new("TextLabel")
	text.Name = "TransitionText"
	text.Size = UDim2.fromScale(0.8, 0.2)
	text.Position = UDim2.fromScale(0.1, 0.4)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = transitionConfig.textColor
	text.TextTransparency = 1
	text.Text = ""
	text.ZIndex = 101
	text.Parent = frame

	screenGui.Parent = playerGui

	_transitionFrame = frame
	_transitionText = text
end

local function _hide(): ()
	if _notificationFrame then
		_notificationFrame.Visible = false
	end
	_current = nil
	_currentPriority = 0
end

local _showImpl: (n: Notification) -> ()

_showImpl = function(n: Notification): ()
	local frame: Frame? = _notificationFrame
	if not frame then return end

	_dismissTrove:Clean()
	_current = n
	_currentPriority = n.priority

	local style = NotificationConfig.styles[n.kind]
	if _titleText and style then
		_titleText.Text = style.title
		_titleText.TextColor3 = style.titleColor
	end
	if _descriptionText then
		_descriptionText.Text = n.message
		_descriptionText.TextColor3 = NotificationConfig.descriptionColor
	end
	frame.Visible = true

	local thread: thread = nil :: any
	thread = task.delay(n.duration, function()
		_dismissTrove:Pop(thread)
		_hide()
		if #_queue > 0 then
			local nextNotification: Notification = table.remove(_queue, 1) :: Notification
			_showImpl(nextNotification)
		end
	end)
	_dismissTrove:Add(thread)
end

-- Index and priority of the lowest-priority queued notification.
local function _lowestPriorityQueued(): (number?, number)
	local lowestIdx: number? = nil
	local lowestPri: number = math.huge
	for i, item in _queue do
		if item.priority < lowestPri then
			lowestPri = item.priority
			lowestIdx = i
		end
	end
	return lowestIdx, lowestPri
end

function NotificationController:push(message: string, duration: number, priority: number, kind: NotificationKind): ()
	if _current then
		if priority > _currentPriority then
			local displaced: Notification = {
				message = (_current :: Notification).message,
				duration = (_current :: Notification).duration,
				priority = _currentPriority,
				kind = (_current :: Notification).kind,
			}
			table.insert(_queue, 1, displaced)
			if #_queue > MAX_QUEUE then
				local lowestIdx: number? = _lowestPriorityQueued()
				table.remove(_queue, lowestIdx or 1)
			end
			_showImpl({ message = message, duration = duration, priority = priority, kind = kind })
		else
			if #_queue >= MAX_QUEUE then
				local lowestIdx: number?, lowestPri: number = _lowestPriorityQueued()
				if lowestIdx ~= nil and lowestPri < priority then
					table.remove(_queue, lowestIdx :: number)
				else
					return
				end
			end
			local insertIdx: number = #_queue + 1
			for i, item in _queue do
				if priority > item.priority then
					insertIdx = i
					break
				end
			end
			table.insert(_queue, insertIdx, { message = message, duration = duration, priority = priority, kind = kind })
		end
	else
		_showImpl({ message = message, duration = duration, priority = priority, kind = kind })
	end
end

function NotificationController:playTransition(message: string, duration: number): ()
	local frame: Frame? = _transitionFrame
	local text: TextLabel? = _transitionText
	if not frame or not text then return end

	_transitionTrove:Clean()

	local fadeTime: number = NotificationConfig.transition.fadeTime
	text.Text = message
	frame.Visible = true
	TweenService:Create(frame, TweenInfo.new(fadeTime), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(text, TweenInfo.new(fadeTime), { TextTransparency = 0 }):Play()

	local thread: thread = nil :: any
	thread = task.delay(fadeTime + duration, function()
		_transitionTrove:Pop(thread)
		local fadeOutFrame = TweenService:Create(frame, TweenInfo.new(fadeTime), { BackgroundTransparency = 1 })
		local fadeOutText = TweenService:Create(text, TweenInfo.new(fadeTime), { TextTransparency = 1 })
		fadeOutFrame:Play()
		fadeOutText:Play()
		fadeOutFrame.Completed:Wait()
		frame.Visible = false
	end)
	_transitionTrove:Add(thread)
end

function NotificationController:onNotification(payload: NotificationPayload): ()
	NotificationController:push(payload.message, payload.duration, payload.priority, payload.kind)
end

function NotificationController:onTransition(payload: TransitionPayload): ()
	NotificationController:playTransition(payload.message, payload.duration)
end

function NotificationController:OnStart(): ()
	_resolveToast()
	_buildTransitionUI()
	Networker.client.new(NotificationNetwork.Notification, NotificationController)
end

export type NotificationController = typeof(NotificationController)
return NotificationController
