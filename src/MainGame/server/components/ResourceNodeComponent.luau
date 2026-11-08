--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Component = require(ReplicatedStorage.Packages.Component)

local ResourceNodeConfig = require(ReplicatedStorage.Shared.config.ResourceNodeConfig)
local GroundItemUtils = require(ServerScriptService.Server.utils.GroundItemUtils)
type DropEntry = ResourceNodeConfig.DropEntry

local _rand = Random.new()

local _noFruitBiomes: { [string]: boolean } = {
	["Arctic Expanse"] = true,
	Snowfields = true,
}

local ResourceNodeComponent = Component.new({ Tag = "ResourceNode" })

function ResourceNodeComponent:Construct()
	local primaryPart: BasePart? = self.Instance.PrimaryPart
	assert(primaryPart, `[ResourceNodeComponent] {self.Instance.Name} is missing PrimaryPart`)
	self._part = primaryPart :: BasePart

	local parent: Instance? = self.Instance.Parent
	self._canDropFruit = not (parent ~= nil and _noFruitBiomes[parent.Name])

	local variant: string? = self.Instance:GetAttribute("treeVariant") :: string?
	self._maxHealth = (variant and ResourceNodeConfig.healthByVariant[variant]) or ResourceNodeConfig.defaultMaxHealth
	self._health = self._maxHealth
	self._midDropped = false
	self._broken = false
end

function ResourceNodeComponent:_spawnDrop(drop: DropEntry): ()
	local basePos: Vector3 = self._part.Position
	local count: number = _rand:NextInteger(drop.minCount, drop.maxCount)

	for _ = 1, count do
		local offset = Vector3.new(_rand:NextNumber(-3, 3), 0, _rand:NextNumber(-3, 3))
		if not GroundItemUtils.spawnAt(drop.itemID, CFrame.new(basePos + offset)) then
			return
		end
	end
end

-- Applies damage from a single swing hit. Returns (crossedMidThreshold, broke) so the
-- caller can decide whether to broadcast a break signal alongside the hit signal.
function ResourceNodeComponent:hit(_player: Player, damage: number): (boolean, boolean)
	if self._broken then
		return false, false
	end

	self._health = math.max(self._health - damage, 0)

	local crossedMid = false
	if
		not self._midDropped
		and self._canDropFruit
		and self._health <= self._maxHealth * ResourceNodeConfig.shakeThreshold
	then
		self._midDropped = true
		crossedMid = true
		local pool: { DropEntry } = ResourceNodeConfig.midDropPool
		self:_spawnDrop(pool[_rand:NextInteger(1, #pool)])
	end

	local broke = false
	if self._health <= 0 then
		broke = true
		self._broken = true
		self:_spawnDrop(ResourceNodeConfig.breakDrop)
		task.defer(function()
			self.Instance:Destroy()
		end)
	end

	return crossedMid, broke
end

function ResourceNodeComponent:isBroken(): boolean
	return self._broken
end

function ResourceNodeComponent:getPosition(): Vector3
	return self._part.Position
end

return ResourceNodeComponent
