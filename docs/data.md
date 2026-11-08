# Player data

Package: **`leifstout/dataservice@1.0.0`** (`require(Packages.DataService).server` / `.client`). The comments in the code
describe it as session-locked profiles ("the same session-locked profile"); `getProfile(player):IsActive()` is a profile-store-style API.

## Schema
`src/Common/config/DataTemplate.luau` is the single source: an exported `PlayerData` type plus the default `template`.
Both places use it. Sub-types: `AnimalData`, and `BadgeTypes.BadgeProfile` from `src/Common/types`.

To add a field: add it to the `PlayerData` type **and** the template, then read it with a path. Nothing in the repo shows a
migration or version field. Older saves are normalised when read:
- `GachaService` `Private._slots(styles)` pads `styles` to `GachaConfig.maxStyles` ("older saves list only the slots they had filled").
- `GachaService` `Private._enter` re-points `EquippedStyle` if it isn't in a slot.
- `BadgeService.loadPlayer` falls back to `""` if the equipped badge is unknown or not earned.

## Server
```lua
local DataService = require(ReplicatedStorage.Packages.DataService).server

-- PlayerDataService:OnStart (one per place)
function DataService.onPlayerInit(_self, player: Player, data: PlayerData): () ... end  -- Lobby only
DataService:init({
	template = DataTemplate,
	profileStoreIndex = "Development",
	useMock = RunService:IsStudio() and ServerScriptService:GetAttribute("UseMockData") == true, -- Lobby only
})

DataService:hasProfile(player)                       -- guard every handler with it
DataService:get(player, { "PlayerStats", "Nova" })
DataService:set(player, { "Inventory", "EquippedStyle" }, styleId)
DataService:set(player, { "Challenges" }, updated, dontReplicate) -- 4th arg skips replication (ChallengeService.loadPlayer)
DataService:update(player, { "PlayerStats", "Nova" }, function(nova: number): number return nova + coins end)
```
Rules seen in the code:
- Check `player.Parent ~= Players or not DataService:hasProfile(player)` first, and return `"notReady"` if it fails.
- Read, validate and write **without yielding in between**. The code says so in a comment at each multi-write site.
- When writing a whole sub-table, `table.clone` it first and set the clone (`ChallengeService`, `GachaService._spin`, `PlayerDataService.awardRoundXp`).
- Cross-service effects run after the data write (`FirstAnimalService._confirm` → `ChallengeService.recordEquip`).
- Per-load hooks are called from `onPlayerInit` in the Lobby `PlayerDataService` (`BadgeService.loadPlayer`, `ChallengeService.loadPlayer`, `FirstAnimalService.loadPlayer`).

MainGame `PlayerDataService` exposes `awardRoundXp(player)` (idempotent per server via `_awardedRoundXp[userId]`) and
`awardNova(player, amount)`. Both check `getProfile(player):IsActive()`. It also exposes `waitForEquippedAnimal(player)`, which yields on
`DataService:waitForData(player)`; that's the package's own "wait until loaded" call, so use it rather than polling `hasProfile`.

## Client
```lua
local DataService = require(ReplicatedStorage.Packages.DataService).client
-- DataController:OnStart -> DataService:init()
DataService:waitForData()
DataService:getChangedSignal({ "PlayerStats" }):Connect(readData)
local stats = DataService:get({ "PlayerStats" })
```
Copy values into Fusion state (`PlayerDataController` → `PlayerState.Level/Xp/Coins`). Clone nested tables before
`:set` because DataService mutates them in place (`BadgeController._readData`). Client data is display-only. Prices,
ownership and spins are always re-checked on the server.

## Non-persistent state
Round state in MainGame (inventory, held item, stats) is **not saved**. It lives in service tables (`InventoryService._inventories`)
and character attributes, and is discarded on leave.
