--!strict
local LegIKControl = {}

type GroundEffector = {
	bone: Bone,
	chainRoot: Bone,
	control: IKControl,
	target: Part,
	poleJoint: Bone?,
	poleTarget: Part?,
}

local RAY_ORIGIN_HEIGHT = 2
local RAY_LENGTH = 5
local FOOT_CLEARANCE = 0.1
local POLE_DISTANCE_MULTIPLIER = 1
local MIN_POLE_DISTANCE = 0.5

local _effectors: { GroundEffector } = {}
local _character: Model?
local _bearLegsBendForward = false
local _raycastParams = RaycastParams.new()
_raycastParams.FilterType = Enum.RaycastFilterType.Exclude
_raycastParams.IgnoreWater = true

local function findBone(parent: Instance, name: string, side: string): Bone?
	local sidedName = string.lower(`{name}.{side}`)
	local unsidedName = string.lower(name)
	for _, child in parent:GetChildren() do
		if child:IsA("Bone") then
			local childName = string.lower(child.Name)
			if childName == sidedName or childName == unsidedName then
				return child
			end
		end
	end

	return nil
end

local function clearLegs(): ()
	for _, effector in _effectors do
		effector.control:Destroy()
		effector.target:Destroy()
		if effector.poleTarget then
			effector.poleTarget:Destroy()
		end
	end
	table.clear(_effectors)
end

local function createTarget(name: string): Part
	local target = Instance.new("Part")
	target.Name = name
	target.Anchored = true
	target.CanCollide = false
	target.CanQuery = false
	target.CanTouch = false
	target.CastShadow = false
	target.Transparency = .5
	target.Size = Vector3.one
	target.Parent = workspace
	return target
end

local function addGroundControl( humanoid: Humanoid, chainRoot: Bone, endEffector: Bone, name: string, poleJoint: Bone): Part
	local index = #_effectors + 1
	local target = createTarget(`GroundIKTarget{index}`)
	local poleTarget = createTarget(`GroundIKPole{index}`)

	local control = Instance.new("IKControl")
	control.Name = name
	control.Type = Enum.IKControlType.Transform
	control.ChainRoot = chainRoot
	control.EndEffector = endEffector
	control.Target = target
	control.Pole = poleTarget
	control.Enabled = false
	control.Parent = humanoid
	control.SmoothTime = 0.1
	control.Weight = 0.35

	table.insert(_effectors, {
		bone = endEffector,
		chainRoot = chainRoot,
		control = control,
		target = target,
		poleJoint = poleJoint,
		poleTarget = poleTarget,
	})

	return target
end

function LegIKControl:Init(character: Model, humanoid: Humanoid): ()
	clearLegs()
	_character = character
	_bearLegsBendForward = character:GetAttribute("animalClass") == "Bear"

	local hips = character:FindFirstChild("Hips", true)
	if not hips or not hips:IsA("Bone") then
		warn(`[LegIKControl] {character.Name} is missing the Hips bone`)
	else
		local legCount = 0
		for _, upperLeg in hips:GetChildren() do
			if not upperLeg:IsA("Bone") then
				continue
			end

			local sideToken = string.match(string.lower(upperLeg.Name), "^upperleg%.([lr])$")
			if not sideToken then
				continue
			end
			local side = if sideToken == "l" then "L" else "R"
			local lowerLeg = findBone(upperLeg, "LowerLeg", side)
			local foot = if lowerLeg then findBone(lowerLeg, "Foot", side) else nil
			if not lowerLeg or not foot then
				warn(`[LegIKControl] {character.Name} has an incomplete leg chain under {upperLeg:GetFullName()}`)
				continue
			end

			legCount += 1
			addGroundControl(humanoid, upperLeg, foot, `LegIK.{side}`, lowerLeg)
		end

		if legCount == 0 then
			warn(`[LegIKControl] {character.Name} has no complete Hips -> UpperLeg -> LowerLeg -> Foot chains`)
		end
	end

	local filterInstances: { Instance } = { character }
	for _, effector in _effectors do
		table.insert(filterInstances, effector.target)
		if effector.poleTarget then
			table.insert(filterInstances, effector.poleTarget)
		end
	end
	_raycastParams.FilterDescendantsInstances = filterInstances
end

function LegIKControl:Tick(): ()
	local character = _character
	if not character then
		return
	end

	for _, effector in _effectors do
		local rayOrigin = effector.bone.WorldCFrame.Position + Vector3.yAxis * RAY_ORIGIN_HEIGHT
		local result = workspace:Raycast(rayOrigin, Vector3.yAxis * -RAY_LENGTH, _raycastParams)

		if not result then
			effector.control.Enabled = false
			continue
		end

		local targetPosition = result.Position + result.Normal * FOOT_CLEARANCE
		effector.target.Position = targetPosition

		if effector.poleTarget and effector.poleJoint then
			local chainRootPosition = effector.chainRoot.WorldCFrame.Position
			local targetDirection = effector.target.Position - chainRootPosition
			if targetDirection.Magnitude > 0.001 then
				local axis = targetDirection.Unit
				local pivot = character:GetPivot()
				local preferredBendDirection = if _bearLegsBendForward then pivot.LookVector else pivot.ZVector
				local bendDirection = preferredBendDirection - axis * preferredBendDirection:Dot(axis)
				if bendDirection.Magnitude < 0.001 then
					local right = pivot.RightVector
					bendDirection = right - axis * right:Dot(axis)
				end

				if bendDirection.Magnitude > 0.001 then
					local kneePosition = effector.poleJoint.WorldCFrame.Position
					local poleDistance = math.max(
						(kneePosition - chainRootPosition).Magnitude * POLE_DISTANCE_MULTIPLIER,
						MIN_POLE_DISTANCE
					)
					effector.poleTarget.Position = chainRootPosition + bendDirection.Unit * poleDistance
				end
			end
		end
		effector.control.Enabled = true
	end
end

export type LegIKControl = typeof(LegIKControl)
return LegIKControl
