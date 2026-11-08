--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ReplicatedStorage.Packages.DataService).client
local GachaConfig = require(ReplicatedStorage.Shared.config.GachaConfig)
local GachaTypes = require(ReplicatedStorage.Shared.types.GachaTypes)
local GachaNetwork = require(script.Parent.Parent.network.GachaNetwork)
local PopupUtils = require(script.Parent.Parent.utils.PopupUtils)
local CurrentStylePanel = require(script.CurrentStylePanel)
local OddsPanel = require(script.OddsPanel)
local PityPanel = require(script.PityPanel)
local SlotsPanel = require(script.SlotsPanel)
local SpinMotion = require(script.SpinMotion)
local SpinPanel = require(script.SpinPanel)

type GachaData = GachaTypes.GachaData
type Rarity = GachaTypes.Rarity
type SpinResult = GachaTypes.SpinResult
type SpinButton = SpinPanel.SpinButton
type Speed = { cycle: number, hold: number }
type Panel = { frame: GuiObject, from: UDim2 }

-- Seconds spent cycling style names, then holding the result.
local _normalSpeed: Speed = { cycle = 1.6, hold = 1.2 }
local _fastSpeed: Speed = { cycle = 0.35, hold = 0.45 }
-- The camera faces the platform's open (-X) side, where the character turns to.
local _cameraOffset = Vector3.new(-30, 9, 0)
local _lookOffset = Vector3.new(0, 5, 0)
local _failMessages: { [string]: string } = {
	noSpins = "NO SPINS LEFT",
	away = "RETURN TO THE SKIN SHOP",
}
local _fadeIn = 0.45
local _fadeOut = 0.28

local _player = Players.LocalPlayer
local _open = false
local _rolling = false
-- Slot picks whose equip request has not returned yet.
local _picking = 0
local _auto = false
local _closing = false

local Private = {}
local Shared = {}

function Private._setControls(enabled: boolean): ()
	local playerModule =
		require(_player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
	local controls = playerModule:GetControls()
	if enabled then
		controls:Enable()
	else
		controls:Disable()
	end
end

function Private._fade(fade: Frame, transparency: number, duration: number): ()
	if SpinMotion.reduced() then
		SpinMotion.cancel(fade, "BackgroundTransparency")
		fade.BackgroundTransparency = transparency
		return
	end
	SpinMotion.play(
		fade,
		"BackgroundTransparency",
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = transparency }
	)
end

function Private._bindGui(): ()
	local playerGui = _player:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("SpinGui") :: ScreenGui
	local spin = gui:WaitForChild("Spin")
	local topPanel = spin:WaitForChild("Top") :: Frame
	local topRight = spin:WaitForChild("TopRight") :: Frame
	local left = spin:WaitForChild("Left") :: Frame
	local bottom = spin:WaitForChild("Bottom2") :: Frame
	local bottomLeft = spin:WaitForChild("BottomLeft") :: Frame
	local bottomRight = spin:WaitForChild("BottomRight") :: Frame
	local backFrame = bottomLeft:WaitForChild("BackToLobbyBTN") :: ImageLabel
	local backButton = backFrame:WaitForChild("HitBox") :: ImageButton

	CurrentStylePanel.bind(topPanel)
	OddsPanel.bind(topRight)
	SpinPanel.bind(bottom)
	PityPanel.bind(bottomRight)
	SpinMotion.button(backFrame, backButton, backFrame, nil)

	-- Edge panels enter from, and leave towards, their own side of the screen.
	local panels: { Panel } = {
		{ frame = topPanel, from = UDim2.fromScale(0, -0.35) },
		{ frame = topRight, from = UDim2.fromScale(0.3, 0) },
		{ frame = left, from = UDim2.fromScale(-0.2, 0) },
		{ frame = bottom, from = UDim2.fromScale(0, 0.35) },
		{ frame = bottomLeft, from = UDim2.fromScale(-0.3, 0) },
		{ frame = bottomRight, from = UDim2.fromScale(0.25, 0) },
	}
	-- Covers the teleport between the lobby and the gacha platform; clear at rest.
	local fade = Instance.new("Frame")
	fade.Name = "SpinFade"
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.Size = UDim2.fromScale(1, 1)
	fade.ZIndex = 100
	fade.Parent = gui

	local shown: GachaData? = nil
	local shownStyle = ""
	-- The top panel shows the picked slot's style. A roll's reveal holds it, and it catches up once
	-- the reveal ends.
	local function renderCurrent(animate: boolean): ()
		if _rolling then
			return
		end
		local current = SlotsPanel.pickedStyle()
		CurrentStylePanel.render(current, animate and current ~= shownStyle)
		shownStyle = current
	end
	local function render(animate: boolean): ()
		local gacha: GachaData = DataService:get({ "Gacha" })
		-- Panels pop whatever changed since this previous render.
		local previous = if animate then shown else nil
		shown = table.clone(gacha)

		SpinPanel.render(gacha, previous)
		PityPanel.render(gacha, previous)
		SlotsPanel.render(gacha.styles, DataService:get({ "Inventory", "EquippedStyle" }), _picking == 0)
		renderCurrent(previous ~= nil)
	end

	-- A pick shows at once and saves as the equip; if the save fails, the next render returns the
	-- pick to the saved equip.
	SlotsPanel.bind(left, function(slot: number): ()
		renderCurrent(true)
		_picking += 1
		GachaNetwork.equip(slot)
		_picking -= 1
		-- A render mid-roll would show the roll's slots before its reveal lands.
		if _open and not _rolling then
			render(true)
		end
	end)

	local function roll(lucky: boolean, speed: Speed, button: SpinButton, withIcon: boolean, slot: number): SpinResult
		_rolling = true
		if withIcon then
			SpinPanel.spinIcon(button, true)
		end
		local result = GachaNetwork.spin(lucky, slot)
		if result.status == "rolled" then
			CurrentStylePanel.reveal(result, speed.cycle)
			OddsPanel.highlight(result.rarity :: Rarity)
			-- The landed slot flashes and takes the result as it lands, not after the hold.
			render(true)
			SlotsPanel.flashSlot(result.slot :: number)
			task.wait(speed.hold)
		else
			CurrentStylePanel.message(
				if result.status == "noSpins" and lucky
					then "NO LUCKY SPINS LEFT"
					else _failMessages[result.status] or "TRY AGAIN"
			)
			SpinPanel.reject(button, lucky)
			task.wait(1)
		end
		if withIcon then
			SpinPanel.spinIcon(button, false)
		end
		_rolling = false
		render(true)
		return result
	end

	local function onSpin(lucky: boolean, speed: Speed, button: SpinButton): ()
		if _rolling or _auto or _closing then
			return
		end
		roll(lucky, speed, button, true, SlotsPanel.target())
	end
	SpinPanel.onActivated("spinOnce", function(): ()
		onSpin(false, _normalSpeed, "spinOnce")
	end)
	SpinPanel.onActivated("lucky", function(): ()
		onSpin(true, _normalSpeed, "lucky")
	end)
	SpinPanel.onActivated("fast", function(): ()
		onSpin(false, _fastSpeed, "fast")
	end)
	SpinPanel.onActivated("auto", function(): ()
		if _auto then
			_auto = false
			return
		end
		if _rolling or _closing then
			return
		end
		-- Auto spins until it reaches the goal rarity (or better), runs out, or is stopped.
		local valid, goal = SpinPanel.readGoal()
		if not valid then
			CurrentStylePanel.message("GOAL: COMMON, RARE, EPIC, LEGENDARY, MYTHICAL OR SECRET")
			return
		end
		_auto = true
		SpinPanel.setAuto(true)
		while _auto and _open do
			-- Each roll reads the pick again, so changing it mid-auto aims the next roll.
			local result = roll(false, _fastSpeed, "auto", false, SlotsPanel.target())
			if result.status ~= "rolled" then
				break
			end
			if goal and (table.find(GachaConfig.rarities, result.rarity :: Rarity) :: number) >= goal then
				break
			end
		end
		_auto = false
		SpinPanel.setAuto(false)
	end)

	local function playOpen(): ()
		for index, panel in panels do
			SpinMotion.slideIn(panel.frame, panel.from, 0.55, (index - 1) * 0.06)
		end
		OddsPanel.playOpen()
		SlotsPanel.playOpen()
		CurrentStylePanel.playOpen()
		SpinPanel.playOpen(function(): boolean
			return _open
		end)
	end

	local function restore(): ()
		_open = false
		_auto = false
		Private._setControls(true)
		-- The current camera can be replaced after startup, so it is looked up on use.
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		local character = _player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		PopupUtils.ShowAllGuis()
	end
	local function settlePanels(): ()
		for _, panel in panels do
			SpinMotion.settle(panel.frame)
		end
	end

	backButton.Activated:Connect(function(): ()
		_auto = false
		if _rolling or _closing or not _open then
			return
		end
		_closing = true
		for _, panel in panels do
			SpinMotion.slideOut(panel.frame, panel.from, _fadeOut)
		end
		Private._fade(fade, 0, _fadeOut)
		task.wait(if SpinMotion.reduced() then 0 else _fadeOut)
		local result = GachaNetwork.leave()
		-- "away" means the server already treats the player as gone.
		if result.status == "left" or result.status == "away" then
			restore()
			Private._fade(fade, 1, _fadeIn)
			task.wait(if SpinMotion.reduced() then 0 else _fadeIn)
			if not _open then
				gui.Enabled = false
				settlePanels()
			end
		else
			Private._fade(fade, 1, _fadeIn)
			playOpen()
		end
		_closing = false
	end)

	GachaNetwork.handlers._opened = function(_, focus: Vector3): ()
		local popup = PopupUtils.GetCurrentPopup()
		if popup then
			PopupUtils.HidePopup(popup):await()
		end
		_open = true
		PopupUtils.HideAllGuis()
		Private._setControls(false)
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(focus + _cameraOffset, focus + _lookOffset)
		render(false)
		fade.BackgroundTransparency = 0
		gui.Enabled = true
		Private._fade(fade, 1, _fadeIn)
		playOpen()
	end
	-- Respawning returns the player to the lobby without the closing transition.
	_player.CharacterAdded:Connect(function(): ()
		if _open then
			restore()
			gui.Enabled = false
			fade.BackgroundTransparency = 1
			settlePanels()
		end
	end)
	-- The reveal shows the result first; the panels catch up when it ends.
	local function onDataChanged(): ()
		if _open and not _rolling then
			render(true)
		end
	end
	DataService:getChangedSignal({ "Gacha" }):Connect(onDataChanged)
	DataService:getChangedSignal({ "Inventory", "EquippedStyle" }):Connect(onDataChanged)
end

function Shared.OnStart(): ()
	DataService:waitForData()
	Private._bindGui()
end

return Shared
