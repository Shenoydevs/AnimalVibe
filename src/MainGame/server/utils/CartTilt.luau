--!strict
local _players = game:GetService("Players")
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _cartConfig = require(_replicatedStorage.Shared.config.CartConfig)

local cartTilt = {}
cartTilt.__index = cartTilt

export type cartTilt = typeof(setmetatable({} :: {
	_model: Model,
	_primaryPart: BasePart,
	_raycastParams: RaycastParams,
	_sampleOffsets: { Vector3 },
	_normal: Vector3,
	_rotation: CFrame,
	_elapsed: number,
}, cartTilt))

function cartTilt.new(model: Model): cartTilt
	local primaryPart: BasePart? = model.PrimaryPart
	assert(primaryPart, "Cart tilt requires a PrimaryPart")
	local halfSize: Vector3 = primaryPart.Size * _cartConfig.tiltSampleInset
	local raycastParams: RaycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true
	raycastParams.RespectCanCollide = true
	return setmetatable({
		_model = model,
		_primaryPart = primaryPart,
		_raycastParams = raycastParams,
		_sampleOffsets = {
			Vector3.zero,
			Vector3.new(-halfSize.X, 0, -halfSize.Z),
			Vector3.new(halfSize.X, 0, -halfSize.Z),
			Vector3.new(-halfSize.X, 0, halfSize.Z),
			Vector3.new(halfSize.X, 0, halfSize.Z),
		},
		_normal = Vector3.yAxis,
		_rotation = CFrame.identity,
		_elapsed = _cartConfig.tiltSampleInterval,
	}, cartTilt)
end

function cartTilt.reset(self: cartTilt): ()
	self._normal = Vector3.yAxis
	self._rotation = CFrame.identity
	self._elapsed = _cartConfig.tiltSampleInterval
	self._raycastParams.FilterDescendantsInstances = {}
end

function cartTilt._sampleGround(self: cartTilt): ()
	local excluded: { Instance } = { self._model }
	for _, player in _players:GetPlayers() do
		local character: Model? = player.Character
		if character then table.insert(excluded, character) end
	end
	self._raycastParams.FilterDescendantsInstances = excluded

	local normalSum: Vector3 = Vector3.zero
	for _, offset in self._sampleOffsets do
		local origin: Vector3 = self._primaryPart.CFrame:PointToWorldSpace(offset)
			+ Vector3.yAxis * _cartConfig.tiltRayHeight
		local hit: RaycastResult? = workspace:Raycast(origin,
			-Vector3.yAxis * (_cartConfig.tiltRayHeight + _cartConfig.tiltRayDepth), self._raycastParams)
		if hit and hit.Normal.Y >= _cartConfig.tiltMinGroundNormalY then
			normalSum += hit.Normal
		end
	end
	-- Keep the last supported slope over gaps rather than snapping upright in midair.
	if normalSum.Magnitude > 0.001 then
		self._normal = normalSum.Unit
	end
end

function cartTilt.update(self: cartTilt, direction: Vector3, dt: number): CFrame
	self._elapsed += dt
	if self._elapsed >= _cartConfig.tiltSampleInterval then
		self._elapsed %= _cartConfig.tiltSampleInterval
		self:_sampleGround()
	end
	local heading: CFrame = CFrame.lookAt(Vector3.zero, direction)
	local normal: Vector3 = heading:VectorToObjectSpace(self._normal)
	local pitch: number = math.clamp(math.atan2(normal.Z, normal.Y),
		-math.rad(_cartConfig.tiltMaxPitch), math.rad(_cartConfig.tiltMaxPitch))
	local roll: number = math.clamp(math.atan2(-normal.X, math.sqrt(normal.Y ^ 2 + normal.Z ^ 2)),
		-math.rad(_cartConfig.tiltMaxRoll), math.rad(_cartConfig.tiltMaxRoll))
	local target: CFrame = CFrame.Angles(pitch, 0, roll)
	self._rotation = self._rotation:Lerp(target, 1 - math.exp(-dt * _cartConfig.tiltResponsiveness))
	return self._rotation
end

return cartTilt
