--!strict
local _replicatedStorage = game:GetService("ReplicatedStorage")

local _config = require(_replicatedStorage.Shared.config.CaveGenerationConfig)
local _mapConfig = require(_replicatedStorage.Shared.config.MapGenerationConfig)
local _biomeTypes = require(_replicatedStorage.Shared.types.BiomeTypes)
local _terrainSurface = require(script.Parent.TerrainSurface)

export type landform = {
	seed: number,
	entry: Vector3,
	shelter: Vector3,
	back: Vector3,
	radius: number,
	height: number,
}

export type passage = {
	a: Vector3,
	b: Vector3,
	radius: number,
	height: number,
	entrance: boolean,
	landform: landform?,
}

export type destination = {
	position: Vector3,
	layer: number,
	campfire: boolean,
	chests: number,
}

export type cave = {
	biomeIndex: number,
	passages: { passage },
	destinations: { destination },
	material: Enum.Material,
	landform: landform,
}

export type column = { floor: number, ceiling: number, wall: number }

local caveGenerator = {}
caveGenerator.__index = caveGenerator

local _emptyPassages: { passage } = {}
local _emptyColumns: { column } = {}

export type caveGenerator = typeof(setmetatable(
	{} :: {
		caves: { cave },
		_seed: number,
		_startPos: Vector3,
		_cells: { [string]: { passage } },
		_materials: { [passage]: Enum.Material },
	},
	caveGenerator
))

local function _projectSegment(a: Vector3, b: Vector3, x: number, z: number): (number, number)
	local dx: number = b.X - a.X
	local dz: number = b.Z - a.Z
	local lengthSquared: number = dx * dx + dz * dz
	local t: number = if lengthSquared > 0
		then math.clamp(((x - a.X) * dx + (z - a.Z) * dz) / lengthSquared, 0, 1)
		else 0
	local ox: number = x - (a.X + dx * t)
	local oz: number = z - (a.Z + dz * t)
	return math.sqrt(ox * ox + oz * oz), t
end

local function _smoothstep(a: number, b: number, value: number): number
	local t: number = math.clamp((value - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function _shapeLandform(form: landform, x: number, z: number, surface: number): (number, boolean)
	local frontDistance: number = _projectSegment(form.entry, form.shelter, x, z)
	local backDistance: number = _projectSegment(form.shelter, form.back, x, z)
	local distance: number = math.min(frontDistance, backDistance)
	-- Warp only past the core so the summit keeps the roof cover _hasCover validated; a capsule outline reads as man-made.
	local warp: number = math.noise(x / _config.hillWarpScale, z / _config.hillWarpScale, form.seed + 17)
		* _config.hillWarpStrength
		* _smoothstep(form.radius, form.radius + 20, distance)
	local slope: number = math.max(distance - form.radius + warp, 0)
	local lateral: number = 1 - _smoothstep(0, _config.entranceTerrainBlend, slope)
	if lateral == 0 then
		return surface, false
	end
	local direction: Vector3 = (form.shelter - form.entry) * Vector3.new(1, 0, 1)
	local along: number = ((x - form.entry.X) * direction.X + (z - form.entry.Z) * direction.Z) / direction.Magnitude
	local front: number = _smoothstep(0, _config.entranceRiseLength, along)
	local weight: number = lateral * front
	local crown: number = (1 - _smoothstep(0, form.radius * 1.6, distance)) * _config.hillCrownHeight
	local ridge: number = (math.noise(x / 32, z / 32, form.seed) + 1) * _config.entranceRidgeHeight
	local detail: number = math.noise(x / 13, z / 13, form.seed + 5) * _config.hillDetailHeight
	local raised: number = math.max(surface, form.entry.Y + form.height + crown + ridge + detail)
	local height: number = surface + (raised - surface) * weight
	local apron: number = (1 - _smoothstep(form.radius * 0.65, form.radius, frontDistance))
		* _smoothstep(-35, 0, along) * (1 - front)
	height += (form.entry.Y - height) * apron
	local mouthEdge: number = _config.entranceRadius
		+ _config.mouthRockWidth
		+ math.noise(x / 9, z / 9, form.seed + 29) * _config.mouthRockWidth * 0.6
	local mouth: boolean = frontDistance < mouthEdge and along > -6 and along < _config.entranceRiseLength + 6
	local outcrop: boolean = weight > 0.35
		and math.noise(x / 22, z / 22, form.seed + 41) > _config.outcropThreshold
	return height, mouth or outcrop
end

local function _cellKey(x: number, z: number): string
	return `{x}:{z}`
end

function caveGenerator.passagesAt(self: caveGenerator, chunkX: number, chunkZ: number): { passage }
	return self._cells[_cellKey(chunkX, chunkZ)] or _emptyPassages
end

function caveGenerator.column(
	self: caveGenerator,
	passages: { passage },
	x: number,
	z: number,
	surface: number
): (number, { column }, Enum.Material?, Enum.Material?)
	if #passages == 0 then
		return surface, _emptyColumns, nil, nil
	end
	local columns: { column } = {}
	local material: Enum.Material? = nil
	local surfaceMaterial: Enum.Material? = nil
	local noise: number = math.noise(x / _config.wallNoiseScale, z / _config.wallNoiseScale, self._seed)
		* _config.wallNoiseStrength
	for _, passage in passages do
		local form: landform? = passage.landform
		if form then
			local rocky: boolean
			surface, rocky = _shapeLandform(form, x, z, surface)
			if rocky then
				surfaceMaterial = self._materials[passage]
			end
			continue
		end
		local distance: number, t: number = _projectSegment(passage.a, passage.b, x, z)
		local floor: number = passage.a.Y + (passage.b.Y - passage.a.Y) * t
		local radius: number = passage.radius + noise
		if distance < radius then
			material = self._materials[passage]
			table.insert(columns, {
				floor = floor,
				ceiling = floor + (passage.height + noise) * math.sqrt(1 - (distance / radius) ^ 2),
				wall = radius - distance,
			})
		end
	end
	return surface, columns, material, surfaceMaterial
end

function caveGenerator.solidOccupancy(columns: { column }, y: number): number
	local air: number = 0
	for _, column in columns do
		local clearance: number = math.min(y - column.floor, column.ceiling - y, column.wall)
		air = math.max(air, math.clamp(0.5 + clearance / 4, 0, 1))
	end
	return 1 - air
end

function caveGenerator.reserve(self: caveGenerator, keepouts: _biomeTypes.KeepoutRegistry): ()
	for _, cave in self.caves do
		for _, passage in cave.passages do
			local steps: number = math.max(1, math.ceil((passage.b - passage.a).Magnitude / 20))
			for step = 0, steps do
				local point: Vector3 = passage.a:Lerp(passage.b, step / steps)
				-- The landform's outer slopes are ordinary hillside; keeping props off them leaves a bald dome.
				local form: landform? = passage.landform
				local radius: number = if form
					then form.radius + _config.entranceTerrainBlend * 0.5
					else passage.radius + _config.roofThickness * 2 + 8
				keepouts:add(point.X, point.Z, radius)
			end
		end
	end
end

local function _addPassage(cave: cave, a: Vector3, b: Vector3, radius: number, height: number, entrance: boolean?): ()
	local horizontal: number = ((b - a) * Vector3.new(1, 0, 1)).Magnitude
	assert(
		horizontal == 0 or math.abs(b.Y - a.Y) / horizontal <= _config.maxSlope,
		"Cave passage exceeds walking slope"
	)
	local steps: number = math.max(1, math.ceil(horizontal / 38))
	local perpendicular: Vector3 = if horizontal > 0
		then Vector3.new(-(b.Z - a.Z), 0, b.X - a.X) / horizontal
		else Vector3.zero
	local previous: Vector3 = a
	local bend: number = if entrance then 0 else math.noise(a.X / 37, b.Z / 47, a.Y / 23) * 18
	for step = 1, steps do
		local t: number = step / steps
		local point: Vector3 = if step == steps then b else a:Lerp(b, t) + perpendicular * math.sin(t * math.pi) * bend
		table.insert(
			cave.passages,
			{ a = previous, b = point, radius = radius, height = height, entrance = entrance == true }
		)
		previous = point
	end
end

local function _addRoom(
	cave: cave,
	point: Vector3,
	radius: number,
	height: number,
	layer: number,
	campfire: boolean,
	chests: number
): ()
	_addPassage(cave, point, point, radius, height)
	table.insert(cave.destinations, { position = point, layer = layer, campfire = campfire, chests = chests })
end

local function _hasCover(surface: _terrainSurface.terrainSurface, cave: cave): boolean
	-- Validate underground cover against the same finished hillside the voxel writer will generate.
	for _, passage in cave.passages do
		if passage.entrance then
			continue
		end
		local steps: number = math.max(1, math.ceil((passage.b - passage.a).Magnitude / 8))
		for step = 0, steps do
			local point: Vector3 = passage.a:Lerp(passage.b, step / steps)
			for ring = 0, 2 do
				for direction = 1, 12 do
					local angle: number = direction * math.pi / 6
					local radius: number = ring * (passage.radius + _config.wallNoiseStrength + 4) / 2
					local x: number, z: number = point.X + math.cos(angle) * radius, point.Z + math.sin(angle) * radius
					local height: number = surface:sample(x, z)
					height = _shapeLandform(cave.landform, x, z, height)
					if height < point.Y + passage.height + _config.wallNoiseStrength + _config.roofThickness then
						return false
					end
				end
			end
		end
	end
	return true
end

function caveGenerator.new(
	surface: _terrainSurface.terrainSurface,
	startPos: Vector3,
	seed: number,
	biomes: { _biomeTypes.Biome },
	halfWidth: number,
	biomeDepth: number
): caveGenerator
	local self: caveGenerator =
		setmetatable({ caves = {}, _seed = seed, _startPos = startPos, _cells = {}, _materials = {} }, caveGenerator)
	if not _config.enabled then
		return self
	end
	assert(
		_config.entranceRadius >= _config.tunnelRadius
			and _config.entranceHeight >= _config.tunnelHeight
			and _config.shelterRadius >= _config.entranceRadius
			and _config.shelterHeight >= _config.tunnelHeight
			and _config.entranceRiseLength > 0
			and _config.entranceTerrainBlend > 0
			and _config.entranceRidgeHeight >= 0,
		"Cave entrance and shelter must accommodate the connecting tunnels"
	)
	local chunkStuds: number = _mapConfig.chunkScale * 4
	local random: Random = Random.new(seed)
	for index, biome in biomes do
		local layers: number = _config.layersByBiome[biome.Name] or 2
		if layers <= 0 then
			continue
		end
		assert(layers <= 3 and layers % 1 == 0, "Cave layer counts must be integers from zero to three")
		local firstSide: number = if random:NextNumber() < 0.5 then -1 else 1
		for windowIndex, window in _config.siteWindows do
			local side: number = if windowIndex % 2 == 1 then firstSide else -firstSide
			for _ = 1, _config.siteAttempts do
				local baseZ: number = startPos.Z
					+ ((index - 1) * biomeDepth + random:NextNumber(window.min, window.max)) * chunkStuds
				local entryX: number = startPos.X + side * halfWidth * chunkStuds * _config.entranceWidthFraction
				local outerX: number = startPos.X + side * halfWidth * chunkStuds * _config.outerWidthFraction
				local entryZ: number = baseZ
				local ground: number = surface:sample(entryX, entryZ)
				local entry: Vector3 = Vector3.new(entryX, ground - 1, entryZ)
				local shelter: Vector3 = Vector3.new(outerX, entry.Y, baseZ + 40)
				-- Start the descent beyond the room footprint so its carving cannot turn the shelter into a ramp.
				local innerOffset: number = _config.shelterRadius + _config.tunnelRadius + 8
				local descent: Vector3 = shelter + Vector3.new(0, 0, innerOffset)
				local form: landform = {
					seed = seed,
					entry = entry,
					shelter = shelter,
					back = if layers >= 2 then descent else shelter,
					radius = _config.shelterRadius + _config.wallNoiseStrength + 4,
					height = math.max(_config.entranceHeight, _config.shelterHeight)
						+ _config.wallNoiseStrength + _config.roofThickness + 4,
				}
				local cave: cave = {
					biomeIndex = index,
					passages = {},
					landform = form,
					destinations = {},
					material = if biome.TerrainType == Enum.Material.Snow
						then Enum.Material.Glacier
						else Enum.Material.Rock,
				}
				_addPassage(cave, entry, shelter, _config.entranceRadius, _config.entranceHeight, true)
				_addRoom(cave, shelter, _config.shelterRadius, _config.shelterHeight, 1, layers == 1, 1)
				if layers >= 2 then
					local innerZ: number = baseZ + innerOffset
					local underground: Vector3 = Vector3.new(outerX, shelter.Y - 40, innerZ + random:NextNumber(160, 180))
					local junction: Vector3 = Vector3.new(outerX - side * 38, shelter.Y - 68, innerZ + 280)
					_addPassage(cave, shelter, descent, _config.tunnelRadius, _config.tunnelHeight)
					_addPassage(cave, descent, underground, _config.tunnelRadius, _config.tunnelHeight)
					_addRoom(cave, underground, 28, 28, 2, true, 1)
					_addPassage(cave, underground, junction, _config.tunnelRadius + 1, _config.tunnelHeight)
					_addRoom(cave, junction, 22, 25, 2, false, 1)
					local alcove: Vector3 =
						Vector3.new(outerX - side * random:NextNumber(75, 90), shelter.Y - 52, innerZ + 215)
					_addPassage(cave, underground, alcove, _config.tunnelRadius, _config.tunnelHeight)
					_addRoom(cave, alcove, 19, 22, 2, false, 1)
					if random:NextNumber() < 0.75 then
						_addPassage(cave, alcove, junction, _config.tunnelRadius, _config.tunnelHeight)
					end
					if layers >= 3 then
						local bend: Vector3 = Vector3.new(outerX, shelter.Y - 92, innerZ + 370)
						local deep: Vector3 =
							Vector3.new(outerX - side * 48, shelter.Y - 118, innerZ + random:NextNumber(465, 490))
						_addPassage(cave, junction, bend, _config.tunnelRadius, _config.tunnelHeight + 2)
						_addPassage(cave, bend, deep, _config.tunnelRadius + 1, _config.tunnelHeight + 2)
						_addRoom(cave, deep, 32, 36, 3, false, 2)
					end
				end
				if not _hasCover(surface, cave) then
					continue
				end
				table.insert(cave.passages, {
					a = entry,
					b = form.back,
					radius = form.radius + _config.entranceTerrainBlend + _config.hillWarpStrength,
					height = form.height,
					entrance = true,
					landform = form,
				})
				table.insert(self.caves, cave)
				for _, passage in cave.passages do
					self._materials[passage] = cave.material
					local padding: number = passage.radius + _config.roofThickness * 2 + 4
					local minX: number =
						math.floor((math.min(passage.a.X, passage.b.X) - padding - startPos.X) / chunkStuds)
					local maxX: number =
						math.floor((math.max(passage.a.X, passage.b.X) + padding - startPos.X) / chunkStuds)
					local minZ: number =
						math.floor((math.min(passage.a.Z, passage.b.Z) - padding - startPos.Z) / chunkStuds)
					local maxZ: number =
						math.floor((math.max(passage.a.Z, passage.b.Z) + padding - startPos.Z) / chunkStuds)
					for x = minX, maxX do
						for z = minZ, maxZ do
							local key: string = _cellKey(x, z)
							local cell: { passage } = self._cells[key] or {}
							self._cells[key] = cell
							table.insert(cell, passage)
						end
					end
				end
				break
			end
		end
	end
	return self
end

return caveGenerator
