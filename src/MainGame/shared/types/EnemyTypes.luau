--!strict

-- Server-side EnemyComponent surface consumed by EnemyAIService.
export type EnemyComponentInterface = {
	getState: (self: EnemyComponentInterface) -> string,
	setState: (self: EnemyComponentInterface, s: string) -> (),
	getTarget: (self: EnemyComponentInterface) -> Player?,
	setTarget: (self: EnemyComponentInterface, p: Player?) -> (),
	getHome: (self: EnemyComponentInterface) -> Vector3,
	getEntityType: (self: EnemyComponentInterface) -> string,
	getWarnedPlayers: (self: EnemyComponentInterface) -> { [Player]: boolean },
	setWarned: (self: EnemyComponentInterface, player: Player, v: boolean) -> (),
	getLastAttackTime: (self: EnemyComponentInterface) -> number,
	setLastAttackTime: (self: EnemyComponentInterface, t: number) -> (),
	getPatrolTarget: (self: EnemyComponentInterface) -> Vector3?,
	setPatrolTarget: (self: EnemyComponentInterface, target: Vector3?) -> (),
	getPatrolWaitUntil: (self: EnemyComponentInterface) -> number,
	setPatrolWaitUntil: (self: EnemyComponentInterface, t: number) -> (),
	Instance: Model,
}

return {}
