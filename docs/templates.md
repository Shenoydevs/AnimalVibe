# Templates

Skeletons distilled from real files. Each one names its source. Replace `Foo` and delete what you don't need.
Pick the variant that matches the place or folder you're working in (see CLAUDE.md, Open questions 1–4).

---

## Server service (MainGame)
Source: `src/MainGame/server/services/InventoryService.luau`, `NotificationService.luau`, `HeldItemService.luau`.

```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Trove = require(Packages.Trove)

local FooConfig = require(ReplicatedStorage.Shared.config.FooConfig)
local FooTypes = require(ReplicatedStorage.Shared.types.FooTypes)
local Network = require(ReplicatedStorage.Shared.network.FooNetwork)
local NotificationConfig = require(ReplicatedStorage.Shared.config.NotificationConfig)
local NotificationService = require(ServerScriptService.Server.services.NotificationService)
local signals = require(ServerScriptService.Server.signals)

local FooSignals = signals.FooSignals

type NetworkerServer = Networker.Server
type FooState = FooTypes.FooState

type RateWindow = {
	windowStart: number,
	count: number,
}

local _trove = Trove.new()
local _networker: NetworkerServer? = nil
local _states: { [Player]: FooState } = {}
local _rateWindows: { [Player]: RateWindow } = {}

local FooService = {}
local Private = {}

local function _checkRateLimit(player: Player): boolean
	local now: number = os.clock()
	local window: RateWindow? = _rateWindows[player]
	if not window or now - window.windowStart >= 1 then
		_rateWindows[player] = { windowStart = now, count = 1 }
		return true
	end
	window.count += 1
	return window.count <= FooConfig.maxRequestsPerSecond
end

function FooService:_replicate(player: Player): ()
	local state: FooState? = _states[player]
	local networker: NetworkerServer? = _networker
	if not state or not networker then return end
	networker:fire(player, "fooUpdated", state)
end

-- Public server API: other services/components call this directly.
function FooService:grant(player: Player, amount: number): boolean
	local state: FooState? = _states[player]
	if not state then return false end
	state.value += amount
	self:_replicate(player)
	FooSignals.FooGranted:Fire(player, amount)
	return true
end

-- Remote handlers: (self, player, ...untrusted args)
function Private.requestSnapshot(_: any, player: Player): ()
	FooService:_replicate(player)
end

function Private.requestUse(_: any, player: Player, index: any): ()
	if not _checkRateLimit(player) then return end
	if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > FooConfig.maxIndex then
		FooService:_replicate(player) -- resync the client on bad input
		return
	end
	local state: FooState? = _states[player]
	if not state then return end
	-- ...authoritative logic...
	NotificationService:notify(player, "Success", "Used it.", 3, NotificationConfig.priority.low)
	FooService:_replicate(player)
end

function FooService:OnStart(): ()
	_networker = Networker.server.new(Network.Foo, Private, { Private.requestSnapshot, Private.requestUse })

	local function watchPlayer(player: Player): ()
		_states[player] = { value = 0 }
	end

	_trove:Connect(Players.PlayerAdded, watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	_trove:Connect(Players.PlayerRemoving, function(player: Player)
		_states[player] = nil
		_rateWindows[player] = nil
	end)
end

export type FooService = typeof(FooService)
return FooService
```

## Server service (Lobby, request/response)
Source: `src/LobbyGame/server/services/GachaService.luau`, `CodeService.luau`, `FirstAnimalService.luau`.

```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local Networker = require(ReplicatedStorage.Packages.Networker)
local FooConfig = require(ReplicatedStorage.Shared.config.FooConfig)
local FooTypes = require(ReplicatedStorage.Shared.types.FooTypes)
local Network = require(ReplicatedStorage.Shared.network)

type ActionResult = FooTypes.ActionResult

local _cooldown = 0.25
local _lastRequest: { [Player]: number } = {}

local Private = {}
local Shared = {}

function Private._checkRequest(player: Player, itemId: any): string?
	if player.Parent ~= Players or not DataService:hasProfile(player) then
		return "notReady"
	end
	local now = workspace:GetServerTimeNow()
	local lastRequest = _lastRequest[player]
	if lastRequest and now - lastRequest < _cooldown then
		return "rateLimited"
	end
	_lastRequest[player] = now
	if type(itemId) ~= "string" or not FooConfig[itemId] then
		return "invalid"
	end
	return nil
end

function Private._buy(_, player: Player, itemId: any): ActionResult
	local rejection = Private._checkRequest(player, itemId)
	if rejection then
		return { status = rejection } :: ActionResult
	end
	local coins: number = DataService:get(player, { "PlayerStats", "Nova" })
	local price = FooConfig[itemId].coinPrice
	if coins < price then
		return { status = "insufficientCoins" }
	end

	-- Both writes use the same session-locked profile and do not yield.
	DataService:set(player, { "Foo", itemId }, true)
	DataService:set(player, { "PlayerStats", "Nova" }, coins - price)
	return { status = "purchased" }
end

function Shared.OnStart(): ()
	Networker.server.new(Network.Foo, Private, { Private._buy })
	Players.PlayerRemoving:Connect(function(player: Player): ()
		_lastRequest[player] = nil
	end)
end

return Shared
```
Add `Foo = "Foo"` to `src/LobbyGame/shared/network.luau`.

---

## Client controller (MainGame)
Source: `src/MainGame/client/controllers/InventoryController.luau`, `HeldItemController.luau`.

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Fusion = require(Packages.Fusion)
local Trove = require(Packages.Trove)

local FooConfig = require(ReplicatedStorage.Shared.config.FooConfig)
local Network = require(ReplicatedStorage.Shared.network.FooNetwork)
local states = require(script.Parent.Parent.states)
local utils = require(script.Parent.Parent.utils)

local FooState = states.FooState
local KeybindUtils = utils.KeybindUtils
local peek = Fusion.peek

type NetworkerClient = Networker.Client

local TOGGLE_ACTION = "toggleFoo" -- must exist in shared/config/KeybindConfig.luau

local _trove = Trove.new()
local _networker: NetworkerClient
local _scope = Fusion.scoped(Fusion)

local FooController = {}
local Private = {}

-- Server -> client. Re-validate the shape even though it came from the server.
function Private.fooUpdated(_: any, payload: any): ()
	if type(payload) ~= "table" or type(payload.value) ~= "number" then return end
	FooState.Value:set(payload.value)
end

function FooController:requestUse(index: number): ()
	if index < 1 or index > FooConfig.maxIndex then return end -- UX pre-check only
	_networker:fire("requestUse", index)
end

function FooController:OnStart(): ()
	_networker = Networker.client.new(Network.Foo, Private)

	_trove:Connect(KeybindUtils.getSignal(TOGGLE_ACTION), function(inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.Begin then return end
		FooState.IsOpen:set(not peek(FooState.IsOpen))
	end)

	_scope:Observer(FooState.Value):onChange(function()
		-- react to state
	end)

	_networker:fire("requestSnapshot")
end

export type FooController = typeof(FooController)
return FooController
```

State module (`client/states/FooState.luau`, then add it to `states/init.luau`). Source: `InventoryState.luau`:
```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local scope = Fusion.scoped(Fusion)

return {
	Value = scope:Value(0),
	IsOpen = scope:Value(false),
	Selected = scope:Value(nil :: number?),
}
```

## Client controller (Lobby, DataService-driven popup)
Source: `src/LobbyGame/client/controllers/BadgeController/init.luau`, `PlayerDataController.luau`.

```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ReplicatedStorage.Packages.DataService).client
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local FooState = require(script.Parent.Parent.states.FooState)
local PopupUtils = require(script.Parent.Parent.utils.PopupUtils)
local FooList = require(script.FooList) -- sub-module exposing Shared.bind(scope, ...)

local _scope = Fusion.scoped(Fusion)

local Private = {}
local Shared = {}

function Private._readData(foo)
	-- DataService mutates nested tables in place; Fusion receives its own snapshot.
	FooState.owned:set(table.clone(foo.owned))
end

function Private._bindGui()
	local playerGui: PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui: ScreenGui = playerGui:WaitForChild("FooGui")
	local wrapper: Frame = gui:WaitForChild("Wrapper")

	PopupUtils.BindHeader(wrapper)
	FooList.bind(_scope, wrapper)

	local closeButton: ImageButton = wrapper:WaitForChild("Elements"):WaitForChild("CloseBTN")
	closeButton.Activated:Connect(function()
		PopupUtils.HidePopup(gui)
	end)

	local menuGui: ScreenGui = playerGui:WaitForChild("FooMenuGui")
	menuGui:WaitForChild("OpenFoo").Activated:Connect(function()
		PopupUtils.ShowPopup(gui)
	end)
	menuGui.Enabled = true
	if PopupUtils.GetCurrentPopup() then
		PopupUtils.HideAllGuis()
	end
end

function Shared.OnStart()
	DataService:waitForData()
	DataService:getChangedSignal({ "Foo" }):Connect(Private._readData)
	Private._readData((DataService:get({ "Foo" })))
	Private._bindGui()
end

return Shared
```

---

## UI component (tag-bound)
Source: `src/LobbyGame/client/components/CurrencyDisplayComponent.luau`, `src/MainGame/client/components/EnemyHealthBarComponent.luau`.

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require(ReplicatedStorage.Packages.Component)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Trove = require(ReplicatedStorage.Packages.Trove)
local FooState = require(script.Parent.Parent.states.FooState)

local FooDisplayComponent = Component.new({ Tag = "FooDisplay" })

function FooDisplayComponent:Construct(): ()
	self._scope = Fusion.scoped(Fusion)
	self._trove = Trove.new()
	local label = self.Instance:FindFirstChild("Label")
	assert(label and label:IsA("TextLabel"), `[FooDisplayComponent] {self.Instance:GetFullName()} is missing Label`)
	self._label = label
end

function FooDisplayComponent:Start(): ()
	self._scope:Hydrate(self._label)({
		Text = self._scope:Computed(function(use)
			return tostring(use(FooState.Value))
		end),
	})
end

function FooDisplayComponent:Stop(): ()
	self._trove:Clean()
	Fusion.doCleanup(self._scope)
end

return FooDisplayComponent
```
To restrict a component to the local player's own UI, pass `Ancestors = { Players.LocalPlayer }` (as `HealthBarComponent` and `DialogComponent` do).

## Server component (prompt-driven world object)
Source: `src/MainGame/server/components/ChestComponent.luau`, `ForageComponent.luau`.

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local FooConfig = require(ReplicatedStorage.Shared.config.FooConfig)

local InventoryService = require(ServerScriptService.Server.services.InventoryService)
local FollowPromptUtils = require(ServerScriptService.Server.utils.FollowPromptUtils)

local FooComponent = Component.new({ Tag = "Foo" })

function FooComponent:Construct()
	self._trove = Trove.new()
	local rootPart: BasePart? = self.Instance.PrimaryPart
	assert(rootPart, `[FooComponent] {self.Instance.Name} is missing PrimaryPart`)
	self._rootPart = rootPart :: BasePart
	self._used = false
end

function FooComponent:Start()
	local prompt: ProximityPrompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Use"
	prompt.HoldDuration = 0.5
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = self._rootPart
	self._trove:Add(prompt)
	self._trove:Connect(prompt.Triggered, function(player: Player)
		self:_handleUse(player)
	end)
end

function FooComponent:Stop()
	self._trove:Clean()
	local destroyThread: thread? = self._destroyThread
	if destroyThread and coroutine.status(destroyThread) == "suspended" then
		task.cancel(destroyThread)
	end
end

function FooComponent:_handleUse(player: Player): ()
	if self._used then return end
	-- Check ownership and other requirements first, and only grant once they pass.
	if not InventoryService:addItem(player, FooConfig.rewardItemId) then return end
	self._used = true
	self._destroyThread = task.delay(FooConfig.destroyDelay, function()
		self.Instance:Destroy()
	end)
end

return FooComponent
```

---

## New remote / network call
Source: `src/MainGame/shared/network/InventoryNetwork.luau`, `CartPullService.luau`, `CartPullController.luau`.

```lua
-- src/MainGame/shared/network/FooNetwork.luau
--!strict
return {
	Foo = "Foo",
}
```
```lua
-- server (in FooService:OnStart)
_networker = Networker.server.new(Network.Foo, Private, { Private.requestBar, Private.getBar })

function Private.requestBar(_: any, player: Player, value: unknown): ()   -- client: _networker:fire("requestBar", v)
	if typeof(value) ~= "boolean" then return end
	-- ...
end

function Private.getBar(_: any, player: Player): number                  -- client: _networker:fetch("getBar")
	return _barValue
end

_networker:fire(player, "onBarChanged", value)          -- one player
_networker:fireAll("onBarChanged", value)               -- everyone
_networker:fireAllExcept(player, "onBarChanged", value) -- everyone else (combat VFX)
_networker:setAll("bar", value)                         -- replicated state field
```
```lua
-- client
local FooController = { bar = nil :: number? } -- field filled by server :set/:setAll
function FooController:onBarChanged(value: number): () end
_networker = Networker.client.new(Network.Foo, FooController)
_trove:Connect(_networker:getServerChangedSignal("bar"), function() ... end)
```

---

## Class with cleanup
Source: `src/MainGame/server/utils/BoulderPullSession.luau`, `CartPullSession.luau`, `src/MainGame/shared/utils/KeepoutRegistry.luau`.

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)

local FooSession = {}
FooSession.__index = FooSession

export type FooSession = typeof(setmetatable({} :: {
	model: Model,
	_trove: typeof(Trove.new()),
	_members: { [Player]: boolean },
	_destroyed: boolean,
}, FooSession))

function FooSession.new(model: Model): FooSession
	local self: FooSession = setmetatable({
		model = model,
		_trove = Trove.new(),
		_members = {},
		_destroyed = false,
	}, FooSession)
	self._trove:Connect(model.AncestryChanged, function()
		if not model:IsDescendantOf(workspace) then
			self:destroy()
		end
	end)
	return self
end

function FooSession.add(self: FooSession, player: Player): boolean
	if self._destroyed or self._members[player] then return false end
	self._members[player] = true
	return true
end

function FooSession.tick(self: FooSession, dt: number): ()
	if self._destroyed then return end
	-- per-frame work, no allocations
end

function FooSession.destroy(self: FooSession): ()
	if self._destroyed then return end
	self._destroyed = true
	self._trove:Destroy()
	table.clear(self._members)
end

return FooSession
```
The owning service keeps `_sessions: { [Model]: FooSession }`, calls `session:tick(dt)` from one `Heartbeat` connection,
and calls `destroy()` when the tagged instance is removed (`BoulderPullService`).
