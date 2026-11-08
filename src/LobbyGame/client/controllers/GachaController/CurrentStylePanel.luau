--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GachaConfig = require(ReplicatedStorage.Shared.config.GachaConfig)
local GachaTypes = require(ReplicatedStorage.Shared.types.GachaTypes)
local SpinMotion = require(script.Parent.SpinMotion)

type Rarity = GachaTypes.Rarity
type SpinResult = GachaTypes.SpinResult

-- Rarer results land harder: a stronger panel flash and screen shake.
local _flashPeak: { [Rarity]: number } =
	{ Common = 0.25, Rare = 0.35, Epic = 0.45, Legendary = 0.55, Mythical = 0.7, Secret = 0.85 }
local _shakeStrength: { [Rarity]: number } =
	{ Common = 0, Rare = 0, Epic = 4, Legendary = 7, Mythical = 11, Secret = 16 }

local _styleIds: { string } = {}
local _topPanel: Frame
local _top: ImageLabel
local _header: TextLabel
local _styleName: TextLabel
local _description: TextLabel
local _headerText = ""
-- The authored colours return once a rarity colour no longer applies.
local _headerColor = ColorSequence.new(Color3.new(1, 1, 1))
local _styleNameColor = ColorSequence.new(Color3.new(1, 1, 1))

local Private = {}
local Shared = {}

function Private._authoredColor(label: TextLabel): ColorSequence
	local gradient = label:FindFirstChildOfClass("UIGradient")
	return if gradient then gradient.Color else ColorSequence.new(label.TextColor3)
end

function Private._outcomeText(result: SpinResult): string
	if result.outcome == "duplicate" then
		return `DUPLICATE: +{result.coins} COINS`
	end
	local replaced = result.replacedId and GachaConfig.styles[result.replacedId]
	if replaced then
		return `NEW STYLE! REPLACED {string.upper(replaced.name)}`
	end
	return "NEW STYLE!"
end

function Shared.bind(topPanel: Frame): ()
	for styleId in GachaConfig.styles do
		table.insert(_styleIds, styleId)
	end
	_topPanel = topPanel
	_top = topPanel:WaitForChild("Base") :: ImageLabel
	_header = _top:WaitForChild("CurrentStyle") :: TextLabel
	_styleName = _top:WaitForChild("StyleName") :: TextLabel
	_description = _top:WaitForChild("Description") :: TextLabel
	_headerText = _header.Text
	_headerColor = Private._authoredColor(_header)
	_styleNameColor = Private._authoredColor(_styleName)
end

-- Shows the equipped style; its name pops when it just changed.
function Shared.render(equippedStyle: string, changed: boolean): ()
	local equipped = GachaConfig.styles[equippedStyle]
	_header.Text = _headerText
	SpinMotion.tint(_header, _headerColor)
	_styleName.Text = if equipped then string.upper(equipped.name) else "NONE"
	SpinMotion.tint(_styleName, if equipped then GachaConfig.rarityColors[equipped.rarity] else _styleNameColor)
	_description.Text = if equipped then string.upper(equipped.description) else "SPIN TO WIN A STYLE"
	if changed then
		SpinMotion.pop(_styleName, 1.2, 0.3)
	end
end

function Shared.message(text: string): ()
	_description.Text = text
	SpinMotion.fadeIn(_description, 0.2)
end

-- Cycles style names for the given seconds, then lands on the rolled style.
function Shared.reveal(result: SpinResult, cycle: number): ()
	local style = GachaConfig.styles[result.styleId :: string]
	local rarity = style.rarity
	_header.Text = "SPINNING..."
	SpinMotion.tint(_header, _headerColor)
	SpinMotion.fadeIn(_header, 0.2)
	_description.Text = ""
	local elapsed = 0
	while elapsed < cycle do
		-- Each name flickers past in its own rarity's colour.
		local passing = GachaConfig.styles[_styleIds[math.random(#_styleIds)]]
		_styleName.Text = string.upper(passing.name)
		SpinMotion.tint(_styleName, GachaConfig.rarityColors[passing.rarity])
		SpinMotion.pop(_styleName, 1.1, 0.1, Enum.EasingStyle.Quad)
		local progress = elapsed / cycle
		-- Names tick slower as the reel winds down.
		elapsed += task.wait(0.05 + progress * progress * 0.2)
	end
	_header.Text = string.upper(rarity)
	_styleName.Text = string.upper(style.name)
	SpinMotion.tint(_header, GachaConfig.rarityColors[rarity])
	SpinMotion.tint(_styleName, GachaConfig.rarityColors[rarity])
	_description.Text = Private._outcomeText(result)
	SpinMotion.pop(_header, 1.35, 0.35)
	SpinMotion.pop(_styleName, 1.6, 0.45)
	SpinMotion.slideIn(_description, UDim2.fromOffset(0, 14), 0.3)
	SpinMotion.fadeIn(_description, 0.3)
	SpinMotion.flash(_top, _flashPeak[rarity], 0.5)
	if _shakeStrength[rarity] > 0 then
		SpinMotion.shake(_topPanel, _shakeStrength[rarity], 0.45)
	end
end

function Shared.playOpen(): ()
	SpinMotion.fadeIn(_header, 0.3, 0.25)
	SpinMotion.fadeIn(_styleName, 0.3, 0.3)
	SpinMotion.fadeIn(_description, 0.3, 0.35)
end

return Shared
