--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local types = require(ReplicatedStorage.Shared.types)
local Throttle = require(ReplicatedStorage.Shared.utils.Throttle)

type NetworkerClient = types.NetworkerClient

local TILT_SEND_INTERVAL = 1 / 20

local TiltControl = {}

local _character: Model
local _networker: NetworkerClient
local _tiltController: BasePart
local _tiltBone: Bone
local _tiltRotation = CFrame.identity
local _tiltRotators: { [Player]: CFrame } = {}
local _sendTilt: Throttle.Stepper = Throttle.new(TILT_SEND_INTERVAL)

local _raycastParams = RaycastParams.new()
_raycastParams.FilterType = Enum.RaycastFilterType.Exclude
_raycastParams.IgnoreWater = true

function TiltControl:Tick(dt: number): ()
	_tiltController.CFrame = _character:GetPivot()

	local targetTilt = CFrame.identity
	local normalRay = workspace:Raycast(_tiltController.Position, _tiltController.CFrame.UpVector * -5, _raycastParams)
	if normalRay then
		local vector = _tiltController.CFrame:VectorToObjectSpace(normalRay.Normal)
		targetTilt = CFrame.Angles(vector.Z, 0, -vector.X/2)
	end

	local blend = 1 - math.exp(-dt * 15)
	_tiltRotation = _tiltRotation:Lerp(targetTilt, blend)
	_tiltController.CFrame = _tiltController.CFrame * _tiltRotation
	_tiltBone.Transform = CFrame.new() * _tiltRotation
	if _sendTilt(dt) then
		_networker:fire("UpdateTilt", _tiltRotation)
	end

	for plr, tiltRotation in _tiltRotators do
		if plr == nil or not plr.Character then
			_tiltRotators[plr] = nil
			continue
		end
		local theirTiltBone = plr.Character:FindFirstChild("Bone.001", true)
		if theirTiltBone then
			theirTiltBone.Transform = CFrame.new() * tiltRotation
		end
	end
end

function TiltControl:OnUpdateTilt(player: Player, tiltRotation: CFrame): ()
	if not player.Character then return end
	_tiltRotators[player] = tiltRotation
end

function TiltControl:Init(character: Model, networker: NetworkerClient): ()
	_character = character
	_networker = networker

	local tiltController = ReplicatedStorage.Assets:FindFirstChild("TiltController", true):Clone()
	tiltController.Parent = character
	_tiltController = tiltController :: BasePart

	local tiltBone = character:FindFirstChild("Bone.001", true)
	assert(tiltBone and tiltBone:IsA("Bone"), `[TiltControl] {character.Name} is missing Bone.001`)
	_tiltBone = tiltBone

	_tiltRotation = CFrame.identity
	_tiltRotators = {}
	_raycastParams.FilterDescendantsInstances = { character }
end

export type TiltControl = typeof(TiltControl)
return TiltControl
