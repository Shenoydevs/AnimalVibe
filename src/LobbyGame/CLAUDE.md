# LobbyGame local conventions

Every file in this place follows these rules, and they differ from MainGame. Match them here.

- **Module shape:** `local Private = {}` + `local Shared = {}` and `return Shared`. Lifecycle is `function Shared.OnStart()`
  (dot, not colon). Helpers are `function Private._name(...)`. Cross-service calls go through `Shared.*` (`ChallengeService.recordEquip`,
  `BadgeService.loadPlayer`). Exceptions: `DataController`, `PlayerDataController` and `PlayerDataService` use `local XController = {}` + `:OnStart(): ()`.
- **Constants/tunables** at the top are `_camelCase` locals (`_dropHeight`, `_returnDistance`, `_normalSpeed`, `_tweenInfo`).
  There is no `UPPER_SNAKE` in this place. Shared numbers live in `shared/config/*Config.luau`.
- **Remote names** start with `_` (`_spin`, `_equip`, `_redeem`, `_opened`, `_onJoinedParty`). The channel is a key in
  `shared/network.luau`.
- **Fetch handlers return `{ status = "..." }`** (plus fields such as `coins`, `styleId`). Guard with a `Private._checkRequest(player, ...)`
  that returns `"notReady" | "rateLimited" | "invalid" | ...` or nil (`GachaService`, `FirstAnimalService`).
- **Client network wrappers** live in `client/network/<Feature>Network.luau`: they create `Networker.client.new` at require time and
  expose typed functions (`GachaNetwork.spin`) and/or a `handlers` table that the controller fills in `OnStart` (`PartyNetwork`).
- **Comments** are full sentences explaining intent and invariants (see `GachaService`, `GachaController`). Keep that density.
- **Formatting** is StyLua output: multi-line `if` blocks, `Hydrate(x)({ ... })` call style, trailing commas.
- **UI:** popups via `utils/PopupUtils` (`ShowPopup`/`HidePopup`/`BindHeader`). Big screens are a controller folder whose sub-modules expose
  `Shared.bind`/`Shared.render`/`Shared.playOpen`. Always handle `GuiService.ReducedMotionEnabled`. HUD guis that should hide behind popups carry the `HideOnPopup` tag.
- **Data:** read with `DataService:get` inside handlers, and never cache server-side. Per-player load hooks are added to `PlayerDataService`'s `onPlayerInit`.
- **Typing:** new files are `--!strict` (all services already are; some older client components, states and index files are not).
