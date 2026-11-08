--!strict
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _characterUtils = require(_replicatedStorage.Shared.utils.CharacterUtils)

local cartInteractionUtils = {}

function cartInteractionUtils.getRootWithin(player: Player, position: Vector3, distance: number): BasePart?
	local character: Model? = player.Character
	if not character or character:GetAttribute("alive") ~= true then return nil end
	local root: BasePart? = _characterUtils.getRoot(character)
	if not root or not root:IsDescendantOf(workspace) then return nil end
	if (root.Position - position).Magnitude > distance then return nil end
	return root
end

export type cartInteractionUtils = typeof(cartInteractionUtils)
return cartInteractionUtils
