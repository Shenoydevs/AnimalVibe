--!strict
local _replicatedStorage = game:GetService("ReplicatedStorage")

local _config = require(_replicatedStorage.Shared.config.MapGenerationConfig)
local _caveConfig = require(_replicatedStorage.Shared.config.CaveGenerationConfig)
local _terrainSurface = require(script.Parent.TerrainSurface)
local _caveGenerator = require(script.Parent.CaveGenerator)

local terrainWriter = {}

type sample = {
	height: number,
	minY: number,
	material: Enum.Material,
	rockMaterial: Enum.Material,
	cavities: { _caveGenerator.column },
}

local function _writeDetailRows(
	row: { sample },
	minY: number,
	firstY: number,
	lastY: number,
	materialRows: { { Enum.Material } },
	occupancyRows: { { number } }
): ()
	for vy = firstY, lastY do
		local y: number = (vy + 0.5) * 4
		local materialRow: { Enum.Material } = table.create(#row)
		local occupancyRow: { number } = table.create(#row)
		for iz, sample in row do
			local occupancy: number = math.clamp((sample.height - vy * 4) / 4, 0, 1)
			if occupancy > 0 and #sample.cavities > 0 then
				occupancy = math.min(occupancy, _caveGenerator.solidOccupancy(sample.cavities, y))
			end
			local material: Enum.Material = if y < sample.height - 8 then sample.rockMaterial else sample.material
			materialRow[iz] = if occupancy > 0 then material else Enum.Material.Air
			occupancyRow[iz] = occupancy
		end
		materialRows[vy - minY + 1] = materialRow
		occupancyRows[vy - minY + 1] = occupancyRow
	end
end

function terrainWriter.writeChunks(
	surface: _terrainSurface.terrainSurface,
	caves: _caveGenerator.caveGenerator,
	startPos: Vector3,
	chunkX: number,
	chunkZ: number,
	lastChunkX: number
): Region3
	local chunkStuds: number = _config.chunkScale * 4
	-- Partition the global grid; expanding each ten-stud chunk independently would overwrite its neighbours.
	local minX: number = math.ceil((startPos.X + chunkX * chunkStuds) / 4)
	local maxX: number = math.ceil((startPos.X + (lastChunkX + 1) * chunkStuds) / 4) - 1
	local minZ: number = math.ceil((startPos.Z + chunkZ * chunkStuds) / 4)
	local maxZ: number = math.ceil((startPos.Z + (chunkZ + 1) * chunkStuds) / 4) - 1
	local minY: number = math.floor((startPos.Y - _config.groundSlabDepth) / 4)
	local top: number = startPos.Y
	local samples: { { sample } } = table.create(maxX - minX + 1)
	for cx = chunkX, lastChunkX do
		local passages: { _caveGenerator.passage } = caves:passagesAt(cx, chunkZ)
		local bottom: number = startPos.Y - _config.groundSlabDepth
		for _, passage in passages do
			bottom = math.min(bottom, passage.a.Y - _caveConfig.floorThickness, passage.b.Y - _caveConfig.floorThickness)
		end
		local chunkMinY: number = math.floor(bottom / 4)
		minY = math.min(minY, chunkMinY)
		local firstVoxelX: number = math.ceil((startPos.X + cx * chunkStuds) / 4)
		local lastVoxelX: number = math.ceil((startPos.X + (cx + 1) * chunkStuds) / 4) - 1
		for vx = firstVoxelX, lastVoxelX do
			local row: { sample } = table.create(maxZ - minZ + 1)
			for vz = minZ, maxZ do
				local x: number, z: number = (vx + 0.5) * 4, (vz + 0.5) * 4
				local height: number, material: Enum.Material = surface:sample(x, z)
				local cavities: { _caveGenerator.column }, caveMaterial: Enum.Material?, surfaceMaterial: Enum.Material?
				height, cavities, caveMaterial, surfaceMaterial = caves:column(passages, x, z, height)
				top = math.max(top, height)
				table.insert(row, {
					height = height,
					minY = chunkMinY,
					material = surfaceMaterial or material,
					rockMaterial = caveMaterial or Enum.Material.Rock,
					cavities = cavities,
				})
			end
			table.insert(samples, row)
		end
	end
	local maxY: number = math.ceil(top / 4)
	local height: number = maxY - minY + 1
	local depth: number = maxZ - minZ + 1
	local materials: { { { Enum.Material } } } = table.create(#samples)
	local occupancies: { { { number } } } = table.create(#samples)
	-- WriteVoxels only reads these rows. Share uniform layers; allocate unique rows only for surface/cave detail.
	local airRow: { Enum.Material } = table.create(depth, Enum.Material.Air)
	local emptyRow: { number } = table.create(depth, 0)
	local fullRow: { number } = table.create(depth, 1)
	for ix, row in samples do
		local rockRow: { Enum.Material } = table.create(depth)
		local rockMaxY: number = maxY
		local rowMaxY: number = minY - 1
		local caveMinY: number, caveMaxY: number = math.huge, -math.huge
		local rowMinY: number = row[1].minY
		for iz, sample in row do
			rockRow[iz] = sample.rockMaterial
			-- The voxel centre is two studs above vy * 4; rock ends eight studs below the surface.
			rockMaxY = math.min(rockMaxY, math.ceil((sample.height - 10) / 4) - 1)
			rowMaxY = math.max(rowMaxY, math.ceil(sample.height / 4) - 1)
			for _, cavity in sample.cavities do
				-- Include partially carved voxels just outside the cave floor and ceiling.
				caveMinY = math.min(caveMinY, math.floor((cavity.floor - 4) / 4))
				caveMaxY = math.max(caveMaxY, math.ceil((cavity.ceiling + 4) / 4))
			end
		end
		local materialRows: { { Enum.Material } } = table.create(height, rockRow)
		local occupancyRows: { { number } } = table.create(height, fullRow)
		for vy = minY, rowMinY - 1 do
			materialRows[vy - minY + 1], occupancyRows[vy - minY + 1] = airRow, emptyRow
		end
		for vy = math.max(rowMinY, rowMaxY + 1), maxY do
			materialRows[vy - minY + 1], occupancyRows[vy - minY + 1] = airRow, emptyRow
		end
		_writeDetailRows(row, minY, math.max(rowMinY, rockMaxY + 1), rowMaxY, materialRows, occupancyRows)
		_writeDetailRows(row, minY, math.max(rowMinY, caveMinY), math.min(rockMaxY, caveMaxY), materialRows, occupancyRows)
		materials[ix] = materialRows
		occupancies[ix] = occupancyRows
	end
	local region: Region3 =
		Region3.new(Vector3.new(minX, minY, minZ) * 4, Vector3.new(maxX + 1, maxY + 1, maxZ + 1) * 4)
	workspace.Terrain:WriteVoxels(region, 4, materials, occupancies)
	return region
end

export type terrainWriter = typeof(terrainWriter)
return terrainWriter
