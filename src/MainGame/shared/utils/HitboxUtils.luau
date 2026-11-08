--!strict

local HitboxUtils = {}

local paramsHitbox = OverlapParams.new()
paramsHitbox.CollisionGroup = "Hitbox"

function HitboxUtils:EnemyHitboxCheck(
	blacklist: { [Model]: boolean },
	hitboxPart: BasePart,
	framesActive: number,
	callback: (caughtEnemies: { Model }) -> ()
): ()
	task.spawn(function()
		repeat
			local partsInside = workspace:GetPartsInPart(hitboxPart, paramsHitbox)
			local caughtEnemies: { Model } = {}

			for _, part in partsInside do
				local parent = part.Parent
				if not parent or not parent:IsA("Model") or blacklist[parent] then continue end
				if parent:HasTag("Enemy") then
					table.insert(caughtEnemies, parent)
					blacklist[parent] = true
				end
			end

			if #caughtEnemies > 0 then
				callback(caughtEnemies)
			end

			framesActive -= 1
			task.wait()
		until framesActive <= 0
	end)
end

return HitboxUtils
