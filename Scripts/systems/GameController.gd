extends Node

enum AppState { BOOT, TITLE, MENU, GAME }
enum RunState { IDLE, OVERLAY, SUSPECT_ACTIVE, VERDICT_PENDING, OUTCOME }
var app_state: int = AppState.BOOT
var run_state: int = RunState.IDLE
var run_seed_value: int = 0
var run_seed_text: String = ""
var forced_seed_text: String = ""

var overlay_open: bool = false
var overlay_id: String = ""

@export var dev_hud_enabled: bool = true
@export var dev_allow_escape_hatch: bool = true
@export var dev_quit_requires_shift: bool = true
@export var dev_log_enabled: bool = true
@export var dev_log_inputs: bool = false
@export var dev_log_state_changes: bool = true
@export var dev_log_overlays: bool = true

var _hud_layer: CanvasLayer
var _hud_label: Label
var _last_logged_app_state: int = -1
var _last_logged_run_state: int = -1
var _last_logged_overlay_open: bool = false
var _last_logged_overlay_id: String = ""

const DEV_HUD_LAYER_NAME: StringName = &"DevHUD"
const DEV_HUD_LABEL_NAME: StringName = &"DevLabel"

const GROUP_UI_GAME: StringName = &"ui_game"
const GROUP_UI_MENU: StringName = &"ui_menu"
const GROUP_INPUT_UI: StringName = &"input_ui"
const GROUP_INPUT_WORLD: StringName = &"input_world"

var _policy_last_state: int = -1
var _policy_last_overlay_open: bool = false
var _overlay_manager: Node
var _seed_dialog: AcceptDialog
var _seed_line: LineEdit
var _seed_label: Label
var _seed_container: MarginContainer
var _seed_ok_button: Button

func _ready() -> void:
	_overlay_manager = preload("res://Scripts/systems/OverlayManager.gd").new()
	_overlay_manager.name = &"OverlayManager"
	add_child(_overlay_manager)
	_init_seed()
	_install_hud()
	_install_seed_prompt()
	_set_dev_hud_visible(dev_hud_enabled)
	_cleanup_duplicate_hud_labels()
	_update_app_state()
	_apply_state_policy("ready")
	_update_hud()
	_log("GameController ready")

func _process(_delta: float) -> void:
	_update_app_state()
	_update_hud()

func _input(event: InputEvent) -> void:
	if get_viewport().is_input_handled():
		return
	if _handle_dev_hotkeys(event):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _handle_dev_hotkeys(event):
		get_viewport().set_input_as_handled()
		return

func _handle_dev_hotkeys(event: InputEvent) -> bool:
	if dev_allow_escape_hatch and event.is_action_pressed("ui_cancel"):
		if overlay_open:
			close_overlay()
			return true

		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			_exit_fullscreen_to_windowed()
			_log("ESC: fullscreen -> windowed")
			return true

		if dev_quit_requires_shift:
			var key_event := event as InputEventKey
			if key_event != null and key_event.shift_pressed:
				_log("ESC: quit")
				get_tree().quit()
				return true
			return true
		else:
			_log("ESC: quit")
			get_tree().quit()
			return true

	var wants_toggle := false
	if InputMap.has_action("dev_toggle_hud") and event.is_action_pressed("dev_toggle_hud"):
		wants_toggle = true
	if InputMap.has_action("dev_toggle") and event.is_action_pressed("dev_toggle"):
		wants_toggle = true

	if wants_toggle:
		dev_hud_enabled = !dev_hud_enabled
		_set_dev_hud_visible(dev_hud_enabled)
		_update_hud()
		_log("HOTKEY F1 dev_toggle -> HUD %s" % ("ON" if dev_hud_enabled else "OFF"))
		return true

	if InputMap.has_action("dev_next_suspect") and event.is_action_pressed("dev_next_suspect"):
		_log("HOTKEY F2 dev_next_suspect (not implemented yet)")
		return true

	if InputMap.has_action("dev_load_seed") and event.is_action_pressed("dev_load_seed"):
		_log("HOTKEY F6 dev_load_seed")
		_open_seed_prompt()
		return true

	if InputMap.has_action("dev_seed_copy") and event.is_action_pressed("dev_seed_copy"):
		DisplayServer.clipboard_set(run_seed_text)
		_log("HOTKEY F7 dev_seed_copy -> %s" % run_seed_text)
		return true

	if InputMap.has_action("dev_seed_reload_clipboard") and event.is_action_pressed("dev_seed_reload_clipboard"):
		_log("HOTKEY F8 dev_seed_reload_clipboard")
		var raw := DisplayServer.clipboard_get()
		var parsed := _seed_parse(raw)
		if parsed >= 0:
			forced_seed_text = _seed_format(parsed)
			_log("SEED OVERRIDE -> %s" % forced_seed_text)
			_init_seed()
			_reset_run_state()
			return true
		_open_seed_prompt()
		return true

	if InputMap.has_action("dev_force_verdict") and event.is_action_pressed("dev_force_verdict"):
		_log("HOTKEY F3 dev_force_verdict (not implemented yet)")
		return false

	if InputMap.has_action("toggle_edge_pan") and event.is_action_pressed("toggle_edge_pan"):
		_log("HOTKEY F4 toggle_edge_pan (not implemented here)")
		return false

	return false

func open_overlay(id: String) -> void:
	overlay_open = true
	overlay_id = id
	if _overlay_manager != null:
		_overlay_manager.call("open", id)
	set_run_state(RunState.OVERLAY)
	if dev_log_overlays:
		_log("OVERLAY open: %s" % id)
	_apply_overlay_lock(true)
	_apply_state_policy("overlay")

func close_overlay() -> void:
	if _overlay_manager != null:
		_overlay_manager.call("close")
	overlay_open = false
	overlay_id = ""
	set_run_state(RunState.IDLE)
	if dev_log_overlays:
		_log("OVERLAY close")
	_apply_overlay_lock(false)
	_apply_state_policy("overlay")

func is_overlay_open() -> bool:
	return overlay_open

func _update_app_state() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		if app_state != AppState.BOOT:
			var old_state := app_state
			app_state = AppState.BOOT
			if dev_log_state_changes:
				_log("STATE -> %s" % _state_name(app_state))
			_on_app_state_changed(old_state, app_state)
		return

	var n := scene.name
	var new_state := AppState.MENU
	if n == "Game":
		new_state = AppState.GAME
	elif "Title" in n:
		new_state = AppState.TITLE
	elif "Boot" in n:
		new_state = AppState.BOOT

	if new_state != app_state:
		var old_state := app_state
		app_state = new_state
		if dev_log_state_changes:
			_log("STATE -> %s" % _state_name(app_state))
		_on_app_state_changed(old_state, app_state)

func set_run_state(new_state: int) -> void:
	if new_state == run_state:
		return
	run_state = new_state
	if dev_log_state_changes:
		_log("RUN -> %s" % _run_state_name(run_state))

func _on_app_state_changed(_from_state: int, _to_state: int) -> void:
	if overlay_open:
		close_overlay()
	_apply_state_policy("state")

func _apply_state_policy(reason: String) -> void:
	if _policy_last_state == app_state and _policy_last_overlay_open == overlay_open:
		return

	_policy_last_state = app_state
	_policy_last_overlay_open = overlay_open

	var in_game := app_state == AppState.GAME
	var world_input := in_game and not overlay_open
	var ui_input := not overlay_open

	_set_group_visible(GROUP_UI_GAME, in_game)
	_set_group_visible(GROUP_UI_MENU, not in_game)
	_set_group_input_enabled(GROUP_INPUT_WORLD, world_input)
	_set_group_input_enabled(GROUP_INPUT_UI, ui_input)

	if dev_log_state_changes:
		_log("POLICY (%s): in_game=%s overlay=%s world_input=%s ui_input=%s" % [reason, str(in_game), str(overlay_open), str(world_input), str(ui_input)])

func _set_group_visible(group_name: StringName, visible: bool) -> void:
	var nodes := get_tree().get_nodes_in_group(group_name)
	for n in nodes:
		if n is CanvasItem:
			(n as CanvasItem).visible = visible

func _set_group_input_enabled(group_name: StringName, enabled: bool) -> void:
	var nodes := get_tree().get_nodes_in_group(group_name)
	for n in nodes:
		if n == null:
			continue

		if n is Control:
			var c := n as Control
			if enabled:
				if c.has_meta("__prev_mouse_filter"):
					c.mouse_filter = int(c.get_meta("__prev_mouse_filter"))
					c.remove_meta("__prev_mouse_filter")
			else:
				if not c.has_meta("__prev_mouse_filter"):
					c.set_meta("__prev_mouse_filter", c.mouse_filter)
				c.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if n is CollisionObject2D:
			var co := n as CollisionObject2D
			if enabled:
				if co.has_meta("__prev_pickable"):
					co.input_pickable = bool(co.get_meta("__prev_pickable"))
					co.remove_meta("__prev_pickable")
			else:
				if not co.has_meta("__prev_pickable"):
					co.set_meta("__prev_pickable", co.input_pickable)
				co.input_pickable = false

		if n.has_method("set_process_input"):
			n.set_process_input(enabled)
		if n.has_method("set_process_unhandled_input"):
			n.set_process_unhandled_input(enabled)

		if n.has_method("set_input_enabled"):
			n.call("set_input_enabled", enabled)

func _install_hud() -> void:
	if is_instance_valid(_hud_layer):
		return

	_hud_layer = CanvasLayer.new()
	_hud_layer.name = DEV_HUD_LAYER_NAME
	_hud_layer.layer = 100
	add_child(_hud_layer)

	_hud_label = Label.new()
	_hud_label.name = DEV_HUD_LABEL_NAME
	_hud_label.position = Vector2(12, 12)
	_hud_layer.add_child(_hud_label)

func _install_seed_prompt() -> void:
	if is_instance_valid(_seed_dialog):
		return

	_seed_dialog = AcceptDialog.new()
	_seed_dialog.title = "Load Seed"
	_seed_dialog.exclusive = true
	_seed_dialog.min_size = Vector2(560, 180)
	_seed_dialog.close_requested.connect(_on_seed_dialog_closed)
	_seed_dialog.confirmed.connect(_on_seed_dialog_confirmed)
	add_child(_seed_dialog)

	_seed_container = MarginContainer.new()
	_seed_container.add_theme_constant_override("margin_left", 12)
	_seed_container.add_theme_constant_override("margin_right", 12)
	_seed_container.add_theme_constant_override("margin_top", 12)
	_seed_container.add_theme_constant_override("margin_bottom", 12)
	_seed_dialog.add_child(_seed_container)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_seed_container.add_child(vbox)

	_seed_label = Label.new()
	_seed_label.text = "Current: "
	vbox.add_child(_seed_label)

	_seed_line = LineEdit.new()
	_seed_line.placeholder_text = "K11-XXXX or digits"
	_seed_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_line.text_changed.connect(_on_seed_line_text_changed)
	vbox.add_child(_seed_line)

	_seed_ok_button = _seed_dialog.get_ok_button()
	_update_seed_ok_button()

func _open_seed_prompt() -> void:
	if not is_instance_valid(_seed_dialog):
		_install_seed_prompt()
	var clipboard_text := DisplayServer.clipboard_get()
	var parsed_clipboard := _seed_parse(clipboard_text)
	if parsed_clipboard >= 0:
		_seed_line.text = _seed_format(parsed_clipboard)
	else:
		_seed_line.text = run_seed_text
	_seed_label.text = "Current: %s" % get_seed_display()
	_update_seed_ok_button()
	_seed_dialog.popup_centered(Vector2i(560, 180))
	call_deferred("_seed_prompt_focus")

func _on_seed_dialog_confirmed() -> void:
	var raw := _seed_line.text
	if raw.strip_edges() == "":
		return
	var parsed := _seed_parse(raw)
	if parsed < 0:
		return
	forced_seed_text = _seed_format(parsed)
	_log("SEED OVERRIDE -> %s" % forced_seed_text)
	_init_seed()
	_reset_run_state()

func _on_seed_dialog_closed() -> void:
	if is_instance_valid(_seed_line):
		_seed_line.text = ""
	_update_seed_ok_button()

func _on_seed_line_text_changed(_text: String) -> void:
	_update_seed_ok_button()

func _seed_prompt_focus() -> void:
	if is_instance_valid(_seed_line):
		_seed_line.grab_focus()
		_seed_line.select_all()

func _update_seed_ok_button() -> void:
	if is_instance_valid(_seed_ok_button) and is_instance_valid(_seed_line):
		_seed_ok_button.disabled = _seed_line.text.strip_edges() == ""

func _set_dev_hud_visible(visible: bool) -> void:
	if visible and not is_instance_valid(_hud_layer):
		_install_hud()

	if is_instance_valid(_hud_layer):
		_hud_layer.visible = visible
	if is_instance_valid(_hud_label):
		_hud_label.visible = visible

	var root := get_tree().root
	if root == null:
		return

	for layer in root.find_children(String(DEV_HUD_LAYER_NAME), "CanvasLayer", true, false):
		if layer != _hud_layer and layer is CanvasLayer:
			(layer as CanvasLayer).visible = visible

	for label in root.find_children(String(DEV_HUD_LABEL_NAME), "Label", true, false):
		if label != _hud_label and label is Label:
			(label as Label).visible = visible

func _update_hud() -> void:
	if not dev_hud_enabled:
		return
	if not is_instance_valid(_hud_label):
		return

	_cleanup_duplicate_hud_labels()

	var overlay_text := overlay_id if overlay_open else "none"
	_hud_label.text = "STATE: %s\nRUN: %s\nOVERLAY: %s\nHOTKEYS:\nF8 SeedFromClip\nF7 CopySeed\nF6 LoadSeed\nF4 EdgePan\nF3 Verdict?\nF2 Next?\nF1 HUD" % [_state_name(app_state), _run_state_name(run_state), overlay_text]

	if dev_log_state_changes and run_state != _last_logged_run_state:
		_last_logged_run_state = run_state
		_log("RUN -> %s" % _run_state_name(run_state))

	if dev_log_overlays and (overlay_open != _last_logged_overlay_open or overlay_id != _last_logged_overlay_id):
		_last_logged_overlay_open = overlay_open
		_last_logged_overlay_id = overlay_id

func _cleanup_duplicate_hud_labels() -> void:
	var root := get_tree().root
	if root == null:
		return
	if not is_instance_valid(_hud_layer):
		return

	if not is_instance_valid(_hud_label):
		for label in _hud_layer.find_children(String(DEV_HUD_LABEL_NAME), "Label", true, false):
			if label is Label:
				_hud_label = label as Label
				break
	if not is_instance_valid(_hud_label):
		return
	_hud_label.visible = dev_hud_enabled

	for label in root.find_children(String(DEV_HUD_LABEL_NAME), "Label", true, false):
		if label is Label and label != _hud_label:
			var other := label as Label
			other.visible = false

func _log(msg: String) -> void:
	if not dev_log_enabled:
		return
	print("[K11] %s %s" % [str(Time.get_ticks_msec()), msg])

func _state_name(s: int) -> String:
	match s:
		AppState.BOOT: return "BOOT"
		AppState.TITLE: return "TITLE"
		AppState.MENU: return "MENU"
		AppState.GAME: return "GAME"
		_: return "UNKNOWN"

func _run_state_name(s: int) -> String:
	match s:
		RunState.IDLE: return "IDLE"
		RunState.OVERLAY: return "OVERLAY"
		RunState.SUSPECT_ACTIVE: return "SUSPECT_ACTIVE"
		RunState.VERDICT_PENDING: return "VERDICT_PENDING"
		RunState.OUTCOME: return "OUTCOME"
		_: return "UNKNOWN"

func _exit_fullscreen_to_windowed() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var target_size := Vector2i(1280, 720)
	DisplayServer.window_set_size(target_size)

	var screen_size := DisplayServer.screen_get_size()
	var pos := (screen_size - target_size) / 2
	DisplayServer.window_set_position(pos)

func _apply_overlay_lock(is_open: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	var cams := scene.find_children("", "Camera2D", true, false)
	for cam in cams:
		if cam != null and cam.has_method("set_overlay_open"):
			cam.call("set_overlay_open", is_open)

func _reset_run_state() -> void:
	if overlay_open:
		close_overlay()
	run_state = RunState.IDLE
	_apply_state_policy("seed")
	_update_hud()

func _init_seed() -> void:
	var seed_value := 0
	var has_seed := false
	if forced_seed_text != "":
		var forced_parsed := _seed_parse(forced_seed_text)
		if forced_parsed >= 0:
			seed_value = forced_parsed
			has_seed = true
	else:
		for arg in OS.get_cmdline_args():
			if arg.begins_with("--seed="):
				var cmd_value := _seed_parse(arg.substr(7))
				if cmd_value >= 0:
					seed_value = cmd_value
					has_seed = true
				break

	if not has_seed:
		seed_value = int(Time.get_ticks_msec())

	run_seed_value = seed_value
	run_seed_text = _seed_format(seed_value)
	_log("SEED = %s (%d)" % [run_seed_text, run_seed_value])

func _seed_format(v: int) -> String:
	if v < 0:
		v = -v
	return "K11-%s" % _to_base36(v)

func _seed_parse(s: String) -> int:
	var text := s.strip_edges()
	if text == "":
		return -1

	var upper := text.to_upper()
	if upper.begins_with("K11-"):
		var suffix := text.substr(4).strip_edges()
		if suffix == "":
			return -1
		return _from_base36(suffix)

	var digits_only := true
	for i in text.length():
		var ch := text[i]
		if ch < "0" or ch > "9":
			digits_only = false
			break
	if digits_only:
		return int(text)
	return -1

func get_seed_display() -> String:
	return "%s (%d)" % [run_seed_text, run_seed_value]

func _to_base36(v: int) -> String:
	if v == 0:
		return "0"
	var chars := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var value := v
	var result := ""
	while value > 0:
		var idx := value % 36
		result = chars[idx] + result
		value = int(value / 36)
	return result

func _from_base36(s: String) -> int:
	var chars := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var value := 0
	var upper := s.strip_edges().to_upper()
	for i in upper.length():
		var ch := upper[i]
		var idx := chars.find(ch)
		if idx < 0:
			return -1
		value = value * 36 + idx
	return value
