--!strict
local Players = game:GetService("Players")

local PlayerUtils = {}

function PlayerUtils.forEachAlive(fn: (player: Player, character: Model) -> ()): ()
	for _, player in Players:GetPlayers() do
		local character: Model? = player.Character
		if not character or character:GetAttribute("alive") ~= true then continue end
		fn(player, character)
	end
end

return PlayerUtils
