--!strict

export type cartComponentInterface = {
	getModel: (self: cartComponentInterface) -> Model,
	getRopeParts: (self: cartComponentInterface) -> { BasePart },
	getPosition: (self: cartComponentInterface) -> Vector3,
	getSockets: (self: cartComponentInterface) -> { Attachment },
	setLightLevel: (self: cartComponentInterface, fuel: number, maxFuel: number) -> (),
	setAttachPromptsEnabled: (self: cartComponentInterface, enabled: boolean) -> (),
	setRopePromptsEnabled: (self: cartComponentInterface, enabled: boolean) -> (),
	setRopePromptEnabled: (self: cartComponentInterface, ropePart: BasePart, enabled: boolean) -> (),
	setupPullRig: (self: cartComponentInterface) -> (),
	setPulling: (self: cartComponentInterface, active: boolean) -> (),
	unstuck: (self: cartComponentInterface) -> (),
	setPullVelocity: (self: cartComponentInterface, velocity: Vector3) -> (),
	setPullDirection: (self: cartComponentInterface, direction: Vector3, tilt: CFrame) -> (),
	getForward: (self: cartComponentInterface) -> Vector3,
	setWheelSpinSpeed: (self: cartComponentInterface, angularVelocity: number) -> (),
}

export type pullerEntry = { player: Player, ropePart: BasePart, isLead: boolean }

export type wheelComponentInterface = {
	getPart: (self: wheelComponentInterface) -> BasePart,
	getAxle: (self: wheelComponentInterface) -> Attachment,
	setPromptEnabled: (self: wheelComponentInterface, enabled: boolean) -> (),
}

export type cartStorageInterface = {
	getPart: (self: cartStorageInterface) -> BasePart,
	getDepositDistance: (self: cartStorageInterface) -> number,
	getSlotCount: (self: cartStorageInterface) -> number,
	showItem: (self: cartStorageInterface, slotIndex: number, clone: Model, onRetrieve: (Player) -> ()) -> (),
	clearSlot: (self: cartStorageInterface, slotIndex: number) -> (),
}

return {}
