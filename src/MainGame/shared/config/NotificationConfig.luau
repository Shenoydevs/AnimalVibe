--!strict

type NotificationStyle = {
	title: string,
	titleColor: Color3,
}

local NotificationConfig = {
	priority = {
		high = 3,
		med = 2,
		low = 1,
	},

	maxQueue = 5,

	styles = {
		Info = { title = "INFO", titleColor = Color3.fromRGB(80, 170, 255) },
		Alert = { title = "ALERT!", titleColor = Color3.fromRGB(255, 70, 70) },
		Success = { title = "SUCCESS", titleColor = Color3.fromRGB(90, 220, 110) },
	} :: { [string]: NotificationStyle },

	descriptionColor = Color3.fromRGB(255, 255, 255),

	transition = {
		backgroundColor = Color3.fromRGB(0, 0, 0),
		textColor = Color3.fromRGB(255, 255, 255),
		fadeTime = 0.6,
	},
}

return NotificationConfig
