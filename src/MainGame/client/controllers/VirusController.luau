--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local Network = require(ReplicatedStorage.Shared.network.GameNetwork)
local VirusConfig = require(ReplicatedStorage.Shared.config.VirusConfig)
local NotificationController = require(script.Parent.NotificationController)

local _wallWidth: number = 3000
local _wallHeight: number = 1000
local _wallDepth: number = 150
local _wallColor: Color3 = Color3.fromRGB(80, 200, 60)
local _wallColorIntense: Color3 = Color3.fromRGB(170, 230, 40)
local _wallTransparency: number = 0.94
local _wallTransparencyIntense: number = 0.82

local _maxVisualPhase: number = 6

local _fogWall: Part? = nil
local _farFogEmitter: ParticleEmitter? = nil
local _nearWispsEmitter: ParticleEmitter? = nil

local VirusController = {}

local function _lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

local function createFogWall(boundaryZ: number): Part
	local wall: Part = Instance.new("Part")
	wall.Name = "VirusFogWall"
	wall.Size = Vector3.new(_wallWidth, _wallHeight, _wallDepth)
	wall.CFrame = CFrame.new(0, 200, boundaryZ)
	wall.Anchored = true
	wall.CanCollide = false
	wall.CastShadow = false
	wall.Material = Enum.Material.Neon
	wall.Color = _wallColor
	wall.Transparency = _wallTransparency
	wall.Parent = workspace

	local farFog: ParticleEmitter = Instance.new("ParticleEmitter")
	farFog.Name = "FarFog"
	farFog.Color = ColorSequence.new(_wallColor)
	farFog.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	farFog.LightEmission = 0.25
	farFog.Size = NumberSequence.new(14)
	farFog.SpreadAngle = Vector2.new(50, 50)
	farFog.Lifetime = NumberRange.new(6, 10)
	farFog.Parent = wall

	local nearWisps: ParticleEmitter = Instance.new("ParticleEmitter")
	nearWisps.Name = "NearWisps"
	nearWisps.Color = ColorSequence.new(_wallColor)
	nearWisps.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	nearWisps.LightEmission = 0.4
	nearWisps.Size = NumberSequence.new(5)
	nearWisps.SpreadAngle = Vector2.new(70, 70)
	nearWisps.Lifetime = NumberRange.new(2, 4)
	nearWisps.Parent = wall

	_farFogEmitter = farFog
	_nearWispsEmitter = nearWisps
	return wall
end

-- Scales the fog's density/speed/color toward a sicklier, more turbulent look
-- as the storm phase climbs, so later (more lethal) phases visibly read worse.
local function _applyStormPhase(phase: number): ()
	local wall: Part? = _fogWall
	local farFog: ParticleEmitter? = _farFogEmitter
	local nearWisps: ParticleEmitter? = _nearWispsEmitter
	if not wall or not farFog or not nearWisps then return end

	local alpha: number = math.clamp((phase - 1) / (_maxVisualPhase - 1), 0, 1)
	local color: Color3 = _wallColor:Lerp(_wallColorIntense, alpha)

	wall.Color = color
	wall.Transparency = _lerp(_wallTransparency, _wallTransparencyIntense, alpha)

	farFog.Color = ColorSequence.new(color)
	farFog.Rate = _lerp(20, 55, alpha)
	farFog.Speed = NumberRange.new(_lerp(2, 4, alpha), _lerp(6, 10, alpha))

	nearWisps.Color = ColorSequence.new(color)
	nearWisps.Rate = _lerp(15, 60, alpha)
	nearWisps.Speed = NumberRange.new(_lerp(6, 10, alpha), _lerp(14, 22, alpha))
end

function VirusController:onVirusReleased(): ()
	_fogWall = createFogWall(VirusConfig.initialBoundaryZ)
	_applyStormPhase(1)
	NotificationController:push("You feel something strange in the air…", 5, NotificationController.PRIORITY_MED, "Alert")
end

function VirusController:onVirusBoundaryUpdate(boundaryZ: number, stormPhase: number): ()
	local wall: Part? = _fogWall
	if not wall then return end
	TweenService:Create(wall, TweenInfo.new(VirusConfig.boundaryTweenTime, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(0, 200, boundaryZ),
	}):Play()
	_applyStormPhase(stormPhase)

	if stormPhase > 1 then
		NotificationController:push("The sickness is getting worse…", 4, NotificationController.PRIORITY_LOW, "Alert")
	end
end

function VirusController:OnStart(): ()
	Networker.client.new(Network.Virus, VirusController)
end

export type VirusController = typeof(VirusController)
return VirusController
