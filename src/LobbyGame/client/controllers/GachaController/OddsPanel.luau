--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GachaConfig = require(ReplicatedStorage.Shared.config.GachaConfig)
local GachaTypes = require(ReplicatedStorage.Shared.types.GachaTypes)
local SpinMotion = require(script.Parent.SpinMotion)

type Rarity = GachaTypes.Rarity
type Row = { base: ImageLabel, percent: TextLabel }

local _dimmedTab = 0.45
-- Seconds between odds rows sliding in, so each row arrives on its own.
local _rowStagger = 0.08

local _rows: { [Rarity]: Row } = {}
-- Rows cascade top to bottom in the list layout's order, not rarity order.
local _rowOrder: { Row } = {}
local _tabs: { [string]: Frame } = {}
local _selected = ""
local _cascade = 0

local Private = {}
local Shared = {}

function Private._percent(value: number): string
	return if value % 1 == 0 then string.format("%d", value) else string.format("%.1f", value)
end

function Private._cascadeRows(delay: number): ()
	_cascade += 1
	local token = _cascade
	for index, row in _rowOrder do
		if SpinMotion.reduced() then
			row.base.Visible = true
			SpinMotion.slideIn(row.base, UDim2.new(), 0)
			SpinMotion.fadeIn(row.percent, 0)
			continue
		end
		-- Each row stays hidden until its turn; a newer cascade takes over pending rows.
		row.base.Visible = false
		task.delay(delay + (index - 1) * _rowStagger, function(): ()
			if token ~= _cascade then
				return
			end
			row.base.Visible = true
			SpinMotion.slideIn(row.base, UDim2.fromOffset(50, 0), 0.3)
			SpinMotion.fadeIn(row.percent, 0.25)
		end)
	end
end

function Private._show(key: string): ()
	if _selected == key then
		return
	end
	local animate = _selected ~= ""
	_selected = key
	for rarity, row in _rows do
		row.percent.Text = `[{Private._percent(GachaConfig.odds[key][rarity])}%]`
	end
	for tabKey, tab in _tabs do
		SpinMotion.dim(tab:WaitForChild("MainTitle") :: TextLabel, tabKey ~= key, _dimmedTab)
	end
	if animate then
		SpinMotion.pop(_tabs[key], 1.1, 0.3)
		Private._cascadeRows(0)
	end
end

function Shared.bind(topRight: Frame): ()
	local rarityRows = topRight:WaitForChild("Rarities")
	for _, rarity in GachaConfig.rarities do
		local row = rarityRows:FindFirstChild(rarity)
		if row then
			local base = row:WaitForChild("Base") :: ImageLabel
			local entry: Row = { base = base, percent = base:WaitForChild("%") :: TextLabel }
			_rows[rarity] = entry
			table.insert(_rowOrder, entry)
		end
	end
	table.sort(_rowOrder, function(a: Row, b: Row): boolean
		return (a.base.Parent :: GuiObject).LayoutOrder < (b.base.Parent :: GuiObject).LayoutOrder
	end)

	local oddsTabs = topRight:WaitForChild("NormalVsLuckyOdds")
	_tabs.normal = oddsTabs:WaitForChild("NormalOdds") :: Frame
	_tabs.lucky = oddsTabs:WaitForChild("LuckyOdds") :: Frame
	for key, tab in _tabs do
		local hitBox = SpinMotion.bindButton(tab)
		hitBox.Activated:Connect(function(): ()
			Private._show(key)
		end)
	end
	Private._show("normal")
end

function Shared.playOpen(): ()
	Private._cascadeRows(0.3)
end

-- The rolled rarity's row lights up as the reel lands.
function Shared.highlight(rarity: Rarity): ()
	local row = _rows[rarity]
	if row then
		SpinMotion.pop(row.base, 1.12, 0.4)
		SpinMotion.flash(row.base, 0.6, 0.5)
	end
end

return Shared
