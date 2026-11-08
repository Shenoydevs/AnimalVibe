--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local ChallengeConfig = require(ReplicatedStorage.Shared.config.ChallengeConfig)
local ChallengeTypes = require(ReplicatedStorage.Shared.types.ChallengeTypes)

type ChallengeData = ChallengeTypes.ChallengeData

local _weekSeconds = 7 * 24 * 60 * 60
local _firstSunday = 3 * 24 * 60 * 60 -- Unix epoch began on Thursday.

local Private = {}
local Shared = {}

function Private._nextReset(now: number): number
	return _firstSunday + (math.floor((now - _firstSunday) / _weekSeconds) + 1) * _weekSeconds
end

function Private._getCurrent(player: Player, dontReplicate: boolean?): ChallengeData?
	if not DataService:hasProfile(player) then
		return nil
	end

	local challenges: ChallengeData = DataService:get(player, { "Challenges" })
	local now = os.time()
	if challenges.Timer > now then
		return challenges
	end

	local updated = table.clone(challenges)
	updated.Timer = Private._nextReset(now)
	updated.Progress = table.clone(challenges.Progress)
	for _, challenge in ChallengeConfig do
		if challenge.category == "weekly" then
			updated.Progress[challenge.id] = nil
		end
	end
	DataService:set(player, { "Challenges" }, updated, dontReplicate)
	return updated
end

function Shared.recordEquip(player: Player, animalName: string): ()
	local challenges = Private._getCurrent(player)
	if not challenges then
		return
	end

	local progress = table.clone(challenges.Progress)
	local weeklyCount = 0
	for _, challenge in ChallengeConfig do
		if
			challenge.category == "weekly"
			and challenge.animalName == animalName
			and (progress[challenge.id] or 0) < challenge.target
		then
			progress[challenge.id] = challenge.target
			weeklyCount += 1
		end
	end
	if weeklyCount == 0 then
		return
	end

	for _, challenge in ChallengeConfig do
		local previous = progress[challenge.id] or 0
		if challenge.category == "milestone" and previous < challenge.target then
			progress[challenge.id] = math.min(previous + weeklyCount, challenge.target)
		end
	end

	-- Save completion and milestone progress together; repeated equips cannot count twice.
	local updated = table.clone(challenges)
	updated.Progress = progress
	DataService:set(player, { "Challenges" }, updated)
end

function Shared.loadPlayer(player: Player): ()
	-- onPlayerInit runs before the client's first snapshot.
	Private._getCurrent(player, true)
end

function Private._scheduleReset(): ()
	local now = os.time()
	task.delay(Private._nextReset(now) - now, function(): ()
		for _, player in Players:GetPlayers() do
			Private._getCurrent(player)
		end
		Private._scheduleReset()
	end)
end

function Shared.OnStart(): ()
	Private._scheduleReset()
end

return Shared
