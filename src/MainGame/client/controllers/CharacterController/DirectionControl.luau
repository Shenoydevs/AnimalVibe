--!strict
local DirectionControl = {}

local TURN_RESPONSIVENESS = 10000
local MAX_TURN_SPEED = math.rad(600)
local TURN_TWEEN_SPEED = 7
local MAX_HEAD_ANGLE = math.rad(55)
local HEAD_RESPONSE = 8

local _humanoid: Humanoid?
local _root: BasePart?
local _head: Bone?
local _rx, _ry, _rz
local _attachment: Attachment?
local _alignOrientation: AlignOrientation?
local _smoothedOrientation: CFrame
local _headYaw = 0
local _headPitch = 0
local _previousAutoRotate = true

function DirectionControl:Init(character: Model, humanoid: Humanoid): ()
	if _alignOrientation then
		_alignOrientation:Destroy()
		_alignOrientation = nil
	end
	if _attachment then
		_attachment:Destroy()
		_attachment = nil
	end
	if _humanoid then
		_humanoid.AutoRotate = _previousAutoRotate
	end

	_humanoid = humanoid
	_previousAutoRotate = humanoid.AutoRotate
	_root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = character.Body:FindFirstChild("Head", true)
	_head = if head and head:IsA("Bone") then head else nil
	_headYaw = 0
	_headPitch = 0

	local root = _root
	if not root then
		warn(`[DirectionControl] {character.Name} is missing HumanoidRootPart; smooth turning is disabled`)
		humanoid.AutoRotate = _previousAutoRotate
		return
	end

	if not _head then
		warn(`[DirectionControl] {character.Name} is missing the Head.001 or Head bone; head tracking is disabled`)
	else
		_rx, _ry, _rz = _head.CFrame:ToOrientation()
	end

	humanoid.AutoRotate = false
	local attachment = Instance.new("Attachment")
	attachment.Name = "DirectionControlAttachment"
	attachment.Parent = root
	_attachment = attachment

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "DirectionControlAlignOrientation"
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.Responsiveness = TURN_RESPONSIVENESS
	alignOrientation.MaxAngularVelocity = MAX_TURN_SPEED
	alignOrientation.MaxTorque = 1000000
	alignOrientation.RigidityEnabled = false
	alignOrientation.Parent = root
	_smoothedOrientation = CFrame.lookAt(root.Position, root.Position + root.CFrame.LookVector, Vector3.yAxis)
	alignOrientation.CFrame = _smoothedOrientation
	_alignOrientation = alignOrientation
end

function DirectionControl:Tick(deltaTime: number): ()
	local humanoid = _humanoid
	local root = _root
	if not humanoid or not root or not root.Parent then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local localCameraPosition = root.CFrame:PointToObjectSpace(camera.CFrame.Position)
	local targetYaw = 0
	local targetPitch = 0

	if localCameraPosition.Z >= 0 or localCameraPosition.Z >= -10 then
		local localLookDirection = root.CFrame:VectorToObjectSpace(camera.CFrame.LookVector)
		targetYaw = math.atan2(localLookDirection.X, -localLookDirection.Z)
		targetPitch = math.asin(math.clamp(localLookDirection.Y, -1, 1))
	end

	local targetMagnitude = math.sqrt(targetYaw * targetYaw + targetPitch * targetPitch)
	if targetMagnitude > MAX_HEAD_ANGLE then
		local scale = MAX_HEAD_ANGLE / targetMagnitude
		targetYaw *= scale
		targetPitch *= scale
	end

	local blend = 1 - math.exp(-deltaTime * HEAD_RESPONSE)
	_headYaw += (targetYaw - _headYaw) * blend
	_headPitch += (targetPitch - _headPitch) * blend

	local moveDirection = humanoid.MoveDirection
	if moveDirection.Magnitude > 0.05 then
		local horizontalDirection = Vector3.new(moveDirection.X, 0, moveDirection.Z).Unit
		local alignOrientation = _alignOrientation
		if alignOrientation then
			local targetOrientation = CFrame.lookAt(root.Position, root.Position + horizontalDirection, Vector3.yAxis)
			local turnBlend = 1 - math.exp(-deltaTime * TURN_TWEEN_SPEED)
			_smoothedOrientation = _smoothedOrientation:Lerp(targetOrientation, turnBlend)
			alignOrientation.CFrame = _smoothedOrientation
		end
	end

	local head = _head
	if head and head.Parent then
		head.CFrame = CFrame.new(head.CFrame.Position)
			* CFrame.Angles(_rx, _ry, _rz)
			* CFrame.Angles(-_headYaw, 0, -_headPitch)
	end
end

export type DirectionControl = typeof(DirectionControl)
return DirectionControl
