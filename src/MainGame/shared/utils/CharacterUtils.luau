--!strict

local CharacterUtils = {}

-- Shared guard for the common "model → HumanoidRootPart" chain. Works for
-- player characters and enemy models alike.
function CharacterUtils.getRoot(character: Model?): BasePart?
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function CharacterUtils.getPlayerRoot(player: Player): BasePart?
	return CharacterUtils.getRoot(player.Character)
end

return CharacterUtils
