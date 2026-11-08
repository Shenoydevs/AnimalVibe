--!strict
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local KeybindConfig = require(ReplicatedStorage.Shared.config.KeybindConfig)

type ActionSignal = Signal.Signal<Enum.UserInputState>

local _signals: { [string]: ActionSignal } = {}
local _bound: { [string]: boolean } = {}

local KeybindUtils = {}

local function _onAction(actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject): Enum.ContextActionResult
	local signal: ActionSignal? = _signals[actionName]
	if signal then
		signal:Fire(inputState)
	end
	return Enum.ContextActionResult.Pass
end

-- Binds the action via ContextActionService on first use, so consuming
-- controllers don't depend on Loader OnStart ordering to receive input.
function KeybindUtils.getSignal(actionName: string): ActionSignal
	local signal: ActionSignal? = _signals[actionName]
	if not signal then
		signal = Signal.new()
		_signals[actionName] = signal
	end

	if not _bound[actionName] then
		local bindings: { KeybindConfig.InputBinding }? = KeybindConfig[actionName]
		if not bindings then
			warn(`[KeybindUtils] No key codes configured for action "{actionName}"`)
		else
			_bound[actionName] = true
			ContextActionService:BindAction(actionName, _onAction, false, table.unpack(bindings))
		end
	end

	return signal :: ActionSignal
end

return KeybindUtils
