# MainGame local conventions

## Two naming clusters — match the file you're in
- **Default (most files):** PascalCase service/package locals (`ReplicatedStorage`, `Trove`, `Networker`), `local FooService = {}`,
  `UPPER_SNAKE` constants, `_camelCase` module state, `function FooService:OnStart(): ()`, a `Private` table for remote handlers.
  Reference: `server/services/InventoryService.luau`, `client/controllers/InventoryController.luau`.
- **Cart / campfire / map / terrain / cave / weather cluster** (`CartService`, `CartPullService`, `CartLightService`,
  `CartStorageService`, `CampfireService`, `MapGenerationService`, `CartComponent`, `WheelComponent`, `CartStorageComponent`,
  `CartSignals`, `utils/Cart*`, `utils/Cave*`, `utils/Terrain*`, `CartController`, `CartPullController`, `WeatherController`, …):
  every local is `_camelCase` (`_replicatedStorage`, `_troveModule`, `_networkerModule`), module tables and types are lowercase
  (`cartService`, `type cartState`), and Networker access goes through `_getNetworker()` with `assert(_networker, "... has not started")`.
  Components there are typed: `export type cartComponent = _cartTypes.cartComponentInterface & { ... }`, with methods written as
  `function cartComponent.Construct(self: cartComponent): ()`. The server signals index exposes it as `signals.cartSignals` (lowercase).
- `Boulder*` files use a terse un-prefixed style (`local networker`, `local sessions`). It's isolated, so don't spread it.

## Game systems map
| System | Server | Client | Config |
|---|---|---|---|
| Character stats/death | `GameManagerService` (applies `CharacterSignals.ModDebuff`/`SetDebuff`/`IFrames`/`Revived`), `ReviveService` (ProcessReceipt) | `CharacterController` + `*Control`, `HealthBarComponent`, `LoseScreenComponent` | `CharactersConfig`, `RevivePricingConfig` |
| Inventory (hotbar 1–5, sack 6+) | `InventoryService` | `InventoryController`, `InventoryUIController`, `states/InventoryState` | `InventoryConfig`, `ItemConfig` |
| Held "mouth" item | `HeldItemService` | `HeldItemController`, `ItemControl` | `ItemConfig.slot == "Mouth"` |
| Equipped tool (client-reported hint) | `EquipStateService` | `EquipStateController` | — |
| Combat / chopping | `CombatService`, `ResourceCombatService`, `utils/SwingSession` | `CombatControl`, `ResourceNodeController`, `shared/utils/HitboxUtils` | `CombatConfig`, `ResourceNodeConfig` |
| World pickups | `components/ResourceProp`, `Forage`, `Scavenge`, `WaterResource`, `Chest`, `utils/GroundItemUtils`, `FollowPromptUtils` | `FollowPromptController`, `ProximityPromptController` | `ForageConfig`, `ScavengeConfig`, `ChestConfig`, `WaterResourceConfig`, `FollowPromptConfig` |
| Cart | `CartService` (wheels), `CartPullService` + `utils/CartPullSession`, `CartLightService`, `CartStorageService` | `CartController`, `CartPullController`, `CartIndicatorController`, `CartStorageController` | `CartConfig` |
| Map | `MapGenerationService`, `utils/Terrain*`, `utils/Cave*` | `BiomeController` | `MapConfig`, `MapGenerationConfig`, `CaveGenerationConfig`, `Biome*Config` |
| Time/weather/virus | `DayNightService`, `WeatherService`, `VirusService` | `DayNightController`, `ClockController`, `WeatherController`, `VirusController`, `HudCompassController` | `DayNightConfig`, `WeatherConfig`, `VirusConfig` |
| Enemies | `EnemyService` (spawn), `EnemyAIService` (state machine on timers), `EnemyLootService`, `components/EnemyComponent`, `utils/EnemyPathfinder` | `EnemyController`, `EnemyHealthBarComponent` | `EnemyConfig`, `EntityConfig` |
| Safe zones | `CampfireService` (`isPositionSafe`, `clampOutsideZones`), `CartLightService` (`isInSafezone`, `clampOutsideSafezone`) | `CampfireController` | `CampfireConfig`, `shared/utils/SafezoneUtils` |
| Notifications | `NotificationService` | `NotificationController` | `NotificationConfig` |

## Rules specific to this place
- **Change a character stat only by firing `CharacterSignals.ModDebuff:Fire(player, stat, delta)` or `SetDebuff`.** Never set
  `damage`/`hunger`/… attributes directly. `GameManagerService` clamps the value to 0–150, recomputes `maxStamina`, handles death/`alive`, and notifies the client.
- To iterate living players, use `PlayerUtils.forEachAlive`. Get a character root with `CharacterUtils.getRoot`/`getPlayerRoot`.
- Spawn items in the world with `GroundItemUtils.spawn(itemId, character, aroundCharacter?)` / `spawnAt(itemId, cframe, options?)`.
  Visual clones of resources come from `AssetUtils.cloneResource(itemId, inert?)`.
- Give items with `InventoryService:addItem` (it routes `Hotbar` vs `Mouth`) and check the boolean result before granting anything else.
- Input actions must be declared in `shared/config/KeybindConfig.luau` with keyboard **and** gamepad bindings, and read via `KeybindUtils.getSignal`.
- Heavy per-frame client work goes through `shared/utils/Throttle`.
- Studio-only debug code goes behind `RunService:IsStudio()` on both server and client (`_debugItem`).
