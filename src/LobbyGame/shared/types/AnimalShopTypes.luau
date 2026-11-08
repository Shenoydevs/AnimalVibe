--!strict

export type Animal = {
	starter: boolean,
	order: number,
	coinPrice: number,
	requiredLevel: number,
	robuxPrice: number,
	productId: number?,
}

export type AnimalSkin = {
	order: number,
	coinPrice: number,
}

export type ActionStatus =
	"selected"
	| "equipped"
	| "purchased"
	| "alreadySelected"
	| "owned"
	| "locked"
	| "unavailable"
	| "levelRequired"
	| "insufficientCoins"
	| "chooseStarter"
	| "invalid"
	| "notReady"
	| "rateLimited"

export type ActionResult = { status: ActionStatus }

return {}
