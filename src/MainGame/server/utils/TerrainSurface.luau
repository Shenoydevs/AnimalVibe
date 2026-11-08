--!strict
local _replicatedStorage = game:GetService("ReplicatedStorage")

local _config = require(_replicatedStorage.Shared.config.MapGenerationConfig)
local _biomeTypes = require(_replicatedStorage.Shared.types.BiomeTypes)

type biome = _biomeTypes.Biome
type surfaceRow = {
	index: number,
	blend: number,
	left: number,
	right: number,
	road: boolean,
}
type heightRow = {
	values: { [number]: number },
	index: number,
	blend: number,
	sideScale: number,
	riseStart: number,
	spawnFade: number,
}

local terrainSurface = {}
terrainSurface.__index = terrainSurface

export type terrainSurface = typeof(setmetatable(
	{} :: {
		_startPos: Vector3,
		_seed: number,
		_biomes: { biome },
		_halfWidth: number,
		_biomeDepth: number,
		_mapDepth: number,
		_blendChunks: number,
		_centers: { [number]: number },
		_rows: { [number]: surfaceRow },
		_heightRows: { [number]: heightRow },
		_heightRowKeys: { number },
		_heightRowHead: number,
		_minRoadWidth: number,
	},
	terrainSurface
))

local function _smoothstep(a: number, b: number, x: number): number
	local t: number = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function _hill(x: number, z: number, seed: number, biome: biome): number
	local scale: number = biome.hillNoiseScale or _config.hillNoiseScale
	local height: number = math.max(0, math.noise(x / scale + seed, z / scale) - (biome.hillThreshold or _config.hillThreshold))
		* (biome.hillHeight or _config.hillHeight)
		* (biome.hillScale or 1)
	local detailAmp: number = biome.grassDetailHeight or _config.grassDetailHeight
	if detailAmp ~= 0 then
		local detailScale: number = biome.grassDetailScale or _config.grassDetailScale
		height += math.noise(x / detailScale + seed + 211, z / detailScale) * detailAmp
	end
	return height
end

local function _roll(x: number, z: number, seed: number, biome: biome): number
	local amplitude: number = biome.rollHeight or _config.rollHeight
	if amplitude == 0 then
		return 0
	end
	local scale: number = biome.rollScale or _config.rollScale
	local n: number = math.noise(x / scale + seed + 307, z / scale)
		+ math.noise(x / (scale * 0.4) + seed + 401, z / (scale * 0.4)) * 0.35
	-- Never below zero, so ground beside the fixed-height road can't sink and leave it raised like a causeway.
	return math.clamp(n * 0.5 + 0.5, 0, 1) * amplitude
end

local function _spawnFade(z: number): number
	local chunkStuds: number = _config.chunkScale * 4
	return _smoothstep(_config.spawnDepth * chunkStuds, (_config.spawnDepth + 12) * chunkStuds, z)
end

function terrainSurface.biomeAt(self: terrainSurface, chunkZ: number): (number, number)
	local index: number = math.clamp(math.floor(chunkZ / self._biomeDepth) + 1, 1, #self._biomes)
	local blend: number = if index < #self._biomes
		then 1 - math.clamp((index * self._biomeDepth - chunkZ) / self._blendChunks, 0, 1)
		else 0
	return index, blend
end

function terrainSurface.rawHeight(self: terrainSurface, x: number, z: number): number
	local chunkStuds: number = _config.chunkScale * 4
	local row: heightRow? = self._heightRows[z]
	if not row then
		local index: number, blend: number = self:biomeAt(z / chunkStuds)
		local sideScale: number = self._biomes[index].sideRiseScale or 1
		if blend > 0 then
			sideScale += ((self._biomes[index + 1].sideRiseScale or 1) - sideScale) * blend
		end
		row = {
			values = {},
			index = index,
			blend = blend,
			sideScale = sideScale,
			riseStart = _config.sideRiseStart
				+ math.noise(z / _config.sideNoiseScale, self._seed + 23) * _config.sideRiseJitter,
			spawnFade = _spawnFade(z),
		}
		-- Keep only a chunk's voxel rows plus the next slope-sample row, rather than caching the entire map.
		local oldKey: number? = self._heightRowKeys[self._heightRowHead]
		if oldKey then
			self._heightRows[oldKey] = nil
		end
		self._heightRowKeys[self._heightRowHead] = z
		self._heightRowHead = self._heightRowHead % (math.ceil(_config.chunkScale) + 1) + 1
		self._heightRows[z] = row
	end
	local cached: number? = row.values[x]
	if cached then
		return cached
	end
	local height: number = _hill(x / 4, z / 4, self._seed, self._biomes[row.index])
	if row.blend > 0 then
		height += (_hill(x / 4, z / 4, self._seed, self._biomes[row.index + 1]) - height) * row.blend
	end
	local edge: number = _smoothstep(row.riseStart, 1, math.abs(x) / (self._halfWidth * chunkStuds))
	local ridge: number =
		math.clamp(0.8 + math.noise(x / _config.sideNoiseScale, z / _config.sideNoiseScale, self._seed) * 0.6, 0.4, 1.2)
	local result: number = (height + edge * ridge * _config.sideRiseHeight * row.sideScale) * row.spawnFade
	row.values[x] = result
	return result
end

function terrainSurface.getPathCenter(self: terrainSurface, chunkZ: number): number
	local z: number = math.clamp(chunkZ, 0, self._mapDepth)
	local near: number = math.floor(z)
	local first: number? = self._centers[near]
	local second: number? = self._centers[math.min(near + 1, self._mapDepth)]
	assert(first and second, "Path centers must be baked before terrain generation")
	return first + (second - first) * (z - near)
end

function terrainSurface.getRoadBounds(self: terrainSurface, chunkZ: number): (number, number)
	local chunkStuds: number = _config.chunkScale * 4
	local z: number = chunkZ * chunkStuds
	local minWidth: number = self._minRoadWidth
	local maxWidth: number = math.max(minWidth + 4, _config.roadMaxWidth)
	local width: number = math.clamp(
		(minWidth + maxWidth) * 0.5
			+ math.noise(z / _config.roadWidthNoiseScale, self._seed + 31) * (maxWidth - minWidth),
		minWidth,
		maxWidth
	)
	local center: number = self:getPathCenter(chunkZ) * chunkStuds
	local leftNoise: number = math.noise(z / 42, self._seed + 47) * 2
	local rightNoise: number = math.noise(z / 53, self._seed + 83) * 2
	local finalWidth: number = math.clamp(width + rightNoise - leftNoise, minWidth, maxWidth)
	local edgeCenter: number = center + (rightNoise + leftNoise) * 0.5
	local left: number = edgeCenter - finalWidth * 0.5
	local right: number = edgeCenter + finalWidth * 0.5
	return left / chunkStuds, right / chunkStuds
end

function terrainSurface.grassPatch(self: terrainSurface, worldX: number, worldZ: number): boolean
	local x: number = worldX - self._startPos.X
	local z: number = worldZ - self._startPos.Z
	local index: number, blend: number = self:biomeAt(z / (_config.chunkScale * 4))
	local threshold: number = self._biomes[index].grassPatchThreshold or _config.grassPatchThreshold
	if blend > 0 then
		threshold += ((self._biomes[index + 1].grassPatchThreshold or _config.grassPatchThreshold) - threshold) * blend
	end
	return math.noise(x / _config.grassPatchScale, z / _config.grassPatchScale, self._seed + 59)
			+ math.noise(x / 15, z / 15, self._seed + 67) * 0.12
		> threshold
end

function terrainSurface.sample(self: terrainSurface, worldX: number, worldZ: number): (number, Enum.Material)
	local x: number = worldX - self._startPos.X
	local z: number = worldZ - self._startPos.Z
	local chunkStuds: number = _config.chunkScale * 4
	local chunkZ: number = z / chunkStuds
	local row: surfaceRow? = self._rows[worldZ]
	if not row then
		local index: number, blend: number = self:biomeAt(chunkZ)
		local left: number, right: number = self:getRoadBounds(chunkZ)
		row = {
			index = index,
			blend = blend,
			left = left * chunkStuds,
			right = right * chunkStuds,
			road = chunkZ >= _config.cartChunkZ and chunkZ <= self._mapDepth,
		}
		self._rows[worldZ] = row
	end
	assert(row, "Terrain row preparation failed")
	local distance: number = math.max(row.left - x, x - row.right, 0)
	if row.road and distance == 0 then
		return self._startPos.Y, _config.roadType
	end
	local rawHeight: number = self:rawHeight(x, z)
	local height: number = rawHeight
	if chunkZ <= self._mapDepth then
		height *= _smoothstep(0, _config.pathCorridorChunks * chunkStuds, distance)
	end
	local roll: number = _roll(x / 4, z / 4, self._seed, self._biomes[row.index])
	if row.blend > 0 then
		roll += (_roll(x / 4, z / 4, self._seed, self._biomes[row.index + 1]) - roll) * row.blend
	end
	if roll > 0 then
		height += roll
			* _smoothstep(_config.roadShoulderWidth * 0.5, _config.roadShoulderWidth + _config.rollFadeWidth, distance)
			* _spawnFade(z)
	end
	height += math.clamp((chunkZ - self._mapDepth) * _config.endCapRisePerChunk, 0, _config.endCapMaxRise)
	local index: number = row.index
	if row.blend > 0 and math.noise(x / 16, z / 16, self._seed + 11) + 0.5 < row.blend then
		index += 1
	end
	local biome: biome = self._biomes[index]
	local getMaterial = biome.getTerrainMaterial
	local material: Enum.Material = if getMaterial then getMaterial(x / 4, z / 4, self._seed) else biome.TerrainType
	if
		material == Enum.Material.Grass
		and (distance < _config.roadShoulderWidth or not self:grassPatch(worldX, worldZ))
	then
		material = Enum.Material.LeafyGrass
	end
	if material == Enum.Material.Grass then
		if math.abs(self:rawHeight(x + 4, z) - rawHeight) > 3 or math.abs(self:rawHeight(x, z + 4) - rawHeight) > 3 then
			material = Enum.Material.LeafyGrass
		end
	end
	if row.road and distance < _config.roadShoulderWidth then
		material = biome.roadShoulderMaterial or Enum.Material.Ground
	end
	return self._startPos.Y + height, material
end

function terrainSurface.new(
	startPos: Vector3,
	seed: number,
	biomes: { biome },
	halfWidth: number,
	biomeDepth: number,
	blendChunks: number,
	minRoadWidth: number,
	yieldIfOver: () -> ()
): terrainSurface
	local self: terrainSurface = setmetatable({
		_startPos = startPos,
		_seed = seed,
		_biomes = biomes,
		_halfWidth = halfWidth,
		_biomeDepth = biomeDepth,
		_mapDepth = biomeDepth * #biomes,
		_blendChunks = blendChunks,
		_centers = {},
		_rows = {},
		_heightRows = {},
		_heightRowKeys = {},
		_heightRowHead = 1,
		_minRoadWidth = minRoadWidth,
	}, terrainSurface)
	local chunkStuds: number = _config.chunkScale * 4
	local heights: { [number]: { [number]: number } } = {}
	local maxX: number =
		math.ceil(_config.pathMaxDrift * 2 + _config.pathHillAvoidWindow + minRoadWidth / chunkStuds + 5)
	for z = 0, self._mapDepth + math.ceil(_config.pathHillLookahead) + 1 do
		local row: { [number]: number } = {}
		for x = -maxX, maxX do
			row[x] = self:rawHeight(x * chunkStuds, z * chunkStuds)
		end
		heights[z] = row
		yieldIfOver()
	end
	local function sampleHill(x: number, z: number): number
		local iz: number = math.floor(z)
		local ix: number = math.clamp(math.floor(x), -maxX, maxX - 1)
		local alpha: number = math.clamp(x - ix, 0, 1)
		local near: number = heights[iz][ix] + (heights[iz][ix + 1] - heights[iz][ix]) * alpha
		local far: number = heights[iz + 1][ix] + (heights[iz + 1][ix + 1] - heights[iz + 1][ix]) * alpha
		return near + (far - near) * (z - iz)
	end
	local raw: { [number]: number } = {}
	local previous: number = 0
	for z = 0, self._mapDepth do
		local desired: number = (
			math.noise(seed + z / _config.pathCurveScale)
			+ math.noise(seed * 1.7 + z / (_config.pathCurveScale * 0.4)) * 0.35
		) * _config.pathMaxDrift
		local target: number, bestCost: number = previous, math.huge
		for dx = -_config.pathHillAvoidWindow, _config.pathHillAvoidWindow do
			local candidate: number = desired + dx
			local worst: number = 0
			for _, ahead: number in { 0, _config.pathHillLookahead * 0.5, _config.pathHillLookahead } do
				for lane = -1, 1 do
					worst = math.max(
						worst,
						sampleHill(candidate + lane * minRoadWidth / chunkStuds * 0.5, z + ahead)
							- _config.pathHillIgnoreBelow
					)
				end
			end
			local cost: number = worst * _config.pathHillAvoidWeight
				+ math.abs(dx) * _config.pathDriftWeight
				+ math.abs(candidate - previous) * _config.pathContinuityWeight
			if cost < bestCost then
				bestCost, target = cost, candidate
			end
		end
		previous = math.clamp(target, previous - _config.pathMaxStepChunks, previous + _config.pathMaxStepChunks)
		raw[z] = math.clamp(previous, -halfWidth + 8, halfWidth - 8)
		yieldIfOver()
	end
	for z = 0, self._mapDepth do
		local sum: number, count: number = 0, 0
		for offset = -_config.pathSmoothWindow, _config.pathSmoothWindow do
			local value: number? = raw[z + offset]
			if value then
				sum += value
				count += 1
			end
		end
		self._centers[z] = sum / count
	end
	return self
end

return terrainSurface
