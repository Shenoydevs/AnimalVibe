--!strict
local LevelingConfig = {
	xpPerLevel = 100,
	roundXp = 100,
}

function LevelingConfig.xpForLevel(level: number): number
	return level * LevelingConfig.xpPerLevel
end

function LevelingConfig.addXp(level: number, xp: number, amount: number): (number, number)
	xp += amount
	while xp >= LevelingConfig.xpForLevel(level) do
		xp -= LevelingConfig.xpForLevel(level)
		level += 1
	end
	return level, xp
end

return LevelingConfig
