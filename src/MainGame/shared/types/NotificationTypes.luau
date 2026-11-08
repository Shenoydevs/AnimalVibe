--!strict

export type NotificationKind = "Info" | "Alert" | "Success"

export type NotificationPayload = {
	kind: NotificationKind,
	message: string,
	duration: number,
	priority: number,
}

export type TransitionPayload = {
	message: string,
	duration: number,
}

return {}
