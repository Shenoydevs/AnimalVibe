--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FollowPromptConfig = require(ReplicatedStorage.Shared.config.FollowPromptConfig)
local CharacterUtils = require(ReplicatedStorage.Shared.utils.CharacterUtils)

export type PromptOptions = {
	actionText: string,
	objectText: string,
	holdDuration: number,
	maxDistance: number,
	keyboardKeyCode: Enum.KeyCode?,
	gamepadKeyCode: Enum.KeyCode?,
	offset: number?,
}

local FollowPromptUtils = {}

-- The client slides the returned anchor to the zone edge nearest its own player (see FollowPromptController).
function FollowPromptUtils.attach(zone: BasePart, radius: number, height: number): Attachment
	zone:SetAttribute(FollowPromptConfig.radiusAttribute, radius)
	zone:SetAttribute(FollowPromptConfig.heightAttribute, height)
	local anchor: Attachment = Instance.new("Attachment")
	anchor.Name = FollowPromptConfig.anchorName
	anchor.Position = Vector3.new(0, height, 0)
	anchor.Parent = zone
	CollectionService:AddTag(zone, FollowPromptConfig.tag)
	return anchor
end

-- An invisible part at the model's bounding-box centre, since a model's PrimaryPart can sit anywhere in it.
function FollowPromptUtils.createZone(model: Model, radiusScale: number): (BasePart, Attachment)
	local box: CFrame, size: Vector3 = model:GetBoundingBox()
	local zone: Part = Instance.new("Part")
	zone.Name = "PromptZone"
	zone.Size = Vector3.one
	zone.CFrame = CFrame.new(box.Position)
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanTouch = false
	zone.CanQuery = false
	zone.CastShadow = false
	zone.Transparency = 1
	zone.Parent = model
	local radius: number = math.max(size.X, size.Z) / 2 * radiusScale
	local anchor: Attachment = FollowPromptUtils.attach(zone, radius, -size.Y / 2 + 2)
	return zone, anchor
end

function FollowPromptUtils.createPrompt(anchor: Attachment, options: PromptOptions): ProximityPrompt
	local prompt: ProximityPrompt = Instance.new("ProximityPrompt")
	prompt.ActionText = options.actionText
	prompt.ObjectText = options.objectText
	prompt.HoldDuration = options.holdDuration
	-- Roblox re-checks reach on the server against the anchor's server position (the zone centre), so the
	-- server copy must cover the whole zone; each client shrinks its own copy back to maxDistance from the edge.
	local zone: Instance? = anchor.Parent
	local radius: number = if zone then (zone:GetAttribute(FollowPromptConfig.radiusAttribute) :: number?) or 0 else 0
	prompt.MaxActivationDistance = radius + options.maxDistance + FollowPromptConfig.reachTolerance
	prompt:SetAttribute(FollowPromptConfig.clientDistanceAttribute, options.maxDistance)
	prompt.KeyboardKeyCode = options.keyboardKeyCode or Enum.KeyCode.E
	prompt.GamepadKeyCode = options.gamepadKeyCode or Enum.KeyCode.ButtonX
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("offset", options.offset or 0)
	prompt.Parent = anchor
	return prompt
end

function FollowPromptUtils.canReach(player: Player, zone: BasePart, maxDistance: number): boolean
	local character: Model? = player.Character
	if not character or character:GetAttribute("alive") ~= true then
		return false
	end
	local root: BasePart? = CharacterUtils.getPlayerRoot(player)
	if not root then
		return false
	end
	local radius: number = (zone:GetAttribute(FollowPromptConfig.radiusAttribute) :: number?) or zone.Size.X / 2
	local offset: Vector3 = root.Position - zone.Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius + maxDistance + FollowPromptConfig.reachTolerance
		and math.abs(offset.Y) <= FollowPromptConfig.maxReachHeight
end

return FollowPromptUtils
