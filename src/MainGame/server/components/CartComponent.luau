--!strict
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _serverScriptService = game:GetService("ServerScriptService")
local _tweenService = game:GetService("TweenService")

local _component = require(_replicatedStorage.Packages.Component)
local _troveModule = require(_replicatedStorage.Packages.Trove)
local _cartConfig = require(_replicatedStorage.Shared.config.CartConfig)
local _signals = require(_serverScriptService.Server.signals)

local _cartSignals = _signals.cartSignals

local _cartTypes = require(_replicatedStorage.Shared.types.CartTypes)

type attachPromptEntry = { part: BasePart, prompt: ProximityPrompt }
export type cartComponent = _cartTypes.cartComponentInterface & {
	Instance: Model,
	_trove: typeof(_troveModule.new()),
	_primaryPart: BasePart,
	_sockets: { Attachment },
	_attachPrompts: { attachPromptEntry },
	_ropeParts: { BasePart },
	_pointLight: PointLight,
	_fire: Fire,
	_baseBrightness: number,
	_baseFireSize: number,
	_baseFireHeat: number,
	_lightTweenTrove: typeof(_troveModule.new()),
	_frontLocal: Vector3,
	_frontRotationInverse: CFrame,
	_rigReady: boolean,
	_linearVelocity: LinearVelocity?,
	_alignOrientation: AlignOrientation?,
	_wheelHinges: { HingeConstraint },
	_lightRevision: number,
	_computeFrontLocal: (self: cartComponent) -> Vector3,
}

local cartComponent = _component.new({ Tag = "Cart" })

function cartComponent.Construct(self: cartComponent): ()
	self._trove = _troveModule.new()

	local model: Instance = self.Instance
	assert(model:IsA("Model"), "Cart must be a Model")
	-- The shared objective must remain available to the distant-cart indicator.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local primaryPart: BasePart? = model.PrimaryPart
	assert(primaryPart, `[cartComponent] {self.Instance.Name} is missing PrimaryPart`)

	local sockets: { Attachment } = {}
	for _, child in primaryPart:GetChildren() do
		if child:IsA("Attachment") and child.Name:match("^WheelAttachment") then
			table.insert(sockets, child :: Attachment)
		end
	end

	local attachPrompts: { attachPromptEntry } = {}
	local ropeParts: { BasePart } = {}
	for _, desc in self.Instance:GetDescendants() do
		if not desc:IsA("BasePart") then continue end
		if desc.Name:match("^AttachPromptPart") then
			local prompt: ProximityPrompt? = desc:FindFirstChildWhichIsA("ProximityPrompt")
			if prompt then
				table.insert(attachPrompts, { part = desc :: BasePart, prompt = prompt :: ProximityPrompt })
			end
		elseif desc.Name:match("^RopePullPart") then
			table.insert(ropeParts, desc :: BasePart)
		end
	end

	local light: Instance? = self.Instance:FindFirstChild("Light", true)
	assert(light and light:IsA("BasePart"), `[cartComponent] {self.Instance.Name} is missing a Light part`)

	local pointLight: PointLight? = light:FindFirstChildWhichIsA("PointLight", true)
	assert(pointLight, `[cartComponent] {self.Instance.Name} Light is missing a PointLight`)

	local fire: Fire? = light:FindFirstChildWhichIsA("Fire", true)
	assert(fire, `[cartComponent] {self.Instance.Name} Light is missing a Fire effect`)

	assert(#sockets > 0, "Cart is missing wheel attachments")
	assert(#ropeParts > 0, "Cart is missing rope parts")
	self._primaryPart = primaryPart
	self._sockets = sockets
	self._attachPrompts = attachPrompts
	self._ropeParts = ropeParts
	self._pointLight = pointLight :: PointLight
	self._fire = fire :: Fire
	self._baseBrightness = pointLight.Brightness
	self._baseFireSize = fire.Size
	self._baseFireHeat = fire.Heat
	self._lightTweenTrove = self._trove:Extend()

	local frontLocal: Vector3 = self:_computeFrontLocal()
	self._frontLocal = frontLocal
	self._frontRotationInverse = CFrame.lookAt(Vector3.zero, frontLocal):Inverse()

	self._rigReady = false
	self._lightRevision = 0
	self._linearVelocity = nil :: LinearVelocity?
	self._alignOrientation = nil :: AlignOrientation?
	self._wheelHinges = {} :: { HingeConstraint }
end

function cartComponent.Start(self: cartComponent): ()
	for _, entry in self._attachPrompts do
		self._trove:Connect(entry.prompt.Triggered, function(player: Player): ()
			_cartSignals.attachRequested:Fire(player)
		end)
	end

	for _, ropePart in self._ropeParts do
		local prompt: ProximityPrompt? = ropePart:FindFirstChildWhichIsA("ProximityPrompt")
		if not prompt then continue end
		prompt.Enabled = false
		self._trove:Connect(prompt.Triggered, function(player: Player): ()
			_cartSignals.pullAttachRequested:Fire(player, ropePart)
		end)
	end

	_cartSignals.cartReady:Fire(self)
end

function cartComponent.Stop(self: cartComponent): ()
	self:setPulling(false)
	self:setWheelSpinSpeed(0)
	self._lightRevision += 1
	_cartSignals.cartRemoved:Fire(self)
	self._trove:Clean()
	self._linearVelocity = nil
	self._alignOrientation = nil
	self._rigReady = false
	table.clear(self._wheelHinges)
end

function cartComponent.getModel(self: cartComponent): Model
	return self.Instance
end

function cartComponent.getRopeParts(self: cartComponent): { BasePart }
	return self._ropeParts
end

function cartComponent.getPosition(self: cartComponent): Vector3
	return self._primaryPart.Position
end

function cartComponent.getSockets(self: cartComponent): { Attachment }
	return self._sockets
end

function cartComponent._computeFrontLocal(self: cartComponent): Vector3
	local primaryCFrame: CFrame = self._primaryPart.CFrame
	local sum: Vector3 = Vector3.zero
	local count: number = 0
	for _, ropePart in self._ropeParts do
		local localPos: Vector3 = primaryCFrame:PointToObjectSpace(ropePart.Position)
		sum += Vector3.new(localPos.X, 0, localPos.Z)
		count += 1
	end
	if count == 0 then
		return Vector3.new(0, 0, -1)
	end
	local avg: Vector3 = sum / count
	if avg.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return avg.Unit
end


function cartComponent.setAttachPromptsEnabled(self: cartComponent, enabled: boolean): ()
	for _, entry in self._attachPrompts do
		entry.prompt.Enabled = enabled
	end
end

function cartComponent.setRopePromptsEnabled(self: cartComponent, enabled: boolean): ()
	for _, ropePart in self._ropeParts do
		local prompt: ProximityPrompt? = ropePart:FindFirstChildWhichIsA("ProximityPrompt")
		if prompt then
			prompt.Enabled = enabled
		end
	end
end

function cartComponent.setRopePromptEnabled(self: cartComponent, ropePart: BasePart, enabled: boolean): ()
	local prompt: ProximityPrompt? = ropePart:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		prompt.Enabled = enabled
	end
end

function cartComponent.setLightLevel(self: cartComponent, fuel: number, maxFuel: number): ()
	local t: number = math.clamp(fuel / maxFuel, 0, 1)
	self._lightRevision += 1
	local revision: number = self._lightRevision
	self._lightTweenTrove:Clean()

	if t > 0 then
		self._pointLight.Enabled = true
		self._fire.Enabled = true
	end

	local tweenInfo: TweenInfo = TweenInfo.new(_cartConfig.lightTweenTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local lightTween: Tween = _tweenService:Create(self._pointLight, tweenInfo, {
		Brightness = self._baseBrightness * t,
	})
	local fireTween: Tween = _tweenService:Create(self._fire, tweenInfo, {
		Size = self._baseFireSize * t,
		Heat = self._baseFireHeat * t,
	})

	self._lightTweenTrove:Add(lightTween)
	self._lightTweenTrove:Add(fireTween)

	if t <= 0 then
		self._lightTweenTrove:Connect(lightTween.Completed, function(playbackState: Enum.PlaybackState): ()
			if revision ~= self._lightRevision or playbackState ~= Enum.PlaybackState.Completed then return end
			self._pointLight.Enabled = false
			self._fire.Enabled = false
		end)
	end

	lightTween:Play()
	fireTween:Play()
end

function cartComponent.setupPullRig(self: cartComponent): ()
	if self._rigReady then return end
	self._rigReady = true

	local primaryPart: BasePart = self._primaryPart
	for _, desc in self.Instance:GetDescendants() do
		if not desc:IsA("BasePart") or desc == primaryPart then continue end

		-- Socketed wheels already carry a HingeConstraint (see cartService:_attachWheel).
		-- Rigidly welding them here would lock that hinge and stop them spinning,
		-- so drive them as motors instead of folding them into the rigid chassis.
		local hinge: HingeConstraint? = desc:FindFirstChildWhichIsA("HingeConstraint")
		if hinge then
			hinge.ActuatorType = Enum.ActuatorType.Motor
			hinge.MotorMaxTorque = _cartConfig.wheelMotorTorque
			hinge.AngularVelocity = 0
			desc.Massless = true
			table.insert(self._wheelHinges, hinge)
			continue
		end

		local weld: WeldConstraint = self._trove:Add(Instance.new("WeldConstraint"))
		weld.Part0 = desc
		weld.Part1 = primaryPart
		weld.Parent = desc
		desc.Massless = true
		desc.Anchored = false
	end

	local rigAttachment: Attachment = self._trove:Add(Instance.new("Attachment"))
	rigAttachment.Name = "PullRigAttachment"
	rigAttachment.Parent = primaryPart

	local linearVelocity: LinearVelocity = self._trove:Add(Instance.new("LinearVelocity"))
	linearVelocity.Attachment0 = rigAttachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	linearVelocity.PrimaryTangentAxis = Vector3.xAxis
	linearVelocity.SecondaryTangentAxis = Vector3.zAxis
	linearVelocity.PlaneVelocity = Vector2.zero
	linearVelocity.ForceLimitsEnabled = true
	linearVelocity.Enabled = false
	linearVelocity.Parent = primaryPart

	local alignOrientation: AlignOrientation = self._trove:Add(Instance.new("AlignOrientation"))
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = rigAttachment
	alignOrientation.RigidityEnabled = false
	alignOrientation.Responsiveness = _cartConfig.turnResponsiveness
	alignOrientation.MaxAngularVelocity = _cartConfig.maxTurnAngularVelocity
	alignOrientation.CFrame = primaryPart.CFrame.Rotation
	alignOrientation.Enabled = false
	alignOrientation.Parent = primaryPart

	self._linearVelocity = linearVelocity
	self._alignOrientation = alignOrientation
end

function cartComponent.setPulling(self: cartComponent, active: boolean): ()
	local linearVelocity: LinearVelocity? = self._linearVelocity
	local alignOrientation: AlignOrientation? = self._alignOrientation
	if not linearVelocity or not alignOrientation then return end

	local primaryPart: BasePart = self._primaryPart
	if active then
		primaryPart.Anchored = false
		local weight: number = primaryPart.AssemblyMass * workspace.Gravity
		linearVelocity.MaxForce = weight * _cartConfig.pullForceFactor
		alignOrientation.MaxTorque = weight * _cartConfig.turnTorqueFactor
		linearVelocity.PlaneVelocity = Vector2.zero
		alignOrientation.CFrame = primaryPart.CFrame.Rotation
		linearVelocity.Enabled = true
		alignOrientation.Enabled = true
		primaryPart:SetNetworkOwner(nil)
	else
		linearVelocity.PlaneVelocity = Vector2.zero
		linearVelocity.Enabled = false
		alignOrientation.Enabled = false
		primaryPart.Anchored = true
	end
end

function cartComponent.setPullVelocity(self: cartComponent, velocity: Vector3): ()
	local linearVelocity: LinearVelocity? = self._linearVelocity
	if not linearVelocity then return end
	linearVelocity.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
end

function cartComponent.unstuck(self: cartComponent): ()
	local primaryPart: BasePart = self._primaryPart
	local forward: Vector3 = self:getForward()
	local pivot: CFrame = self.Instance:GetPivot()

	primaryPart.AssemblyLinearVelocity = Vector3.zero
	primaryPart.AssemblyAngularVelocity = Vector3.zero
	self.Instance:PivotTo(pivot + forward * _cartConfig.unstuckDistance + Vector3.new(0, _cartConfig.unstuckLift, 0))
	self:setPullVelocity(Vector3.zero)
	self:setWheelSpinSpeed(0)
end

function cartComponent.setPullDirection(self: cartComponent, direction: Vector3, tilt: CFrame): ()
	local alignOrientation: AlignOrientation? = self._alignOrientation
	if not alignOrientation then return end
	alignOrientation.CFrame = CFrame.lookAt(Vector3.zero, direction) * tilt * self._frontRotationInverse
end

function cartComponent.getForward(self: cartComponent): Vector3
	local worldFront: Vector3 = self._primaryPart.CFrame:VectorToWorldSpace(self._frontLocal)
	local flat: Vector3 = Vector3.new(worldFront.X, 0, worldFront.Z)
	if flat.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

function cartComponent.setWheelSpinSpeed(self: cartComponent, angularVelocity: number): ()
	for _, hinge in self._wheelHinges do
		hinge.AngularVelocity = angularVelocity
	end
end

return cartComponent
