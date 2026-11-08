--!strict
local ChallengeTypes = require(script.Parent.Parent.types.ChallengeTypes)

type Challenge = ChallengeTypes.Challenge

-- IDs are saved in Challenges.Progress; keep them stable when editing display text.
local challenges: { Challenge } = {
	{
		id = "weeklyWolf",
		category = "weekly",
		title = "Wolf pack",
		description = "Equip Wolf in the lobby.",
		target = 1,
		animalName = "Wolf",
	},
	{
		id = "weeklyBear",
		category = "weekly",
		title = "Bear necessities",
		description = "Equip Bear in the lobby.",
		target = 1,
		animalName = "Bear",
	},
	{
		id = "weeklyCompletions",
		category = "milestone",
		title = "Weekly regular",
		description = "Complete 5 weekly challenges.",
		target = 5,
	},
}

return challenges
