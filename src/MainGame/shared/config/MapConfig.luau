--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeTypes = require(ReplicatedStorage.Shared.types.BiomeTypes)

type MapConfig = {
	biomeSequence: { BiomeTypes.Biome },
	biomeDepth: { min: number, max: number }, -- depth in chunks, one roll shared by every biome
	halfWidth: { min: number, max: number }, -- map half-width in chunks
	biomeBlendChunks: number,
}

return {
	-- Ordered front-to-back; adding a biome is one require line here
	biomeSequence = {
		require(script.Parent.BiomeForestConfig),
		require(script.Parent.BiomeFarmlandConfig),
		require(script.Parent.BiomeIndustrialConfig),
		require(script.Parent.BiomeAutumnwoodConfig),
		require(script.Parent.BiomeSnowfieldsConfig),
		require(script.Parent.BiomeArcticConfig),
	},
	biomeDepth = { min = 150, max = 180 }, -- 1500-1800 studs (10 studs/chunk)
	halfWidth = { min = 45, max = 55 }, -- 900-1100 studs total width, randomized per server
	biomeBlendChunks = 8,
} :: MapConfig
