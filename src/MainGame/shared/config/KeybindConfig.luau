--!strict

export type InputBinding = Enum.KeyCode | Enum.UserInputType
type KeybindConfig = { [string]: { InputBinding } }

local keybindConfig: KeybindConfig = {
	toggleInventory = { Enum.KeyCode.B, Enum.KeyCode.ButtonL1 },
	sprint = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL2 },
	attack = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 },
	pickupOrDrop = { Enum.KeyCode.E, Enum.KeyCode.ButtonX },
	storeItem = { Enum.KeyCode.F, Enum.KeyCode.ButtonY },
	dropItem = { Enum.KeyCode.R, Enum.KeyCode.ButtonR1 },
	ropeAnimal = { Enum.KeyCode.V },
	debugitem = { Enum.KeyCode.C },
	slotHotkey1 = { Enum.KeyCode.One },
	slotHotkey2 = { Enum.KeyCode.Two },
	slotHotkey3 = { Enum.KeyCode.Three },
	slotHotkey4 = { Enum.KeyCode.Four },
	slotHotkey5 = { Enum.KeyCode.Five },
	hotbarPrev = { Enum.KeyCode.DPadLeft },
	hotbarNext = { Enum.KeyCode.DPadRight },
	call = { Enum.KeyCode.G, Enum.KeyCode.DPadUp },
	releaseRope = { Enum.KeyCode.X, Enum.KeyCode.ButtonB },
	unstuckCart = { Enum.KeyCode.Z },
	-- Spectate keys deliberately reuse gameplay keys (E, ButtonL2, ButtonR2): SpectatorController only
	-- acts on them while the player is dead, and KeybindUtils passes input through to every action.
	spectatePrevious = { Enum.KeyCode.Q, Enum.KeyCode.ButtonL2 },
	spectateNext = { Enum.KeyCode.E, Enum.KeyCode.ButtonR2 },
}

return keybindConfig
