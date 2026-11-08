--!strict
local ScavengeConfig = {
	tag = "Scavengeable",
	actionText = "Search",
	objectText = "House",
	holdDuration = 2.5,
	promptDistance = 12,
	zoneRadiusScale = 0.95,
	novaMin = 10,
	novaMax = 50,
}

assert(
	ScavengeConfig.novaMin >= 0 and ScavengeConfig.novaMax >= ScavengeConfig.novaMin,
	"[ScavengeConfig] invalid NOVA range"
)

return ScavengeConfig
