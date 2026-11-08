--!strict

export type Keepout = {
	x: number,
	z: number,
	r: number,
}

local KeepoutRegistry = {}
KeepoutRegistry.__index = KeepoutRegistry

local _cellSize: number = 64
type cells = { [number]: { [number]: { Keepout } } }

export type KeepoutRegistry = typeof(setmetatable({} :: { _cells: cells }, KeepoutRegistry))

function KeepoutRegistry.new(): KeepoutRegistry
	return setmetatable({ _cells = {} }, KeepoutRegistry)
end

function KeepoutRegistry.add(self: KeepoutRegistry, x: number, z: number, r: number): ()
	local keepout: Keepout = { x = x, z = z, r = r }
	-- Index every cell touched by the footprint, including large buildings and cave reservations.
	for cx = math.floor((x - r) / _cellSize), math.floor((x + r) / _cellSize) do
		local row = self._cells[cx]
		if not row then
			row = {}
			self._cells[cx] = row
		end
		for cz = math.floor((z - r) / _cellSize), math.floor((z + r) / _cellSize) do
			local cell = row[cz]
			if not cell then
				cell = {}
				row[cz] = cell
			end
			table.insert(cell, keepout)
		end
	end
end

-- Footprint-aware: clear only if a circle of radius r at (x, z) intersects no registered keepout
function KeepoutRegistry.isClear(self: KeepoutRegistry, x: number, z: number, r: number): boolean
	for cx = math.floor((x - r) / _cellSize), math.floor((x + r) / _cellSize) do
		local row = self._cells[cx]
		if not row then
			continue
		end
		for cz = math.floor((z - r) / _cellSize), math.floor((z + r) / _cellSize) do
			local cell = row[cz]
			if not cell then
				continue
			end
			for _, keepout in cell do
				local dx: number = x - keepout.x
				local dz: number = z - keepout.z
				local minDist: number = r + keepout.r
				if dx * dx + dz * dz < minDist * minDist then
					return false
				end
			end
		end
	end
	return true
end

return KeepoutRegistry
