--!strict
local _players = game:GetService("Players")
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _runService = game:GetService("RunService")
local _userInputService = game:GetService("UserInputService")

local _packages = _replicatedStorage.Packages
local _networkerModule = require(_packages.Networker)
local _troveModule = require(_packages.Trove)
local _timer = require(_packages.Timer)
local _cartTypes = require(_replicatedStorage.Shared.types.CartTypes)

local _cartConfig = require(_replicatedStorage.Shared.config.CartConfig)
local _characterUtils = require(_replicatedStorage.Shared.utils.CharacterUtils)
local _throttle = require(_replicatedStorage.Shared.utils.Throttle)
local _network = require(_replicatedStorage.Shared.network.CartNetwork)
local _keybindUtils = require(script.Parent.Parent.utils.KeybindUtils)
local states = require(script.Parent.Parent.states)

type networkerClient = _networkerModule.Client

type pullerEntry = _cartTypes.pullerEntry
type ropeVisual = {
	ropeAttachment: Attachment,
	characterAttachment: Attachment,
	beam: Beam,
	lastStrain: number,
}

local _ropeColor = Color3.fromRGB(139, 90, 43)
local _ropeStrainColor = Color3.fromRGB(200, 60, 40)
local _sagUpdateInterval = 1 / 30

local _networker: networkerClient? = nil

local function _getNetworker(): networkerClient
	return assert(_networker, "Cart networking has not started")
end
local _trove = _troveModule.new()
local _ropeTrove = _trove:Extend()
local _inputTrove = _trove:Extend()
local _sagTrove = _trove:Extend()
local _ropes: { ropeVisual } = {}

local PlayerActionState = states.PlayerActionState

local cartPullController = {
	pullers = {} :: { pullerEntry },
}

local function _createRopeVisual(ropePart: BasePart, root: BasePart): ()
	local ropeAttachment: Attachment = _ropeTrove:Add(Instance.new("Attachment"))
	ropeAttachment.Parent = ropePart

	local characterAttachment: Attachment = _ropeTrove:Add(Instance.new("Attachment"))
	characterAttachment.Parent = root

	local beam: Beam = _ropeTrove:Add(Instance.new("Beam"))
	beam.Attachment0 = ropeAttachment
	beam.Attachment1 = characterAttachment
	beam.Width0 = 0.12
	beam.Width1 = 0.12
	beam.Segments = 12
	beam.Color = ColorSequence.new(_ropeColor)
	beam.FaceCamera = true
	beam.Parent = workspace

	table.insert(_ropes, {
		ropeAttachment = ropeAttachment,
		characterAttachment = characterAttachment,
		beam = beam,
		lastStrain = 0,
	})

	PlayerActionState.RopeEquipped:set(true)
end

local function _updateSag(): ()
	for _, rope in _ropes do
		local dist: number = (rope.ropeAttachment.WorldPosition - rope.characterAttachment.WorldPosition).Magnitude
		local slack: number = math.clamp(1 - dist / _cartConfig.tautDistance, 0, 1)
		local curve: number = 0.2 + _cartConfig.ropeSagMax * slack
		rope.beam.CurveSize0 = curve
		rope.beam.CurveSize1 = curve

		local strain: number = math.clamp(
			(dist - _cartConfig.surgeDistance) / (_cartConfig.maxRopeDistance - _cartConfig.surgeDistance),
			0,
			1
		)
		if math.abs(strain - rope.lastStrain) > 0.05 or (strain == 0 and rope.lastStrain ~= 0) then
			rope.lastStrain = strain
			rope.beam.Color = ColorSequence.new(_ropeColor:Lerp(_ropeStrainColor, strain))
		end
	end
end

function cartPullController:_rebuildRopes(): ()
	_ropeTrove:Clean()
	_sagTrove:Clean()
	table.clear(_ropes)

	for _, entry in cartPullController.pullers do
		if not entry.player or not entry.ropePart then continue end
		local root: BasePart? = _characterUtils.getPlayerRoot(entry.player)
		if root then
			_createRopeVisual(entry.ropePart, root)
		else
			local character: Model? = entry.player.Character
			if character then
				_ropeTrove:Connect(character.ChildAdded, function(child: Instance): ()
					if child.Name == "HumanoidRootPart" then cartPullController:_rebuildRopes() end
				end)
			end
			_ropeTrove:Connect(entry.player.CharacterAdded, function(): ()
				cartPullController:_rebuildRopes()
			end)
		end
	end

	if #_ropes > 0 then
		local step = _throttle.new(_sagUpdateInterval)
		_sagTrove:Connect(_runService.RenderStepped, function(dt: number): ()
			if step(dt) then
				_updateSag()
			end
		end)
	end
end

function cartPullController:isLocalPlayerPulling(): boolean
	local localPlayer = _players.LocalPlayer
	for _, entry in cartPullController.pullers do
		if entry.player == localPlayer then
			return true
		end
	end
	return false
end

local function _sendPullInput(): ()
	if not cartPullController:isLocalPlayerPulling() then PlayerActionState.RopeEquipped:set(false) return end
	local character: Model? = _players.LocalPlayer.Character
	local humanoid: Humanoid? = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local isMoving: boolean = humanoid ~= nil and humanoid.MoveDirection.Magnitude > _cartConfig.moveInputThreshold
	_getNetworker():fire("setPullInput", isMoving)
end

function cartPullController:_refreshPullInput(): ()
	_inputTrove:Clean()
	if not self:isLocalPlayerPulling() then PlayerActionState.RopeEquipped:set(false) return end

	-- Refresh unchanged intent so the server can expire input from a stalled client.
	local inputTimer = _inputTrove:Add(_timer.new(_cartConfig.pullInputInterval))
	_inputTrove:Connect(inputTimer.Tick, _sendPullInput)
	_sendPullInput()
	inputTimer:Start()
end

function cartPullController:OnStart(): ()
	_networker = _networkerModule.client.new(_network.cartPull, cartPullController)

	_trove:Connect(_getNetworker():getServerChangedSignal("pullers"), function(): ()
		cartPullController:_refreshPullInput()
		cartPullController:_rebuildRopes()
	end)
	_getNetworker():fire("requestPullers")
	_trove:Connect(_userInputService.JumpRequest, function(): ()
		if cartPullController:isLocalPlayerPulling() then
			_getNetworker():fire("releaseRope")
		end
	end)

	_trove:Connect(_keybindUtils.getSignal("releaseRope"), function(inputState: Enum.UserInputState): ()
		if inputState ~= Enum.UserInputState.Begin then return end
		if not cartPullController:isLocalPlayerPulling() then return end
		_getNetworker():fire("releaseRope")
	end)

	_trove:Connect(_keybindUtils.getSignal("unstuckCart"), function(inputState: Enum.UserInputState): ()
		if inputState ~= Enum.UserInputState.Begin then return end
		if not cartPullController:isLocalPlayerPulling() then return end
		_getNetworker():fire("unstuckCart")
	end)
end

export type cartPullController = typeof(cartPullController)
return cartPullController
