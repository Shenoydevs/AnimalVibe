--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Trove = require(ReplicatedStorage.Packages.Trove)
local config = require(ReplicatedStorage.Shared.config)
local states = require(script.Parent.Parent.states)
local network = require(script.Parent.Parent.network)
local utils = require(script.Parent.Parent.utils)

local PartyState = states.PartyState
local PartyNetwork = network.PartyNetwork
local PartyConfig = config.PartyConfig
local PopupUtils = utils.PopupUtils

local _switchPosition = {
	Enabled = UDim2.fromScale(0.734, 0.5),
	Disabled = UDim2.fromScale(0.320, 0.5),
}
local _baseColor = {
	Enabled = ColorSequence.new(Color3.fromHex("#ffde9f")),
	Disabled = ColorSequence.new(Color3.fromHex("#16130e")),
}

local _player = Players.LocalPlayer
local _partyConfigGui = _player.PlayerGui:WaitForChild("PartyConfigGui")

local _wrapper = _partyConfigGui.Wrapper
local _content = _wrapper.Content
local _elements = _wrapper.Elements
local _closeButton = _elements.CloseBTN.Hitbox
local _cancellingTimer = _content.CancellingTimer
local _playerAmountFrame = _content.PlayerAmnt
local _addButton = _playerAmountFrame.AddBTN.Hitbox
local _minusButton = _playerAmountFrame.MinusBTN.Hitbox
local _playerAmount = _playerAmountFrame.AmntBase.PlayerAmnt
local _privateModeFrame = _content.PrivateMode
local _privateModeButton = _privateModeFrame.ToggleButton
local _createPartyButton = _content.CreatePartyBTN.Hitbox
local _exitButton = _partyConfigGui.ExitWrapper.ExitBTN

local _scope = Fusion.scoped(Fusion)
local _sessionTrove = Trove.new()

local Private = {}
local Shared = {}

function Shared.OnStart()
	PartyNetwork.handlers._openPartyConfig = Private._openPartyConfig
	PartyNetwork.handlers._onPartyCancelled = Private._onPartyCancelled
	PartyNetwork.handlers._onJoinedParty = Private._onJoinedParty
	PartyNetwork.handlers._onLeftParty = Private._onLeftParty

	_scope:Hydrate(_cancellingTimer)({
		Text = _scope:Computed(function(use)
			return `CANCELLING CREATION IN {tostring(use(PartyState.TimeLeft))} SECONDS`
		end),
	})

	_scope:Hydrate(_playerAmount)({
		Text = _scope:Computed(function(use)
			return tostring(use(PartyState.PlayerCount))
		end),
	})

	local _switchPositionGoal = _scope:Computed(function(use)
		return use(PartyState.PrivateMode) and _switchPosition.Enabled or _switchPosition.Disabled
	end)

	_scope:Hydrate(_privateModeButton.Switch)({
		Position = _scope:Spring(_switchPositionGoal, 20, 1),
	})

	_scope:Hydrate(_privateModeButton.Glow)({
		Transparency = _scope:Computed(function(use)
			return use(PartyState.PrivateMode) and NumberSequence.new(0) or NumberSequence.new(1)
		end),
	})

	_scope:Hydrate(_privateModeButton.Base.UIGradient)({
		Color = _scope:Computed(function(use)
			return use(PartyState.PrivateMode) and _baseColor.Enabled or _baseColor.Disabled
		end),
	})

	_addButton.Activated:Connect(Private._onAddPlayer)
	_minusButton.Activated:Connect(Private._onRemovePlayer)
	_privateModeButton.Activated:Connect(Private._onTogglePrivateMode)
	_createPartyButton.Activated:Connect(Private._onCreateParty)
end

function Private._onAddPlayer()
	local current = Fusion.peek(PartyState.PlayerCount)
	if current < PartyConfig.MaxPlayers then
		PartyState.PlayerCount:set(current + 1)
	end
end

function Private._onRemovePlayer()
	local current = Fusion.peek(PartyState.PlayerCount)
	if current > PartyConfig.MinPlayers then
		PartyState.PlayerCount:set(current - 1)
	end
end

function Private._onCreateParty()
	local playerCount = Fusion.peek(PartyState.PlayerCount)
	local privateMode = Fusion.peek(PartyState.PrivateMode)

	_sessionTrove:Clean()
	PopupUtils.HidePopup(_partyConfigGui)

	PartyNetwork.fire("_configure", playerCount, privateMode)
end

function Private._onTogglePrivateMode()
	PartyState.PrivateMode:set(not Fusion.peek(PartyState.PrivateMode))
end

function Private._openPartyConfig(_: any, duration: number)
	_sessionTrove:Clean()

	PartyState.TimeLeft:set(duration)
	PartyState.PlayerCount:set(PartyConfig.MaxPlayers)
	PartyState.PrivateMode:set(true)

	local cancelled = false

	_sessionTrove:Add(function()
		cancelled = true
		PartyState.TimeLeft:set(0)
		PartyState.PlayerCount:set(PartyConfig.MaxPlayers)
		PartyState.PrivateMode:set(true)
	end)

	task.spawn(function()
		while Fusion.peek(PartyState.TimeLeft) > 0 do
			task.wait(1)

			if cancelled then
				break
			end

			PartyState.TimeLeft:set(Fusion.peek(PartyState.TimeLeft) - 1)
		end
	end)

	_sessionTrove:Connect(_closeButton.Activated, Private._onClose)

	PopupUtils.ShowPopup(_partyConfigGui):andThen(function()
		_exitButton.Visible = true
	end)
end

function Private._onClose()
	_sessionTrove:Clean()
	_exitButton.Visible = false
	PopupUtils.HidePopup(_partyConfigGui):andThen(function()
		PartyNetwork.fire("_closeParty")
	end)
end

function Private._onPartyCancelled(_: any)
	_sessionTrove:Clean()
	_exitButton.Visible = false
	PopupUtils.HidePopup(_partyConfigGui)
end

function Private._onJoinedParty(_: any)
	PartyState.InParty:set(true)
end

function Private._onLeftParty(_: any)
	PartyState.InParty:set(false)
	_exitButton.Visible = false
end

return Shared
