--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	DamageReceived = Signal.new(),
	StaminaZeroed = Signal.new(),
	ShowLost = Signal.new(),
	ShowLostALL = Signal.new(),
	PlayAgainButton = Signal.new(),
	ToggleEquip = Signal.new(),
	UpdateEquipHelper = Signal.new(),
	UpdateShareable = Signal.new(),

	-- Lose screen state sent by GameManagerService (rendered by LoseScreenComponent).
	ReplayCountChanged = Signal.new(), -- (ready: number, total: number)
	ReviveAllOffered = Signal.new(), -- (productId: number, returnSeconds: number)
	DownedOffered = Signal.new(), -- (productId: number, reviveSeconds: number, deathSeconds: number)
	DiedPermanently = Signal.new(),
}
