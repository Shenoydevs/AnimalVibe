--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaitFor = require(ReplicatedStorage.Packages.WaitFor)

local WAIT_TIMEOUT = 30

local GuiUtils = {}

function GuiUtils.waitFor(parent: Instance, childName: string, logTag: string): Instance?
	local ok, child = WaitFor.Child(parent, childName, WAIT_TIMEOUT):await()
	if not ok or not child then
		warn(`[{logTag}] Missing "{childName}" under {parent:GetFullName()}`)
		return nil
	end
	return child :: Instance
end

return GuiUtils
