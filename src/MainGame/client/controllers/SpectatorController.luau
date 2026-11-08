--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local KeybindUtils = require(script.Parent.Parent.utils.KeybindUtils)

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local _spectating = false
local _targetIndex = 0
local _target: Model?
local _playersFolder: Folder?

local NEXT, PREVIOUS = 1, -1

local SpectatorController = {}

local function getTargets(): { Model }
	local targets: { Model } = {}
	for _, child in _playersFolder:GetChildren() do
		if not child:IsA("Model") then continue end
		table.insert(targets, child)
	end

	table.sort(targets, function(left, right)
		return left.Name < right.Name
	end)
	return targets
end

local function setTarget(target: Model?): ()
	local humanoid = if target then target:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid then return end

	_target = target
	Camera.CameraType = Enum.CameraType.Custom
	Camera.CameraSubject = humanoid
end

local function cycle(direction: number): ()
	if not _spectating then return end

	local targets = getTargets()
	if #targets == 0 then return end

	_targetIndex = _targetIndex + direction
	if _targetIndex > #targets then _targetIndex = 1 end
	if _targetIndex < 1 then _targetIndex = #targets end

	setTarget(targets[_targetIndex])
end

local function startSpectating(): ()
	if _spectating then return end

	_spectating = true
    local targets = getTargets()
    for index, target in targets do
        if target.Name == LocalPlayer.Character.Name then
            _targetIndex = index
            setTarget(targets[_targetIndex])
            break
        end
    end
end

local function stopSpectating(): ()
	if not _spectating then return end
	_spectating = false
	_targetIndex = 0
	_target = nil

    Camera.CameraType = Enum.CameraType.Custom
    Camera.CameraSubject = LocalPlayer.Character.Humanoid
end


local function updateDeathState(): ()
	local character = LocalPlayer.Character
	if not character then return end

	if character:GetAttribute("alive") == true then stopSpectating() return end
	startSpectating()
end

function SpectatorController:OnStart(): ()
    _playersFolder = workspace:WaitForChild("Map"):WaitForChild("Players")

	local previousSignal = KeybindUtils.getSignal("spectatePrevious")
	previousSignal:Connect(function(inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			cycle(PREVIOUS)
		end
	end)

	local nextSignal = KeybindUtils.getSignal("spectateNext")
	nextSignal:Connect(function(inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			cycle(NEXT)
		end
	end)

	LocalPlayer.CharacterAdded:Connect(function(character: Model)
		_spectating = false
		_target = nil
		_targetIndex = 0
		Camera.CameraType = Enum.CameraType.Custom
		local humanoid = character:WaitForChild("Humanoid")
		Camera.CameraSubject = humanoid
		character:GetAttributeChangedSignal("alive"):Connect(updateDeathState)
	end)

	RunService.RenderStepped:Connect(function()
		if not _spectating then return end
        if _target == nil or _target.Parent == nil then cycle(NEXT) end        
	end)
end

export type SpectatorController = typeof(SpectatorController)

return SpectatorController
