--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local Shake = require(ReplicatedStorage.Packages.Shake)
local Network = require(ReplicatedStorage.Shared.network.ResourceNodeNetwork)
local VFXUtils = require(script.Parent.Parent.utils.VFXUtils)

type NetworkerClient = Networker.Client
type ShakeInstance = Shake.Shake

local _networker: NetworkerClient

local _paramsHitbox = OverlapParams.new()
_paramsHitbox.FilterType = Enum.RaycastFilterType.Exclude
_paramsHitbox.CollisionGroup = "Hitbox"

-- One live Shake per currently-shaking node; a repeat hit just restarts it instead of
-- layering a second RenderStep binding onto the same model.
local _activeShakes: { [Model]: ShakeInstance } = {}

local Private = {}

local ResourceNodeController = {}

local function _playShake(model: Model): ()
	if not model.PrimaryPart then
		return
	end

	local shake: ShakeInstance? = _activeShakes[model]
	if not shake then
		local newShake: ShakeInstance = Shake.new()
		newShake.Amplitude = 1.5
		newShake.Frequency = 0.6
		newShake.FadeInTime = 0
		newShake.FadeOutTime = 0.4
		newShake.PositionInfluence = Vector3.new(0.3, 0, 0.3)
		newShake.RotationInfluence = Vector3.new(0.05, 0.05, 0.05)
		_activeShakes[model] = newShake
		shake = newShake

		local basePivot: CFrame = model:GetPivot()
		newShake:BindToRenderStep(Shake.NextRenderName(), Enum.RenderPriority.Last.Value, function(pos, rot, completed)
			if not model.Parent then
				newShake:Stop()
				_activeShakes[model] = nil
				return
			end

			model:PivotTo(basePivot * CFrame.new(pos) * CFrame.Angles(rot.X, rot.Y, rot.Z))

			if completed then
				model:PivotTo(basePivot)
				_activeShakes[model] = nil
			end
		end)
	end

	local activeShake: ShakeInstance = shake :: ShakeInstance
	activeShake:Start()
end

local function _playHitVFX(model: Model): ()
	VFXUtils:DamageFlicker(model, false)
	_playShake(model)
end

function ResourceNodeController:ScanAndChop(hitboxPart: BasePart, framesActive: number): ()
	local blacklist: { [Model]: boolean } = {}

	task.spawn(function()
		repeat
			local partsInside = workspace:GetPartsInPart(hitboxPart, _paramsHitbox)
			local caughtNodes: { Model } = {}

			for _, part in partsInside do
				local parent = part.Parent
				if not parent or not parent:IsA("Model") or blacklist[parent] then
					continue
				end
				if parent:HasTag("ResourceNode") then
					table.insert(caughtNodes, parent)
					blacklist[parent] = true
				end
			end

			if #caughtNodes > 0 then
				for _, node in caughtNodes do
					_playHitVFX(node)
				end
				_networker:fire("requestChop", caughtNodes)
			end

			framesActive -= 1
			task.wait()
		until framesActive <= 0
	end)
end

function Private.onResourceNodeHit(t: unknown, models: { Model }): ()
	for _, model in models do
		_playHitVFX(model)
	end
end

function Private.onResourceNodeBroken(t: unknown, models: { Model }): ()
	for _, model in models do
		_activeShakes[model] = nil
	end
end

function ResourceNodeController:OnStart(): ()
	_networker = Networker.client.new(Network.ResourceNode, Private)
end

export type ResourceNodeController = typeof(ResourceNodeController)
return ResourceNodeController
