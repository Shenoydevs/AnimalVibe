--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local config = require(ReplicatedStorage.Shared.config)
local Network = require(ReplicatedStorage.Shared.network)
local enums = require(ReplicatedStorage.Shared.enums)
local types = require(ReplicatedStorage.Shared.types)
local signals = require(ServerScriptService.Server.signals)
local PlaceConfig = require(ReplicatedStorage.Common.config.PlaceConfig)

type PartyData = types.PartyData
type NetworkerServer = types.NetworkerServer

local PartyConfig = config.PartyConfig
local PartyState = enums.PartyState
local PartySignals = signals.PartySignals

local _parties: { [Instance]: PartyData } = {}
local _teleportDebounce: { [Player]: boolean } = {}
local _networker: NetworkerServer?

local Private = {}
local Shared = {}

function Shared.OnStart()
	Private._setupParties()

	_networker =
		Networker.server.new(Network.Party, Private, { Private._closeParty, Private._configure, Private._exitParty })

	PartySignals.PlayerEntered:Connect(Private._onPlayerEntered)
	PartySignals.PlayerExited:Connect(Private._onPlayerExited)
	Players.PlayerRemoving:Connect(Private._onPlayerRemoving)
end

function Private._setupParties()
	for _, instance in CollectionService:GetTagged(PartyConfig.PartyZoneTag) do
		Private._setupParty(instance)
	end

	CollectionService:GetInstanceAddedSignal(PartyConfig.PartyZoneTag):Connect(Private._setupParty)
end

function Private._setupParty(instance: Instance)
	if not instance:IsA("Model") then
		return
	end

	local spawnInside = instance:FindFirstChild("SpawnInside") :: BasePart
	local spawnOutside = instance:FindFirstChild("SpawnOutside") :: BasePart

	if not (spawnInside and spawnOutside) then
		warn(`[PartyService] {instance.Name} is missing SpawnInside or SpawnOutside`)
		return
	end

	_parties[instance] = {
		State = PartyState.EMPTY,
		Owner = nil,
		Members = {},
		Timer = nil,
		Cancelled = false,
		SessionId = 0,
		MaxPlayers = PartyConfig.MaxPlayers,
		IsPrivate = false,
		SpawnInside = spawnInside.CFrame,
		SpawnOutside = spawnOutside.CFrame,
	}
end

function Private._configure(_: any, player: Player, maxPlayers: any, isPrivate: any)
	local p = player :: Player

	if type(maxPlayers) ~= "number" or type(isPrivate) ~= "boolean" then
		return
	end

	maxPlayers = math.clamp(maxPlayers, PartyConfig.MinPlayers, PartyConfig.MaxPlayers)

	for zone, party in _parties do
		if party.Owner ~= p or party.State ~= PartyState.CREATING then
			continue
		end

		if party.Timer then
			party.Cancelled = true
			task.cancel(party.Timer)
			party.Timer = nil
		end

		party.MaxPlayers = maxPlayers
		party.IsPrivate = isPrivate

		local count = Private._getMemberCount(party)
		zone:SetAttribute("MaxPlayers", party.MaxPlayers)
		zone:SetAttribute("MemberCount", count)

		if count >= party.MaxPlayers then
			Private._setState(zone, PartyState.STARTING)
			Private._startStartingTimer(zone, party)
		else
			Private._setState(zone, PartyState.INTERMISSION)
			Private._startIntermissionTimer(zone, party)
		end

		break
	end
end

function Private._closeParty(_: any, player: any)
	for zone, party in _parties do
		if party.Owner == player and party.State == PartyState.CREATING then
			Private._resetParty(zone, party)
			break
		end
	end
end

function Private._exitParty(_: any, player: any)
	local p = player :: Player
	for zone, party in _parties do
		if not party.Members[p] then
			continue
		end

		if party.Owner == p then
			Private._resetParty(zone, party)
		else
			party.Members[p] = nil
			PartySignals.PlayerLeft:Fire(zone, p)

			task.spawn(Private._movePlayer, p, party.SpawnOutside)

			if party.State == PartyState.INTERMISSION then
				zone:SetAttribute("MemberCount", Private._getMemberCount(party))
			end
		end
		break
	end
end

function Private._onPlayerEntered(zone: Instance, player: Player)
	local party = _parties[zone]
	if not party then
		warn(`[PartyService] Party not found for zone {zone.Name}`)
		return
	end

	if party.Members[player] then
		return
	end

	local isOwner = party.Owner == nil
	local isOpen = party.State == PartyState.INTERMISSION
	if not isOwner and not isOpen then
		return
	end

	if isOpen and party.IsPrivate then
		local owner = party.Owner :: Player
		local ok, isFriend = pcall(function()
			return player:IsFriendsWithAsync(owner.UserId)
		end)

		if not ok or not isFriend then
			return
		end

		if party.State ~= PartyState.INTERMISSION then
			return
		end
	end

	party.Members[player] = true

	if _networker then
		_networker:fire(player, "_onJoinedParty")
	end

	task.spawn(Private._movePlayer, player, party.SpawnInside)

	if isOpen then
		local count = Private._getMemberCount(party)
		zone:SetAttribute("MemberCount", count)

		if count >= party.MaxPlayers and party.Timer then
			party.Cancelled = true

			task.cancel(party.Timer)

			party.Timer = nil
			Private._setState(zone, PartyState.STARTING)
			Private._startStartingTimer(zone, party)
		end
	end

	if isOwner then
		party.Owner = player
		party.SessionId += 1
		Private._setState(zone, PartyState.CREATING)

		local sessionId = party.SessionId
		party.Timer = task.delay(PartyConfig.CreatingDuration, function()
			local current = _parties[zone]
			if
				not current
				or current.SessionId ~= sessionId
				or current.State ~= PartyState.CREATING
				or current.Cancelled
			then
				return
			end

			current.Timer = nil
			Private._resetParty(zone, current)
		end)

		if _networker then
			_networker:fire(player, "_openPartyConfig", PartyConfig.CreatingDuration)
		end
	end
end

function Private._onPlayerRemoving(player: Player)
	for zone, party in _parties do
		if not party.Members[player] then
			continue
		end

		if party.Owner == player then
			Private._resetParty(zone, party)
		else
			party.Members[player] = nil
			PartySignals.PlayerLeft:Fire(zone, player)

			if party.State == PartyState.INTERMISSION then
				zone:SetAttribute("MemberCount", Private._getMemberCount(party))
			end
		end
		break
	end
end

function Private._onPlayerExited(zone: Instance, player: Player)
	local party = _parties[zone]
	if not party or not party.Members[player] then
		return
	end

	if party.Owner == player then
		Private._resetParty(zone, party)
	else
		party.Members[player] = nil

		if _networker then
			_networker:fire(player, "_onLeftParty")
		end

		if party.State == PartyState.INTERMISSION then
			zone:SetAttribute("MemberCount", Private._getMemberCount(party))
		end
	end
end

function Private._setState(zone: Instance, state: string)
	local party = _parties[zone]
	if not party then
		return
	end

	party.State = state
	zone:SetAttribute("State", state)

	if state == PartyState.CREATING or state == PartyState.STARTING then
		zone:SetAttribute("IsOpen", false)
	else
		zone:SetAttribute("IsOpen", true)
	end
end

function Private._resetParty(zone: Instance, party: PartyData)
	if party.Timer then
		party.Cancelled = true
		task.cancel(party.Timer)
	end

	zone:SetAttribute("IsOpen", false)

	if party.Owner then
		if _networker then
			_networker:fire(party.Owner, "_onPartyCancelled")
		end
	end

	for member in party.Members do
		if _networker then
			_networker:fire(member, "_onLeftParty")
		end

		PartySignals.PlayerLeft:Fire(zone, member)
		task.spawn(Private._movePlayer, member, party.SpawnOutside)
	end

	party.State = PartyState.EMPTY
	party.Owner = nil
	party.Members = {}
	party.Timer = nil
	party.Cancelled = false
	party.SessionId += 1
	party.MaxPlayers = PartyConfig.MaxPlayers
	party.IsPrivate = false

	zone:SetAttribute("State", PartyState.EMPTY)
	zone:SetAttribute("MemberCount", 0)
	zone:SetAttribute("MaxPlayers", 0)
	zone:SetAttribute("Duration", 0)

	task.defer(function()
		zone:SetAttribute("IsOpen", true)
	end)
end

function Private._startIntermissionTimer(zone: Instance, party: PartyData)
	party.Cancelled = false
	local sessionId = party.SessionId
	party.Timer = task.spawn(function()
		for i = PartyConfig.IntermissionDuration, 0, -1 do
			zone:SetAttribute("Duration", i)

			if i == 0 then
				break
			end

			task.wait(1)

			if party.Cancelled or party.SessionId ~= sessionId then
				return
			end
		end

		party.Timer = nil

		Private._setState(zone, PartyState.STARTING)
		Private._startStartingTimer(zone, party)
	end)
end

function Private._startStartingTimer(zone: Instance, party: PartyData)
	party.Cancelled = false
	local sessionId = party.SessionId

	party.Timer = task.spawn(function()
		for i = PartyConfig.StartingDuration, 0, -1 do
			zone:SetAttribute("Duration", i)

			if i == 0 then
				break
			end

			task.wait(1)

			if party.Cancelled or party.SessionId ~= sessionId then
				return
			end
		end

		party.Timer = nil

		for member in party.Members do
			if not member.Character then
				party.Members[member] = nil
			end
		end

		if Private._getMemberCount(party) < PartyConfig.MinPlayers then
			Private._resetParty(zone, party)
			return
		end

		Private._teleportPlayers(zone, party)
	end)
end

function Private._teleportPlayers(zone: Instance, party: PartyData)
	local members = {}
	for member in party.Members do
		table.insert(members, member)
	end

	local ok, result = pcall(function()
		local accessCode = TeleportService:ReserveServerAsync(PlaceConfig.mainGameId)

		for _, member in members do
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = accessCode
			options:SetTeleportData({
				-- TODO: replace with real teleport data
				partySize = #members,
			})

			TeleportService:TeleportAsync(PlaceConfig.mainGameId, { member }, options)
		end
	end)

	if not ok then
		warn("[PartyService] Teleport failed:", result)
		Private._resetParty(zone, party)
	end
end

function Private._getMemberCount(party: PartyData): number
	local count = 0

	for _ in party.Members do
		count += 1
	end

	return count
end

function Private._movePlayer(player: Player, cframe: CFrame)
	if _teleportDebounce[player] then
		return
	end

	_teleportDebounce[player] = true

	local character = player.Character
	if not character then
		_teleportDebounce[player] = nil
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		_teleportDebounce[player] = nil
		return
	end

	root.CFrame = cframe

	task.defer(function()
		_teleportDebounce[player] = nil
	end)
end

return Shared
