# Architecture

## DataModel mapping
| Repo path | Main (`main.project.json`) / Lobby (`lobby.project.json`) |
|---|---|
| `Packages/` (wally install) | `ReplicatedStorage.Packages` |
| `src/Common` | `ReplicatedStorage.Common` |
| `src/<Place>/shared` | `ReplicatedStorage.Shared` |
| `src/<Place>/server` | `ServerScriptService.Server` (Script `init.server.luau` / `startup.server.luau`) |
| `src/<Place>/client` | `StarterPlayer.StarterPlayerScripts.Client` (LocalScript `init.client.luau` / `startup.client.luau`) |

`main.project.json` sets `$ignoreUnknownInstances: true` on the service nodes, so Studio-made children survive a sync.
Studio-only instances the code depends on: `ReplicatedStorage.Assets.{Animals,Resources,AnimalSounds,UI,GUIs,DebugItem,Hostiles…}`,
`ReplicatedStorage.DebugAnimal` (optional StringValue, MainGame Studio), `workspace.Map`, `workspace.Zones`, `Lighting.Popup_BlurEffect`, and the
StarterGui ScreenGuis (`ScreenGui/GameHud`, `PartyConfigGui`, `BadgeGui`, `SpinGui`, …). MainGame creates `ReplicatedStorage.ComingBack` (BoolValue) at runtime.

## Third-party packages (`wally.toml`)
| Package | Used for | Where |
|---|---|---|
| `sleitnick/loader@2.0.0` | bootstrap: load `*Service`/`*Controller` and spawn `OnStart`, load `*Component` | 4 bootstrap scripts |
| `leifstout/networker@0.3.1` | all remotes (fire/fetch/replicated state) | ~48 files |
| `leifstout/dataservice@1.0.0` | player profiles (server) and replicated data (client) | ~15 files |
| `sleitnick/component@2.4.8` | CollectionService-tag-bound classes | 27 components |
| `sleitnick/trove@1.8.0` | cleanup | ~57 files |
| `elttob/fusion@0.3.0` | client reactive state, Hydrate bindings, springs | ~38 files |
| `sleitnick/signal@2.0.3` | server/client signals modules, KeybindUtils | 9 files |
| `sleitnick/timer@2.0.0` | periodic ticks (day/night, AI, virus, campfire heal) | 9 files |
| `sleitnick/wait-for@1.0.0` | Promise-based child waits (`GuiUtils`, `NotificationController`, `HudCompass`) | 3 files |
| `evaera/promise@4.0.0` (`Packages.promise`, lowercase) | `PopupUtils` transitions, `HudCompass` | 2 files |
| `sleitnick/shake@1.1.0` | UI/camera shakes | `HealthBarComponent`, `ResourceNodeController` |
| `ldgerrits/quickzone@^1.4.7` | player-in-zone detection | `GachaService`, `PartyZoneComponent` |

## Lifecycle
```
Server script:  Loader.LoadDescendants(script, MatchesName("Service$"))   -- require all services (top-level code runs)
                Loader.SpawnAll(..., "OnStart")                           -- task.spawn each OnStart
                Loader.LoadDescendants(script, MatchesName("Component$")) -- require components -> they bind to tags
Client script:  wait for game.Loaded, then the same with "Controller$"
```
- Services require each other directly at the top of the file (`require(ServerScriptService.Server.services.X)` or
  `require(script.Parent.X)`). Avoid circular requires: it is a one-way dependency graph
  (Inventory → Notification; HeldItem → EquipState, Inventory, Notification; EnemyAI → EnemyComponent, Campfire, Cart).
- A service can require a component module to read its class (`EnemyAIService` → `EnemyComponent`, `ResourceCombatService` →
  `ResourceNodeComponent`, then `EnemyComponent:FromInstance(model) :: EnemyComponentInterface?`). Components require services for actions (`ChestComponent` → `InventoryService`).
- Module state is created at require time (`local _trove = Trove.new()`). Networkers are created in `OnStart` (MainGame) or at
  require time in Lobby `client/network/*`.

## Event flow examples
- **Stat change:** `DayNightService:HungerStep` → `CharacterSignals.ModDebuff:Fire(player, "hunger", n)` → `GameManagerService`
  clamps the attribute, recomputes `maxStamina`, flips `alive`, then `_networker:fire(player, "ModDebuff", …)` → `CharacterController:HandleDebuff`
  → `MovementControl:UpdateMaxStamina` → `CharacterState.*:set` → `HealthBarComponent` springs.
- **Day cycle:** `DayNightService` Timer → `GameSignals.DayCycleCompleted` → `VirusService` (advance wall), `WeatherService` (re-roll),
  `EnemyService` (tier/day), `CartLightService`.
- **Map:** `MapGenerationService` → `GameSignals.BiomeFeaturesGenerated` / `MapSpawnReady` / `MapGenerationCompleted` →
  `EnemyService`, `CampfireService`, `GameManagerService` (spawns characters once terrain is ready).
- **Party → match:** `PartyZoneComponent` (QuickZone) → `PartySignals.PlayerEntered` → `PartyService` state machine
  (`EMPTY → CREATING → INTERMISSION → STARTING`, mirrored to zone attributes) → `TeleportService:ReserveServerAsync(PlaceConfig.mainGameId)`.

## Characters
- Lobby: `FirstAnimalService._spawn` clones `Assets.Animals[name]`, applies `AnimalConfig`, sets `player.Character`, and destroys the old character.
- MainGame: `GameManagerService` spawns a character for every player (live and Studio) once `MapSpawnReady` fires. The animal is
  the one equipped in the Lobby (`PlayerDataService.waitForEquippedAnimal`, 15 s timeout). Studio uses `ReplicatedStorage.DebugAnimal`
  if it exists. Unknown or unconfigured animals fall back to the template default (`Horse`) with a warning.
  `PreparePlayer(animal)` clones the rig and sets every stat as an attribute from `CharactersConfig`.
  The client `CharacterController` is initialised by the server event `InitCharacter` and composes `*Control` sub-modules
  (Movement, Animator, Combat, Item, Tilt, LegIK, Footsounds, Direction, Social, Ability), each with `:Init(character, …)` and `:Tick(dt)`.
- Stamina/sprint and WalkSpeed are client-driven (`MovementControl`). Stat values come from server attributes.

## Performance practices in use
- `Throttle.new(interval)` stepper for heavy per-frame work (`HudCompassController`, `DayNightController`, `TiltControl`).
- Spatial hashing (`KeepoutRegistry`), cached RaycastParams at module level (`EnemyService`, `MapGenerationService`).
- Budgeted generation with cursors carried across frames (`MapGenerationService` stream/population queues).
- Timers at fixed rates for AI (`EnemyAIService` detection/path/attack timers) instead of per-frame loops.
- Weak-keyed caches for UI motion (`SpinMotion`).
- `AssetUtils.cloneResource(id, inert)` strips prompts and disables collisions on visual clones.

## Testing / debugging
No test framework, no CI. Debug hooks are Studio-gated: `RunService:IsStudio()` guards `_debugItem` (server) and the
`DebugItem` GUI (client), and the Lobby has the `UseMockData` attribute on ServerScriptService. In Studio, the MainGame character
type comes from `ReplicatedStorage.DebugAnimal` when that StringValue exists.
