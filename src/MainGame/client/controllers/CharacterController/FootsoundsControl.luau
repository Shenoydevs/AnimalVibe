--!strict
local RunService = game:GetService("RunService")

local FootsoundsControl = {}

local MIN_STEP_INTERVAL = 0.2
local MAX_STEP_INTERVAL = 0.5
local MIN_MOVEMENT_SPEED = 2
local STEP_DISTANCE = 4.5

local _sounds: { Sound } = {}
local _connections: { RBXScriptConnection } = {}
local _lastSoundIndex = 0
local _movementSpeed = 0
local _stepTimer = 0

local function disconnectAll(): ()
	for _, connection in _connections do
		connection:Disconnect()
	end
	table.clear(_connections)
	table.clear(_sounds)
end

function FootsoundsControl:Init(character: Model, humanoid: Humanoid): ()
	disconnectAll()
	_lastSoundIndex = 0
	_movementSpeed = 0
	_stepTimer = 0

	local primaryPart = character.PrimaryPart
	if not primaryPart then
		warn(`[FootsoundsControl] {character.Name} has no PrimaryPart; footsteps were disabled`)
		return
	end

	for _, child in primaryPart:GetChildren() do
		if child:IsA("Sound") and (child.Name == "Footstep" or child.Name == "Footsteps") then
			table.insert(_sounds, child)
		end
	end

	if #_sounds == 0 then
		warn(`[FootsoundsControl] {character.Name} is missing a Footstep or Footsteps sound on its PrimaryPart`)
		return
	end

	table.insert(
		_connections,
		humanoid.Running:Connect(function(speed: number)
			_movementSpeed = speed
			if speed < MIN_MOVEMENT_SPEED then
				_stepTimer = 0
			end
		end)
	)

	table.insert(
		_connections,
		RunService.Heartbeat:Connect(function(deltaTime: number)
			if _movementSpeed < MIN_MOVEMENT_SPEED or humanoid.FloorMaterial == Enum.Material.Air then
				_stepTimer = 0
				return
			end

			local stepInterval = math.clamp(STEP_DISTANCE / _movementSpeed, MIN_STEP_INTERVAL, MAX_STEP_INTERVAL)
			_stepTimer += deltaTime
			if _stepTimer < stepInterval then
				return
			end

			_stepTimer %= stepInterval
			_lastSoundIndex = (_lastSoundIndex % #_sounds) + 1
			local sound = _sounds[_lastSoundIndex]
			sound.TimePosition = 0
			sound:Play()
		end)
	)
end

export type FootsoundsControl = typeof(FootsoundsControl)
return FootsoundsControl
