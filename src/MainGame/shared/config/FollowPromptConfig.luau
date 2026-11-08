--!strict
return {
	tag = "FollowPrompt",
	anchorName = "PromptAnchor",
	radiusAttribute = "followRadius",
	heightAttribute = "followHeight",
	clientDistanceAttribute = "clientDistance",
	-- Zones further than this past their edge can't show a prompt, so their anchors aren't worth moving.
	updateMargin = 40,
	-- Server-side reach check slack; the client moves the anchor locally, so the server can't trust its position.
	reachTolerance = 6,
	maxReachHeight = 25,
}
