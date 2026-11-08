--!strict

type LightingPreset = {
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	ExposureCompensation: number,
}

type ColorCorrectionPreset = {
	Brightness: number,
	Contrast: number,
	Saturation: number,
	TintColor: Color3,
}

type AtmospherePreset = {
	Density: number,
	Offset: number,
	Haze: number,
	Color: Color3,
	Decay: Color3,
}

type BloomPreset = {
	Intensity: number,
	Size: number,
	Threshold: number,
}

type PhasePreset = {
	lighting: LightingPreset,
	colorCorrection: ColorCorrectionPreset,
	atmosphere: AtmospherePreset,
	bloom: BloomPreset,
}

local DayNightConfig = {
	-- Cycle timing (1 in-game day = 480s; hour = 20s real).
	cycleDuration = 480,
	startHour = 6,
	updateRate = 0.2,

	hungerCycle = 180,
	thirstCycle = 300,
	hungerPerCycle = 5,
	thirstPerCycle = 5,

	-- Hour boundaries that flip the visual phase. Night is announced an hour before the
	-- hunters arrive so the notification reads as a warning, not a jump-scare.
	nightApproachHour = 20,
	hunterHour = 21,
	dawnHour = 5,

	nightApproachMessage = "Night approaching",
	dawnMessage = "Dawn breaks",

	presets = {
		Day = {
			lighting = {
				Brightness = 2,
				Ambient = Color3.fromRGB(70, 70, 70),
				OutdoorAmbient = Color3.fromRGB(140, 140, 140),
				ExposureCompensation = 0,
			},
			colorCorrection = {
				Brightness = 0,
				Contrast = 0,
				Saturation = 0,
				TintColor = Color3.fromRGB(255, 255, 255),
			},
			atmosphere = {
				Density = 0.3,
				Offset = 0.25,
				Haze = 1,
				Color = Color3.fromRGB(199, 170, 107),
				Decay = Color3.fromRGB(106, 112, 125),
			},
			bloom = {
				Intensity = 0.4,
				Size = 24,
				Threshold = 1.5,
			},
		} :: PhasePreset,

		Night = {
			lighting = {
				Brightness = 1.8,
				Ambient = Color3.fromRGB(45, 50, 70),
				OutdoorAmbient = Color3.fromRGB(69, 80, 112),
				ExposureCompensation = -0.2,
			},
			colorCorrection = {
				Brightness = 0.215,
				Contrast = 0.2,
				Saturation = -0.2,
				TintColor = Color3.fromRGB(120, 140, 200),
			},
			atmosphere = {
				Density = 0.45,
				Offset = 0.1,
				Haze = 5,
				Color = Color3.fromRGB(50, 57, 104),
				Decay = Color3.fromRGB(27, 38, 68),
			},
			bloom = {
				Intensity = 0.6,
				Size = 24,
				Threshold = 1.1,
			},
		} :: PhasePreset,
	},

	-- Local-player "closing in" darkness applied on top of the night preset whenever the
	-- player is outside every safezone.
	safezone = {
		checkInterval = 0.1,
		factorLerpRate = 3,
		margin = 2,
		outsideOverlayTransparency = 0.6,
		outsideColorCorrectionBrightness = -0.08,
		vignetteImage = nil :: string?,
	},

	campfireNightBoost = {
		brightnessMultiplier = 2.2,
		rangeMultiplier = 1.6,
		fireSizeMultiplier = 1.4,
		fireHeatMultiplier = 1.3,
	},

	cartNightBoost = {
		lightBrightness = 3,
		lightRange = 60,
		lightColor = Color3.fromRGB(255, 180, 90),
	},
}

return DayNightConfig
