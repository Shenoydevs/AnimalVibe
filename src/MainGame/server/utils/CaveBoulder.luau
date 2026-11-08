--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage.Shared.config.BoulderConfig)
local CaveConfig = require(ReplicatedStorage.Shared.config.CaveGenerationConfig)
local CaveGenerator = require(script.Parent.CaveGenerator)

local CaveBoulder = {}

function CaveBoulder.place(container: Folder, cave: CaveGenerator.cave, template: Model): Model
	local inward = ((cave.landform.shelter - cave.landform.entry) * Vector3.new(1, 0, 1)).Unit
	local outward = -inward
	local floor = cave.landform.entry + inward * CaveConfig.entranceRiseLength
	local model = template:Clone()
	model.Name = "EntranceBoulder"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local _, originalSize = model:GetBoundingBox()
	local diameter = CaveConfig.entranceRadius * 2 + Config.entranceOverlap
	model:ScaleTo(model:GetScale() * math.max(
		diameter / originalSize.X,
		(CaveConfig.entranceHeight + Config.entranceOverlap) / (originalSize.Y * (1 - Config.groundEmbedFraction))
	))
	local box, size = model:GetBoundingBox()
	local center = floor + Vector3.new(0, size.Y * (0.5 - Config.groundEmbedFraction), 0)
	local frame = CFrame.lookAt(center, center + outward)
	-- A random roll about the pull axis keeps every boulder's facets from presenting the same face.
	local roll = CFrame.Angles(0, 0, Random.new(math.floor(floor.X * 7 + floor.Z * 13)):NextNumber(0, math.pi * 2))
	model:PivotTo(frame * roll * box:ToObjectSpace(model:GetPivot()))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = true
		end
	end
	model:SetAttribute("pullDirection", outward)
	model:SetAttribute("pullDistance", CaveConfig.entranceRiseLength + size.Z / 2 + Config.clearance)
	model:SetAttribute("pullProgress", 0)
	model:SetAttribute("cleared", false)
	model:SetAttribute("pullerCount", 0)
	container:SetAttribute("blocked", true)

	-- The mesh's irregular edges must not leave a walkable gap around the seal.
	-- Keep this seal at the mouth while the visible boulder is being extracted.
	local seal = Instance.new("Part")
	seal.Name = "BoulderSeal"
	seal.Size = Vector3.new(diameter, CaveConfig.entranceHeight + Config.entranceOverlap, 4)
	seal.CFrame = CFrame.lookAt(floor + Vector3.new(0, seal.Size.Y / 2 - 2, 0), floor + outward + Vector3.new(0, seal.Size.Y / 2 - 2, 0))
	seal.Transparency = 1
	seal.Anchored = true
	seal.Parent = container
	local sealReference = Instance.new("ObjectValue")
	sealReference.Name = "EntranceSeal"
	sealReference.Value = seal
	sealReference.Parent = model

	local ropes = Instance.new("Folder")
	ropes.Name = "PullRopes"
	ropes.Parent = model
	local rockPart = assert(model:FindFirstChildWhichIsA("BasePart", true), "Boulder needs a BasePart")
	for index = 1, Config.maxPullers do
		local lateral = (index - (Config.maxPullers + 1) / 2) * Config.ropeSlotSpacing
		local position = floor + outward * (size.Z / 2 + Config.ropeHandleOffset)
			+ frame.RightVector * lateral + Vector3.new(0, Config.ropeHeight, 0)
		local handle = Instance.new("Part")
		handle.Name = `RopePullPart{index}`
		-- Invisible support for the loose rope end and grab prompt.
		handle.Size = Vector3.new(0.2, 0.2, 0.2)
		handle.Transparency = 1
		handle.Anchored = true
		handle.CanCollide = false
		handle.CanTouch = false
		handle.CanQuery = false
		handle.Position = position
		handle.Parent = ropes
		local tip = Instance.new("Attachment")
		tip.Name = "RopeTip"
		tip.Parent = handle
		local anchor = Instance.new("Attachment")
		anchor.Name = `BoulderRopeAnchor{index}`
		anchor.Position = rockPart.CFrame:PointToObjectSpace(position - outward * (Config.ropeHandleOffset + 4))
		anchor.Parent = rockPart
		local rope = Instance.new("RopeConstraint")
		rope.Name = "PullRope"
		rope.Attachment0 = anchor
		rope.Attachment1 = tip
		rope.Length = Config.ropeHandleOffset + 4.5
		rope.Thickness = Config.ropeThickness
		rope.Visible = true
		rope.Restitution = 0
		rope.Color = BrickColor.new(Color3.fromRGB(139, 90, 43))
		rope.Parent = handle
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PullBoulder"
		prompt.ActionText = "Grab rope"
		prompt.ObjectText = "Cave boulder"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance = Config.interactDistance
		prompt.RequiresLineOfSight = false
		-- Attachment parenting uses Roblox's built-in prompt, including touch input.
		prompt.Parent = tip
	end
	model.Parent = container
	CollectionService:AddTag(model, Config.tag)
	return model
end

return CaveBoulder
