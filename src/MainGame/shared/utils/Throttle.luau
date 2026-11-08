--!strict

export type Stepper = (dt: number) -> (boolean, number)

local Throttle = {}

function Throttle.new(interval: number): Stepper
	assert(interval > 0, "[Throttle] interval must be > 0")

	local accumulator: number = 0
	return function(dt: number): (boolean, number)
		accumulator += dt
		if accumulator < interval then
			return false, 0
		end
		local elapsed: number = accumulator
		-- Reset to zero rather than subtracting `interval`: a frame-rate dip should drop the
		-- backlog, not fire a burst of catch-up calls the next time the loop runs.
		accumulator = 0
		return true, elapsed
	end
end

return Throttle
