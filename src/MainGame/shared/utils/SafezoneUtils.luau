--!strict

local safezoneUtils = {}

function safezoneUtils.isInside(position: Vector3, center: Vector3, radius: number, halfHeight: number?): boolean
	if halfHeight and math.abs(position.Y - center.Y) > halfHeight then
		return false
	end
	local dx: number = position.X - center.X
	local dz: number = position.Z - center.Z
	return dx * dx + dz * dz < radius * radius
end

function safezoneUtils.clampOutside(
	position: Vector3,
	center: Vector3,
	radius: number,
	margin: number,
	halfHeight: number?
): Vector3
	if halfHeight and math.abs(position.Y - center.Y) > halfHeight then
		return position
	end
	local offset: Vector3 = (position - center) * Vector3.new(1, 0, 1)
	if offset.Magnitude >= radius then
		return position
	end
	local direction: Vector3 = if offset.Magnitude > 0.001 then offset.Unit else Vector3.xAxis
	local pushRadius: number = radius + margin
	return Vector3.new(center.X + direction.X * pushRadius, position.Y, center.Z + direction.Z * pushRadius)
end

export type safezoneUtils = typeof(safezoneUtils)
return safezoneUtils
