local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Signal = require(ReplicatedStorage.Packages.Signal)
local DeviceUtils = require(ReplicatedStorage.Shared.utils.DeviceUtils)

local player = Players.LocalPlayer

local DialogComponent = Component.new({ Tag = "Dialog", Ancestors = { player }})

local KeyCodes = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three
}

function DialogComponent:Construct()
	self._scope = Fusion.scoped(Fusion)
	self._trove = Trove.new()
	self._troveSelections = Trove.new()

	self._ui = {
		Frame = self.Instance.Dialog,
		Title = self.Instance.Dialog.TitleText,
		Text = self.Instance.Dialog.descriptionText,
		Options = self.Instance.list,
	}
	
	local function updateSize()
		self._ui.Frame.Size = UDim2.new(1.5,0,0.37, (self._ui.Text.TextBounds.X / self._ui.Text.TextBounds.Y) * 1.35)
	end
	
	self._trove:Connect(self._ui.Text:GetPropertyChangedSignal("TextBounds"), updateSize)
end

function DialogComponent:DoTutorial()
	self:Show()
	self:AsyncShowDialog("GREAT, YOU'VE FINALLY WOKEN UP...", {{ Text = "CONTINUE" }})
	self:AsyncShowDialog("IN CASE YOU FORGOT, WE'RE CURRENTLY ON THE RUN FROM THOSE HUMANS.", {{ Text = "CONTINUE" }})
	self:AsyncShowDialog("FUNNY, TO THINK THEY WERE ONCE SWORN ALLIES OF OURS...", {{ Text = "CONTINUE" }})
	self:AsyncShowDialog("ANYWAYS, GET A MOVE ON. WE NEED TO HURRY UP AND GET OUT OF HERE, AND FAST.", {{ Text = "CONTINUE" }})
	self:AsyncShowDialog("IT SEEMS THE CART WAS DAMAGED ON THE WAY HERE... THE WHEELS BROKE OFF AS WE HID HERE.", {{ Text = "CONTINUE" }})
	self:AsyncShowDialog("THE WHEELS SHOULD BE SOMEWHERE AROUND HERE. SEARCH AROUND, COME BACK WITH THE WHEELS AND ASSEMBLE THEM ONTO THE CART, AND QUICKLY.", {{ Text = "UNDERSTOOD" }})
	self:Hide()

	local function onWheelsAssembled()
		self:AsyncShowDialog("GOOD JOB, THE CART SHOULD BE ALL GOOD TO GO NOW. PULL IT WITH YOU, AND DO NOT LET YOUR CART GET DESTROYED.", {{ Text = "CONTINUE" }})
		self:AsyncShowDialog("NOW, HEAD ON OVER ALL THE WAY TO WILDBORNE. ALTHOUGH, YOU'LL NEED TO CROSS PLENTY OF DIFFERENT BIOMES ALONG THE WAY.", {{ Text = "CONTINUE" }})
		self:AsyncShowDialog("GOOD LUCK... STAY SAFE FROM THE HUNTERS, SCAVENGE WHATEVER YOU MAY NEED TO PROTECT YOURSELF AS YOU TRAVEL.", {{ Text = "GOODBYE" }})
	end

	-- TODO ON TUTORIAL
end


function DialogComponent:Start() end

-- Show a dialog. `options` is an array of { Text = string, Callback = function }
function DialogComponent:AsyncShowDialog(text, options)
	local done = false
	local finished = Signal.new()
	self._troveSelections:Add(finished)

	options = options or {{ Text = "OK" }}

	self._ui.Text.Text = tostring(text or "")
	for _, child in ipairs(self._ui.Options:GetChildren()) do
		if child:IsA("TextButton") then
			child.Visible = false
		end
	end

	local firstButton
	for index, opt in ipairs(options) do
		local btn = self._ui.Options:FindFirstChild(tostring(index))
		btn.Text = `{index}. {opt.Text}`
		firstButton = firstButton or btn

		local function onActivate()
			if done then return end
			if type(opt.Callback) == "function" then 
				local ok, err = pcall(opt.Callback)
				if not ok then
					warn(`[DialogComponent] Option callback error: {err}`)
				end
			end
			
			done = true
			finished:Fire()
		end

		btn.Visible = true
		self._troveSelections:Add(btn.Activated:Once(onActivate))

		local keyCode = KeyCodes[index]
		if keyCode then
			local inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed then return end
				if input.KeyCode == keyCode then
					onActivate()
				end
			end)
			self._troveSelections:Add(inputConn)
		end
	end

	local function selectFirst(device)
		if device == "Gamepad" then
			GuiService.SelectedObject = firstButton
		end
	end
	self._troveSelections:Add(DeviceUtils.onChanged(selectFirst))

	task.wait() -- Show() makes the dialog visible a frame late; selecting a hidden button is dropped
	selectFirst(DeviceUtils.getCurrent())

	if not done then
		finished:Wait()
	end
	self._troveSelections:Clean()
	self:_clearSelection()
end

function DialogComponent:_clearSelection()
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(self._ui.Options) then
		GuiService.SelectedObject = nil
	end
end

function DialogComponent:Show()
	task.delay(0, function()
		self.Instance.Visible = true
	end)
end

function DialogComponent:Hide()
	self.Instance.Visible = false
end

function DialogComponent:Stop()
	self.Instance.Visible = false
	self._trove:Clean()
	self._troveSelections:Clean()
	self:_clearSelection()
	Fusion.doCleanup(self._scope)
end

return DialogComponent