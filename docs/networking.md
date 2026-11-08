# Networking

All client/server traffic goes through **`leifstout/networker@0.3.1`** (`ReplicatedStorage.Packages.Networker`). There is no
raw `RemoteEvent` or `RemoteFunction` anywhere in `src`. `Packages/` isn't committed, so the API below comes from how the code
in this repo calls it.

## API as used

| Side | Call | Meaning | Example |
|---|---|---|---|
| server | `Networker.server.new(name, handlers?, exposed?)` | open a channel. `exposed` is the list of handler functions the client may call | `InventoryService:OnStart` |
| server | `:fire(player, event, ...)` | call `handlers[event](self, ...)` on that client | `InventoryService:_replicate` |
| server | `:fireAll(event, ...)` / `:fireAllExcept(player, event, ...)` | broadcast | `VirusService`, `CombatService` |
| server | `:set(player, key, value)` / `:setAll(key, value)` | replicated state field | `CartPullService`, `DayNightService` "day" |
| client | `Networker.client.new(name, handlers)` | open the same channel | every controller |
| client | `:fire(fn, ...)` | one-way call of an exposed server function | `InventoryController:requestMove` |
| client | `:fetch(fn, ...)` | yields and returns the server function's return value | `GachaNetwork.spin`, `CartController:OnStart` |
| client | `:getServerChangedSignal(key)` | fires when `set`/`setAll` changes `key` (the value appears as `handlers[key]`) | `CartPullController`, `HudCompassController` |

Server handler signature: `function Private.name(_self, player: Player, ...untrusted)`. The first argument is the handler
table, the second is the calling player (injected by Networker, so it can be trusted). Client handler signature: `function Private.name(_self, ...)`.

## Defining a channel

- **MainGame:** one module per feature, `src/MainGame/shared/network/<Feature>Network.luau`, returning a name table.
  A module can define several channels (`CharacterNetwork` = `Character` + `Combat`; `GameNetwork` = `Game` + `Virus` + `Hud`;
  `CartNetwork` = `cart` + `cartPull`). Some configs carry their own channel name (`BoulderConfig.network = "BoulderPull"`).
- **Lobby:** a single `src/LobbyGame/shared/network.luau` table (`Party`, `FirstAnimal`, `Badge`, `Codes`, `Gacha`). Client
  wrappers in `src/LobbyGame/client/network/*Network.luau` create the client Networker at require time and expose typed
  functions (`GachaNetwork.spin(lucky, slot): SpinResult`) or a `handlers` table that the controller fills in `OnStart` (`PartyNetwork`).

## Server-side validation patterns (copy these)

```lua
-- Integer slot in range (InventoryService)
local function _isValidSlotIndex(value: any, capacity: number): boolean
	return type(value) == "number" and value % 1 == 0 and value >= 1 and value <= capacity
end

-- Vector input, rejects NaN/inf/oversized (BoulderPullService)
if typeof(direction) ~= "Vector3" then return end
if not (direction.Magnitude <= 1.05) then return end

-- Instance target list (CombatService/_getAttackableHumanoid + SwingSession)
if typeof(target) ~= "Instance" or not target:IsA("Model") then return nil end
if not target:HasTag("Enemy") then return nil end
-- SwingSession caps targets per swing, dedupes hits, checks maxHitDistance and the attackSpeed cooldown.

-- String key against config (CodeService / FirstAnimalService)
if type(code) ~= "string" or #code == 0 or #code > 64 then return { status = "invalid" } end
if type(animalName) ~= "string" or not AnimalShopConfig[animalName] then return "invalid" end

-- Proximity (CartService / FollowPromptUtils)
if not _cartInteractionUtils.getRootWithin(player, position, _cartConfig.interactDistance) then return end
if not FollowPromptUtils.canReach(player, self._zone, ForageConfig.promptDistance) then return end
```

On bad input, either drop the request silently or resync the client (`InventoryService` calls `_replicate(player)` so the
UI snaps back). Lobby fetch handlers always return `{ status = "<reason>" }` with statuses like `notReady`, `rateLimited`,
`invalid`, `locked`, `owned`, `insufficientCoins`, `away`. The client maps them to messages (`GachaController._failMessages`).

## Rate limiting patterns

| Pattern | Where |
|---|---|
| Fixed 1 s window with a count (`maxMovesPerSecond`) | `InventoryService._checkRateLimit` |
| Per-action last-request timestamp via `workspace:GetServerTimeNow()` | `GachaService._checkRequest` ("per action, so picking a slot never rate-limits the next spin") |
| Single cooldown per player | `CodeService` (0.5 s), `BadgeService` (0.15 s), `FirstAnimalService` (0.25 s), `CartPullService:requestPullers` (0.5 s) |
| Gameplay cooldown from a server attribute | `SwingSession.begin` (`attackSpeed` * `CombatConfig.cooldownTolerance`) |
| Client-side send throttling (as well as the server check, not instead of it) | `BoulderPullController` (`pullInputInterval`), `TiltControl` (`Throttle`) |

Always clear the limiter table on `PlayerRemoving`.

## Trusted vs never trusted

- **Trusted:** the `player` argument, server attributes on characters, DataService values read on the server, config tables.
- **Never trusted:** every other argument. That includes booleans that change server behaviour (`HeldItemService` ignores the
  client's `sackEquipped` argument and works it out itself), client-reported equip state (`EquipStateService`: "only tells callers what to check"), item ids, instances, CFrames, and vectors.
- Server→client payloads are re-validated on the client before they touch state (`InventoryController` `Private.inventoryUpdated`).

## Payload shapes

Payloads are plain tables or primitives, typed in `shared/types` (`NotificationTypes.NotificationPayload`, `InventoryTypes.SlotEntry`,
`GachaTypes.SpinResult`, `CartTypes.pullerEntry`). Send snapshots, not deltas: inventory sends the full `{ SlotEntry }` list,
and cart assembly sends `(assembled, revision)` so the client ignores stale updates (`cartController:onAssemblyChanged`).
New clients ask for a snapshot in `OnStart` (`requestSnapshot`, or `fetch("getPhase")`/`fetch("getWeather")`).
