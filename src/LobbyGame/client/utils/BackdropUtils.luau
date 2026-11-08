--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local _tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local _background = Players.LocalPlayer.PlayerGui:WaitForChild("BackdropGui"):WaitForChild("Background")
local _tween = nil

local Private = {}
local Shared = {}

function Private._cancelTween()
	if _tween then
		_tween:Cancel()
		_tween:Destroy()
	end
end

function Shared.Show(tweenInfo)
	Private._cancelTween()
	if not _background.Visible then
		_background.BackgroundTransparency = 1
	end
	_background.Visible = true
	local tween = TweenService:Create(_background, tweenInfo or _tweenInfo, { BackgroundTransparency = 0.25 })
	_tween = tween
	tween:Play()
end

function Shared.Hide(onComplete, tweenInfo)
	Private._cancelTween()
	local tween = TweenService:Create(_background, tweenInfo or _tweenInfo, { BackgroundTransparency = 1 })
	_tween = tween
	tween.Completed:Once(function(state)
		if state ~= Enum.PlaybackState.Completed or _tween ~= tween then
			return
		end
		_background.Visible = false
		if onComplete then
			onComplete()
		end
	end)
	tween:Play()
end

return Shared
