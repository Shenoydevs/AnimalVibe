--!strict
local UserInputService = game:GetService("UserInputService")

export type Device = "Keyboard" | "Gamepad" | "Touch"

local DeviceUtils = {}

function DeviceUtils.classify(inputType: Enum.UserInputType): Device
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	end
	if string.match(inputType.Name, "^Gamepad") then
		return "Gamepad"
	end
	return "Keyboard"
end

function DeviceUtils.getCurrent(): Device
	return DeviceUtils.classify(UserInputService:GetLastInputType())
end

function DeviceUtils.onChanged(callback: (Device) -> ()): RBXScriptConnection
	return UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
		callback(DeviceUtils.classify(inputType))
	end)
end

return DeviceUtils
