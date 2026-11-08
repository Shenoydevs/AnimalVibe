--!strict

export type Category = "weekly" | "milestone"

export type Challenge = {
	id: string,
	category: Category,
	title: string,
	description: string,
	target: number,
	animalName: string?,
}

-- Mirrors the Challenges profile field in Common/config/DataTemplate.
export type ChallengeData = {
	Timer: number,
	Progress: { [string]: number },
}

return {}
