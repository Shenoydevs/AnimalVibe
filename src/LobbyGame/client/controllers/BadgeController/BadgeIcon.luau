--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local BadgeConfig = require(ReplicatedStorage.Common.config.BadgeConfig)
local BadgeState = require(script.Parent.Parent.Parent.states.BadgeState)

local _colorInfo = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Shared = {}

function Shared.bind(scope, container, badgeId, highlight)
	local stroke: ImageLabel = container:WaitForChild("Stroke")
	local icon: ImageLabel = container:WaitForChild("Icon")
	local base: ImageLabel = container:WaitForChild("Base")
	local color: Fusion.Computed<Color3> = scope:Computed(function(use)
		return BadgeConfig.rarityColors[BadgeConfig.badges[use(badgeId)].rarity]
	end)
	local transparency: Fusion.Computed<number> = scope:Computed(function(use)
		return if use(BadgeState.earned)[use(badgeId)] then 0 else 0.65
	end)

	local strokeColor: Fusion.Computed<Color3> = scope:Computed(function(use)
		return use(color):Lerp(Color3.new(1, 1, 1), if highlight then use(highlight) else 0)
	end)
	scope:Hydrate(stroke)({ ImageColor3 = scope:Tween(strokeColor, _colorInfo), ImageTransparency = transparency })
	scope:Hydrate(base)({ ImageColor3 = scope:Tween(color, _colorInfo), ImageTransparency = transparency })
	scope:Hydrate(icon)({
		Image = scope:Computed(function(use)
			return BadgeConfig.badges[use(badgeId)].icon
		end),
		ImageTransparency = transparency,
	})
end

return Shared
