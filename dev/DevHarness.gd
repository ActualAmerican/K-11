extends Node
class_name DevHarness

const DEV_TEST_SHOT_TYPE := 3 # GameController.ShotType.DEV_TEST
const HUD_REFRESH_INTERVAL := 0.1

var controller: Node = null
var hud_visible := true

var _hud_refresh_accum: float = 0.0
var _last_toggle_edge_pan_event_id: int = 0
var _last_force_verdict_event_id: int = 0

func attach(p_controller: Node) -> void:
	controller = p_controller
	if controller == null:
		return
	_safe_call("._install_hud")
	_mount_hud_globally()
	_safe_call("._install_seed_prompt")
	hud_visible = _c_bool("dev_hud_enabled")
	_safe_call("._set_dev_hud_visible", [hud_visible])
	_safe_call("._cleanup_duplicate_hud_labels")
	_safe_call("._update_hud")

func handle_case_handling_input(event: InputEvent, scene: Node) -> bool:
	if controller == null:
		return false
	if scene == null:
		return false
	if not (event is InputEventKey):
		return false
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return false
	if scene.has_method("_handle_pip_calibration_key"):
		return bool(scene.call("_handle_pip_calibration_key", k))
	return false

func tick(_delta: float) -> void:
	if controller == null:
		return
	_mount_hud_globally()
	if not _c_bool("dev_hud_enabled"):
		return
	_hud_refresh_accum += _delta
	if _hud_refresh_accum < HUD_REFRESH_INTERVAL:
		return
	_hud_refresh_accum = 0.0
	_safe_call("._update_hud")

func handle_input(event: InputEvent) -> bool:
	if controller == null or event == null:
		return false

	if _c_bool("dev_allow_escape_hatch") and event.is_action_pressed("ui_cancel"):
		if _c_bool("overlay_open"):
			var overlay_id: String = _c_str("overlay_id")
			var intermission_sys: Object = _c_obj("_intermission_sys")
			if intermission_sys != null and intermission_sys.has_method("is_active") and bool(intermission_sys.call("is_active")) and overlay_id.begins_with("INTERMISSION_"):
				_safe_call("._on_intermission_continue")
			else:
				_safe_call(".close_overlay")
			return true

		var mode: int = DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			_safe_call("._exit_fullscreen_to_windowed")
			_log("ESC: fullscreen -> windowed")
			return true

		if _c_bool("dev_quit_requires_shift"):
			var key_event: InputEventKey = event as InputEventKey
			if key_event != null and key_event.shift_pressed:
				_log("ESC: quit")
				controller.get_tree().quit()
				return true
			return true
		_log("ESC: quit")
		controller.get_tree().quit()
		return true

	var wants_toggle: bool = false
	if InputMap.has_action("dev_toggle_hud") and event.is_action_pressed("dev_toggle_hud"):
		wants_toggle = true
	if InputMap.has_action("dev_toggle") and event.is_action_pressed("dev_toggle"):
		wants_toggle = true

	if wants_toggle:
		var next_visible: bool = not _c_bool("dev_hud_enabled")
		_c_set("dev_hud_enabled", next_visible)
		hud_visible = next_visible
		_safe_call("._set_dev_hud_visible", [next_visible])
		_safe_call("._update_hud")
		_log("HOTKEY F1 dev_toggle -> HUD %s" % ("ON" if next_visible else "OFF"))
		return true

	if InputMap.has_action("dev_next_suspect") and event.is_action_pressed("dev_next_suspect"):
		if _c_bool("overlay_open"):
			var oid: String = _c_str("overlay_id")
			if oid == "EVIDENCE" or oid == "VERDICT_RESULT":
				_safe_call(".close_overlay")
		_safe_call("._advance_to_next_suspect")
		var current_suspect: Object = _c_obj("current_suspect")
		var sid: String = "n/a"
		var t: String = "n/a"
		if current_suspect != null:
			if current_suspect.has_method("short_id"):
				sid = str(current_suspect.call("short_id"))
			if current_suspect.has_method("truth_label"):
				t = str(current_suspect.call("truth_label"))
		_log("HOTKEY F2 dev_next_suspect -> idx=%d seed=%s id=%s truth=%s" % [_c_int("suspect_index"), _c_str("suspect_seed_text"), sid, t])
		_safe_call("._update_hud")
		return true

	if InputMap.has_action("dev_load_seed") and event.is_action_pressed("dev_load_seed"):
		_log("HOTKEY F6 dev_load_seed")
		_safe_call("._open_seed_prompt")
		return true

	if InputMap.has_action("dev_seed_copy") and event.is_action_pressed("dev_seed_copy"):
		DisplayServer.clipboard_set(_c_str("run_seed_text"))
		_log("HOTKEY F7 dev_seed_copy -> %s" % _c_str("run_seed_text"))
		return true

	if InputMap.has_action("dev_end_game") and event.is_action_pressed("dev_end_game"):
		var k_end: InputEventKey = event as InputEventKey
		if k_end != null and k_end.pressed and not k_end.echo and k_end.keycode == KEY_F12:
			_log("HOTKEY F12 dev_end_game -> quit")
			controller.get_tree().quit()
			return true
		return false

	if InputMap.has_action("dev_force_verdict") and event.is_action_pressed("dev_force_verdict"):
		var force_id: int = event.get_instance_id()
		if force_id != _last_force_verdict_event_id:
			_last_force_verdict_event_id = force_id
			_log("HOTKEY F3 dev_force_verdict (not implemented yet)")
		return false

	if InputMap.has_action("toggle_edge_pan") and event.is_action_pressed("toggle_edge_pan"):
		var edge_id: int = event.get_instance_id()
		if edge_id != _last_toggle_edge_pan_event_id:
			_last_toggle_edge_pan_event_id = edge_id
			_log("HOTKEY F4 toggle_edge_pan")
		return false

	# Preserve current gating behavior: this flag gates the entire raw-key dev block.
	if _c_bool("dev_allow_suspect_io") and event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k != null and k.pressed and not k.echo:
			if k.keycode == KEY_F9:
				_log("HOTKEY F9: use Ctrl+Shift+I for suspect import (F9 is not bound).")
				return true
			if k.keycode == KEY_F8:
				_log("HOTKEY F8: do not use in-editor (Godot stops play). Use Ctrl+Shift+E for export.")
				return true

			if not k.ctrl_pressed and not k.shift_pressed:
				var pk := k.physical_keycode
				var kc := k.keycode
				if pk == KEY_0 or kc == KEY_0 or kc == KEY_KP_0 or k.unicode == 48 or k.key_label == KEY_0:
					_safe_call("._dev_set_live_rounds_and_sync", [0])
					return true
				if pk == KEY_1 or kc == KEY_1 or kc == KEY_KP_1:
					_safe_call("._dev_set_live_rounds_and_sync", [1])
					return true
				if pk == KEY_2 or kc == KEY_2 or kc == KEY_KP_2:
					_safe_call("._dev_set_live_rounds_and_sync", [2])
					return true
				if pk == KEY_3 or kc == KEY_3 or kc == KEY_KP_3:
					_safe_call("._dev_set_live_rounds_and_sync", [3])
					return true
				if pk == KEY_4 or kc == KEY_4 or kc == KEY_KP_4:
					_safe_call("._dev_set_live_rounds_and_sync", [4])
					return true
				if pk == KEY_5 or kc == KEY_5 or kc == KEY_KP_5:
					_safe_call("._dev_set_live_rounds_and_sync", [5])
					return true
				if pk == KEY_6 or kc == KEY_6 or kc == KEY_KP_6:
					_safe_call("._dev_set_live_rounds_and_sync", [6])
					return true

			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_E:
				_safe_call("._dev_export_suspect")
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_I:
				_safe_call("._dev_import_suspect_clipboard_or_prompt")
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_R:
				_safe_call("._cache_revolver_widget")
				var rev_sys_r: Object = _c_obj("_revolver_sys")
				if rev_sys_r == null:
					_log("REVOLVER DEV: add round failed (system missing)")
					return true
				var idx := int(rev_sys_r.call("add_live_round_random"))
				_safe_call("._sync_revolver_widget")
				var snap_r: Dictionary = rev_sys_r.call("snapshot")
				if idx >= 0:
					_log("REVOLVER DEV: add round -> chamber=%d danger_fill=%d danger=%d injected=1 live_mask=%d" % [
						idx,
						snap_r.get("danger_fill", -1),
						snap_r.get("danger", -1),
						snap_r.get("live_mask", -1)
					])
				else:
					_log("REVOLVER DEV: add round failed danger_fill=%d danger=%d injected=0 live_mask=%d" % [
						snap_r.get("danger_fill", -1),
						snap_r.get("danger", -1),
						snap_r.get("live_mask", -1)
					])
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_BRACKETRIGHT:
				_safe_call("._cache_revolver_widget")
				var rev_sys_up: Object = _c_obj("_revolver_sys")
				if rev_sys_up == null:
					_log("REVOLVER DEV: tier++ failed (system missing)")
					return true
				var snap_up: Dictionary = rev_sys_up.call("snapshot")
				var tier_up := clampi(int(snap_up.get("danger", 0)) + 1, 0, 6)
				_safe_call("._dev_set_danger_tier_and_reload", [tier_up])
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_BRACKETLEFT:
				_safe_call("._cache_revolver_widget")
				var rev_sys_dn: Object = _c_obj("_revolver_sys")
				if rev_sys_dn == null:
					_log("REVOLVER DEV: tier-- failed (system missing)")
					return true
				var snap_dn: Dictionary = rev_sys_dn.call("snapshot")
				var tier_dn := clampi(int(snap_dn.get("danger", 0)) - 1, 0, 6)
				_safe_call("._dev_set_danger_tier_and_reload", [tier_dn])
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_BACKSLASH:
				_safe_call("._dev_set_danger_tier_and_reload", [0])
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_Z:
				_safe_call("._cache_revolver_widget")
				var rev_sys_z: Object = _c_obj("_revolver_sys")
				if rev_sys_z == null:
					_log("DANGER DEV: fill=0 failed (system missing)")
					return true
				rev_sys_z.call("set_danger_fill", 0)
				_safe_call("._sync_revolver_widget")
				var snap0: Dictionary = rev_sys_z.call("snapshot")
				_log("DANGER DEV: fill=0 danger_fill=%d danger=%d injected=0 live_mask=%d" % [
					snap0.get("danger_fill", -1),
					snap0.get("danger", -1),
					snap0.get("live_mask", -1)
				])
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_X:
				_safe_call("._cache_revolver_widget")
				if _c_obj("_revolver_sys") == null:
					_log("DANGER DEV: +25 failed (system missing)")
					return true
				_safe_call("._apply_danger_penalty", [25, "DEV:+25"])
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_C:
				_safe_call("._cache_revolver_widget")
				if _c_obj("_revolver_sys") == null:
					_log("DANGER DEV: +50 failed (system missing)")
					return true
				_safe_call("._apply_danger_penalty", [50, "DEV:+50"])
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_V:
				_safe_call("._cache_revolver_widget")
				if _c_obj("_revolver_sys") == null:
					_log("DANGER DEV: +100 failed (system missing)")
					return true
				_safe_call("._apply_danger_penalty", [100, "DEV:+100"])
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_N:
				_safe_call("._apply_noise_trigger", [&"dev_noise_spike", {"amount": 10, "reason": "DEV:+10"}])
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_M:
				var phone: Object = _c_obj("_phone")
				if phone != null:
					var was_on: bool = bool(phone.get("ringing"))
					if phone.has_method("toggle_dev"):
						phone.call("toggle_dev")
						_log("NOISE DEV: phone_ringing %s" % ("OFF" if was_on else "ON"))
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_P:
				_c_set("_noise_carryover_next_suspect", true)
				_log("NOISE DEV: carryover enabled for next suspect")
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_A:
				_safe_call("._apply_noise_trigger", [&"attempt_failure_beep", {"source": "dev"}])
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_G:
				_safe_call("._apply_noise_trigger", [&"camera_interference", {"source": "dev"}])
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_B:
				_safe_call("._apply_noise_trigger", [&"vent_drill", {"source": "dev"}])
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_D:
				_safe_call("._apply_noise_trigger", [&"case_handling_failure", {"source": "dev"}])
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_T:
				var sim: RevolverSim = RevolverSim.new()
				var rev_sys_t: Object = _c_obj("_revolver_sys")
				var tier: int = int(rev_sys_t.get("danger")) if rev_sys_t != null else 6
				var report: Dictionary = sim.run(_c_int("run_seed_u64"), 50, tier)
				_log("REVOLVER_SIM: " + String(report.get("summary", "")))
				if not bool(report.get("ok", false)):
					var errs: Array = report.get("errors", [])
					var max_errs: int = min(10, errs.size())
					for i in range(max_errs):
						_log("REVOLVER_SIM_FAIL: " + String(errs[i]))
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_K:
				_safe_call(".request_shot", [DEV_TEST_SHOT_TYPE, false, "dev_hotkey"])
				return true
			if k.ctrl_pressed and k.shift_pressed and k.keycode == KEY_L:
				_safe_call(".request_shot", [DEV_TEST_SHOT_TYPE, true, "dev_hotkey"])
				return true

	return false

func _safe_call(method_name: String, args: Array = []) -> Variant:
	if controller == null:
		return null
	var actual := method_name
	if actual.begins_with("."):
		actual = actual.substr(1)
	if not controller.has_method(actual):
		return null
	return controller.callv(actual, args)

func _c_get(name: String, fallback: Variant = null) -> Variant:
	if controller == null:
		return fallback
	var v: Variant = controller.get(name)
	return fallback if v == null else v

func _c_set(name: String, value: Variant) -> void:
	if controller == null:
		return
	controller.set(name, value)

func _c_bool(name: String) -> bool:
	return bool(_c_get(name, false))

func _c_int(name: String) -> int:
	return int(_c_get(name, 0))

func _c_str(name: String) -> String:
	return str(_c_get(name, ""))

func _c_obj(name: String) -> Object:
	var v: Variant = _c_get(name, null)
	return v as Object

func _log(msg: String) -> void:
	_safe_call("._log", [msg])

func _mount_hud_globally() -> void:
	if controller == null:
		return
	var hud_layer: CanvasLayer = _c_obj("_hud_layer") as CanvasLayer
	if hud_layer == null or not is_instance_valid(hud_layer):
		return
	var global_mount: Node = get_parent()
	if global_mount == null:
		return
	if hud_layer.get_parent() != global_mount:
		var old_parent: Node = hud_layer.get_parent()
		if old_parent != null:
			old_parent.remove_child(hud_layer)
		global_mount.add_child(hud_layer)
	# Ensure Dev HUD stays above all gameplay overlays.
	hud_layer.layer = 2048
	for c in hud_layer.find_children("*", "Control", true, false):
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
