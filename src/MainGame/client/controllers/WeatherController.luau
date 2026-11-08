--!strict
local _lighting = game:GetService("Lighting")
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _soundService = game:GetService("SoundService")
local _tweenService = game:GetService("TweenService")

local _networkerModule = require(_replicatedStorage.Packages.Networker)
local _troveModule = require(_replicatedStorage.Packages.Trove)
local _weatherConfig = require(_replicatedStorage.Shared.config.WeatherConfig)
local _weatherNetwork = require(_replicatedStorage.Shared.network.WeatherNetwork)

type networkerClient = _networkerModule.Client

local _flashBrightness: number = 0.6
local _flashFadeTime: number = 0.35
local _strikeSoundLifetime: number = 6

local _trove = _troveModule.new()
local _currentWeather: string = "Standard"
local _warningSound: Sound? = nil
-- Its own effect rather than DayNightController's lighting, so a flash never fights the day/night presets.
local _flash: ColorCorrectionEffect? = nil

local weatherController = {}

function weatherController.getCurrentWeather(): string
	return _currentWeather
end

function weatherController:onWeatherChanged(name: string): ()
	_currentWeather = name
end

function weatherController:onThunderWarning(_delay: number): ()
	local sound: Sound? = _warningSound
	if sound then
		sound:Play()
	end
end

function weatherController:onThunderStrike(position: Vector3): ()
	local flash: ColorCorrectionEffect? = _flash
	if flash then
		flash.Brightness = _flashBrightness
		_tweenService:Create(flash, TweenInfo.new(_flashFadeTime), { Brightness = 0 }):Play()
	end
	local soundId: string? = _weatherConfig.Thunder.strikeSoundId
	if not soundId then
		return
	end
	local emitter: Attachment = Instance.new("Attachment")
	emitter.WorldPosition = position
	emitter.Parent = workspace.Terrain
	local sound: Sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.RollOffMaxDistance = 1500
	sound.Parent = emitter
	sound:Play()
	task.delay(_strikeSoundLifetime, function()
		emitter:Destroy()
	end)
end

function weatherController:OnStart(): ()
	local warningId: string? = _weatherConfig.Thunder.warningSoundId
	if warningId then
		local sound: Sound = _trove:Add(Instance.new("Sound"))
		sound.Name = "ThunderWarning"
		sound.SoundId = warningId
		sound.Parent = _soundService
		_warningSound = sound
	end

	local flash: ColorCorrectionEffect = _trove:Add(Instance.new("ColorCorrectionEffect"))
	flash.Name = "ThunderFlash"
	flash.Brightness = 0
	flash.Parent = _lighting
	_flash = flash

	local networker: networkerClient = _networkerModule.client.new(_weatherNetwork.Weather, weatherController)
	task.spawn(function()
		local current: string? = networker:fetch("getWeather")
		if current then
			_currentWeather = current
		end
	end)
end

export type weatherController = typeof(weatherController)
return weatherController
