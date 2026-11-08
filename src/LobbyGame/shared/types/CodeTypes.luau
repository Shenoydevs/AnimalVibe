--!strict

export type RedeemResult = {
	status: "redeemed",
	coins: number,
} | {
	status: "invalid" | "alreadyRedeemed" | "notReady" | "rateLimited",
}

return {}
