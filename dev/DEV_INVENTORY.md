# Dev Tooling Inventory (Prelim, no behavior changes)

Generated from repo scan only. No refactors or behavior changes.

## Scope / Scan Notes

- Primary runtime dev tooling lives in `Scripts/systems/GameController.gd` (autoload) and `Scripts/ui/CaseHandlingScene.gd` (PiP calibration hotkeys).
- Dev sim harness exists in `dev/RevolverSim.gd`.
- `Scripts/systems/OverlayManager.gd` contains one explicit dev-only overlay id (`DEV_TEST`) plus non-dev runtime overlays.

## Step 1: Dev Folders + Name-Match Script/Scene Candidates

### `res://dev/`

- `dev/RevolverSim.gd` (`RevolverSim.run`) - dev sim/test harness for revolver behavior
- `dev/RevolverSim.gd.uid`

### Name-match scan (`Dev|Sim|Debug|Test|Harness|Cheat|Hotkey|HUD|Overlay`)

- `Scripts/systems/OverlayManager.gd`
- `Scenes/ComputerTerminalOverlay.tscn`
- `Scenes/EndCardOverlay.tscn`
- `Scripts/ui/ComputerTerminalOverlay.gd`
- `Scripts/ui/EndCardOverlay.gd`
- `Scripts/ui/CaseFolderOverlay.gd`
- `Scripts/ui/VerdictResultOverlay.gd`
- `addons/pip_author_preview/crop_overlay.gd` (editor plugin tooling, not runtime game dev hotkey tooling)
- `dev/RevolverSim.gd`

## A) Entry Points

### Runtime entry points (dev-related)

- `project.godot:20` autoload -> `Scripts/systems/GameController.gd` (`GameController`)
- `Scripts/systems/GameController.gd:300` `func _input(event)`
- `Scripts/systems/GameController.gd:308` `func _unhandled_input(event)`
- `Scripts/systems/GameController.gd:363` `func _handle_dev_hotkeys(event) -> bool` (main dev command dispatcher)
- `Scripts/ui/CaseHandlingScene.gd:311` `func _input(event)` (Case Handling PiP calibration hotkeys)
- `Scripts/ui/CaseHandlingScene.gd:355` `func _handle_pip_calibration_key(event) -> bool`
- `Scripts/systems/Camera.gd:29` `func _process(delta)` handles `toggle_edge_pan` action (actual edge-pan toggle)
- `Scripts/systems/OverlayManager.gd:17` `func open(id, payload)` contains `DEV_TEST` overlay path

### Hotkeys list (key -> action -> handler)

| Key | Input action | Handlers |
|---|---|---|
| `Esc` | `ui_cancel` | `Scripts/systems/GameController.gd:363` `_handle_dev_hotkeys` (dev escape hatch: close overlays/fullscreen/quit w/ shift) |
| `F1` | `dev_toggle` | `Scripts/systems/GameController.gd:363` `_handle_dev_hotkeys` |
| `F2` | `dev_next_suspect` | `Scripts/systems/GameController.gd:363` `_handle_dev_hotkeys` |
| `F3` | `dev_force_verdict` | `Scripts/systems/GameController.gd:363` `_handle_dev_hotkeys` (log-only stub) |
| `F4` | `toggle_edge_pan` | `Scripts/systems/GameController.gd:363` `_handle_dev_hotkeys` (logs), `Scripts/systems/Camera.gd:29` `_process` (actual toggle) |
| `F6` | `dev_load_seed` | `Scripts/systems/GameController.gd:363` `_handle_dev_hotkeys` -> `_open_seed_prompt` |
| `F7` | `dev_seed_copy` | `Scripts/systems/GameController.gd:363` `_handle_dev_hotkeys` |
| `F12` | `dev_end_game` | `Scripts/systems/GameController.gd:363` `_handle_dev_hotkeys` |

### Non-InputMap dev hotkeys (raw key handling)

Defined in `Scripts/systems/GameController.gd:445`+ inside `_handle_dev_hotkeys` and in `Scripts/ui/CaseHandlingScene.gd:355`+.

- `F8`, `F9` warnings (editor-safe reminders) in `GameController`
- `0..6`
- `Ctrl+Shift+E/I/R/[ ] \\ Z X C V N M P A G B D T K L`
- Case Handling PiP calibration keys: `F8`, arrows, `Shift+Arrows`, `Ctrl+Arrows`, `Ctrl+Shift+Arrows`, `PgUp`, `PgDn`, `Alt` (fine step), `P`

## B) Commands

### GameController dev commands (`Scripts/systems/GameController.gd:363` `_handle_dev_hotkeys`)

Note: the raw-key dev block at `Scripts/systems/GameController.gd:445` is gated by `dev_allow_suspect_io`, so that export/import flag currently also gates revolver/danger/noise dev keys.

| Command / Key | Implementation | What it does | Dependencies | Safe context |
|---|---|---|---|---|
| `Esc` (`ui_cancel`) | `_handle_dev_hotkeys` | Dev escape hatch: closes overlay, exits fullscreen, or quits (shift-gated) | `overlay_open`, `overlay_id`, `_intermission_sys`, `DisplayServer`, `SceneTree` | Anywhere runtime (except import dialog open) |
| `F1` `dev_toggle` (`dev_toggle_hud` alias check also present but not in `project.godot`) | `_handle_dev_hotkeys` -> `_set_dev_hud_visible`, `_update_hud` | Toggle dev HUD visibility | Dev HUD nodes (`_hud_layer`, labels) | Anywhere runtime |
| `F2` `dev_next_suspect` | `_handle_dev_hotkeys` -> `_advance_to_next_suspect` | Skips to next suspect, closes some overlays first | `current_suspect`, suspect seed/state, overlay state | Anywhere runtime; most useful in game |
| `F3` `dev_force_verdict` | `_handle_dev_hotkeys` | Currently log-only stub | `_last_force_verdict_event_id` | Anywhere runtime |
| `F4` `toggle_edge_pan` | `_handle_dev_hotkeys` (log only) + `Camera._process` | Toggle camera edge pan | `Camera2D` with `Scripts/systems/Camera.gd`, action present in `InputMap` | In `Game.tscn` with camera present |
| `F6` `dev_load_seed` | `_handle_dev_hotkeys` -> `_open_seed_prompt` | Opens seed override dialog | Seed prompt UI (`AcceptDialog`, `LineEdit`), seed parsing, `_request_seed_reload` | Anywhere runtime |
| `F7` `dev_seed_copy` | `_handle_dev_hotkeys` | Copies current run seed text to clipboard | `DisplayServer.clipboard_set`, `run_seed_text` | Anywhere runtime |
| `F12` `dev_end_game` | `_handle_dev_hotkeys` | Quits app (only when actual key is F12) | `SceneTree.quit()` | Anywhere runtime |
| `F8` (raw) | `_handle_dev_hotkeys` | Warns: use `Ctrl+Shift+E` for export (editor-safe) | Log only | Anywhere runtime |
| `F9` (raw) | `_handle_dev_hotkeys` | Warns: use `Ctrl+Shift+I` for import (editor-safe) | Log only | Anywhere runtime |
| `0..6` | `_handle_dev_hotkeys` -> `_dev_set_live_rounds_and_sync` | Sets revolver live rounds via fresh cylinder load | `_revolver_sys`, `_revolver_widget`, `Revolver` node | In-game scene with revolver system/widget |
| `Ctrl+Shift+E` | `_handle_dev_hotkeys` -> `_dev_export_suspect` | Export suspect JSON to clipboard and `user://dev/*.json` | `current_suspect`, `SuspectIO`, `SuspectData`, `DisplayServer`, `user://dev` | Anywhere runtime; requires current suspect |
| `Ctrl+Shift+I` | `_handle_dev_hotkeys` -> `_dev_import_suspect_clipboard_or_prompt` | Import suspect JSON from clipboard / `user://dev/last_suspect.json` / paste dialog | `SuspectIO`, `SuspectData`, `SeedUtil`, `DisplayServer`, import dialog UI | Anywhere runtime |
| `Ctrl+Shift+R` | `_handle_dev_hotkeys` | Add random live round to revolver | `_revolver_sys.add_live_round_random`, `_sync_revolver_widget` | In-game scene with revolver system/widget |
| `Ctrl+Shift+]` | `_handle_dev_hotkeys` -> `_dev_set_danger_tier_and_reload` | Increment danger tier and reload | `_revolver_sys.snapshot`, `_revolver_sys.set_danger/load_fresh_cylinder` | In-game scene with revolver |
| `Ctrl+Shift+[` | `_handle_dev_hotkeys` -> `_dev_set_danger_tier_and_reload` | Decrement danger tier and reload | Same as above | In-game scene with revolver |
| `Ctrl+Shift+\\` | `_handle_dev_hotkeys` -> `_dev_set_danger_tier_and_reload(0)` | Reset danger tier to 0 and reload | Same as above | In-game scene with revolver |
| `Ctrl+Shift+Z` | `_handle_dev_hotkeys` | Reset danger fill to 0 | `_revolver_sys.set_danger_fill`, `_sync_revolver_widget` | In-game scene with revolver |
| `Ctrl+Shift+X` | `_handle_dev_hotkeys` -> `_apply_danger_penalty(25, ...)` | Add danger fill (+25) | `_revolver_sys`, overflow discharge path, revolver UI | In-game scene with revolver |
| `Ctrl+Shift+C` | `_handle_dev_hotkeys` -> `_apply_danger_penalty(50, ...)` | Add danger fill (+50) | Same as above | In-game scene with revolver |
| `Ctrl+Shift+V` | `_handle_dev_hotkeys` -> `_apply_danger_penalty(100, ...)` | Add danger fill (+100) | Same as above | In-game scene with revolver |
| `Ctrl+Shift+N` | `_handle_dev_hotkeys` -> `_apply_noise_trigger("dev_noise_spike")` | Apply dev noise +10 trigger | `_noise_sys.apply_trigger`, `time_policy.noise_triggers`, `dev_noise_spike` trigger id | In-game scene with noise system/policy |
| `Ctrl+Shift+M` | `_handle_dev_hotkeys` -> `_phone.toggle_dev()` | Toggle phone ringing for noise testing | `_phone` (`PhoneSystem`), policy/noise hookup via `PhoneSystem.setup` | In-game runtime with phone system |
| `Ctrl+Shift+P` | `_handle_dev_hotkeys` | Enable noise carryover for next suspect | `_noise_carryover_next_suspect` flag | In-game runtime |
| `Ctrl+Shift+A` | `_handle_dev_hotkeys` -> `_apply_noise_trigger("attempt_failure_beep")` | Simulate attempt-failure noise | `_noise_sys`, `time_policy` trigger ids | In-game runtime |
| `Ctrl+Shift+G` | `_handle_dev_hotkeys` -> `_apply_noise_trigger("camera_interference")` | Simulate camera interference noise | `_noise_sys`, `time_policy` trigger ids | In-game runtime |
| `Ctrl+Shift+B` | `_handle_dev_hotkeys` -> `_apply_noise_trigger("vent_drill")` | Simulate vent drill noise | `_noise_sys`, `time_policy` trigger ids | In-game runtime |
| `Ctrl+Shift+D` | `_handle_dev_hotkeys` -> `_apply_noise_trigger("case_handling_failure")` | Simulate case-handling failure noise | `_noise_sys`, `time_policy` trigger ids | In-game runtime |
| `Ctrl+Shift+T` | `_handle_dev_hotkeys` -> `RevolverSim.new().run(...)` | Runs revolver sim harness (50 shots) and logs summary/errors | `dev/RevolverSim.gd`, `RevolverSystem`, `run_seed_u64`, optional `_revolver_sys.danger` | Anywhere runtime; meaningful with seed/revolver state |
| `Ctrl+Shift+K` | `_handle_dev_hotkeys` -> `request_shot(DEV_TEST,false,...)` | Test revolver click cinematic | `request_shot`, `_revolver_sys`, `Revolver` widget signals | Only when no overlay (`request_shot` enforces) |
| `Ctrl+Shift+L` | `_handle_dev_hotkeys` -> `request_shot(DEV_TEST,true,...)` | Test revolver boom cinematic | Same as above | Only when no overlay (`request_shot` enforces) |

### Supporting implementation functions (dev command dependencies)

- `Scripts/systems/GameController.gd:1519` `_dev_set_danger_tier_and_reload`
- `Scripts/systems/GameController.gd:1530` `_dev_set_live_rounds_and_sync`
- `Scripts/systems/GameController.gd:1461` `_apply_danger_penalty`
- `Scripts/systems/GameController.gd:1496` `_apply_noise_trigger`
- `Scripts/systems/GameController.gd:1271` `request_shot` (`DEV_TEST` allowed only when `not overlay_open`)
- `Scripts/systems/GameController.gd:2378` `_dev_export_suspect`
- `Scripts/systems/GameController.gd:2427` `_dev_import_suspect_clipboard_or_prompt`
- `Scripts/systems/GameController.gd:2462` `_install_suspect_import_prompt`
- `Scripts/systems/GameController.gd:809` `_install_seed_prompt`
- `Scripts/systems/GameController.gd:853` `_open_seed_prompt`

### Case Handling PiP calibration commands (`Scripts/ui/CaseHandlingScene.gd`)

| Command / Key | Implementation | What it does | Dependencies | Safe context |
|---|---|---|---|---|
| `F8` | `_handle_pip_calibration_key` | Toggle PiP calibration mode; shows overlay label + capture rect, prints values | `noise_meter_pip`, calibration UI label, `_draw` | `CASE_HANDLING` overlay / `CaseHandlingScene` runtime only |
| `Arrows` | `_handle_pip_calibration_key` | Move capture source center | `pip_source_center_px`, `_update_live_pip_region`, `_layout_noise_meter_pip` | Calibration active only |
| `Shift+Arrows` | `_handle_pip_calibration_key` | Resize capture source rect | `pip_source_size_px` | Calibration active only |
| `Ctrl+Arrows` | `_handle_pip_calibration_key` | Move on-screen PiP frame (`NoiseMeterPiP`) | `noise_meter_pip` offsets | Calibration active only |
| `Ctrl+Shift+Arrows` | `_handle_pip_calibration_key` | Resize on-screen PiP frame | `noise_meter_pip` offsets | Calibration active only |
| `PgUp` / `PgDn` | `_handle_pip_calibration_key` | Adjust calibration step size | `pip_runtime_calibration_step_px` | Calibration active only |
| `Alt` modifier | `_handle_pip_calibration_key` | Fine step (`1.0`) | calibration step logic | Calibration active only |
| `P` | `_handle_pip_calibration_key` -> `_print_pip_calibration_values` | Print current PiP calibration values to console | `print`, PiP fields | Calibration active or anytime after F8 path |

## C) UI Surfaces

### Dev-only HUD / dialogs / overlays

| Surface | Created in | How created / mounted | Invoke | Close / toggle |
|---|---|---|---|---|
| Dev HUD (`CanvasLayer` + labels) | `Scripts/systems/GameController.gd:762` `_install_hud` | `CanvasLayer.new()` + `RichTextLabel.new()` + `Label.new()` children added to autoload (`GameController`) | Auto in `_ready` (`_install_hud` + `_set_dev_hud_visible`) | `F1` / `_set_dev_hud_visible` |
| Dev hotkeys list labels | `Scripts/systems/GameController.gd:762`, expanded in `:2188` `_update_hud` | Runtime labels under dev HUD layer; dynamic column creation in `_update_hud` | Shown when dev HUD enabled | Hidden with dev HUD toggle |
| Dev event log label | `Scripts/systems/GameController.gd:797` `_install_hud` | `Label.new()` in dev HUD layer; text fed by `_log` / `_update_event_log_display` | Auto when dev logging + HUD enabled | Hidden with dev HUD toggle |
| Seed prompt dialog (`Load Seed`) | `Scripts/systems/GameController.gd:809` `_install_seed_prompt` | `AcceptDialog.new()` + `MarginContainer` + `Label` + `LineEdit`; child of `GameController` | `F6` (`dev_load_seed`) | Confirm/close (`_on_seed_dialog_confirmed`, `_on_seed_dialog_closed`) |
| Suspect import dialog (`Import Suspect JSON`) | `Scripts/systems/GameController.gd:2462` `_install_suspect_import_prompt` | `AcceptDialog.new()` + labels + `TextEdit`; child of `GameController` | `Ctrl+Shift+I` fallback when clipboard/last file invalid | Confirm/close (`_on_suspect_import_confirmed`, `_on_suspect_import_closed`) |
| Case Handling PiP calibration label | `Scripts/ui/CaseHandlingScene.gd:441` `_ensure_pip_calibration_ui` | `Label.new()` added to `CaseHandlingScene` root (`add_child`) | `F8` in Case Handling scene | `F8` toggles off |
| Case Handling PiP calibration capture overlay | `Scripts/ui/CaseHandlingScene.gd:740` `_draw` | Custom draw rect/crosshair when `_pip_calibration_active` | `F8` in Case Handling scene | `F8` toggles off |
| `DEV_TEST` overlay placeholder | `Scripts/systems/OverlayManager.gd:47` `open(id, payload)` | `Label.new()` under generic overlay panel when `id == "DEV_TEST"` | `open_overlay("DEV_TEST")` if called (not found in current runtime paths) | `close_overlay()` / `OverlayManager.close()` |

### Runtime-created UI found by scan but not dev-only (not primary inventory targets)

- `Scripts/systems/GameController.gd:1105` case transition black `CanvasLayer`/`ColorRect` (scene transition effect)
- `Scripts/systems/GameController.gd:1549` evidence dimmer + close button runtime patching
- `Scripts/systems/OverlayManager.gd:17` many gameplay overlays (`PHONE`, `COMPUTER_TERMINAL`, `VENT_EXIT`, `CASE_HANDLING`, etc.)

## D) Suggested Extraction Grouping (for future refactor only)

### 1) Input / Hotkeys

- `GameController._handle_dev_hotkeys`
- InputMap action mapping + raw-key fallbacks
- Case-specific hotkey routing (`CaseHandlingScene` calibration)
- Camera dev-ish edge-pan toggle logging split (`GameController`) vs actual action (`Camera`)

### 2) HUD / Debug UI

- Dev HUD install/update/visibility/log rendering
- Seed prompt dialog
- Suspect import dialog
- Overlay placeholder (`DEV_TEST`)

### 3) Sim Harness

- `dev/RevolverSim.gd`
- `Ctrl+Shift+T` runner + log formatting

### 4) Seed + Suspect IO

- Seed copy/load (`F6`, `F7`)
- Suspect export/import (`Ctrl+Shift+E/I`)
- `SuspectIO` JSON/fingerprint/file helpers (`Scripts/systems/SuspectIO.gd:52`, `:56`, `:62`, `:65`, `:82`, `:91`)

### 5) State Mutation Commands

- Revolver state mutation (live rounds, tier reload, add round)
- Danger penalties/reset
- Noise trigger injection / phone ring toggle / carryover flag
- Dev shot cinematic tests (`Ctrl+Shift+K/L`)

## E) Recommended Future `DevHarness` API (signatures only)

```gdscript
class_name DevHarness
extends RefCounted

func attach(context: Dictionary) -> void
func detach() -> void

func handle_input(event: InputEvent) -> bool
func handle_case_handling_input(event: InputEvent, case_scene: CaseHandlingScene) -> bool

func tick(delta: float) -> void
func refresh_hud() -> void
func set_hud_visible(visible: bool) -> void

func can_run(command: StringName) -> bool
func run_command(command: StringName, args: Dictionary = {}) -> bool

func open_seed_prompt() -> void
func open_suspect_import_prompt(prefill: String = "") -> void

func export_suspect() -> Dictionary
func import_suspect_from_clipboard_or_prompt() -> Dictionary

func apply_noise_trigger(id: StringName, meta: Dictionary = {}) -> void
func apply_danger(points: int, reason: String) -> int
func set_revolver_live_rounds(count: int) -> void
func set_revolver_tier_and_reload(tier: int) -> void

func run_revolver_sim(shots: int = 50) -> Dictionary
func request_dev_shot(will_boom: bool) -> bool
```

## Scene / Runtime Touch Map (consolidated)

- `Scenes/Game.tscn`
  - Nodes touched by dev tooling lookups/UI: `Revolver`, `Sound/NoiseMeter`, `Camera2D`, `HudRoot`, `EvidenceLogPanel`, `Vent`, `Folder`, `Computer`, `Computer/ComputerScreenWindow`, `CaseDrawer` (see `Game.tscn` node refs around `Scenes/Game.tscn:47`, `:72`, `:82`, `:86`, `:118`, `:121`, `:135`, `:181`, `:192`, `:229`, `:297`)
  - Dev HUD + dialogs mount under autoload `GameController` (runtime-added nodes)
- `Scenes/CaseHandlingScene.tscn`
  - PiP calibration hotkeys/UI overlay (`Scripts/ui/CaseHandlingScene.gd`)
  - `NoiseMeterPiP` frame manipulated during calibration
- `Scenes/ComputerTerminalOverlay.tscn`
  - Opened via `OverlayManager` for `COMPUTER_TERMINAL`
- `Scenes/VentExitScene.tscn`
  - Opened via `OverlayManager` for `VENT_EXIT`
- `Scenes/EndCardOverlay.tscn`
  - Opened via `OverlayManager` for `END_CARD`
- `Scenes/RevolverWidget.tscn`
  - Revolver state sync + dev shot cinematics operate on the instantiated `Revolver` widget in `Game.tscn`

## Key Dependency Definitions (supporting refs)

- `Scripts/systems/NoiseSystem.gd:163` `apply_trigger(id, meta)`
- `Scripts/systems/InterrogationTimePolicy.gd:56` `get_noise_trigger(id)`
- `Scripts/systems/NoiseTriggerDef.gd:8` `dev_only` metadata flag
- `content/policies/InterrogationTimePolicy_Default.tres:51` `dev_noise_spike` trigger (marked `dev_only = true` at `:54`)
- `Scripts/systems/PhoneSystem.gd:28` `toggle_dev()`
- `Scripts/systems/Camera.gd:30` actual `toggle_edge_pan` action consumption
- `dev/RevolverSim.gd:4` `run(seed_u64, shots, _tier)`
