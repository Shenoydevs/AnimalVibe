--!strict
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local DeviceUtils = require(ReplicatedStorage.Shared.utils.DeviceUtils)

type PromptEntry = {
	gui: BillboardGui,
	keyImage: ImageLabel?,
	keyLabel: TextLabel?,
}

local _template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("PromptTemplate") :: BillboardGui
local _activePrompts: { [ProximityPrompt]: PromptEntry } = {}
local _keyboardKeyImage = ""

local ProximityPromptController = {}

local function _applyDevice(prompt: ProximityPrompt, entry: PromptEntry, device: DeviceUtils.Device): ()
	local keyImage = entry.keyImage
	local keyLabel = entry.keyLabel
	if not keyImage or not keyLabel then return end

	if device == "Gamepad" then
		keyImage.Image = UserInputService:GetImageForKeyCode(prompt.GamepadKeyCode)
		keyLabel.Text = ""
	else
		keyImage.Image = _keyboardKeyImage
		keyLabel.Text = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	end
end

function ProximityPromptController:OnStart(): ()
	local templateKeyImage = _template:FindFirstChild("inside", true) :: ImageLabel?
	_keyboardKeyImage = if templateKeyImage then templateKeyImage.Image else ""

	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		local part = prompt.Parent
		if not part then return end
		-- Default-style prompts on attachments (cave boulder ropes) rely on Roblox's own UI; only redraw Custom ones.
		local isCustomAttachment: boolean = part:IsA("Attachment") and prompt.Style == Enum.ProximityPromptStyle.Custom
		if not part:IsA("BasePart") and not isCustomAttachment then return end
		if _activePrompts[prompt] then return end

		local gui = _template:Clone()
		local offset = prompt:GetAttribute("offset")
		gui.StudsOffset = Vector3.new(0, if type(offset) == "number" then offset else 0, 0)

		local descriptionText = gui:FindFirstChild("descriptionText", true) :: TextLabel?
		if descriptionText then
			descriptionText.Text = prompt.ActionText
		end

		local entry: PromptEntry = {
			gui = gui,
			keyImage = gui:FindFirstChild("inside", true) :: ImageLabel?,
			keyLabel = gui:FindFirstChild("buttonlabel", true) :: TextLabel?,
		}
		_applyDevice(prompt, entry, DeviceUtils.getCurrent())

		gui.Adornee = part
		gui.Parent = part
		_activePrompts[prompt] = entry
	end)

	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		local entry = _activePrompts[prompt]
		if not entry then return end

		entry.gui:Destroy()
		_activePrompts[prompt] = nil
	end)

	DeviceUtils.onChanged(function(device: DeviceUtils.Device)
		for prompt, entry in _activePrompts do
			_applyDevice(prompt, entry, device)
		end
	end)
end

export type ProximityPromptController = typeof(ProximityPromptController)
return ProximityPromptController
