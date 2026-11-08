export type PartyData = {
	State: string,
	Owner: Player?,
	Members: { [Player]: boolean },
	Timer: thread?,
	Cancelled: boolean,
	SessionId: number,
	MaxPlayers: number,
	IsPrivate: boolean,
	SpawnInside: CFrame,
	SpawnOutside: CFrame,
}

return {}
