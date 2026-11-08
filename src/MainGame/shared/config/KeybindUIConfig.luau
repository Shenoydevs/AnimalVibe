--!strict

export type RowId = "sprint" | "openSack" | "context" | "use" | "store" | "dropTool"

export type RowConfig = {
	id: RowId,
	action: string,
	label: string?,
	gold: boolean?,
	keyboardIcon: string?,
}

local keybindUIConfig: { RowConfig } = {
	{ id = "sprint", action = "sprint", label = "SPRINT", keyboardIcon = "rbxassetid://132244115491418" },
	{ id = "openSack", action = "toggleInventory", label = "OPEN SACK" },
	{ id = "context", action = "pickupOrDrop", gold = true },
	{ id = "use", action = "attack", keyboardIcon = "rbxassetid://16081386298" },
	{ id = "store", action = "storeItem"},
	{ id = "dropTool", action = "dropItem", label = "DROP" },
	{ id = "cutRope", action = "releaseRope", label = "CUT" },
	{ id = "unStuck", action = "unstuckCart", label = "UNSTUCK" },
}

return keybindUIConfig
