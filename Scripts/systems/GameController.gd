extends Node

enum AppState { BOOT, TITLE, MENU, GAME }
enum RunState { IDLE, OVERLAY, SUSPECT_ACTIVE, VERDICT_PENDING, OUTCOME }
var app_state: int = AppState.BOOT
var run_state: int = RunState.IDLE
var run_seed_value: int = 0
var run_seed_text: String = ""
var forced_seed_text: String = ""
const SeedUtil := preload("res://Scripts/systems/SeedUtil.gd")
const SuspectIO := preload("res://Scripts/systems/SuspectIO.gd")
const SuspectFactory := preload("res://Scripts/systems/SuspectFactory.gd")
const SuspectData := preload("res://Scripts/systems/SuspectData.gd")
var run_seed_u64: int = 0
var suspect_index: int = 0
var suspect_seed_value: int = 0
var suspect_seed_text: String = ""
var current_suspect: SuspectData = null
# --- Evidence UI (5.2) ---
var _tabs_bar: Node = null
var _evidence_panel: Control = null
var _evidence_dimmer: ColorRect = null
var _evidence_active_tab: String = ""
const OVERLAY_EVIDENCE_ID := "EVIDENCE"
const OVERLAY_CASE_FOLDER_ID := "CASE_FOLDER"
var _case_folder: Sprite2D = null
var _case_folder_base_modulate: Color = Color(1, 1, 1, 1)
var _case_folder_image: Image = null
var _case_folder_image_size: Vector2i = Vector2i.ZERO
var _case_folder_outline: Node = null
var _case_folder_hover: bool = false
var _pending_verdict_id: String = ""
var _verdict_buttons: Array[Button] = []
var _verdict_committed: bool = false
var _verdict_choice: String = ""
var _verdict_overlay: Node = null
var _last_verdict: String = ""
var _last_truth_guilty: bool = false
var _last_verdict_correct: bool = false
var _punishment_pending: bool = false
var _pending_run_fail: bool = false
var _scapegoat_count: int = 0

var overlay_open: bool = false
var overlay_id: String = ""

@export var dev_hud_enabled: bool = true
@export var dev_allow_escape_hatch: bool = true
@export var dev_quit_requires_shift: bool = true
@export var dev_log_enabled: bool = true
@export var dev_log_inputs: bool = false
@export var dev_log_state_changes: bool = true
@export var dev_log_overlays: bool = true
@export var dev_allow_suspect_io: bool = true
@export var dev_enable_scapegoat: bool = true

var _hud_layer: CanvasLayer
var _hud_label: Label
var _hud_hotkeys_label: Label
var _hud_event_log_label: Label
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
var _suspect_import_dialog: AcceptDialog
var _suspect_import_text: TextEdit
var _suspect_import_label: Label
var _suspect_import_error_label: Label
var _suspect_import_hint_label: Label
var _suspect_import_prev_hud_visible: bool = false
var _last_import_prompt_time_msec: int = 0
var _camera_node: Camera2D
var _camera_missing_logged: bool = false
var _hud_refresh_accum: float = 0.0
const HUD_REFRESH_INTERVAL: float = 0.1
var _dev_event_log: Array[String] = []
const DEV_EVENT_LOG_MAX: int = 50
const DEV_EVENT_LOG_VISIBLE: int = 12
const DEV_EVENT_LOG_LINE_HEIGHT: float = 14.0
const DEV_EVENT_LOG_WIDTH: float = 520.0
var _event_log_visible_lines: int = DEV_EVENT_LOG_VISIBLE
var _last_toggle_edge_pan_event_id: int = 0
var _last_force_verdict_event_id: int = 0
var _seed_prompt_prev_hud_visible: bool = false
var _pending_seed_reload: bool = false
var _pending_seed_text: String = ""

func _ready() -> void:
	_overlay_manager = preload("res://Scripts/systems/OverlayManager.gd").new()
	_overlay_manager.name = &"OverlayManager"
	_overlay_manager.call("set_controller", self)
	add_child(_overlay_manager)
	_init_seed()
	_install_hud()
	_init_verdict_flow_ui()
	_install_seed_prompt()
	_set_dev_hud_visible(dev_hud_enabled)
	_cleanup_duplicate_hud_labels()
	_cache_camera()
	_update_app_state()
	_apply_state_policy("ready")
	_cache_case_folder()
	_update_hud()
	_log("GameController ready")

func _process(_delta: float) -> void:
	_update_app_state()
	if _pending_seed_reload:
		_pending_seed_reload = false
		if _pending_seed_text == forced_seed_text:
			_log("SEED RELOAD skipped (same seed)")
		else:
			forced_seed_text = _pending_seed_text
			_log("SEED OVERRIDE -> %s" % forced_seed_text)
			_init_seed()
			_reset_run_state()
	if dev_hud_enabled:
		_hud_refresh_accum += _delta
		if _hud_refresh_accum >= HUD_REFRESH_INTERVAL:
			_hud_refresh_accum = 0.0
			_update_hud()

	if app_state == AppState.GAME and not overlay_open:
		if _case_folder == null:
			_cache_case_folder()
		if _camera_node == null:
			_cache_camera()
		if _case_folder != null and _camera_node != null:
			var mouse_world: Vector2 = _camera_node.get_global_mouse_position()
			_case_folder_hover = _is_mouse_over_case_folder(mouse_world)
			if _case_folder_outline is CanvasItem:
				(_case_folder_outline as CanvasItem).visible = _case_folder_hover
			if not _case_folder_hover:
				_clear_folder_highlight()

func _input(event: InputEvent) -> void:
	if get_viewport().is_input_handled():
		return
	if is_instance_valid(_suspect_import_dialog) and _suspect_import_dialog.visible:
		return
	if _handle_dev_hotkeys(event):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_suspect_import_dialog) and _suspect_import_dialog.visible:
		return
	if _handle_dev_hotkeys(event):
		get_viewport().set_input_as_handled()
		return

	if app_state != AppState.GAME:
		return
	if overlay_open:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _camera_node == null:
				_cache_camera()
			if _case_folder == null:
				_cache_case_folder()
			if _camera_node == null:
				return
			var mouse_world: Vector2 = _camera_node.get_global_mouse_position()
			if _is_mouse_over_case_folder(mouse_world):
				var payload := _build_case_folder_payload()
				open_overlay(OVERLAY_CASE_FOLDER_ID, payload)
				get_viewport().set_input_as_handled()

func _handle_dev_hotkeys(event: InputEvent) -> bool:
	if dev_allow_escape_hatch and event.is_action_pressed("ui_cancel"):
		if overlay_open:
			close_overlay()
			return true

		var mode: int = DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			_exit_fullscreen_to_windowed()
			_log("ESC: fullscreen -> windowed")
			return true

		if dev_quit_requires_shift:
			var key_event: InputEventKey = event as InputEventKey
			if key_event != null and key_event.shift_pressed:
				_log("ESC: quit")
				get_tree().quit()
				return true
			return true
		else:
			_log("ESC: quit")
			get_tree().quit()
			return true

	var wants_toggle: bool = false
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
		if overlay_open and (overlay_id == OVERLAY_EVIDENCE_ID or overlay_id == "VERDICT_RESULT"):
			close_overlay()
		_advance_to_next_suspect()
		var sid: String = current_suspect.short_id() if current_suspect != null else "n/a"
		var t: String = current_suspect.truth_label() if current_suspect != null else "n/a"
		_log("HOTKEY F2 dev_next_suspect -> idx=%d seed=%s id=%s truth=%s" % [suspect_index, suspect_seed_text, sid, t])
		_update_hud()
		return true

	if InputMap.has_action("dev_load_seed") and event.is_action_pressed("dev_load_seed"):
		_log("HOTKEY F6 dev_load_seed")
		_open_seed_prompt()
		return true

	if InputMap.has_action("dev_seed_copy") and event.is_action_pressed("dev_seed_copy"):
		DisplayServer.clipboard_set(run_seed_text)
		_log("HOTKEY F7 dev_seed_copy -> %s" % run_seed_text)
		return true

	if InputMap.has_action("dev_end_game") and event.is_action_pressed("dev_end_game"):
		var k_end: InputEventKey = event as InputEventKey
		if k_end != null and k_end.pressed and not k_end.echo and k_end.keycode == KEY_F12:
			_log("HOTKEY F12 dev_end_game -> quit")
			get_tree().quit()
			return true
		return false

	if InputMap.has_action("dev_force_verdict") and event.is_action_pressed("dev_force_verdict"):
		var event_id: int = event.get_instance_id()
		if event_id != _last_force_verdict_event_id:
			_last_force_verdict_event_id = event_id
			_log("HOTKEY F3 dev_force_verdict (not implemented yet)")
		return false

	if InputMap.has_action("toggle_edge_pan") and event.is_action_pressed("toggle_edge_pan"):
		var event_id: int = event.get_instance_id()
		if event_id != _last_toggle_edge_pan_event_id:
			_last_toggle_edge_pan_event_id = event_id
			_log("HOTKEY F4 toggle_edge_pan")
		return false

	if dev_allow_suspect_io and event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k != null and k.pressed and not k.echo:
			if k.keycode == KEY_F9:
				_log("HOTKEY F9: use Ctrl+Shift+I for suspect import (F9 is not bound).")
				return true
			if k.keycode == KEY_F8:
				_log("HOTKEY F8: do not use in-editor (Godot stops play). Use Ctrl+Shift+E for export.")
				return true
			# Editor-safe dev hotkeys (avoid F8 stop, F9 play bindings)
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_E:
				_dev_export_suspect()
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_I:
				_dev_import_suspect_clipboard_or_prompt()
				return true

	return false

func open_overlay(id: String, payload: Dictionary = {}) -> void:
	overlay_open = true
	overlay_id = id
	if id != "VERDICT_RESULT" and _overlay_manager != null:
		_overlay_manager.call("open", id, payload)
	set_run_state(RunState.OVERLAY)
	if dev_log_overlays:
		_log("OVERLAY open: %s" % id)
	_apply_overlay_lock(true)
	_apply_state_policy("overlay")

func close_overlay() -> void:
	if overlay_id == OVERLAY_EVIDENCE_ID:
		_hide_evidence_overlay()
	elif overlay_id == "VERDICT_RESULT":
		if _verdict_overlay != null and _verdict_overlay.has_method("hide_overlay"):
			_verdict_overlay.call("hide_overlay")
	else:
		if _overlay_manager != null:
			_overlay_manager.call("close")
	overlay_open = false
	overlay_id = ""
	_clear_folder_highlight()
	set_run_state(RunState.IDLE)
	if dev_log_overlays:
		_log("OVERLAY close")
	_apply_overlay_lock(false)
	_apply_state_policy("overlay")

func is_overlay_open() -> bool:
	return overlay_open

func _update_app_state() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		if app_state != AppState.BOOT:
			var old_state: int = app_state
			app_state = AppState.BOOT
			if dev_log_state_changes:
				_log("STATE -> %s" % _state_name(app_state))
			_on_app_state_changed(old_state, app_state)
		return

	var n: String = scene.name
	var new_state: int = AppState.MENU
	if n == "Game":
		new_state = AppState.GAME
	elif "Title" in n:
		new_state = AppState.TITLE
	elif "Boot" in n:
		new_state = AppState.BOOT

	if new_state != app_state:
		var old_state: int = app_state
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
	if _to_state == AppState.GAME:
		_cache_camera()
		_cache_evidence_ui()
		_hide_evidence_overlay()
		_cache_case_folder()
		_init_verdict_flow_ui()
	_apply_state_policy("state")

func _apply_state_policy(reason: String) -> void:
	if _policy_last_state == app_state and _policy_last_overlay_open == overlay_open:
		return

	_policy_last_state = app_state
	_policy_last_overlay_open = overlay_open

	var in_game: bool = app_state == AppState.GAME
	var evidence_open: bool = overlay_open and overlay_id == OVERLAY_EVIDENCE_ID
	var world_input: bool = in_game and not overlay_open
	var ui_input: bool = not overlay_open or evidence_open

	_set_group_visible(GROUP_UI_GAME, in_game)
	_set_group_visible(GROUP_UI_MENU, not in_game)
	_set_group_input_enabled(GROUP_INPUT_WORLD, world_input)
	_set_group_input_enabled(GROUP_INPUT_UI, ui_input)

	if dev_log_state_changes:
		_log("POLICY (%s): in_game=%s overlay=%s world_input=%s ui_input=%s" % [reason, str(in_game), str(overlay_open), str(world_input), str(ui_input)])

func _set_group_visible(group_name: StringName, visible: bool) -> void:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
	for n in nodes:
		if n is CanvasItem:
			(n as CanvasItem).visible = visible

func _set_group_input_enabled(group_name: StringName, enabled: bool) -> void:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
	for n in nodes:
		if n == null:
			continue

		if n is Control:
			var c: Control = n as Control
			if enabled:
				if c.has_meta("__prev_mouse_filter"):
					c.mouse_filter = int(c.get_meta("__prev_mouse_filter"))
					c.remove_meta("__prev_mouse_filter")
			else:
				if not c.has_meta("__prev_mouse_filter"):
					c.set_meta("__prev_mouse_filter", c.mouse_filter)
				c.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if n is CollisionObject2D:
			var co: CollisionObject2D = n as CollisionObject2D
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
	_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_hud_label)

	_hud_hotkeys_label = Label.new()
	_hud_hotkeys_label.name = &"DevHotkeys"
	_hud_hotkeys_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_hud_hotkeys_label)

	_hud_event_log_label = Label.new()
	_hud_event_log_label.name = &"DevEventLogLabel"
	_hud_event_log_label.z_index = 1
	_hud_event_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_event_log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_event_log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_hud_event_log_label.clip_text = true
	_hud_event_log_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hud_layer.add_child(_hud_event_log_label)

func _install_seed_prompt() -> void:
	if is_instance_valid(_seed_dialog):
		return

	_seed_dialog = AcceptDialog.new()
	_seed_dialog.title = "Load Seed"
	_seed_dialog.exclusive = true
	_seed_dialog.always_on_top = true
	_seed_dialog.transient = true
	_seed_dialog.unresizable = true
	_seed_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_seed_dialog.set_process_input(true)
	_seed_dialog.set_process_unhandled_input(true)
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

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_seed_container.add_child(vbox)

	_seed_label = Label.new()
	_seed_label.text = "Current: "
	_seed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_seed_label)

	_seed_line = LineEdit.new()
	_seed_line.placeholder_text = "K11-XXXX or digits"
	_seed_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_line.mouse_filter = Control.MOUSE_FILTER_STOP
	_seed_line.text_changed.connect(_on_seed_line_text_changed)
	vbox.add_child(_seed_line)

	_seed_ok_button = _seed_dialog.get_ok_button()
	_update_seed_ok_button()

func _open_seed_prompt() -> void:
	if not is_instance_valid(_seed_dialog):
		_install_seed_prompt()
	_seed_prompt_prev_hud_visible = dev_hud_enabled
	if dev_hud_enabled:
		_set_dev_hud_visible(false)
	var clipboard_text: String = DisplayServer.clipboard_get()
	var parsed_clipboard: int = _seed_parse(clipboard_text)
	if parsed_clipboard >= 0:
		_seed_line.text = _seed_format(parsed_clipboard)
	else:
		_seed_line.text = run_seed_text
	_seed_label.text = "Current: %s" % get_seed_display()
	_update_seed_ok_button()
	_seed_dialog.popup_centered(Vector2i(560, 180))
	call_deferred("_seed_prompt_focus")

func _on_seed_dialog_confirmed() -> void:
	var raw: String = _seed_line.text
	if raw.strip_edges() == "":
		if _seed_prompt_prev_hud_visible:
			_set_dev_hud_visible(true)
		return
	var parsed: int = _seed_parse(raw)
	if parsed < 0:
		return
	_request_seed_reload(_seed_format(parsed))
	if _seed_prompt_prev_hud_visible:
		_set_dev_hud_visible(true)

func _on_seed_dialog_closed() -> void:
	if is_instance_valid(_seed_line):
		_seed_line.text = ""
	_update_seed_ok_button()
	if _seed_prompt_prev_hud_visible:
		_set_dev_hud_visible(true)

func _on_seed_line_text_changed(_text: String) -> void:
	_update_seed_ok_button()

func _seed_prompt_focus() -> void:
	if is_instance_valid(_seed_line):
		_seed_line.grab_focus()
		_seed_line.select_all()

func _update_seed_ok_button() -> void:
	if is_instance_valid(_seed_ok_button) and is_instance_valid(_seed_line):
		_seed_ok_button.disabled = _seed_line.text.strip_edges() == ""

func _cache_camera() -> void:
	if is_instance_valid(_camera_node):
		return
	var root: Node = get_tree().current_scene
	if root == null:
		return
	_camera_node = root.find_child("Camera2D", true, false) as Camera2D
	if _camera_node == null and not _camera_missing_logged:
		_camera_missing_logged = true
		_log("CAMERA: n/a (Camera2D not found in current scene)")
	elif _camera_node != null:
		_camera_missing_logged = false

func _cache_evidence_ui() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return

	_tabs_bar = root.find_child("TabsBar", true, false)
	if _tabs_bar != null and _tabs_bar.has_signal("tab_changed"):
		var cb := Callable(self, "_on_tabs_bar_tab_changed")
		if not _tabs_bar.is_connected("tab_changed", cb):
			_tabs_bar.connect("tab_changed", cb)

	_evidence_panel = root.find_child("EvidenceLogPanel", true, false) as Control
	if _evidence_panel == null:
		_log("EVIDENCE: n/a (EvidenceLogPanel node not found)")
		return

	# Hide by default (only visible on tab click)
	_evidence_panel.visible = false
	if _evidence_panel.has_method("set"):
		_evidence_panel.set("debug_force_visible", false)
	_evidence_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_evidence_panel.z_index = 2000

	# Ensure we have a dimmer behind it that blocks clicks
	var parent := _evidence_panel.get_parent()
	if parent is Control:
		_evidence_dimmer = (parent as Control).get_node_or_null("EvidenceDimmer") as ColorRect
		if _evidence_dimmer == null:
			_evidence_dimmer = ColorRect.new()
			_evidence_dimmer.name = "EvidenceDimmer"
			_evidence_dimmer.color = Color(0, 0, 0, 0.55)
			_evidence_dimmer.visible = false
			_evidence_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			(parent as Control).add_child(_evidence_dimmer)
			var panel_index: int = (parent as Control).get_children().find(_evidence_panel)
			if panel_index >= 0:
				(parent as Control).move_child(_evidence_dimmer, panel_index)

			_evidence_dimmer.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
					if overlay_open and overlay_id == OVERLAY_EVIDENCE_ID:
						close_overlay()
			)

		_evidence_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_evidence_dimmer.offset_left = 0
		_evidence_dimmer.offset_top = 0
		_evidence_dimmer.offset_right = 0
		_evidence_dimmer.offset_bottom = 0
		_evidence_dimmer.visible = false
		_evidence_dimmer.z_index = 1999

	# Force the panel to behave like a centered popup (no .tscn edits)
	_evidence_panel.set_anchors_preset(Control.PRESET_CENTER)
	_evidence_panel.offset_left = -260
	_evidence_panel.offset_top = -140
	_evidence_panel.offset_right = 260
	_evidence_panel.offset_bottom = 140
	if _evidence_panel.has_method("clear"):
		_evidence_panel.call("clear")

	var close_button := _evidence_panel.get_node_or_null("EvidenceClose") as Button
	if close_button == null:
		close_button = Button.new()
		close_button.name = "EvidenceClose"
		close_button.text = "X"
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP
		close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		close_button.anchor_right = 1.0
		close_button.offset_left = -32
		close_button.offset_top = 6
		close_button.offset_right = -6
		close_button.offset_bottom = 30
		_evidence_panel.add_child(close_button)
		close_button.pressed.connect(func() -> void:
			close_overlay()
		)

func _cache_case_folder() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	if _case_folder != null:
		return
	var folder_node := root.find_child("Folder", true, false)
	if folder_node is Sprite2D:
		_case_folder = folder_node as Sprite2D
		_case_folder_base_modulate = _case_folder.modulate
		var hit := _case_folder.get_node_or_null("FolderHit")
		if hit != null:
			hit.queue_free()
		if _case_folder.texture != null:
			_case_folder_image = _case_folder.texture.get_image()
			if _case_folder_image != null:
				_case_folder_image_size = _case_folder_image.get_size()
		_ensure_case_folder_outline()

func _is_mouse_over_case_folder(mouse_world: Vector2) -> bool:
	if _case_folder == null or _case_folder.texture == null:
		return false
	var local: Vector2 = _case_folder.to_local(mouse_world)
	var size: Vector2 = _case_folder.texture.get_size()
	var rect := Rect2(Vector2.ZERO, size)
	if _case_folder.centered:
		rect.position = -size * 0.5
	if not rect.has_point(local):
		return false

	if _case_folder_image != null and _case_folder_image_size != Vector2i.ZERO:
		var tex_pos: Vector2 = local
		if _case_folder.centered:
			tex_pos += size * 0.5
		var ix: int = int(floor(tex_pos.x))
		var iy: int = int(floor(tex_pos.y))
		if ix >= 0 and iy >= 0 and ix < _case_folder_image_size.x and iy < _case_folder_image_size.y:
			var a: float = _case_folder_image.get_pixel(ix, iy).a
			return a > 0.1

	return true

func _clear_folder_highlight() -> void:
	if _case_folder != null:
		_case_folder.modulate = _case_folder_base_modulate

func _ensure_case_folder_outline() -> void:
	if _case_folder == null:
		return
	if _case_folder_outline != null:
		return
	if _case_folder.texture == null:
		return

	var outline: Sprite2D = preload("res://ui/AlphaOutline.gd").new() as Sprite2D
	_case_folder_outline = outline
	if outline == null:
		return
	outline.name = "FolderHoverOutline"
	outline.texture = _case_folder.texture
	outline.centered = _case_folder.centered
	outline.z_index = _case_folder.z_index + 1
	outline.visible = false
	_case_folder.add_child(outline)

func _build_case_folder_payload() -> Dictionary:
	if current_suspect == null:
		return {
			"title": "CASE FOLDER",
			"left_text": "No suspect loaded.",
			"right_text": ""
		}

	var cs: Dictionary = current_suspect.charge_sheet
	var left_lines: Array[String] = []
	left_lines.append("CASE: %s" % String(cs.get("case_id", "")))
	left_lines.append("TITLE: %s" % String(cs.get("title", "")))
	left_lines.append("CHARGES:")
	var charges: Array = cs.get("charges", [])
	for c in charges:
		left_lines.append("- %s" % String(c))
	left_lines.append("")
	left_lines.append("BRIEF:")
	left_lines.append(String(cs.get("brief", "")))

	var right_lines: Array[String] = []
	right_lines.append("DOSSIER")
	right_lines.append("")
	var tab_order: Array[String] = ["ALIBI", "TIMELINE", "MOTIVE", "CAPABILITY", "PROFILE"]
	for tab in tab_order:
		right_lines.append("%s:" % tab)
		var tab_data: Dictionary = current_suspect.tabs.get(tab, {})
		var facts: Array = tab_data.get("facts", [])
		if facts.is_empty():
			right_lines.append("- (none)")
		else:
			for f in facts:
				if typeof(f) != TYPE_DICTIONARY:
					continue
				var d: Dictionary = f
				var rel: String = String(d.get("reliability", "UNK"))
				var text: String = String(d.get("text", ""))
				right_lines.append("- [%s] %s" % [rel, text])
		right_lines.append("")

	return {
		"title": "CASE FOLDER",
		"left_text": "\n".join(left_lines),
		"right_text": "\n".join(right_lines)
	}

func _set_dev_hud_visible(visible: bool) -> void:
	if visible and not is_instance_valid(_hud_layer):
		_install_hud()

	if is_instance_valid(_hud_layer):
		_hud_layer.visible = visible
	if is_instance_valid(_hud_label):
		_hud_label.visible = visible
	if is_instance_valid(_hud_hotkeys_label):
		_hud_hotkeys_label.visible = visible
	if is_instance_valid(_hud_event_log_label):
		_hud_event_log_label.visible = visible

	var root: Node = get_tree().root
	if root == null:
		return

	for layer in root.find_children(String(DEV_HUD_LAYER_NAME), "CanvasLayer", true, false):
		if layer != _hud_layer and layer is CanvasLayer:
			(layer as CanvasLayer).visible = visible

	for label in root.find_children(String(DEV_HUD_LABEL_NAME), "Label", true, false):
		if label != _hud_label and label is Label:
			(label as Label).visible = visible

func _init_verdict_flow_ui() -> void:
	if _verdict_overlay != null:
		return
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var hud_root: Node = root.find_child("HudRoot", true, false)
	if hud_root == null:
		return
	var verdict: Node = root.find_child("VerdictBar", true, false)
	if verdict == null:
		return

	_verdict_buttons.clear()
	for child in verdict.get_children():
		if child is Button:
			var btn := child as Button
			var verdict_id: String = btn.name.strip_edges().to_upper()
			if verdict_id == "CLRPH":
				verdict_id = "CLEAR"
			elif verdict_id == "CNVTPH":
				verdict_id = "CONVICT"
			elif verdict_id == "SGPH":
				verdict_id = "SCAPEGOAT"
			elif verdict_id == "":
				verdict_id = btn.text.strip_edges().to_upper()
			btn.pressed.connect(_on_verdict_pressed.bind(verdict_id))
			if verdict_id == "SCAPEGOAT" and not dev_enable_scapegoat:
				btn.disabled = true
			_verdict_buttons.append(btn)

	_verdict_overlay = preload("res://ui/VerdictResultOverlay.gd").new()
	if _verdict_overlay != null and _verdict_overlay is Control:
		var overlay_ctrl := _verdict_overlay as Control
		overlay_ctrl.visible = false
		overlay_ctrl.z_index = 3000
		hud_root.add_child(overlay_ctrl)
		if _verdict_overlay.has_signal("continued"):
			_verdict_overlay.connect("continued", Callable(self, "_on_verdict_overlay_continued"))

func _on_verdict_pressed(verdict_id: String) -> void:
	if _verdict_committed:
		return
	_verdict_committed = true
	_verdict_choice = verdict_id
	_pending_verdict_id = verdict_id

	for btn in _verdict_buttons:
		if btn != null:
			btn.disabled = true

	var truth_guilty: bool = current_suspect != null and current_suspect.truth_guilty
	var is_correct: bool = false
	if verdict_id == "CLEAR":
		is_correct = not truth_guilty
	elif verdict_id == "CONVICT":
		is_correct = truth_guilty
	else:
		is_correct = false

	_last_verdict = verdict_id
	_last_truth_guilty = truth_guilty
	_last_verdict_correct = is_correct
	_pending_run_fail = (verdict_id != "SCAPEGOAT" and not is_correct)
	_punishment_pending = (verdict_id == "SCAPEGOAT") or (not is_correct)
	if verdict_id == "SCAPEGOAT":
		_scapegoat_count += 1

	open_overlay("VERDICT_RESULT")
	if _verdict_overlay != null and _verdict_overlay.has_method("show_result"):
		_verdict_overlay.call("show_result", verdict_id, truth_guilty, is_correct, verdict_id == "SCAPEGOAT")

	_log("VERDICT pressed: %s" % verdict_id)
	set_run_state(RunState.VERDICT_PENDING)

func _on_verdict_overlay_continued() -> void:
	close_overlay()
	if _punishment_pending:
		_log("PUNISHMENT: PENDING (revolver later)")
	if _pending_run_fail:
		_log("OUTCOME: FAIL (wrong verdict) verdict=%s truth=%s" % [_last_verdict, "GUILTY" if _last_truth_guilty else "INNOCENT"])
		set_run_state(RunState.OUTCOME)
	_pending_run_fail = false
	_advance_to_next_suspect()
	set_run_state(RunState.IDLE)

func _advance_to_next_suspect() -> void:
	suspect_index += 1
	_refresh_suspect_seed()
	_update_hud()

func _reset_verdict_flow() -> void:
	_verdict_committed = false
	_verdict_choice = ""
	_pending_run_fail = false
	_punishment_pending = false
	for btn in _verdict_buttons:
		if btn != null:
			if btn.text.strip_edges().to_upper() == "SCAPEGOAT" and not dev_enable_scapegoat:
				btn.disabled = true
			else:
				btn.disabled = false

func _update_hud() -> void:
	if not dev_hud_enabled:
		return
	if not is_instance_valid(_hud_label):
		return

	_cleanup_duplicate_hud_labels()

	if _camera_node == null and app_state == AppState.GAME:
		_cache_camera()

	var overlay_text: String = overlay_id if overlay_open else "none"
	var seed_text: String = run_seed_text
	var camera_text: String = "n/a"
	var edge_pan_text: String = "n/a"
	if _camera_node != null:
		var pos: Vector2 = _camera_node.global_position
		var zoom: Vector2 = _camera_node.zoom
		camera_text = "pos=(%d,%d) zoom=(%.2f,%.2f)" % [int(round(pos.x)), int(round(pos.y)), zoom.x, zoom.y]
		if _camera_node.has_method("is_edge_pan_enabled"):
			edge_pan_text = "ON" if _camera_node.call("is_edge_pan_enabled") else "OFF"
	var camera_line: String = "CAMERA: %s edge_pan=%s" % [camera_text, edge_pan_text]
	var hotkeys_text: String = "HOTKEYS:\nF12 EndGame\nCtrl+Shift+I ImportSuspect\nCtrl+Shift+E ExportSuspect\nF7 CopySeed\nF6 LoadSeed\nF4 EdgePan\nF3 Verdict?\nF2 Next?\nF1 HUD"
	var seed64_text: String = SeedUtil.hex16(run_seed_u64)
	_hud_label.text = "\n".join([
		_format_hud_line("STATE", _state_name(app_state)),
		_format_hud_line("RUN", _run_state_name(run_state)),
		_format_hud_line("OVERLAY", overlay_text),
		_format_hud_line("SEED", seed_text),
		_format_hud_line("SEED64", seed64_text),
		camera_line,
		_format_hud_line("SUSPECT_IDX", str(suspect_index)),
		_format_hud_line("SUSPECT_SEED", suspect_seed_text),
		_format_hud_line("SUSPECT_ID", current_suspect.short_id() if current_suspect != null else "n/a"),
		_format_hud_line("SILH", current_suspect.silhouette_label if current_suspect != null else "n/a"),
		_format_hud_line("DEADLINE", current_suspect.get_deadline_label() if current_suspect != null else "n/a"),
		_format_hud_line("TRUTH", current_suspect.truth_label() if current_suspect != null else "n/a"),
		"",
	])
	if is_instance_valid(_hud_hotkeys_label):
		_hud_hotkeys_label.text = hotkeys_text
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		var hotkeys_size: Vector2 = _hud_hotkeys_label.get_minimum_size()
		_hud_hotkeys_label.position = Vector2(12, max(viewport_size.y - hotkeys_size.y - 12.0, 12.0))
	if is_instance_valid(_hud_event_log_label):
		_update_event_log_display()
		var viewport_size2: Vector2 = get_viewport().get_visible_rect().size
		_event_log_visible_lines = min(DEV_EVENT_LOG_VISIBLE, max(1, _dev_event_log.size()))
		var log_height: float = DEV_EVENT_LOG_LINE_HEIGHT * float(_event_log_visible_lines)
		var log_y: float = 12.0
		var log_width: float = min(DEV_EVENT_LOG_WIDTH, viewport_size2.x - 24.0)
		var log_x: float = max(viewport_size2.x - log_width - 12.0, 12.0)
		_hud_event_log_label.position = Vector2(log_x, log_y)
		_hud_event_log_label.size = Vector2(log_width, log_height)


	if dev_log_overlays and (overlay_open != _last_logged_overlay_open or overlay_id != _last_logged_overlay_id):
		_last_logged_overlay_open = overlay_open
		_last_logged_overlay_id = overlay_id

func _cleanup_duplicate_hud_labels() -> void:
	var root: Node = get_tree().root
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
			var other: Label = label as Label
			other.visible = false

	for label in root.find_children("DevEventLogLabel", "Label", true, false):
		if label is Label and label != _hud_event_log_label:
			var other_log: Label = label as Label
			other_log.visible = false

func _log(msg: String) -> void:
	if not dev_log_enabled:
		return
	var ticks: int = Time.get_ticks_msec()
	var line: String = "%s %s" % [str(ticks), msg]
	print("[K11] %s" % line)
	_dev_event_log.append(line)
	if _dev_event_log.size() > DEV_EVENT_LOG_MAX:
		_dev_event_log = _dev_event_log.slice(_dev_event_log.size() - DEV_EVENT_LOG_MAX, _dev_event_log.size())
	_update_event_log_display()

func _update_event_log_display() -> void:
	if not dev_hud_enabled:
		return
	if not is_instance_valid(_hud_event_log_label):
		return
	var count: int = min(_event_log_visible_lines, _dev_event_log.size())
	var start: int = max(0, _dev_event_log.size() - count)
	_hud_event_log_label.text = "\n".join(_dev_event_log.slice(start, _dev_event_log.size()))

func _request_seed_reload(seed_text: String) -> void:
	_pending_seed_text = seed_text
	_pending_seed_reload = true
	_log("SEED RELOAD REQUESTED -> %s" % _pending_seed_text)

func _format_hud_line(label: String, value: String) -> String:
	return "%s: %s" % [label.rpad(12, " "), value]

func _dev_suspect_export_path() -> String:
	var seed_slug: String = run_seed_text.replace(":", "_").replace("/", "_")
	return "user://dev/suspect_%s_idx%03d.json" % [seed_slug, suspect_index]

func _dev_export_suspect() -> void:
	if current_suspect == null:
		_log("SUSPECT_EXPORT: no current suspect")
		return
	var json: String = SuspectIO.to_json(current_suspect, true)
	var fp_obj: String = SuspectIO.fingerprint_suspect(current_suspect)
	var fp_json: String = SuspectIO.fingerprint_json(json)
	DisplayServer.clipboard_set(json)
	var fp_clip: String = SuspectIO.fingerprint_json(DisplayServer.clipboard_get())

	var path: String = _dev_suspect_export_path()
	var ok: bool = SuspectIO.write_text(path, json)
	var last_path: String = "user://dev/last_suspect.json"
	var ok_last: bool = SuspectIO.write_text(last_path, json)
	if ok:
		if ok_last:
			_log("SUSPECT_EXPORT ok idx=%d id=%s truth=%s fp_obj=%s fp_json=%s fp_clip=%s -> %s + last_suspect.json (and clipboard)" % [
				suspect_index,
				current_suspect.short_id(),
				current_suspect.truth_label(),
				fp_obj.substr(0, 12),
				fp_json.substr(0, 12),
				fp_clip.substr(0, 12),
				path
			])
		else:
			_log("SUSPECT_EXPORT ok idx=%d id=%s truth=%s fp_obj=%s fp_json=%s fp_clip=%s -> %s (last_suspect.json FAILED, clipboard set)" % [
				suspect_index,
				current_suspect.short_id(),
				current_suspect.truth_label(),
				fp_obj.substr(0, 12),
				fp_json.substr(0, 12),
				fp_clip.substr(0, 12),
				path
			])
	else:
		_log("SUSPECT_EXPORT FAILED fp_obj=%s fp_json=%s fp_clip=%s -> %s (clipboard still set)" % [
			fp_obj.substr(0, 12),
			fp_json.substr(0, 12),
			fp_clip.substr(0, 12),
			path
		])
	if fp_obj != "" and fp_json != "" and fp_clip != "" and (fp_obj != fp_json or fp_json != fp_clip):
		_log("SUSPECT_EXPORT WARN mismatch fp_obj=%s fp_json=%s fp_clip=%s" % [
			fp_obj.substr(0, 12),
			fp_json.substr(0, 12),
			fp_clip.substr(0, 12)
		])

func _dev_import_suspect_clipboard_or_prompt() -> void:
	if is_instance_valid(_suspect_import_dialog) and _suspect_import_dialog.visible:
		return
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_import_prompt_time_msec < 200:
		return
	var clip: String = DisplayServer.clipboard_get()
	var fp_src: String = SuspectIO.fingerprint_json(clip)
	var s: SuspectData = SuspectIO.from_json(clip)
	if s != null:
		_apply_imported_suspect(s, "clipboard")
		var fp_obj: String = SuspectIO.fingerprint_suspect(s)
		_log("SUSPECT_IMPORT ok src=clipboard idx=%d id=%s truth=%s fp_src=%s fp_obj=%s" % [
			s.suspect_index,
			s.short_id(),
			s.truth_label(),
			fp_src.substr(0, 12),
			fp_obj.substr(0, 12)
		])
		if fp_src != "" and fp_obj != "" and fp_src != fp_obj:
			_log("SUSPECT_IMPORT WARN fp_src=%s fp_obj=%s" % [fp_src.substr(0, 12), fp_obj.substr(0, 12)])
		return

	var last_path: String = "user://dev/last_suspect.json"
	var last_text: String = SuspectIO.read_text(last_path)
	var s2: SuspectData = SuspectIO.from_json(last_text)
	if s2 != null:
		_apply_imported_suspect(s2, "file:last_suspect")
		return

	_log("SUSPECT_IMPORT: invalid/empty clipboard JSON -> opening paste dialog")
	var prefill: String = clip
	_last_import_prompt_time_msec = now_msec
	_open_suspect_import_prompt(prefill)

func _install_suspect_import_prompt() -> void:
	if is_instance_valid(_suspect_import_dialog):
		return

	_suspect_import_dialog = AcceptDialog.new()
	_suspect_import_dialog.title = "Import Suspect JSON"
	_suspect_import_dialog.exclusive = true
	_suspect_import_dialog.always_on_top = true
	_suspect_import_dialog.transient = true
	_suspect_import_dialog.unresizable = false
	_suspect_import_dialog.dialog_hide_on_ok = false
	_suspect_import_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_suspect_import_dialog.set_process_input(true)
	_suspect_import_dialog.set_process_unhandled_input(true)
	_suspect_import_dialog.min_size = Vector2(860, 520)
	_suspect_import_dialog.close_requested.connect(_on_suspect_import_closed)
	_suspect_import_dialog.confirmed.connect(_on_suspect_import_confirmed)
	add_child(_suspect_import_dialog)

	var container: MarginContainer = MarginContainer.new()
	container.add_theme_constant_override("margin_left", 12)
	container.add_theme_constant_override("margin_right", 12)
	container.add_theme_constant_override("margin_top", 12)
	container.add_theme_constant_override("margin_bottom", 12)
	_suspect_import_dialog.add_child(container)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	container.add_child(vbox)

	_suspect_import_label = Label.new()
	_suspect_import_label.text = "Paste suspect JSON (must include schema_version=%d)" % SuspectData.SCHEMA_VERSION
	_suspect_import_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_suspect_import_label)

	_suspect_import_hint_label = Label.new()
	_suspect_import_hint_label.text = "Tip: Ctrl+Shift+E exports JSON to clipboard. Ctrl+Shift+I imports (clipboard or prompt). F7 copies seed (not JSON)."
	_suspect_import_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_suspect_import_hint_label)

	_suspect_import_error_label = Label.new()
	_suspect_import_error_label.text = ""
	_suspect_import_error_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_suspect_import_error_label)

	_suspect_import_text = TextEdit.new()
	_suspect_import_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_suspect_import_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_suspect_import_text.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	_suspect_import_text.focus_mode = Control.FOCUS_ALL
	_suspect_import_text.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(_suspect_import_text)

func _open_suspect_import_prompt(prefill: String) -> void:
	if not is_instance_valid(_suspect_import_dialog):
		_install_suspect_import_prompt()
	if _suspect_import_dialog.visible:
		_suspect_import_dialog.move_to_foreground()
		_suspect_import_dialog.grab_focus()
		call_deferred("_suspect_import_focus")
		return

	_suspect_import_prev_hud_visible = dev_hud_enabled
	if dev_hud_enabled:
		_set_dev_hud_visible(false)

	if is_instance_valid(_suspect_import_error_label):
		_suspect_import_error_label.text = ""
	_suspect_import_text.text = prefill
	_suspect_import_dialog.popup_centered(Vector2i(860, 520))
	call_deferred("_suspect_import_activate")

func _suspect_import_focus() -> void:
	if is_instance_valid(_suspect_import_text):
		_suspect_import_text.grab_focus()
		_suspect_import_text.set_caret_line(0)
		_suspect_import_text.set_caret_column(0)
		_suspect_import_text.select_all()
		_suspect_import_text.select_all()

func _suspect_import_focus_and_select_all() -> void:
	if is_instance_valid(_suspect_import_text):
		_suspect_import_text.grab_focus()
		_suspect_import_text.select_all()

func _suspect_import_activate() -> void:
	if not is_instance_valid(_suspect_import_dialog):
		return
	_suspect_import_dialog.move_to_foreground()
	_suspect_import_dialog.grab_focus()
	_suspect_import_focus_and_select_all()

func _on_suspect_import_confirmed() -> void:
	var text: String = _suspect_import_text.text
	var s: SuspectData = SuspectIO.from_json(text)
	if s == null:
		if is_instance_valid(_suspect_import_error_label):
			_suspect_import_error_label.text = "Invalid JSON or schema_version mismatch (expected schema_version=%d)." % SuspectData.SCHEMA_VERSION
		_log("SUSPECT_IMPORT FAILED: invalid JSON or schema_version mismatch")
		call_deferred("_suspect_import_focus_and_select_all")
		return
	_apply_imported_suspect(s, "paste")
	_suspect_import_dialog.hide()
	_on_suspect_import_closed()

func _on_suspect_import_closed() -> void:
	if is_instance_valid(_suspect_import_text):
		_suspect_import_text.text = ""
	if _suspect_import_prev_hud_visible:
		_set_dev_hud_visible(true)

func _apply_imported_suspect(s: SuspectData, source: String) -> void:
	current_suspect = s

	run_seed_text = s.run_seed_text
	run_seed_u64 = s.run_seed_u64
	run_seed_value = _seed_parse(run_seed_text)

	suspect_index = s.suspect_index
	suspect_seed_value = s.suspect_seed_u64
	suspect_seed_text = "K11S-%s" % SeedUtil.hex16(suspect_seed_value)

	var fp: String = SuspectIO.fingerprint_suspect(s)
	var sid: String = s.short_id()
	var t: String = s.truth_label()
	_log("SUSPECT_IMPORT ok src=%s fp=%s idx=%d id=%s truth=%s" % [source, fp.substr(0, 12), suspect_index, sid, t])
	_update_hud()

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

	var target_size: Vector2i = Vector2i(1280, 720)
	DisplayServer.window_set_size(target_size)

	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var pos: Vector2i = (screen_size - target_size) / 2
	DisplayServer.window_set_position(pos)

func _apply_overlay_lock(is_open: bool) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	var cams: Array[Node] = scene.find_children("", "Camera2D", true, false)
	for cam in cams:
		if cam != null and cam.has_method("set_overlay_open"):
			cam.call("set_overlay_open", is_open)

func _reset_run_state() -> void:
	if overlay_open:
		close_overlay()
	run_state = RunState.IDLE
	suspect_index = 0
	_refresh_suspect_seed()
	_log("SUSPECT_STREAM reset idx=%d seed=%s" % [suspect_index, suspect_seed_text])
	_apply_state_policy("seed")
	_update_hud()

func _init_seed() -> void:
	var seed_value: int = 0
	var has_seed: bool = false
	if forced_seed_text != "":
		var forced_parsed: int = _seed_parse(forced_seed_text)
		if forced_parsed >= 0:
			seed_value = forced_parsed
			has_seed = true
	else:
		for arg in OS.get_cmdline_args():
			if arg.begins_with("--seed="):
				var cmd_value: int = _seed_parse(arg.substr(7))
				if cmd_value >= 0:
					seed_value = cmd_value
					has_seed = true
				break

	if not has_seed:
		seed_value = int(Time.get_ticks_msec())

	run_seed_value = seed_value
	run_seed_text = _seed_format(seed_value)
	_log("SEED = %s (%d)" % [run_seed_text, run_seed_value])
	run_seed_u64 = SeedUtil.normalize_seed(run_seed_value)
	suspect_index = 0
	_refresh_suspect_seed()
	_log("SEED64 = %s" % SeedUtil.hex16(run_seed_u64))
	_log("SUSPECT_STREAM init idx=%d seed=%s" % [suspect_index, suspect_seed_text])

func _seed_format(v: int) -> String:
	if v < 0:
		v = -v
	return "K11-%s" % _to_base36(v)

func _seed_parse(s: String) -> int:
	var text: String = s.strip_edges()
	if text == "":
		return -1

	var upper: String = text.to_upper()
	if upper.begins_with("K11-"):
		var suffix: String = text.substr(4).strip_edges()
		if suffix == "":
			return -1
		return _from_base36(suffix)

	var digits_only: bool = true
	for i in text.length():
		var ch: String = text[i]
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
	var chars: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var value: int = v
	var result: String = ""
	while value > 0:
		var idx: int = value % 36
		result = chars[idx] + result
		value = int(value / 36)
	return result

func _from_base36(s: String) -> int:
	var chars: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var value: int = 0
	var upper: String = s.strip_edges().to_upper()
	for i in upper.length():
		var ch: String = upper[i]
		var idx: int = chars.find(ch)
		if idx < 0:
			return -1
		value = value * 36 + idx
	return value

func _on_tabs_bar_tab_changed(tab_id: String) -> void:
	if current_suspect == null:
		_log("EVIDENCE: no current_suspect")
		return
	if _evidence_panel == null:
		_cache_evidence_ui()
		if _evidence_panel == null:
			return
	if overlay_open and overlay_id == OVERLAY_EVIDENCE_ID:
		_refresh_evidence_overlay(tab_id)
	else:
		_open_evidence_overlay(tab_id)


func _open_evidence_overlay(tab_id: String) -> void:
	_evidence_active_tab = tab_id

	var entries := _build_evidence_entries_for_tab(current_suspect, tab_id)

	# Feed the panel (EvidenceLogPanel has set_entries(entries, active_tab))
	if _evidence_panel.has_method("set_entries"):
		_evidence_panel.call("set_entries", entries, tab_id)

	# Show popup + dimmer
	if is_instance_valid(_evidence_dimmer):
		_evidence_dimmer.visible = true
	_evidence_panel.visible = true

	# Treat as overlay for ESC + camera lock consistency
	overlay_open = true
	overlay_id = OVERLAY_EVIDENCE_ID
	set_run_state(RunState.OVERLAY)
	_set_world_tabs_pickable(false)
	_set_hud_tabs_enabled(false)
	if dev_log_overlays:
		var fp := SuspectIO.fingerprint_suspect(current_suspect)
		_log("EVIDENCE open tab=%s lines=%d fp=%s" % [tab_id, entries.size(), fp.substr(0, 12)])
	_apply_overlay_lock(true)
	_apply_state_policy("evidence")

func _refresh_evidence_overlay(tab_id: String) -> void:
	_evidence_active_tab = tab_id
	var entries := _build_evidence_entries_for_tab(current_suspect, tab_id)
	if _evidence_panel != null and _evidence_panel.has_method("set_entries"):
		_evidence_panel.call("set_entries", entries, tab_id)
	if dev_log_overlays:
		var fp := SuspectIO.fingerprint_suspect(current_suspect)
		_log("EVIDENCE switch tab=%s lines=%d fp=%s" % [tab_id, entries.size(), fp.substr(0, 12)])


func _hide_evidence_overlay() -> void:
	if is_instance_valid(_evidence_dimmer):
		_evidence_dimmer.visible = false
	if is_instance_valid(_evidence_panel):
		_evidence_panel.visible = false
		if _evidence_panel.has_method("clear"):
			_evidence_panel.call("clear")
	_evidence_active_tab = ""
	_set_world_tabs_pickable(true)
	_set_hud_tabs_enabled(true)


func _build_evidence_entries_for_tab(s: SuspectData, tab_id: String) -> Array:
	var out: Array = []
	var tab_data: Variant = s.tabs.get(tab_id, null)
	var facts: Array = []
	if typeof(tab_data) == TYPE_DICTIONARY:
		facts = (tab_data as Dictionary).get("facts", []) as Array

	# Header line (plain text)
	out.append({
		"tab": "",
		"reliability": "",
		"text": "%s  (%d)   [ESC to close]" % [tab_id, facts.size()]
	})

	for f in facts:
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var d := f as Dictionary
		out.append({
			"tab": tab_id,
			"reliability": String(d.get("reliability", "")),
			"text": String(d.get("text", ""))
		})

	return out

func _set_world_tabs_pickable(enabled: bool) -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var tabs: Array[Node] = root.find_children("Tab_*", "Area2D", true, false)
	for t in tabs:
		var area := t as Area2D
		if area != null:
			area.input_pickable = enabled
	_set_world_tab_bar_enabled(enabled)

func _set_world_tab_bar_enabled(enabled: bool) -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var bar: Node = root.find_child("WorldTabBar", true, false)
	if bar != null and bar.has_method("set_enabled"):
		bar.call("set_enabled", enabled)

func _set_hud_tabs_enabled(enabled: bool) -> void:
	if _tabs_bar == null:
		var root: Node = get_tree().current_scene
		if root != null:
			_tabs_bar = root.find_child("TabsBar", true, false)
	if _tabs_bar is Control:
		var c := _tabs_bar as Control
		c.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	var buttons: Array[Node] = []
	if _tabs_bar != null:
		buttons.append_array(_tabs_bar.find_children("", "Button", true, false))
	var root_tabs: Node = get_tree().current_scene
	if root_tabs != null:
		var verdict: Node = root_tabs.find_child("VerdictBar", true, false)
		if verdict != null:
			buttons.append_array(verdict.find_children("", "Button", true, false))
	for b in buttons:
		var btn := b as Button
		if btn != null:
			btn.disabled = not enabled

func _refresh_suspect_seed() -> void:
	suspect_seed_value = SeedUtil.derive_seed(run_seed_u64, "suspect", suspect_index)
	suspect_seed_text = "K11S-%s" % SeedUtil.hex16(suspect_seed_value)
	current_suspect = SuspectFactory.generate(run_seed_u64, run_seed_text, suspect_index)
	if current_suspect != null:
		_log("SUSPECT idx=%d seed=%s id=%s truth=%s" % [suspect_index, suspect_seed_text, current_suspect.id, current_suspect.truth_label()])
	_reset_verdict_flow()
