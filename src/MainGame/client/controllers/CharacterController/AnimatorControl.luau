--!strict
local AnimationControl = {}

local _currentAnim = ""
local _currentAnimInstance = nil
local _currentAnimTrack = nil
local _currentAnimKeyframeHandler = nil
local _pose = "Standing"
local _animTable = {}
local _animNames = {}
local _Humanoid
local _Character

-- declarations
local _jumpAnimTime = 0
local _jumpAnimDuration = 0.3
local _fallTransitionTime = 0.3
local _basewalkspeed = 1

function AnimationControl:Init(character : Model, characterData): ()
	_Character = character
	_Humanoid = character:WaitForChild("Humanoid")

	_animNames = { 
		idle = { id = `http://www.roblox.com/asset/?id={characterData.idleAnim}`,weight = Enum.AnimationPriority.Core },
		walk = { id = `http://www.roblox.com/asset/?id={characterData.walkingAnim}`,weight = Enum.AnimationPriority.Core } ,
		run = { id = `http://www.roblox.com/asset/?id={characterData.runningAnim}`,weight = Enum.AnimationPriority.Core },
		jump = { id = `http://www.roblox.com/asset/?id={characterData.jumpAnim}`,weight = Enum.AnimationPriority.Movement },
		fall = { id = `http://www.roblox.com/asset/?id={characterData.fallAnim}`,weight = Enum.AnimationPriority.Movement }
	}
	_basewalkspeed = characterData.walkingBaseAnimSpeed

	local dances = {"dance1", "dance2", "dance3"}

	-- Existance in this list signifies that it is an emote, the value indicates if it is a looping emote
	local emoteNames = { wave = false, point = false, dance1 = true, dance2 = true, dance3 = true, laugh = false, cheer = false}

	script.ChildAdded:Connect(scriptChildModified)
	script.ChildRemoved:Connect(scriptChildModified)

	-- Clear any existing animation tracks
	-- Fixes issue with characters that are moved in and out of the Workspace accumulating tracks
	local animator = if _Humanoid then _Humanoid:FindFirstChildOfClass("Animator") else nil
	if animator then
		local animTracks = animator:GetPlayingAnimationTracks()
		for i,track in ipairs(animTracks) do
			track:Stop(0)
			track:Destroy()
		end
	end

	for name, fileList in pairs(_animNames) do 
		configureAnimationSet(name, fileList)
	end	

	local function stopAllAnimations()
		local oldAnim = _currentAnim

		-- return to idle if finishing an emote
		if (emoteNames[oldAnim] ~= nil and emoteNames[oldAnim] == false) then
			oldAnim = "idle"
		end

		_currentAnim = ""
		_currentAnimInstance = nil
		if (_currentAnimKeyframeHandler ~= nil) then
			_currentAnimKeyframeHandler:disconnect()
		end

		if (_currentAnimTrack ~= nil) then
			_currentAnimTrack:Stop()
			_currentAnimTrack:Destroy()
			_currentAnimTrack = nil
		end
		return oldAnim
	end

	-- Preload animations
	local function playAnimation(animName, transitionTime, _Humanoid) 
		local anim = _animTable[animName].anim
		local weight = _animTable[animName].weight

		-- switch animation		
		if (anim ~= _currentAnimInstance) then

			if (_currentAnimTrack ~= nil) then
				_currentAnimTrack:Stop(transitionTime)
				_currentAnimTrack:Destroy()
			end

			-- load it to the _Humanoid; get AnimationTrack
			_currentAnimTrack = _Humanoid.Animator:LoadAnimation(anim)
			_currentAnimTrack.Priority = weight

			-- play the animation
			_currentAnimTrack:Play(transitionTime)
			_currentAnim = animName
			_currentAnimInstance = anim
		end
	end

	local function onRunning(speed)
		if speed > 0.01 then
			playAnimation("walk", 0.1, _Humanoid)
			_currentAnimTrack:AdjustSpeed((speed / 14.5) * _basewalkspeed)
			_pose = "Running"
		else
			if emoteNames[_currentAnim] == nil then
				playAnimation("idle", 0.1, _Humanoid)
				_pose = "Standing"
			end
		end
	end

	local function onDied()
		_pose = "Dead"
	end

	local function onJumping()
		playAnimation("jump", 0.1, _Humanoid)
		_jumpAnimTime = _jumpAnimDuration
		_pose = "Jumping"
	end

	local function onFreeFall()
		if (_jumpAnimTime <= 0) then
			playAnimation("fall", _fallTransitionTime, _Humanoid)
		end
		_pose = "FreeFall"
	end

	-- connect events
	_Humanoid.Died:connect(onDied)
	_Humanoid.Running:connect(onRunning)
	_Humanoid.Jumping:connect(onJumping)
	_Humanoid.FreeFalling:connect(onFreeFall)
	_Humanoid.FallingDown:connect(onFallingDown)
	_Humanoid.Seated:connect(onSeated)
	_Humanoid.PlatformStanding:connect(onPlatformStanding)
	_Humanoid.Swimming:connect(onSwimming)

	-- main program
	local lastTick = 0

	local function move(ticktime)
		local amplitude = 1
		local frequency = 1
		local deltaTime = ticktime - lastTick
		lastTick = ticktime

		local climbFudge = 0
		local setAngles = false

		if (_jumpAnimTime > 0) then
			_jumpAnimTime = _jumpAnimTime - deltaTime
		end

		if (_pose == "FreeFall" and _jumpAnimTime <= 0) then
			playAnimation("fall", _fallTransitionTime, _Humanoid)
		elseif (_pose == "Seated") then
			playAnimation("sit", 0.5, _Humanoid)
			return
		elseif (_pose == "Running") then
			playAnimation("walk", 0.1, _Humanoid)
		elseif (_pose == "Dead" or _pose == "GettingUp" or _pose == "FallingDown" or _pose == "Seated" or _pose == "PlatformStanding") then
			stopAllAnimations()
			amplitude = 0.1
			frequency = 1
			setAngles = true
		end
	end

	-- initialize to idle
	playAnimation("idle", 0.1, _Humanoid)
	_pose = "Standing"

	task.spawn(function()
		while _Character.Parent ~= nil do
			local ticktime = task.wait(0.1)
			move(ticktime)
		end
	end)
end


function configureAnimationSet(name, fileList)
	_animTable[name] = {}
	_animTable[name].anim = Instance.new("Animation")
	_animTable[name].anim.Name = name
	_animTable[name].anim.AnimationId = fileList.id
	_animTable[name].weight = fileList.weight
end

-- Setup animation objects
function scriptChildModified(child)
	local fileList = _animNames[child.Name]
	if (fileList ~= nil) then
		configureAnimationSet(child.Name, fileList)
	end	
end

function onFallingDown()
	_pose = "FallingDown"
end

function onSeated()
	_pose = "Seated"
end

function onPlatformStanding()
	_pose = "PlatformStanding"
end

function onSwimming(speed)
	if speed > 0 then
		_pose = "Running"
	else
		_pose = "Standing"
	end
end

export type AnimationControl = typeof(AnimationControl)

return AnimationControl
