# CLAUDE.md — AnimalSurvival (Lobby + Main Game)

Read this before writing code. New code must look like the code next to it. Longer references:
`docs/architecture.md`, `docs/networking.md`, `docs/data.md`, `docs/ui.md`, `docs/templates.md` (copy-paste skeletons).
Folder-specific rules: `src/LobbyGame/CLAUDE.md`, `src/MainGame/CLAUDE.md`.

## 1. Project overview

- Roblox co-op survival game. Players pick an animal in the **Lobby** place, form a party, and get teleported to a reserved
  **Main Game** server. There they fix and pull a cart through procedurally generated biomes, survive hunger, thirst,
  sickness, weather, a virus wall and hunters, and revive each other. Lobby features: party zones, animal shop/skins,
  gacha "styles", badges, codes, weekly challenges.
- Two Rojo places share `src/Common` and `Packages`:
  | Place | Project file | Port | Server / Client / Shared |
  |---|---|---|---|
  | Main Game | `main.project.json` | 8000 | `src/MainGame/{server,client,shared}` |
  | Lobby | `lobby.project.json` | 8001 | `src/LobbyGame/{server,client,shared}` |
- Tooling (`rokit.toml`): rojo 7.7.0, wally 0.3.2, stylua 2.1.0, selene 0.28.0. No CI, no tests, no `stylua.toml`
  (StyLua defaults: tabs, 120 columns). `.vscode/settings.json` formats on save with StyLua and builds the luau-lsp sourcemap from `lobby.project.json`.
- Commands:
  ```bash
  rokit install                     # install pinned tools
  wally install                     # -> Packages/ (gitignored)
  rojo serve main.project.json      # or lobby.project.json
  selene src                        # lint (std = "roblox")
  stylua src                        # format (stylua --check src to verify)
  ```
- Studio-owned content is **not in the repo**: `ReplicatedStorage.Assets` (Animals, Resources, UI/GUI templates,
  sounds), every ScreenGui under StarterGui/PlayerGui, the Workspace map. Code reaches it by name, so keep names exact.
- Git workflow (README): never push to `main`; one branch per task (`feature/…`, `fix/…`, `asset/…`); open a PR with a description.

## 2. Golden rules

1. **Every new file starts with `--!strict`** (170/175 MainGame files, all Common files, and all Lobby services already do).
2. **The module name decides how it loads.** `*Service` (server) and `*Controller` (client) are required by `Loader` and
   their `OnStart` is spawned. `*Component` modules are required so their sleitnick `Component` class binds to a tag.
   Anything else (`*Utils`, `*Session`, `*Panel`, `*Control`, `*Card`) loads only when something requires it. Never give a helper module one of those suffixes.
3. **Never trust the client.** Every remote handler type-checks every argument (`type(x) ~= "number"`, `typeof(v) ~= "Vector3"`,
   integer and range checks), re-reads state on the server, and rejects quietly (`return`, or `{ status = "invalid" }`).
   Examples: `InventoryService` `Private.moveItem`, `GachaService` `Private._spin`, `BoulderPullService:setPullInput`.
4. **Rate-limit every client→server request.** Use a per-player timestamp or window that is cleared on `PlayerRemoving`
   (`InventoryService._checkRateLimit`, `GachaService._checkRequest`, `CodeService` 0.5 s, `CartPullService:requestPullers`, `SwingSession.begin`,
   `GameManagerService._withinRate`).
5. **Remotes go through `Networker` only.** You will not find `RemoteEvent` or `RemoteFunction` anywhere in `src`. The channel name lives in a shared network
   module. Only the functions listed in the third argument of `Networker.server.new` can be called by the client.
6. **The server owns gameplay state and data.** Client-side checks are UX only (`InventoryController:requestMove`
   pre-checks, then the server re-validates). Character stats live in **server-set attributes** (`alive`, `damage`, `hunger`, …).
7. **Clean up per-player state on `PlayerRemoving`.** Every `{ [Player]: … }` table gets cleared there (see any service).
8. **Every connection that outlives a call goes in a Trove.** Use module-level `_trove` in services/controllers, `self._trove`
   in components and classes, and a child trove (`_trove:Extend()` or a per-session `Trove.new()`) for anything that resets. Components clean up in `Stop`.
9. **Modules talk to each other** by direct `require` of another service/controller, or through the `signals` modules
   (Signal) for decoupled events. There is no `_G`, no shared registry and no DI framework.
10. **Tunables go in `shared/config/*Config.luau`. Shared types go in `shared/types/*Types.luau`.** Don't hard-code numbers
    that already have a config home (ids belong in `Common/config/PlaceConfig.luau`).
11. **Player data goes only through `DataService`** (`leifstout/dataservice`). Writes happen on the server after validation, inside a
    non-yielding sequence of `get`/`set`/`update` calls (see the "do not yield" comments in `GachaService`, `FirstAnimalService`).
12. **UI is authored in Studio.** Code finds it (`WaitForChild` / `GuiUtils.waitFor` / `WaitFor`) and drives it with Fusion
    `Value`/`Computed`/`Spring`/`Observer`/`Hydrate`. Nothing in the repo builds UI trees with Fusion `New`.
13. **Log with `warn(\`[ModuleName] message\`)`.** Never use `print` (there are 0 in `src`). Use `assert` with the same prefix for required
    instance setup in `Construct` (`ChestComponent`, `ForageComponent`).
14. **Lobby UI respects `GuiService.ReducedMotionEnabled`** (all 15 Lobby UI motion files do). New Lobby animation must too.

## 3. Project structure

```
src/Common/            -> ReplicatedStorage.Common   (both places)
  config/              DataTemplate (player save schema), PlaceConfig, AnimalConfig, BadgeConfig, LevelingConfig
  types/               BadgeTypes
  components/          components shared by both clients, re-exported from each place's client/components (MonetizationButtonComponent)
src/<Place>/shared/    -> ReplicatedStorage.Shared
  config/              *Config.luau tunables (Lobby also has config/init.luau index)
  types/               *Types.luau, NetworkServerType/NetworkClientType, init.luau re-exports
  network/             MainGame: one *Network.luau per feature. Lobby: single network.luau name table
  utils/               (MainGame) shared pure helpers: CharacterUtils, DeviceUtils, Throttle, KeepoutRegistry…
  enums/               (Lobby) PartyStateEnum
src/<Place>/server/    -> ServerScriptService.Server
  init.server.luau / startup.server.luau   bootstrap
  services/            *Service.luau singletons
  components/          *Component.luau (tag-bound, sleitnick Component)
  signals/             *Signals.luau tables of Signal.new(), indexed by signals/init.luau
  utils/               server helpers and classes (*Utils, *Session, generators)
  config/              (Lobby) server-only config, e.g. CodeConfig (secret codes)
src/<Place>/client/    -> StarterPlayer.StarterPlayerScripts.Client
  init.client.luau / startup.client.luau   bootstrap
  controllers/         *Controller.luau, or a folder `XController/init.luau` + sub-modules
  components/          *Component.luau (UI/world bindings by tag)
  states/              Fusion Value stores (one module per domain) + init.luau index
  signals/             (MainGame) client Signals
  network/             (Lobby) thin Networker wrappers per feature
  utils/               GuiUtils, KeybindUtils, VFXUtils (Main); PopupUtils, BackdropUtils (Lobby)
```

Where new code goes: gameplay logic → `server/services`. Per-tagged-instance behaviour → `server/components`.
Input, camera, HUD → `client/controllers`. Reusable UI widget bound by tag → `client/components`. Client reactive state → `client/states`.
Numbers → `shared/config`. Payload/record types → `shared/types`. Remote channel name → `shared/network`.

## 4. Architecture & lifecycle

Bootstrap (`src/MainGame/server/init.server.luau`; the client and Lobby versions are the same apart from where the search starts):
```lua
Loader.SpawnAll(Loader.LoadDescendants(script, Loader.MatchesName("Service$")), "OnStart")
Loader.LoadDescendants(script, Loader.MatchesName("Component$"))
```
- All Services/Controllers are **required first** (top-level code runs, in require order). Then each `OnStart` is **spawned
  in its own thread**. There is no ordering guarantee between `OnStart`s, and an `OnStart` may yield (`DataService:waitForData()`).
- Components load after every service has been required. `Construct` runs synchronously for each tagged instance; `Start` and `Stop` follow the Component lifecycle.
- The client waits for `game.Loaded` before loading.
- Don't depend on another module's `OnStart` having run. Lazily-initialised helpers exist for this:
  `KeybindUtils.getSignal` binds on first use ("so consuming controllers don't depend on Loader OnStart ordering"), and
  the cart modules use `_getNetworker()` with an assert.
- Lifecycle method signature: MainGame `function XService:OnStart(): ()`. Lobby `function Shared.OnStart()`.

**Add a service:** create `server/services/FooService.luau` from `docs/templates.md#server-service`. Add
`shared/network/FooNetwork.luau` if it talks to clients and `shared/config/FooConfig.luau` for its numbers. Nothing to register.
**Add a controller:** `client/controllers/FooController.luau` (or `FooController/init.luau` + sub-modules for big UI).
**Add a component:** `FooComponent.luau` with `Component.new({ Tag = "Foo" })`. Tag the instances in Studio.

## 5. Code style

**Module layout** (in this order, blank line between groups):
1. `--!strict`
2. `game:GetService` locals (usually alphabetical)
3. `local Packages = ReplicatedStorage.Packages`, then package requires (Networker, Trove, Fusion…)
4. Project requires: config, types, network, utils, then other services/controllers, then `signals`/`states`/`utils` indexes
5. Unpack index tables: `local InventorySignals = signals.InventorySignals`, `local peek = Fusion.peek`
6. `type` aliases (`type NetworkerServer = Networker.Server`, `type SlotArray = InventoryTypes.SlotArray`) and local record types
7. Constants (`local TOTAL_SLOTS = …`)
8. Module state (`local _trove = Trove.new()`, `local _networker: NetworkerServer? = nil`, `local _byPlayer: { [Player]: T } = {}`)
9. `local FooService = {}` and `local Private = {}`
10. Private `local function _helper()`, then public methods, then `Private.*` remote handlers, then `OnStart`
11. `export type FooService = typeof(FooService)` then `return FooService`

**Naming (prevailing):**
- Files and modules are PascalCase with a role suffix: `InventoryService`, `HudCompassController`, `ChestComponent`, `ItemConfig`,
  `CartTypes`, `GroundItemUtils`, `CartPullSession`. Controller sub-modules: `*Control` (CharacterController), `*Panel`/`*Card`/`*Details` (Lobby UI).
- Service and package locals are PascalCase (`ReplicatedStorage`, `Trove`). File-private state and functions use `_camelCase`. Public
  methods are camelCase (`addItem`, `countItem`, `notify`); older/gameplay modules use PascalCase (`GetEquippedItem`, `EndGameLost`).
- Private methods on a module or component are `self:_name()` (`InventoryService:_replicate`, `ChestComponent:_handleOpen`).
- Constants: `UPPER_SNAKE` in MainGame, `_camelCase` in Lobby (see Open questions).
- Types are PascalCase (`ItemStack`, `SpinResult`). String-literal unions are used for enums: `"Info" | "Alert" | "Success"`.
- Remote event names are camelCase verbs, `request*` for client→server and `on*`/`*Updated` for server→client
  (`requestSnapshot`, `moveItem`, `inventoryUpdated`, `onNotification`). Lobby prefixes them with `_` (`_spin`, `_opened`).
- Character attributes are camelCase (`alive`, `baseStamina`, `attackDamage`, `pullingCart`). CollectionService tags are PascalCase (`Enemy`, `ResourceProp`, `Campfire`, `HideOnPopup`).

**Typing:** annotate params and returns, `(): ()` for no return. Use optional types for lookups (`local stack: ItemStack? = inventory[slot]`).
Remote params are typed `any`/`unknown` and narrowed with checks, then cast (`local from: number = fromIndex :: number`).
Types are exported from `shared/types/*Types.luau` (which `return {}`). Component "interfaces" are declared as
types so services can hold them (`CartTypes.cartComponentInterface`, `EnemyTypes.EnemyComponentInterface`).

**Formatting:** tabs. Use generalized iteration (`for _, p in Players:GetPlayers()`) over `ipairs`. Use interpolated strings
for messages, `if … then … else` expressions, and `continue` in loops. Short guards are often one-liners in MainGame (`if not inventory then return end`).
Comments are sparse `--` lines that explain **why** (invariants, trust boundaries, ordering), never what. No doc-comment format is used.

## 6. Systems

### Networking — `docs/networking.md`
- Channel: `shared/network/FooNetwork.luau` → `return { Foo = "Foo" }` (Lobby: add a key to `shared/network.luau`).
- Server: `_networker = Networker.server.new(Network.Foo, Private, { Private.requestBar })`. Handlers have the signature
  `(self, player, ...args)`. A handler's return value answers a client `fetch`.
- Client: `_networker = Networker.client.new(Network.Foo, HandlerTable)`. The server's `fire(player, "onX", …)` calls `HandlerTable.onX(self, …)`.
  `_networker:fire("requestBar", …)` is one-way. `_networker:fetch("getBar")` yields for a return value.
- Replicated state: the server calls `networker:set(player, key, v)` / `setAll(key, v)`. The client reads the field on its handler table and
  listens with `getServerChangedSignal(key)` (`CartPullService` "pullers", `DayNightService` "day", `BoulderPullService` "boulder").
- Cosmetic client→others relays are still validated and rate-limited (`GameManagerService` `Private.UpdateTilt`: CFrame type,
  rotation only, bounded angle; `Private._replicateItem`: owned Hotbar item).
- Mistakes to avoid: relaying client payloads to other clients unvalidated, and trusting client booleans that change what the
  server does. `HeldItemService` ignores the client's "sack equipped" flag and uses `_isSackEquipped(player)` instead.

### Data — `docs/data.md`
- Schema and defaults: `src/Common/config/DataTemplate.luau` (`PlayerData` type + template). Both places call
  `DataService.server:init({ template = DataTemplate, profileStoreIndex = "Development" })` in `PlayerDataService:OnStart`.
- Server: `DataService:hasProfile(p)`, `:get(p, path)`, `:set(p, path, v, dontReplicate?)`, `:update(p, path, fn)`, and the
  `onPlayerInit(self, player, data)` hook (Lobby `PlayerDataService`). Paths are arrays: `{ "PlayerStats", "Nova" }`.
- Client: `DataService.client:init()` (in `DataController`), then `:waitForData()`, `:get(path)`, `:getChangedSignal(path)`. Copy the values into Fusion state (`PlayerDataController`, `BadgeController` clones nested tables first).
- No versioning or migrations. Older saves are normalised when read (`GachaService` `Private._slots`, `_enter`'s EquippedStyle fix).
- Mistakes to avoid: yielding between a `get` and its `set`, writing from the client, and trusting a cached client value for prices or ownership.

### UI — `docs/ui.md`
- **Lobby:** popups are ScreenGuis with a `Wrapper` frame. Open and close them with `PopupUtils.ShowPopup(gui)` / `HidePopup(gui)` (they return Promises,
  handle blur/FOV/backdrop, and hide HUD guis tagged `HideOnPopup`). A big screen is a controller folder: `init.luau` binds the GUI, and
  sub-modules expose `Shared.bind(...)` / `Shared.render(...)` (`GachaController/*Panel`, `BadgeController/*`).
- **MainGame:** HUD in `PlayerGui.ScreenGui.GameHud`. Controllers resolve it with `GuiUtils.waitFor(parent, name, logTag)`. State is in
  `client/states/*State` and rendering in `scope:Observer(state):onBind(render)` (`InventoryUIController`). Tag-bound
  components hydrate bars and billboards (`HealthBarComponent`, `EnemyHealthBarComponent`).
- Input goes through `KeybindUtils.getSignal(action)` with bindings in `shared/config/KeybindConfig.luau` (keyboard + gamepad per
  action). Device detection uses `DeviceUtils.getCurrent()/onChanged`. Gamepad cursor and selection are handled (`InventoryUIController`, `DialogComponent`).

### Cleanup
- Trove API used here: `Connect`, `Add(instance|thread|fn|obj[, "destroy"])`, `Extend()`, `Clean()`, `Destroy()`, `Pop(thread)`.
- Fusion scopes: `Fusion.scoped(Fusion)` per module or component. Components call `Fusion.doCleanup(self._scope)` in `Stop`.
- Threads: keep the handle and `task.cancel` it in `Stop` if it is still suspended (`ChestComponent`, `ResourcePropComponent`), or
  add the `task.delay` thread to a trove and `Pop` it when it fires (`NotificationController`).
- Per-player: a `_playerTroves[player]` destroyed on leave (`HeldItemService`). Per-session: carry/puller troves destroyed on
  drop/detach, plus `CharacterRemoving` and `alive` attribute watchers (`CartService:_pickupWheel`).

### Async
- Default to the `task` library (`task.spawn`, `task.delay`, `task.defer` for destroy-after-signal). Promises (`evaera/promise`) appear only through
  `WaitFor` (`WaitFor.Child(...):await()` in `GuiUtils`, `:andThen():catch(warn)` in `NotificationController`) and `PopupUtils`.
- Wrap only engine calls that can fail in `pcall` (`IsFriendsWithAsync`, `TeleportAsync`, `SetNetworkOwner`, `SetCore`).
  Teleports go through `PlaceConfig` ids; the server uses `TeleportAsync` (`GameManagerService._teleportToLobby`), and
  client-initiated teleports use `TeleportService:Teleport` (`ReturnToLobbyComponent`).
- Periodic work uses sleitnick `Timer` (`Timer.new(rate)`, `.Tick:Connect`, `:Start()`, added to the trove) or
  `Heartbeat` + `Throttle.new(interval)`. Avoid `while true do task.wait()` loops in new code.

### State & events
- Server cross-module events: `server/signals/*Signals.luau` → `{ Name = Signal.new() }`, required through `signals/init.luau`
  (`signals.CharacterSignals.ModDebuff:Fire(player, "hunger", amount)` is how every stat change happens).
- Client: `client/signals` (UI ↔ character events) and `client/states` (Fusion `Value`s read with `peek`/`use`).
- Attributes carry replicated per-instance state: character stats, `PartyZone` `State`/`MemberCount`/`Duration`, and `equippedBadgeId` on the Player.
- CollectionService tags bind Components and are also scanned directly by services (`Campfire`, `CaveBoulder`, `PartyZone`).

### Config
- Shared config modules return plain tables, often with a local `type` annotation (`InventoryConfig`, `KeybindConfig`). Weighted
  tables, odds and ids live there (`ChestConfig.lootWeights`, `GachaConfig.odds`). Secrets stay server-side (`LobbyGame/server/config/CodeConfig.luau`).

### Game systems (MainGame) — details in `src/MainGame/CLAUDE.md`
Character stats (damage/hunger/thirst/sickness/weight subtract from `baseStamina`, managed by `GameManagerService` via `CharacterSignals`),
inventory (5 hotbar slots + Sack slots, `InventoryService`), held "mouth" item (`HeldItemService`), combat (`SwingSession` cooldown
and distance checks), cart assembly, pulling and light, map/cave generation, day/night, weather, virus wall, enemies (spawn + AI + loot), revive purchases (`ReviveService`).

## 7. Checklists

**Before adding a remote**
- [ ] Channel name is in the shared network module, and the handler is in the third argument of `Networker.server.new`.
- [ ] Every argument is type- and range-checked on the server. Instances are checked with `typeof(x) == "Instance"` + `IsA`/`HasTag`/ancestry.
- [ ] Distance and ownership are checked on the server (`CartInteractionUtils.getRootWithin`, `FollowPromptUtils.canReach`, `SwingSession`).
- [ ] The handler is rate-limited per player, and the limiter table is cleared on `PlayerRemoving`.
- [ ] The client keeps optimistic checks only for UX. Fetch responses use `{ status = "..." }` (Lobby).

**Before adding UI**
- [ ] The GUI exists in Studio with stable names. Code finds it with `WaitForChild`/`GuiUtils.waitFor` and warns if it's missing.
- [ ] State lives in `client/states` or a module `_scope`. Rendering goes through `Observer`/`Hydrate`, and the scope is cleaned up in `Stop`.
- [ ] Keyboard, touch and gamepad all work (KeybindConfig entry, `Activated` events, gamepad selection).
- [ ] Lobby: open with `PopupUtils`, and honour `ReducedMotionEnabled`.

**Before finishing any task**
- [ ] `--!strict` at the top, and no new type errors (luau-lsp).
- [ ] `selene src` passes, and `stylua` has formatted the files you touched.
- [ ] Every connection, thread and instance you created has a cleanup path. Per-player tables are cleared on leave.
- [ ] No `print`, no magic numbers that belong in config, no hard-coded place ids.
- [ ] The file matches its neighbours (naming variant of that folder, module layout, Private table usage).

## 8. Do not

- Use raw `RemoteEvent`/`RemoteFunction`, `_G`, `shared`, or `wait()`/`spawn()`/`delay()` (the code uses only `task.*`).
- Build UI trees in code with `Fusion.New` (UI is Studio-authored), or create ScreenGuis except for overlays like
  `NotificationController`'s transition or `DayNightController`.
- Let the client decide damage, currency, loot, ownership or prices. `EquipStateService` is client-reported and only a hint
  ("InventoryService ownership is still the real authority").
- Edit `PlayerGui` from the server. Send state over Networker and render it on the client (the lose screen:
  `GameManagerService` fires `DownedOffer`/`ReviveAllOffer`/`ReplayCount`, and `LoseScreenComponent` draws them).
- Leave connections outside a trove in components, or forget `Stop`.
- Yield inside DataService read-modify-write sequences.
- Add a module ending in `Service`/`Controller`/`Component` that isn't meant to be auto-loaded.

## 9. Open questions (inconsistencies — decide before large refactors)

1. **Local naming has three styles.** (a) PascalCase services/modules + `_camelCase` state is the majority (InventoryService, all Lobby).
   (b) All-`_camelCase` locals (`_replicatedStorage`, `_troveModule`), lowercase module tables (`cartService`) and lowercase
   types (`cartState`) are used in 26 cart/campfire/map/terrain/cave/weather files and look newer. (c) Terse, un-prefixed `Boulder*` files.
   Which one is canonical? For now, match the file or cluster you're editing.
2. **Service shape.** MainGame: `local FooService = {}` + `:OnStart(): ()`. Lobby: `Private`/`Shared` tables + `Shared.OnStart()`.
3. **Constants:** `UPPER_SNAKE` (18 MainGame files) or `_camelCase` locals (all of Lobby, and some MainGame such as `HealthBarComponent`).
4. **Networker handler table:** a separate `Private` table (`InventoryService`, `HeldItemService`, `InventoryController`,
   `CharacterController`, all of Lobby), the module itself (`CombatService`, `CartService`, `EquipStateService`, `DayNightService`,
   `NotificationController`, `CartController`), or `self` (`BoulderPullService`). Most Lobby clients wrap channels in
   `client/network/*Network.luau` (`CodeController` doesn't), while MainGame controllers create them inline.
5. **Networker type:** `Networker.Server`/`Networker.Client` (most) or `types.NetworkerServer` (`typeof(Networker.server.new(""))`).
6. **Formatting isn't uniformly applied.** One-line `if … then return end` and `Hydrate(x) { … }` call style (MainGame) would be
   rewritten by StyLua defaults, which Lobby follows. Should we add a `stylua.toml` and format the whole of `src` in one commit?
7. **Data key casing is mixed:** `redeemedCodes`/`badges`/`Gacha.spins` use camelCase, while `PlayerStats`/`Inventory.EquippedAnimal` use PascalCase. Instance attributes are also mixed (`IsOpen`, `ItemID`, `Id` vs `alive`, `baseStamina`).
8. **Fusion scope local** is named `scope` in some modules and `_scope` in others. A small number of files use `ipairs`.
9. `docs/` (and `AGENTS.md`, `.claude/`) are in `.gitignore`. Should `docs/` be committed?
10. `profileStoreIndex = "Development"` in both places, and the template's default `Gacha.spins = 100`. Are these meant for production?
