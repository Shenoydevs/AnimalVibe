# UI

Framework: **Fusion 0.3** (`elttob/fusion@0.3.0`) for state and bindings only. Every ScreenGui, BillboardGui template and
widget is authored in Studio (StarterGui → PlayerGui, or `ReplicatedStorage.Assets.UI` / `Assets.GUIs`). None of it is in the repo.
Code finds instances by name, binds them, and clones templates. `scope:New` is never used.

## Fusion usage (as written in this repo)
```lua
local _scope = Fusion.scoped(Fusion)              -- one per module, or self._scope per component
local value = _scope:Value(0)                      -- usually lives in client/states/*State.luau
local text = _scope:Computed(function(use) return tostring(use(value)) end)
_scope:Hydrate(label)({ Text = text, Position = _scope:Spring(goal, 20, 1) })
_scope:Tween(_scope:Computed(...), tweenInfo)      -- CodeController
_scope:Observer(value):onBind(render)              -- run now + on change
_scope:Observer(value):onChange(render)            -- only on change
Fusion.peek(value)                                 -- read outside reactive scope (often `local peek = Fusion.peek`)
Fusion.doCleanup(self._scope)                      -- in Component:Stop
```
Don't call `:set` inside a `Computed`. `HealthBarComponent` does, and new code shouldn't copy it.

## MainGame HUD pattern
Source: `InventoryUIController.luau`, `KeyBindsUIController.luau`, `HudCompassController.luau`.
1. In `OnStart`, resolve `PlayerGui.ScreenGui.GameHud.<Section>` step by step with
   `GuiUtils.waitFor(parent, childName, logTag)`. It waits 30 s, warns `[logTag] Missing "x" under …`, and returns nil. Bail out early on nil.
2. Cache refs in a typed record (`type SlotRefs = { frame: GuiObject, icon: ImageLabel, ... }`). Clone templates
   (`SlotTemplate:Clone()`, set `Name`/`LayoutOrder`, parent them).
3. State lives in `client/states/*State`. Render with `scope:Observer(State.X):onBind(_render)`. Input comes from
   `KeybindUtils.getSignal(action)` (Begin/End `UserInputState`) and button `MouseButton1Down`/`Activated`.
4. Drag interactions get their own `Trove` holding `RenderStepped`/`InputEnded`/`InputBegan`, destroyed on cancel (`_pressOnBag`).
5. Gamepad: `GamepadService:EnableGamepadCursor(frame)` while open, and `GuiService.SelectedObject` for dialogs (`DialogComponent`).
6. Overlays that must exist without Studio UI are built with `Instance.new` (`NotificationController._buildTransitionUI`:
   `ResetOnSpawn = false`, `IgnoreGuiInset = true`, high `DisplayOrder`).

World UI: a Component clones a BillboardGui template from `ReplicatedStorage.Assets.UI`, adds it to its trove, sets
`Adornee`, and re-renders on attribute or Humanoid changes (`AnimalHealthBarComponent`, `EnemyHealthBarComponent`).

Notifications: on the server, `NotificationService:notify(player, kind, message, duration, NotificationConfig.priority.x)` / `notifyAll`.
On the client, call `NotificationController:push(message, duration, priority, kind)` directly. It's a priority queue capped at `maxQueue`.

## Lobby popup pattern
Source: `utils/PopupUtils.luau`, `BadgeController/`, `CodeController.luau`, `GachaController/`.
- Every popup ScreenGui has a `Wrapper` frame (optionally a `Motion` CanvasGroup and a `UIScale`). Motion variants are chosen by
  wrapper attributes `badgePopupMotion` / `animalShopMotion`.
- `PopupUtils.ShowPopup(gui)` / `HidePopup(gui)` return a Promise. They handle the blur (`Lighting.Popup_BlurEffect`), the FOV tween, the
  backdrop, and hiding every ScreenGui tagged **`HideOnPopup`**. Only one popup is open at a time (`GetCurrentPopup`).
- `PopupUtils.BindHeader(wrapper)` gives the standard title/divider animation. `PopupUtils.ShineSequence(color)` builds the glint gradient.
- Menu buttons live in separate `*MenuGui` ScreenGuis (`BadgeMenuGui.OpenBadges`, `CodeMenuGui.OpenCodes`).
- Large screens are split into sub-modules in the controller folder, each with `Private`/`Shared`, exposing
  `Shared.bind(...)`, `Shared.render(...)`, `Shared.playOpen()`. The controller's `init.luau` composes them (`GachaController/init.luau`).
- **Motion must honour `GuiService.ReducedMotionEnabled`.** Check it, swap in short/zero TweenInfos, and settle on change
  (`PopupUtils`, `SpinMotion.reduced()`, `CodeController._reducedMotion`).
- Reusable motion helpers: `GachaController/SpinMotion.luau` (weak-keyed tween/rest caches, `play`, `cancel`, `slideIn`, `pop`, `flash`, `bindButton`).
- Buttons get a hover/press feel from the **`AnimatedButton`** tag (`AnimatedButtonComponent`, configured by attributes such as `buttonGlowColor`).
  Purchases use the **`MonetizationButton`** tag with `ItemType` = `"DeveloperProduct"|"Gamepass"` and a numeric `Id` attribute
  (`src/Common/components/MonetizationButtonComponent.luau`, re-exported by both places; `Id` is read on click so code can set it at runtime).

## Styling
There's no theme module. Colours and TweenInfos are module-level locals at the top of each UI file (`_toneColors`,
`_showInfo`, `_switchPosition`, `_baseColor`) or in config (`NotificationConfig.styles`, `KeybindUIConfig`). Scaling uses
`UDim2.fromScale` and authored `UIScale`/`UIAspectRatioConstraint`s. Never use pixel offsets for layout except small nudges.

## Opening/closing summary
| Kind | Open | Close |
|---|---|---|
| Lobby popup | `PopupUtils.ShowPopup(gui)` | `PopupUtils.HidePopup(gui)` |
| Lobby full-screen mode (gacha) | server fires `_opened` → `PopupUtils.HideAllGuis()`, scriptable camera, `gui.Enabled = true` | `restore()` → `ShowAllGuis()`, camera back to Custom |
| MainGame HUD panel | set a state `Value` (`InventoryState.IsOpen:set(true)`) | set it false; the observer toggles `Visible` |
| Tagged component | the tag is added or removed in Studio/at runtime | `Stop` |
