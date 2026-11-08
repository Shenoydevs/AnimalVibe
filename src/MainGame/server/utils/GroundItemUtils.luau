--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type SpawnOptions = {
	anchored: boolean?,
	droppedUI: boolean?,
}

local GroundItemUtils = {}

local function _groundItemsFolder(): Instance
	local map: Instance? = workspace:FindFirstChild("Map")
	local folder: Instance? = if map then map:FindFirstChild("GroundItems") else nil
	return folder or map or workspace
end

function GroundItemUtils.spawnAt(itemId: string, cframe: CFrame, options: SpawnOptions?): Model?
	local template: Instance? = ReplicatedStorage.Assets.Resources:FindFirstChild(itemId)
	if not template or not template:IsA("Model") then
		warn(`[GroundItemUtils] Missing resource template for itemID "{itemId}"`)
		return nil
	end

	local clone: Model = template:Clone()
	local primaryPart: BasePart? = clone.PrimaryPart
	if not primaryPart then
		warn(`[GroundItemUtils] "{itemId}" template is missing PrimaryPart`)
		clone:Destroy()
		return nil
	end

	local opts: SpawnOptions = options or {}
	if opts.anchored then
		primaryPart.Anchored = true
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
			end
		end
	end
	if opts.droppedUI then
		ReplicatedStorage.Assets.UI.DroppedItem:Clone().Parent = clone
	end

	clone:PivotTo(cframe)
	clone.Parent = _groundItemsFolder()
	return clone
end

function GroundItemUtils.spawn(itemId: string, character: Model, aroundCharacter: boolean?): ()
	local primaryPart: BasePart? = character.PrimaryPart
	if not primaryPart then return end

	local angle = math.random() * math.pi * 2
	local dropOffset = if aroundCharacter then CFrame.new(math.cos(angle) * 5, 0.85, math.sin(angle) * 5) else CFrame.new(0, 0.85, -5)
	GroundItemUtils.spawnAt(itemId, primaryPart.CFrame * dropOffset, { anchored = true, droppedUI = true })
end

return GroundItemUtils
