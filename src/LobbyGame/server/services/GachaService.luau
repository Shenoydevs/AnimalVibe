--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local Networker = require(ReplicatedStorage.Packages.Networker)
local QuickZone = require(ReplicatedStorage.Packages.QuickZone)
local GachaConfig = require(ReplicatedStorage.Shared.config.GachaConfig)
local GachaTypes = require(ReplicatedStorage.Shared.types.GachaTypes)
local Network = require(ReplicatedStorage.Shared.network)

type GachaData = GachaTypes.GachaData
type Rarity = GachaTypes.Rarity
type SpinResult = GachaTypes.SpinResult
type ActionResult = GachaTypes.ActionResult

-- Characters land this high above the platform and settle onto it.
local _dropHeight = 4
local _returnDistance = 32
-- The opener zone rises this high above the circle, covering rigs that hover on their hip height.
local _openerHeight = 12
local _random = Random.new()
local _stylesByRarity: { [Rarity]: { string } } = {}
local _visitors: { [Player]: Model } = {}
-- Per action, so picking a slot never rate-limits the next spin (which would end an auto-spin).
local _lastRequest: { [Player]: { [string]: number } } = {}
local _networker = nil
local _opener: BasePart
local _platform: BasePart

local Private = {}
local Shared = {}

function Private._checkRequest(player: Player, action: string): string?
	if player.Parent ~= Players or not DataService:hasProfile(player) then
		return "notReady"
	end
	local now = workspace:GetServerTimeNow()
	local requests = _lastRequest[player] or {}
	_lastRequest[player] = requests
	local lastRequest = requests[action]
	if lastRequest and now - lastRequest < 0.15 then
		return "rateLimited"
	end
	requests[action] = now
	-- A respawn leaves the gacha, so only the visiting character counts.
	if not player.Character or _visitors[player] ~= player.Character then
		return "away"
	end
	return nil
end

function Private._rollRarity(odds: { [Rarity]: number }): Rarity
	local roll = _random:NextNumber(0, 100)
	for _, rarity in GachaConfig.rarities do
		roll -= odds[rarity]
		if roll < 0 then
			return rarity
		end
	end
	return "Common"
end

-- Fills every slot up to maxStyles; older saves list only the slots they had filled.
function Private._slots(styles: { string }): { string }
	local slots = table.create(GachaConfig.maxStyles, "")
	for index = 1, GachaConfig.maxStyles do
		slots[index] = styles[index] or ""
	end
	return slots
end

function Private._isSlot(slot: any): boolean
	return type(slot) == "number" and slot % 1 == 0 and slot >= 1 and slot <= GachaConfig.maxStyles
end

function Private._moveCharacter(character: Model, target: Vector3, facing: Vector3): ()
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local rootCFrame = CFrame.lookAt(target, target + facing)
		+ Vector3.yAxis * (humanoid.HipHeight + root.Size.Y / 2 + _dropHeight)
	character:PivotTo(rootCFrame * root.CFrame:ToObjectSpace(character:GetPivot()))
end

function Private._enter(player: Player, character: Model): ()
	if _visitors[player] == character then
		return
	end
	if not DataService:hasProfile(player) or not DataService:get(player, { "Inventory", "HasSelectedFirstAnimal" }) then
		return
	end

	_visitors[player] = character
	-- The equipped style is the picked slot's, so it must be in a slot; older saves may equip one
	-- that is not, and then the first slot is picked.
	local styles = Private._slots(DataService:get(player, { "Gacha", "styles" }))
	if not table.find(styles, DataService:get(player, { "Inventory", "EquippedStyle" })) then
		DataService:set(player, { "Inventory", "EquippedStyle" }, styles[1])
	end
	local top = _platform.Position + Vector3.yAxis * _platform.Size.Y / 2
	-- The platform's open side faces -X, where the client places the camera.
	Private._moveCharacter(character, top, -Vector3.xAxis)
	_networker:fire(player, "_opened", _platform.Position)
end

function Private._spin(_, player: Player, lucky: any, slot: any): SpinResult
	local rejection = Private._checkRequest(player, "spin")
	if rejection then
		return { status = rejection } :: SpinResult
	end
	if type(lucky) ~= "boolean" or not Private._isSlot(slot) then
		return { status = "invalid" }
	end
	local gacha: GachaData = DataService:get(player, { "Gacha" })
	local available = if lucky then gacha.luckySpins else gacha.spins
	if available < 1 then
		return { status = "noSpins" }
	end

	local updated: GachaData = table.clone(gacha)
	updated.styles = Private._slots(gacha.styles)
	if lucky then
		updated.luckySpins -= 1
	else
		updated.spins -= 1
	end
	updated.pity += 1
	updated.secretPity += 1
	local rarity: Rarity
	if updated.secretPity >= GachaConfig.secretPityTarget then
		rarity = "Secret"
	elseif updated.pity >= GachaConfig.pityTarget then
		rarity = "Mythical"
	else
		rarity = Private._rollRarity(GachaConfig.odds[if lucky then "lucky" else "normal"])
	end
	-- A Secret also satisfies Mythical pity.
	if rarity == "Secret" then
		updated.secretPity = 0
		updated.pity = 0
	elseif rarity == "Mythical" then
		updated.pity = 0
	end

	local pool = _stylesByRarity[rarity]
	local styleId = pool[_random:NextInteger(1, #pool)]
	local result: SpinResult = { status = "rolled", styleId = styleId, rarity = rarity, outcome = "added", slot = slot }
	-- The roll lands in the picked slot even when another slot already holds the same style.
	local current = updated.styles[slot]
	if current == styleId then
		-- The slot already holds this style, so nothing changes and it pays duplicate coins instead.
		result.outcome = "duplicate"
		result.coins = GachaConfig.duplicateCoins[rarity]
	else
		updated.styles[slot] = styleId
		if current ~= "" then
			result.outcome = "replaced"
			result.replacedId = current
		end
	end

	-- These writes use the same session-locked profile and do not yield. Rolls land in the picked
	-- slot, which is the equipped one, so its new style is equipped.
	DataService:set(player, { "Gacha" }, updated)
	DataService:set(player, { "Inventory", "EquippedStyle" }, styleId)
	local coins = result.coins
	if coins then
		DataService:update(player, { "PlayerStats", "Nova" }, function(nova: number): number
			return nova + coins
		end)
	end
	return result
end

-- Picking a slot equips what it holds; an empty slot equips no style.
function Private._equip(_, player: Player, slot: any): ActionResult
	local rejection = Private._checkRequest(player, "equip")
	if rejection then
		return { status = rejection } :: ActionResult
	end
	if not Private._isSlot(slot) then
		return { status = "invalid" }
	end

	local styles = Private._slots(DataService:get(player, { "Gacha", "styles" }))
	DataService:set(player, { "Inventory", "EquippedStyle" }, styles[slot])
	return { status = "equipped" }
end

function Private._leave(_, player: Player): ActionResult
	local rejection = Private._checkRequest(player, "leave")
	if rejection then
		return { status = rejection } :: ActionResult
	end

	_visitors[player] = nil
	local character = player.Character :: Model
	-- Return beside the opener, outside its circle, so the player does not re-enter at once.
	local outward = (Vector3.new(-1, 0, 0.4)).Unit
	local target = _opener.Position + outward * _returnDistance
	Private._moveCharacter(character, target, outward)
	return { status = "left" }
end

function Shared.OnStart(): ()
	for styleId, style in GachaConfig.styles do
		local pool = _stylesByRarity[style.rarity] or {}
		table.insert(pool, styleId)
		_stylesByRarity[style.rarity] = pool
	end
	for _, rarity in GachaConfig.rarities do
		assert(_stylesByRarity[rarity], `[GachaService] No styles configured for {rarity}`)
	end

	_networker = Networker.server.new(Network.Gacha, Private, { Private._spin, Private._equip, Private._leave })
	Players.PlayerRemoving:Connect(function(player: Player): ()
		_visitors[player] = nil
		_lastRequest[player] = nil
	end)

	_platform = workspace:WaitForChild("Skin Gacha World"):WaitForChild("Circle") :: BasePart
	_opener = workspace
		:WaitForChild("Map")
		:WaitForChild("Buildings")
		:WaitForChild("Skin Shop Opener")
		:WaitForChild("Circle") :: BasePart
	-- The circle is a flat mesh, so the zone is an upright cylinder of its width rising above it.
	-- QuickZone cylinders run along their X axis.
	local zone = QuickZone.Zone.new({
		cframe = CFrame.new(_opener.Position + Vector3.yAxis * (_openerHeight / 2)) * CFrame.Angles(0, 0, math.pi / 2),
		size = Vector3.new(_openerHeight, _opener.Size.X, _opener.Size.X),
		shape = "Cylinder",
	})
	QuickZone.Observer
		.new({ groups = { QuickZone.Group.players() }, zones = { zone } })
		:onPlayerEnter(function(player: Player): ()
			local character = player.Character
			if character then
				Private._enter(player, character)
			end
		end)
end

return Shared
