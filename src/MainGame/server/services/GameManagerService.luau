--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local types = require(ReplicatedStorage.Shared.types)
local Network = require(ReplicatedStorage.Shared.network.CharacterNetwork)
local ItemConsumeNetwork = require(ReplicatedStorage.Shared.network.ItemConsumeNetwork)

local Signals = require(ServerScriptService.Server.signals)

local EquipStateService = require(ServerScriptService.Server.services.EquipStateService)
local InventoryService = require(ServerScriptService.Server.services.InventoryService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local GroundItemUtils = require(ServerScriptService.Server.utils.GroundItemUtils)

local CharacterConfig = require(ReplicatedStorage.Shared.config.CharactersConfig)
local PricingRevive = require(ReplicatedStorage.Shared.config.RevivePricingConfig)
local ItemConfig = require(ReplicatedStorage.Shared.config.ItemConfig)
local DataTemplate = require(ReplicatedStorage.Common.config.DataTemplate)
local PlaceConfig = require(ReplicatedStorage.Common.config.PlaceConfig)

type NetworkerServer = types.NetworkerServer

type RateWindow = {
	windowStart: number,
	count: number,
}

local PERMANENT_DEATH_SECONDS = 120
local RETURN_TO_LOBBY_SECONDS = 77
local DATA_WAIT_TIMEOUT = 15
local DEFAULT_ANIMAL: string = DataTemplate.Inventory.EquippedAnimal
-- The client sends tilt at 20/s (TiltControl) and item visuals on equip changes.
local MAX_TILT_UPDATES_PER_SECOND = 30
local MAX_ITEM_REPLICATIONS_PER_SECOND = 10
-- Ground-normal tilt never exceeds ~65 degrees; anything larger is not a real tilt.
local MAX_TILT_ANGLE = math.rad(80)

local _networker: NetworkerServer
local _itemConsumeNetworker: NetworkerServer
local GameManagerService = {}
local _numReplayPlayers = 0
local _numPlayers = 0
local _replayPlayers: { [Player]: boolean } = {}
local _countedPlayers: { [Player]: boolean } = {}
local _tiltWindows: { [Player]: RateWindow } = {}
local _itemWindows: { [Player]: RateWindow } = {}

local Private = {}

local function _withinRate(windows: { [Player]: RateWindow }, player: Player, maxPerSecond: number): boolean
	local now: number = os.clock()
	local window: RateWindow? = windows[player]
	if not window or now - window.windowStart >= 1 then
		windows[player] = { windowStart = now, count = 1 }
		return true
	end
	window.count += 1
	return window.count <= maxPerSecond
end

local function _teleportToLobby(players: { Player }): ()
	if #players == 0 then return end
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(PlaceConfig.lobbyId, players)
	end)
	if not ok then
		warn(`[GameManagerService] Lobby teleport failed: {err}`)
	end
end

-- Keeps the team together in a fresh reserved match; falls back to the Lobby if that fails.
local function _teleportToNewMatch(players: { Player }): ()
	if #players == 0 then return end
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = TeleportService:ReserveServerAsync(PlaceConfig.mainGameId)
		TeleportService:TeleportAsync(PlaceConfig.mainGameId, players, options)
	end)
	if not ok then
		warn(`[GameManagerService] Replay teleport failed, sending the team to the Lobby: {err}`)
		_teleportToLobby(players)
	end
end

function GameManagerService:EndGameWon()
	for _, player in Players:GetPlayers() do
		PlayerDataService.awardRoundXp(player)
	end
end

function GameManagerService:CountAlivePlayers()
	local count = 0
	for _, v in Players:GetPlayers() do
		if v.Character and v.Character:GetAttribute("alive") then
			count += 1
		end
	end
	return count
end

function GameManagerService:GetProgressivePriceZone(reviveAll: boolean)
	local getZone = 1
	return if reviveAll then PricingRevive.ReviveAll[getZone] else PricingRevive.ReviveMe[getZone]
end

local function _broadcastReplayCount(): ()
	_networker:fireAll("ReplayCount", _numReplayPlayers, _numPlayers)
end

local function _checkReplay(): ()
	if ReplicatedStorage.ComingBack.Value == true then return end
	if _numPlayers == 0 or _numReplayPlayers < _numPlayers then return end

	ReplicatedStorage.ComingBack.Value = true
	local players = Players:GetPlayers()
	for _, v in players do
		PlayerDataService.awardRoundXp(v)
	end
	_teleportToNewMatch(players)
end

local function UpdateReplay(player: Player?)
	if ReplicatedStorage.ComingBack.Value == true then
		return
	end

	if player then
		if _replayPlayers[player] then
			_replayPlayers[player] = nil
			_numReplayPlayers -= 1
		else
			_replayPlayers[player] = true
			_numReplayPlayers += 1
		end
	end

	_broadcastReplayCount()
	if player then
		_checkReplay()
	end
end

-- TODO APPLY DINAMYC PRICING FOR REVIVE BUTTONS DEPENDING ON THE LAST ZONE

function GameManagerService:EndGameLost()
	UpdateReplay()
	local productId = GameManagerService:GetProgressivePriceZone(true)
	for _, player: Player in Players:GetPlayers() do
		_networker:fire(player, "ShowLost", false)
		local char: Model? = player.Character
		if not char then continue end

		char:SetAttribute("canBuyRevive", nil)
		char:SetAttribute("canRevive", nil)
		char:SetAttribute("canReviveAll", true)
		_networker:fire(player, "ReviveAllOffer", productId, RETURN_TO_LOBBY_SECONDS)
		_networker:fire(player, "ShowLostALL", true)
	end

	task.spawn(function()
		for _ = RETURN_TO_LOBBY_SECONDS, 0, -1 do
			if ReplicatedStorage.ComingBack.Value == true then return end
			if GameManagerService:CountAlivePlayers() > 0 then
				-- Someone bought a team revive; the round continues.
				_replayPlayers = {}
				_numReplayPlayers = 0
				_broadcastReplayCount()
				return
			end
			task.wait(1)
		end

		ReplicatedStorage.ComingBack.Value = true
		local players = Players:GetPlayers()
		for _, v in players do
			PlayerDataService.awardRoundXp(v)
		end
		_teleportToLobby(players)
	end)
end

function GameManagerService:LostPlayer(player: Player, char: Model)
	local productId = GameManagerService:GetProgressivePriceZone(false)
	local deathMod: number = char:GetAttribute("deathMod") :: number
	local deathSeconds: number = math.max(PERMANENT_DEATH_SECONDS * deathMod, 30)
	local reviveSeconds: number = math.max(60 * (1 - (deathMod - 1)), 20)
	char:SetAttribute("deathMod", deathMod + 0.15)

	-- Every downing opens a new purchase window, not just the first one.
	char:SetAttribute("canBuyRevive", true)
	char:SetAttribute("canRevive", true)
	_networker:fire(player, "DownedOffer", productId, math.ceil(reviveSeconds), deathSeconds)
	_networker:fire(player, "ShowLost", true)

	local function isAlive(): boolean
		return char:GetAttribute("alive") == true
	end

	task.spawn(function()
		local deadline: number = os.clock() + reviveSeconds + 1
		repeat
			task.wait(1)
		until os.clock() >= deadline or isAlive()
		char:SetAttribute("canBuyRevive", nil)
	end)

	task.spawn(function()
		local deadline: number = os.clock() + deathSeconds
		repeat
			task.wait(0.5)
		until os.clock() >= deadline or isAlive()
		if isAlive() then return end

		char:SetAttribute("canRevive", nil)
		if player.Parent == Players then
			_networker:fire(player, "DiedPermanently")
		end
	end)
end

function GameManagerService:PreparePlayer(chosedAnimal: string)
	local animalData = CharacterConfig[chosedAnimal]
	local animalChar = ReplicatedStorage.Assets.Animals[chosedAnimal]:Clone()

	animalChar.PrimaryPart.Anchored = true

	animalChar:SetAttribute("attackDamage", animalData.damage)
	animalChar:SetAttribute("attackSpeed", animalData.attackCooldown)

	animalChar:SetAttribute("currentSpeed", animalData.walkSpeed)
	animalChar:SetAttribute("walkSpeed", animalData.walkSpeed)
	animalChar:SetAttribute("runningSpeed", animalData.sprintSpeed)

	animalChar:SetAttribute("cartModifier", animalData.cartModifier)

	animalChar:SetAttribute("baseStamina", 100 * animalData.healthModifier)
	animalChar:SetAttribute("maxStamina", 100 * animalData.healthModifier)
	animalChar:SetAttribute("stamina", 100 * animalData.healthModifier)

	animalChar:SetAttribute("damage", 0)
	animalChar:SetAttribute("thirst", 0)
	animalChar:SetAttribute("hunger", 0)
	animalChar:SetAttribute("sickness", 0)
	animalChar:SetAttribute("weight", 0)

	animalChar:SetAttribute("alive", true)
	animalChar:SetAttribute("canRevive", true)
	animalChar:SetAttribute("canBuyRevive", true)
	animalChar:SetAttribute("deathMod", 1)

	animalChar:SetAttribute("animalClass", chosedAnimal)
	animalChar:AddTag("ShareItem")

	for _, sound in ReplicatedStorage.Assets.AnimalSounds.Shared:GetChildren() do
		sound:Clone().Parent = animalChar.PrimaryPart
	end

	animalChar.PrimaryPart.Anchored = false

	return animalChar
end

-- Falls back to the template's default animal when the saved one has no MainGame rig/config.
local function _validAnimal(name: any): string
	if type(name) == "string" and CharacterConfig[name] and ReplicatedStorage.Assets.Animals:FindFirstChild(name) then
		return name
	end
	warn(`[GameManagerService] Animal "{tostring(name)}" is not playable here, using {DEFAULT_ANIMAL}`)
	return DEFAULT_ANIMAL
end

-- Studio keeps using the DebugAnimal value; live servers use the animal equipped in the Lobby.
local function _withAnimal(player: Player, callback: (animal: string) -> ()): ()
	if RunService:IsStudio() then
		local debugAnimal: Instance? = ReplicatedStorage:FindFirstChild("DebugAnimal")
		if debugAnimal and debugAnimal:IsA("StringValue") then
			callback(_validAnimal(debugAnimal.Value))
			return
		end
	end

	local settled = false
	local function settle(animal: string): ()
		if settled or player.Parent ~= Players then return end
		settled = true
		callback(animal)
	end
	task.spawn(function()
		settle(_validAnimal(PlayerDataService.waitForEquippedAnimal(player)))
	end)
	task.delay(DATA_WAIT_TIMEOUT, function()
		if settled or player.Parent ~= Players then return end
		warn(`[GameManagerService] {player.Name}'s data did not load in time, using {DEFAULT_ANIMAL}`)
		settle(DEFAULT_ANIMAL)
	end)
end

function GameManagerService.OnStart()
	_networker = Networker.server.new(Network.Character, Private, { Private._playAgain, Private._replicateItem, Private._requestDropItem, Private._debugItem, Private.UpdateTilt })
	_itemConsumeNetworker = Networker.server.new(ItemConsumeNetwork.ItemConsume)

	local comingBack = Instance.new("BoolValue")
	comingBack.Name = "ComingBack"
	comingBack.Value = false
	comingBack.Parent = ReplicatedStorage

	local mapFolder: Folder = workspace:WaitForChild("Map") :: Folder
	local playersFolder: Folder = mapFolder:WaitForChild("Players") :: Folder

	local _terrainReady: boolean = false
	local _pendingPlayers: { [Player]: string } = {}

	local function assignCharacter(player: Player, chosedAnimal: string): ()
		if player.Parent ~= Players or _countedPlayers[player] then return end
		_countedPlayers[player] = true
		_numPlayers += 1

		local char: Model = GameManagerService:PreparePlayer(chosedAnimal)
		-- Named before parenting so clients never see the template's name.
		char.Name = player.Name
		char.Parent = playersFolder
		char.HumanoidRootPart.Anchored = false

		local spawnLoc: SpawnLocation? = workspace:FindFirstChildWhichIsA("SpawnLocation") :: SpawnLocation?
		if spawnLoc then
			char:PivotTo(spawnLoc.CFrame)
		end

		local previous: Model? = player.Character
		player.Character = char
		if previous and previous ~= char then
			previous:Destroy()
		end
		_networker:fire(player, "InitCharacter", chosedAnimal)

		char:GetAttributeChangedSignal("alive"):Connect(function()
			if char:GetAttribute("alive") == true then return end
			task.delay(3, function()
				if GameManagerService:CountAlivePlayers() > 0 then GameManagerService:LostPlayer(player, char) return end
				GameManagerService:EndGameLost()
			end)
		end)
	end

	local function onPlayerAdded(player: Player): ()
		_withAnimal(player, function(animal: string)
			if _terrainReady then
				assignCharacter(player, animal)
			else
				_pendingPlayers[player] = animal
			end
		end)
	end

	Signals.GameSignals.MapSpawnReady:Connect(function()
		_terrainReady = true
		for player, animal in _pendingPlayers do
			assignCharacter(player, animal)
		end
		table.clear(_pendingPlayers)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		_pendingPlayers[player] = nil
		_tiltWindows[player] = nil
		_itemWindows[player] = nil
		if _countedPlayers[player] then
			_countedPlayers[player] = nil
			_numPlayers -= 1
		end
		if _replayPlayers[player] then
			_replayPlayers[player] = nil
			_numReplayPlayers -= 1
		end
		if ReplicatedStorage.ComingBack.Value == true then return end
		_broadcastReplayCount()
		-- The leaver may have been the last vote the rest of the team was waiting on.
		if _numReplayPlayers > 0 then
			_checkReplay()
		end
	end)

	-- Character Signals for Debuff

	local function updateMaxStamina(character : Model)
		return math.max(character:GetAttribute("baseStamina") - (character:GetAttribute("damage") + character:GetAttribute("thirst") + character:GetAttribute("sickness") + character:GetAttribute("hunger") + character:GetAttribute("weight")), 0)
	end

	local function updateAliveState(player : Player, character : Model, maxStamina : number) : boolean
		if maxStamina > 0 and not character:GetAttribute("alive") then
			character:SetAttribute("alive", true)
			_networker:fire(player, "Revive")
			return true
		elseif maxStamina <= 0 and character:GetAttribute("alive") then
			character:SetAttribute("alive", false)
			Signals.InventorySignals.DropAll:Fire(player)
			return false
		end
		return true
	end

	Signals.CharacterSignals.ModDebuff:Connect(function(player : Player, debuff : string, value : number)
		local char: Model = player.Character
		if not char then return end

		if char:GetAttribute("IFrame") and value >= 0 then return end
		if char:GetAttribute("maxStamina") <= 0 and value > 0  then return end

		char:SetAttribute(debuff, math.clamp(char:GetAttribute(debuff) + value,0,150))
		local maxStamina = updateMaxStamina(char)
		char:SetAttribute("maxStamina", maxStamina)
		updateAliveState(player, char, maxStamina)

		if debuff == "damage" and value > 0 then
			_networker:fireAll("onAnimalDamaged", char)
		end
		_networker:fire(player, "ModDebuff", debuff, value)
	end)

	Signals.CharacterSignals.SetDebuff:Connect(function(player : Player, debuff : string, value : number)
		local char: Model = player.Character
		if not char then return end

		if char:GetAttribute("IFrame") and value >= char:GetAttribute(debuff) then return end
		if char:GetAttribute("maxStamina") <= 0 and value >= char:GetAttribute(debuff) then return end

		char:SetAttribute(debuff, math.clamp(value,0,150))

		local maxStamina = updateMaxStamina(char)
		char:SetAttribute("maxStamina", maxStamina)
		updateAliveState(player, char, maxStamina)
		_networker:fire(player, "SetDebuff", debuff, value)
	end)

	Signals.CharacterSignals.IFrames:Connect(function(player : Player, timer : number)
		local char: Model = player.Character
		if not char then return end

		char:SetAttribute("IFrame", true)
		task.delay(timer, function()
			char:SetAttribute("IFrame", false)
		end)
	end)

	Signals.CharacterSignals.ConsumeVFX:Connect(function(eaterCharName : string, hungerValue : number?, healValue : number?)
		_networker:fireAll("ItemVFX", eaterCharName, hungerValue, healValue)
	end)

	Signals.CharacterSignals.Revived:Connect(function(player : Player, reviveAll : boolean)
		local char: Model? = player.Character
		if not char then return end
		char:SetAttribute("alive", true)
		_networker:fire(player, if reviveAll then "ShowLostALL" else "ShowLost", false)
	end)

	Signals.CharacterSignals.ItemConsumed:Connect(function(player : Player, itemID : string)
		_itemConsumeNetworker:fire(player, "onItemConsumed", itemID)
	end)
end

function Private._playAgain(_: any, player: Player)
	UpdateReplay(player)
end

function Private._debugItem(_: any, player: Player, itemName: any)
	if not RunService:IsStudio() then return end
	local character: Model? = player.Character
	if type(itemName) ~= "string" or not character then return end
	GroundItemUtils.spawnAt(itemName, character:GetPivot() * CFrame.new(0, 0, -5))
end

function Private._requestDropItem(_: any, player: Player, itemID: any): ()
	if type(itemID) ~= "string" then
		return
	end

	local itemData = ItemConfig[itemID]
	if not itemData then
		return
	end

	if EquipStateService:GetEquippedItem(player) ~= itemID then
		return
	end
	local char: Model? = player.Character
	if not char then
		return
	end

	if not InventoryService:dropItem(player, itemID, 1) then
		return
	end
end

-- Cosmetic relay of the equipped tool to other clients; only tools the player owns are relayed.
function Private._replicateItem(_: any, player: Player, show: any, itemID: any): ()
	if not _withinRate(_itemWindows, player, MAX_ITEM_REPLICATIONS_PER_SECOND) then return end

	if show ~= true then
		_networker:fireAllExcept(player, "ReplicateItem", player, nil)
		return
	end

	if type(itemID) ~= "string" then return end
	local itemData = ItemConfig[itemID]
	if not itemData or itemData.slot ~= "Hotbar" then return end
	if InventoryService:countItem(player, itemID) < 1 then return end
	_networker:fireAllExcept(player, "ReplicateItem", player, itemID)
end

-- Cosmetic relay of the ground-normal tilt; only a bounded, finite rotation is passed on.
function Private.UpdateTilt(_: any, player: Player, tiltRotation: any)
	if typeof(tiltRotation) ~= "CFrame" then return end
	if not _withinRate(_tiltWindows, player, MAX_TILT_UPDATES_PER_SECOND) then return end

	local rotation: CFrame = tiltRotation.Rotation
	local _axis: Vector3, angle: number = rotation:ToAxisAngle()
	-- `not (x <= max)` also rejects NaN.
	if not (math.abs(angle) <= MAX_TILT_ANGLE) then return end

	_networker:fireAllExcept(player, "UpdateTilt", player, rotation)
end

return GameManagerService
