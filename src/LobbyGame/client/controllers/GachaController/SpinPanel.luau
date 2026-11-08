--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GachaConfig = require(ReplicatedStorage.Shared.config.GachaConfig)
local GachaTypes = require(ReplicatedStorage.Shared.types.GachaTypes)
local SpinMotion = require(script.Parent.SpinMotion)

type GachaData = GachaTypes.GachaData
export type SpinButton = "spinOnce" | "lucky" | "fast" | "auto"
type Button = { frame: GuiObject, hit: ImageButton, icon: GuiObject? }

local _buttons: { [SpinButton]: Button } = {}
local _spinCountBase: ImageLabel
local _spinCount: TextLabel
local _spinPrice: TextLabel
local _luckyTitle: TextLabel
local _autoTitle: TextLabel
local _autoText = ""
local _goalFrame: ImageLabel
local _goalBox: TextBox

local Private = {}
local Shared = {}

function Private._bindButton(key: SpinButton, frame: GuiObject): ()
	local hit, icon = SpinMotion.bindButton(frame, true)
	_buttons[key] = { frame = frame, hit = hit, icon = icon }
end

function Private._goalRank(text: string): number?
	local goal = string.lower((string.gsub(text, "%s", "")))
	if #goal < 3 then
		return nil
	end
	for rank, rarity in GachaConfig.rarities do
		if string.sub(string.lower(rarity), 1, #goal) == goal then
			return rank
		end
	end
	return nil
end

function Shared.bind(bottom: Frame): ()
	local buttons = bottom:WaitForChild("Buttons")
	_spinCountBase = bottom:WaitForChild("ImageLabel") :: ImageLabel
	_spinCount = _spinCountBase:WaitForChild("BTNTItle") :: TextLabel
	_spinPrice = bottom:WaitForChild("SpinPrice") :: TextLabel
	local spinOnce = buttons:WaitForChild("SpinOnce")
	local luckyButton = spinOnce:WaitForChild("BTN2") :: Frame
	_luckyTitle = luckyButton:WaitForChild("BTNTItle") :: TextLabel
	local autoButton = buttons:WaitForChild("AutoSpin")
	local autoMain = autoButton:WaitForChild("MainBTN") :: Frame
	_autoTitle = autoMain:WaitForChild("BTNTItle") :: TextLabel
	_autoText = _autoTitle.Text
	_goalFrame = autoButton:WaitForChild("Textbox") :: ImageLabel
	_goalBox = _goalFrame:WaitForChild("TextBox") :: TextBox

	Private._bindButton("spinOnce", spinOnce:WaitForChild("MainBTN") :: Frame)
	Private._bindButton("lucky", luckyButton)
	Private._bindButton("fast", buttons:WaitForChild("FastSpin"):WaitForChild("MainBTN") :: Frame)
	Private._bindButton("auto", autoMain)

	-- Captured before focus can enlarge it, so blur always returns to the authored size.
	local goalScale = SpinMotion.scale(_goalFrame)
	local goalRest: number = SpinMotion.rest(goalScale, "Scale")
	_goalBox.Focused:Connect(function(): ()
		if not SpinMotion.reduced() then
			SpinMotion.play(
				goalScale,
				"Scale",
				TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = goalRest * 1.05 }
			)
		end
	end)
	_goalBox.FocusLost:Connect(function(): ()
		SpinMotion.play(goalScale, "Scale", TweenInfo.new(0.15), { Scale = goalRest })
	end)
end

function Shared.onActivated(key: SpinButton, callback: () -> ()): ()
	_buttons[key].hit.Activated:Connect(callback)
end

-- Given the previously shown data, a changed spin count pops.
function Shared.render(gacha: GachaData, previous: GachaData?): ()
	_spinCount.Text = `SPINS: {gacha.spins}`
	_luckyTitle.Text = `LUCKY SPIN x{gacha.luckySpins}`
	if not previous then
		return
	end
	if gacha.spins ~= previous.spins then
		SpinMotion.pop(_spinCountBase, 1.18, 0.3)
	end
	if gacha.luckySpins ~= previous.luckySpins then
		SpinMotion.pop(_luckyTitle, 1.3, 0.3)
	end
end

function Shared.spinIcon(key: SpinButton, spinning: boolean): ()
	local icon = _buttons[key].icon
	if icon then
		SpinMotion.spinIcon(icon, spinning)
	end
end

-- A refused spin shakes its button and points at the empty counter.
function Shared.reject(key: SpinButton, lucky: boolean): ()
	SpinMotion.pop(if lucky then _luckyTitle else _spinCountBase, 1.25, 0.35)
	SpinMotion.shake(_buttons[key].frame, 6, 0.35)
end

-- An empty goal is valid with no rank; text that names no rarity shakes the box and is invalid.
function Shared.readGoal(): (boolean, number?)
	local goal = Private._goalRank(_goalBox.Text)
	if goal == nil and string.match(_goalBox.Text, "%S") then
		SpinMotion.shake(_goalFrame, 6, 0.35)
		return false, nil
	end
	return true, goal
end

function Shared.setAuto(running: boolean): ()
	_autoTitle.Text = if running then "STOP AUTO" else _autoText
	SpinMotion.fadeIn(_autoTitle, 0.2)
	SpinMotion.pop(_autoTitle, 1.15, 0.25)
	Shared.spinIcon("auto", running)
end

-- The spin counter pops once the panels have arrived, unless the gacha has closed by then.
function Shared.playOpen(isOpen: () -> boolean): ()
	SpinMotion.fadeIn(_spinPrice, 0.3, 0.4)
	task.delay(0.35, function(): ()
		if isOpen() then
			SpinMotion.pop(_spinCountBase, 0.6, 0.4)
		end
	end)
end

return Shared
