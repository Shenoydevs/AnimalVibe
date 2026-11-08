--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RESOURCE_PROP_TAG = "ResourceProp"

local AssetUtils = {}

function AssetUtils.cloneResource(itemId: string, inert: boolean?): Model?
	local template: Instance? = ReplicatedStorage.Assets.Resources:FindFirstChild(itemId)
	if not template or not template:IsA("Model") or not template.PrimaryPart then
		return nil
	end

	local clone: Model = template:Clone()
	CollectionService:RemoveTag(clone, RESOURCE_PROP_TAG)
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		elseif inert and descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	return clone
end

return AssetUtils
