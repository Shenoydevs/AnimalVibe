--!strict

-- Server-side ResourceNodeComponent surface consumed by ResourceCombatService.
export type ResourceNodeComponentInterface = {
	hit: (self: ResourceNodeComponentInterface, player: Player, damage: number) -> (boolean, boolean),
	isBroken: (self: ResourceNodeComponentInterface) -> boolean,
	getPosition: (self: ResourceNodeComponentInterface) -> Vector3,
	Instance: Model,
}

return {}
