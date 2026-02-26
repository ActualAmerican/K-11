@tool
extends Control
class_name CaseHandlingScene

enum PipSourceMode {
	MANUAL,
	FOLLOW_TARGET,
}

signal finished(success: bool, noise_points: int)

@export var max_pull_px: float = 655.0
@export var yank_velocity_px_s: float = 1400.0
@export var yank_noise_points: int = 18
@export var auto_fit_to_viewport: bool = true
@export var editor_preview_runtime_layout: bool = false
@export var editor_preview_size: Vector2 = Vector2(1920.0, 1080.0)
@export var lock_drawer_at_max_open: bool = true
@export var file_ready_threshold: float = 0.98
@export var place_anim_duration_s: float = 0.22
@export var drawer_close_duration_s: float = 0.22
@export var fade_out_duration_s: float = 0.42
@export var fade_black_hold_s: float = 0.2
@export_group("Noise Meter PiP")
@export var pip_meter_scale: Vector2 = Vector2(1.0, 1.0)
@export var pip_meter_offset: Vector2 = Vector2(0.0, 0.0)
@export var pip_meter_z_index: int = 18
@export var pip_source_mode: PipSourceMode = PipSourceMode.FOLLOW_TARGET
@export var pip_source_target_path: NodePath = ^"Sound/NoiseMeter"
@export var pip_source_center_px: Vector2 = Vector2(330.0, 260.0)
@export var pip_source_size_px: Vector2 = Vector2(420.0, 280.0)
@export var pip_source_follow_offset_px: Vector2 = Vector2.ZERO
@export_group("Noise Meter PiP Editor Preview")
@export var pip_editor_preview_enabled: bool = true
@export var pip_editor_preview_texture: Texture2D
@export var pip_editor_preview_scene: PackedScene = preload("res://Scenes/Game.tscn")
@export_group("Noise Meter PiP Runtime Calibration")
@export var pip_runtime_calibration_hotkey_enabled: bool = true
@export var pip_runtime_calibration_start_active: bool = false
@export var pip_runtime_calibration_step_px: float = 4.0
@export var pip_runtime_calibration_big_step_px: float = 16.0

@export_group("Balance Minigame")
@export var balance_enabled: bool = true
@export var balance_safe_width_slow: float = 0.45
@export var balance_safe_width_fast: float = 0.22
@export var balance_target_interval_slow: float = 0.75
@export var balance_target_interval_fast: float = 0.35
@export var balance_center_lerp_slow: float = 2.0
@export var balance_center_lerp_fast: float = 5.0
@export var balance_drift_rate_slow: float = 0.55
@export var balance_drift_rate_fast: float = 1.35
@export var balance_correction_per_px: float = 0.0035
@export var balance_mouse_max_px_per_frame: float = 30.0
@export var balance_mouse_force_gain: float = 170.0
@export var balance_mouse_direct_gain: float = 0.38
@export var balance_needle_stiffness: float = 7.0
@export var balance_needle_damping: float = 4.0
@export var balance_center_wander_amp: float = 0.09
@export var balance_center_wander_hz_slow: float = 0.28
@export var balance_center_wander_hz_fast: float = 0.75
@export var balance_scrape_rate: float = 10.0
@export var balance_release_slam_noise: int = 6
@export var balance_slam_close_duration_s: float = 0.14
@export var balance_visual_shift_px: float = 10.0
@export var balance_visual_rot_deg: float = 1.6
@export var balance_yellow_threshold: float = 0.17
@export var balance_orange_threshold: float = 0.50
@export var balance_red_threshold: float = 0.83
@export var balance_jam_noise_rate: float = 10.0
@export var balance_red_slam_noise_bonus: int = 4
@export var balance_green_open_speed: float = 0.42
@export var balance_yellow_open_speed: float = 0.20
@export var balance_open_speed_scale: float = 0.62
@export var balance_red_grip_loss_delay_s: float = 0.12

@onready var background: Sprite2D = $Background
@onready var open_drawer: Sprite2D = $OpenDrawer
@onready var table_top: Sprite2D = $TableTop
@onready var case_file: Sprite2D = $ClosedCaseFolder
@onready var drawer_handle: Sprite2D = find_child("Handle", true, false) as Sprite2D
@onready var drop_zone_indicator: Control = $DropZoneIndicator
@onready var balance_gauge: DrawerBalanceGauge = $BalanceGauge
@onready var noise_meter_pip: Control = $NoiseMeterPiP
@onready var noise_meter_pip_frame: Control = $NoiseMeterPiP/Frame
@onready var noise_meter_pip_viewport: SubViewport = $NoiseMeterPiP/PipViewport
@onready var noise_meter_pip_snapshot: Sprite2D = $NoiseMeterPiP/PipSnapshot

var _pull_ratio: float = 0.0
var _drag_drawer: bool = false
var _noise_points: int = 0
var _last_tick_ms: int = 0
var _locked: bool = false
var _drawer_track_origin: Vector2 = Vector2.ZERO
var _drawer_min_position: Vector2 = Vector2.ZERO
var _drawer_max_position: Vector2 = Vector2.ZERO
var _drawer_base_pos: Vector2 = Vector2.ZERO
var _layout_captured: bool = false
var _background_design_pos: Vector2 = Vector2.ZERO
var _open_drawer_design_pos: Vector2 = Vector2.ZERO
var _table_top_design_pos: Vector2 = Vector2.ZERO
var _case_file_design_pos: Vector2 = Vector2.ZERO
var _handle_design_pos: Vector2 = Vector2.ZERO
var _handle_drawer_offset_design: Vector2 = Vector2.ZERO
var _handle_design_scale: Vector2 = Vector2.ONE
var _handle_design_rot: float = 0.0
var _filing_in_progress: bool = false
var _fade_rect: ColorRect = null
var _drawer_locked_open: bool = false
var _balance_value: float = 0.0
var _safe_center: float = 0.0
var _safe_target: float = 0.0
var _safe_timer: float = 0.0
var _safe_wander_phase: float = 0.0
var _scrape_accum: float = 0.0
var _drag_dx_accum: float = 0.0
var _pull_speed: float = 0.0
var _balance_velocity: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _slam_closing: bool = false
var _balance_danger_current: float = 0.0
var _pull_intent_strength: float = 0.0
var _jam_noise_accum: float = 0.0
var _red_hold_accum: float = 0.0
var _pip_sound_source: Sprite2D = null
var _pip_editor_texture_mode: bool = false
var _pip_editor_source_viewport: SubViewport = null
var _pip_editor_live_container: SubViewportContainer = null
var _pip_editor_scene_root: Node = null
var _pip_runtime_target_node: Node2D = null
var _pip_editor_target_node: Node2D = null
var _pip_runtime_camera: Camera2D = null
var _pip_editor_camera: Camera2D = null
var _pip_calibration_active: bool = false
var _pip_calibration_label: Label = null
var _pip_last_capture_rect_screen: Rect2 = Rect2()
var _pip_last_capture_rect_valid: bool = false
var _case_noise_cb: Callable = Callable()
var _case_noise_policy: InterrogationTimePolicy = null
var _drawer_handle_outline: Sprite2D = null

func _pip_is_follow_mode() -> bool:
	return pip_source_mode == PipSourceMode.FOLLOW_TARGET

func configure_from_payload(payload: Dictionary) -> void:
	if payload == null:
		return
	var noise_cb_v: Variant = payload.get("on_case_handling_noise", null)
	if noise_cb_v is Callable:
		_case_noise_cb = noise_cb_v as Callable
	var noise_policy_v: Variant = payload.get("noise_policy", null)
	if noise_policy_v is InterrogationTimePolicy:
		_case_noise_policy = noise_policy_v as InterrogationTimePolicy
	var center_v: Variant = payload.get("pip_source_center_px", null)
	if center_v is Vector2:
		pip_source_center_px = center_v as Vector2
	var size_v: Variant = payload.get("pip_source_size_px", null)
	if size_v is Vector2:
		pip_source_size_px = size_v as Vector2
	_layout_noise_meter_pip()
	_update_live_pip_region()

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		_ensure_runtime_drawer_handle_parenting()
		_ensure_drawer_handle_outline()
		_setup_live_pip_feed()
		if editor_preview_runtime_layout:
			_capture_design_layout_once()
			_fit_scene_for_size(editor_preview_size)
			_rebuild_drawer_track()
			_update_visual_state()
			_update_ui()
		_update_live_pip_region()
		_layout_noise_meter_pip()
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_ensure_runtime_drawer_handle_parenting()
	_ensure_drawer_handle_outline()
	_pull_ratio = 0.0
	_drawer_locked_open = false
	_capture_design_layout_once()
	_ensure_fade_rect()
	_apply_layer_order()
	if auto_fit_to_viewport:
		_fit_scene_to_viewport()

	_rebuild_drawer_track()
	_cache_pip_sound_source()
	_setup_live_pip_feed()
	_layout_noise_meter_pip()
	_pip_calibration_active = pip_runtime_calibration_start_active

	case_file.visible = false
	if balance_gauge != null:
		balance_gauge.visible = false
	_reset_noise_meter_pip()
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)

	_update_visual_state()
	_update_ui()
	_ensure_pip_calibration_ui()
	_refresh_pip_calibration_ui()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_setup_live_pip_feed()
		if editor_preview_runtime_layout:
			_fit_scene_for_size(editor_preview_size)
			_rebuild_drawer_track()
			_update_visual_state()
			_update_ui()
		_update_live_pip_region()
		_layout_noise_meter_pip()
		return

	_update_live_pip_region()
	if _pip_calibration_active:
		_refresh_pip_calibration_ui()
		queue_redraw()

	if not balance_enabled or not _drag_drawer:
		return

	var speed_mul: float = clampf(_pull_speed / 0.9, 0.0, 1.0)
	var target_interval: float = lerpf(balance_target_interval_slow, balance_target_interval_fast, speed_mul)
	_safe_timer += _delta
	if _safe_timer >= target_interval:
		_safe_timer = 0.0
		_safe_target = _rng.randf_range(-0.85, 0.85)

	var follow: float = lerpf(balance_center_lerp_slow, balance_center_lerp_fast, speed_mul)
	var k: float = 1.0 - exp(-follow * _delta)
	_safe_center = lerpf(_safe_center, _safe_target, k)
	var wander_hz: float = lerpf(balance_center_wander_hz_slow, balance_center_wander_hz_fast, speed_mul)
	_safe_wander_phase = wrapf(_safe_wander_phase + (TAU * wander_hz * _delta), 0.0, TAU)
	var effective_safe_center: float = clampf(_safe_center + (sin(_safe_wander_phase) * balance_center_wander_amp), -0.92, 0.92)

	var width: float = lerpf(balance_safe_width_slow, balance_safe_width_fast, speed_mul)
	var drift_rate: float = lerpf(balance_drift_rate_slow, balance_drift_rate_fast, speed_mul)

	var drag_dx_used: float = clampf(_drag_dx_accum, -balance_mouse_max_px_per_frame, balance_mouse_max_px_per_frame)
	var mouse_input: float = drag_dx_used * balance_correction_per_px
	var control_force: float = mouse_input * balance_mouse_force_gain
	var random_force: float = _rng.randf_range(-1.0, 1.0) * drift_rate
	var restoring_force: float = -_balance_value * balance_needle_stiffness
	var accel: float = control_force + random_force + restoring_force
	_balance_velocity += accel * _delta
	_balance_velocity /= (1.0 + maxf(0.0, balance_needle_damping) * _delta)
	_drag_dx_accum = 0.0
	_balance_value += mouse_input * balance_mouse_direct_gain
	_balance_value += _balance_velocity * _delta
	_balance_value = clampf(_balance_value, -1.0, 1.0)
	if absf(_balance_value) >= 0.999:
		_balance_velocity = 0.0

	# Scrape danger stays tied to leaving the safe band.
	var dist: float = absf(_balance_value - effective_safe_center) - (width * 0.5)
	if dist > 0.0:
		_scrape_accum += dist * balance_scrape_rate * (1.0 + speed_mul * 1.2) * _delta
		var pts: int = int(floor(_scrape_accum))
		if pts > 0:
			_scrape_accum -= float(pts)
			_add_noise_points(pts, "rail scrape")
	else:
		_scrape_accum = maxf(_scrape_accum - _delta * 0.5, 0.0)

	# Zone danger matches DrawerBalanceGauge._zone_color_for_t exactly.
	var max_dist: float = maxf(absf(-1.0 - effective_safe_center), absf(1.0 - effective_safe_center))
	if max_dist <= 0.001:
		max_dist = 1.0
	var zone_danger: float = clampf(absf(_balance_value - effective_safe_center) / max_dist, 0.0, 1.0)

	_balance_danger_current = zone_danger
	_pull_intent_strength = 1.0
	if zone_danger >= balance_orange_threshold and zone_danger < balance_red_threshold:
		var jam_norm: float = clampf((zone_danger - balance_orange_threshold) / maxf(0.001, balance_red_threshold - balance_orange_threshold), 0.0, 1.0)
		_jam_noise_accum += balance_jam_noise_rate * jam_norm * _pull_intent_strength * (1.0 + speed_mul) * _delta
		var jam_pts: int = int(floor(_jam_noise_accum))
		if jam_pts > 0:
			_jam_noise_accum -= float(jam_pts)
			_add_noise_points(jam_pts, "rail jam")
	else:
		_jam_noise_accum = maxf(_jam_noise_accum - _delta * 0.5, 0.0)

	var zone: int = _get_balance_zone(zone_danger)
	if zone == 3:
		_red_hold_accum += _delta
		if _red_hold_accum >= balance_red_grip_loss_delay_s and not _slam_closing and not _filing_in_progress and not _locked:
			_trigger_lost_grip_slam()
			return
	else:
		_red_hold_accum = 0.0

	if zone == 0:
		_set_pull_ratio(_pull_ratio + (balance_green_open_speed * balance_open_speed_scale * _delta), Time.get_ticks_msec())
	elif zone == 1:
		_set_pull_ratio(_pull_ratio + (balance_yellow_open_speed * balance_open_speed_scale * _delta), Time.get_ticks_msec())

	if balance_gauge != null:
		balance_gauge.yellow_threshold = balance_yellow_threshold
		balance_gauge.orange_threshold = balance_orange_threshold
		balance_gauge.red_threshold = balance_red_threshold
		balance_gauge.set_state(_balance_value, effective_safe_center, width, zone_danger)
	_apply_balance_transform()
	_update_ui()

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _handle_pip_calibration_key(event as InputEventKey):
			get_viewport().set_input_as_handled()
			return
	if _locked:
		return
	if _filing_in_progress:
		return
	if _slam_closing:
		return

	var now_ms: int = Time.get_ticks_msec()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_pos: Vector2 = get_viewport().get_mouse_position()
			if _is_file_drop_ready() and _get_drop_zone_rect().has_point(mouse_pos):
				_start_filing_sequence()
				return
			var click_target: Sprite2D = drawer_handle if drawer_handle != null else open_drawer
			if _is_over_sprite(click_target, mouse_pos):
				_drag_drawer = true
				_last_tick_ms = now_ms
				_balance_begin()
				_update_handle_visual()
				return
		else:
			var was_dragging: bool = _drag_drawer
			_drag_drawer = false
			_balance_end()
			_pull_intent_strength = 0.0
			_update_handle_visual()
			if was_dragging and _pull_ratio < 0.999 and not _filing_in_progress and not _locked:
				_add_noise_points(balance_release_slam_noise, "drawer slam")
				_drawer_locked_open = false
				_slam_close_to_min()
				_pull_speed = 0.0

	if event is InputEventMouseMotion and _drag_drawer:
		_drag_dx_accum += event.relative.x

func _handle_pip_calibration_key(event: InputEventKey) -> bool:
	if not pip_runtime_calibration_hotkey_enabled:
		return false
	if event.keycode == KEY_F8:
		_pip_calibration_active = not _pip_calibration_active
		_ensure_pip_calibration_ui()
		_refresh_pip_calibration_ui()
		queue_redraw()
		_print_pip_calibration_values()
		return true
	if not _pip_calibration_active:
		return false

	var step: float = pip_runtime_calibration_step_px
	if event.shift_pressed and not event.ctrl_pressed:
		# Shift is used for source-rect resize; keep step default unless Ctrl is not held.
		step = pip_runtime_calibration_step_px
	if event.ctrl_pressed and event.shift_pressed:
		# Ctrl+Shift is frame resize; keep normal step by default.
		step = pip_runtime_calibration_step_px
	if event.keycode == KEY_PAGEUP:
		pip_runtime_calibration_step_px = minf(64.0, pip_runtime_calibration_step_px + 1.0)
		_refresh_pip_calibration_ui()
		return true
	if event.keycode == KEY_PAGEDOWN:
		pip_runtime_calibration_step_px = maxf(1.0, pip_runtime_calibration_step_px - 1.0)
		_refresh_pip_calibration_ui()
		return true
	if event.alt_pressed:
		step = 1.0
	step = maxf(1.0, step)

	var dx: float = 0.0
	var dy: float = 0.0
	match event.keycode:
		KEY_LEFT:
			dx = -step
		KEY_RIGHT:
			dx = step
		KEY_UP:
			dy = -step
		KEY_DOWN:
			dy = step
		_:
			pass

	var changed: bool = false
	if dx != 0.0 or dy != 0.0:
		if event.ctrl_pressed:
			# Ctrl = adjust on-screen PiP frame (NoiseMeterPiP control).
			if noise_meter_pip != null:
				if event.shift_pressed:
					# Ctrl+Shift+Arrows = resize display frame.
					noise_meter_pip.offset_right += dx
					noise_meter_pip.offset_bottom += dy
				else:
					noise_meter_pip.offset_left += dx
					noise_meter_pip.offset_right += dx
					noise_meter_pip.offset_top += dy
					noise_meter_pip.offset_bottom += dy
				_layout_noise_meter_pip()
				changed = true
		else:
			if event.shift_pressed:
				# Shift+Arrows = resize capture source rect.
				pip_source_size_px = Vector2(
					maxf(8.0, pip_source_size_px.x + dx),
					maxf(8.0, pip_source_size_px.y + dy)
				)
			else:
				# Arrows = move capture source center.
				pip_source_center_px += Vector2(dx, dy)
			_update_live_pip_region()
			_layout_noise_meter_pip()
			changed = true

	if event.keycode == KEY_P:
		_print_pip_calibration_values()
		return true
	if changed:
		_refresh_pip_calibration_ui()
		queue_redraw()
		_print_pip_calibration_values()
		return true
	return false

func _ensure_pip_calibration_ui() -> void:
	if Engine.is_editor_hint():
		return
	if _pip_calibration_label != null and is_instance_valid(_pip_calibration_label):
		return
	_pip_calibration_label = Label.new()
	_pip_calibration_label.name = "PipCalibrationLabel"
	_pip_calibration_label.visible = false
	_pip_calibration_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pip_calibration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pip_calibration_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_pip_calibration_label.position = Vector2(16.0, 16.0)
	_pip_calibration_label.z_index = 500
	_pip_calibration_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_pip_calibration_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_pip_calibration_label.add_theme_constant_override("outline_size", 4)
	add_child(_pip_calibration_label)

func _refresh_pip_calibration_ui() -> void:
	if Engine.is_editor_hint():
		return
	_ensure_pip_calibration_ui()
	if _pip_calibration_label == null or not is_instance_valid(_pip_calibration_label):
		return
	_pip_calibration_label.visible = _pip_calibration_active
	if not _pip_calibration_active:
		return
	var frame_rect: Rect2 = Rect2(
		Vector2(noise_meter_pip.offset_left, noise_meter_pip.offset_top),
		Vector2(noise_meter_pip.offset_right - noise_meter_pip.offset_left, noise_meter_pip.offset_bottom - noise_meter_pip.offset_top)
	)
	var mode_text: String = "FOLLOW" if _pip_is_follow_mode() else "MANUAL"
	_pip_calibration_label.text = (
		"PiP CALIBRATION (F8 toggle, P print)\n" +
		"Arrows: move capture center | Shift+Arrows: resize capture\n" +
		"Ctrl+Arrows: move PiP frame | Ctrl+Shift+Arrows: resize PiP frame\n" +
		"Alt=fine step | PgUp/PgDn step=(%.0f)\n" % [pip_runtime_calibration_step_px] +
		("Mode: %s  Center=(%.1f, %.1f)  Size=(%.1f, %.1f)\n" % [mode_text, pip_source_center_px.x, pip_source_center_px.y, pip_source_size_px.x, pip_source_size_px.y]) +
		("Frame=(%.1f, %.1f, %.1f, %.1f)\n" % [frame_rect.position.x, frame_rect.position.y, frame_rect.size.x, frame_rect.size.y]) +
		("FollowOffset=(%.1f, %.1f)" % [pip_source_follow_offset_px.x, pip_source_follow_offset_px.y])
	)

func _print_pip_calibration_values() -> void:
	if Engine.is_editor_hint():
		return
	print("[PIP CAL] center=", pip_source_center_px, " size=", pip_source_size_px,
		" frame_offsets=(", noise_meter_pip.offset_left, ",", noise_meter_pip.offset_top, ",", noise_meter_pip.offset_right, ",", noise_meter_pip.offset_bottom, ")")

func _set_pull_ratio(v: float, now_ms: int) -> void:
	if lock_drawer_at_max_open and _drawer_locked_open:
		v = 1.0
	var new_ratio: float = clampf(v, 0.0, 1.0)
	var dt: float = 0.0
	if _last_tick_ms > 0:
		dt = float(max(1, now_ms - _last_tick_ms)) / 1000.0
	if dt > 0.0:
		_pull_speed = absf(new_ratio - _pull_ratio) / dt
	else:
		_pull_speed = 0.0

	if absf(new_ratio - _pull_ratio) < 0.0001:
		_last_tick_ms = now_ms
		return

	_last_tick_ms = now_ms

	if lock_drawer_at_max_open and new_ratio >= 0.999:
		new_ratio = 1.0
		_drawer_locked_open = true
		if _drag_drawer:
			_drag_drawer = false
			_pull_speed = 0.0
			_balance_end()

	_pull_ratio = new_ratio
	_update_visual_state()
	_update_ui()

func _update_visual_state() -> void:
	_drawer_base_pos = _drawer_min_position.lerp(_drawer_max_position, _pull_ratio)
	_apply_balance_transform()
	_position_balance_gauge()
	_refresh_drop_zone_indicator()
	_update_ui_for_state()

func _update_ui() -> void:
	pass

func _update_ui_for_state() -> void:
	pass

func _apply_balance_transform() -> void:
	var shift: float = _balance_value * balance_visual_shift_px
	open_drawer.position = _drawer_base_pos + Vector2(shift, 0.0)
	open_drawer.rotation = deg_to_rad(_balance_value * balance_visual_rot_deg)
	_update_handle_visual()

func _position_balance_gauge() -> void:
	if balance_gauge == null or open_drawer == null or open_drawer.texture == null:
		return
	var drawer_rect: Rect2 = _sprite_global_rect(open_drawer)
	var sx: float = absf(open_drawer.scale.x)
	var sy: float = absf(open_drawer.scale.y)
	var design_rect: Rect2 = Rect2(740.0, 760.0, 440.0, 180.0)
	var v: Variant = balance_gauge.get("design_rect_px")
	if v is Rect2:
		design_rect = v
	balance_gauge.global_position = drawer_rect.position + Vector2(design_rect.position.x * sx, design_rect.position.y * sy)
	balance_gauge.size = Vector2(design_rect.size.x * sx, design_rect.size.y * sy)

func _on_viewport_size_changed() -> void:
	if Engine.is_editor_hint():
		return
	if auto_fit_to_viewport:
		_fit_scene_to_viewport()
	_rebuild_drawer_track()
	_layout_noise_meter_pip()
	_update_visual_state()

func _layout_noise_meter_pip() -> void:
	if noise_meter_pip == null or noise_meter_pip_snapshot == null:
		return
	var pip_size: Vector2 = noise_meter_pip.size
	if pip_size.x <= 1.0 or pip_size.y <= 1.0:
		pip_size = Vector2(
			maxf(1.0, noise_meter_pip.offset_right - noise_meter_pip.offset_left),
			maxf(1.0, noise_meter_pip.offset_bottom - noise_meter_pip.offset_top)
		)
	noise_meter_pip.visible = true
	noise_meter_pip.modulate = Color(1, 1, 1, 1)
	if noise_meter_pip_frame != null:
		noise_meter_pip_frame.visible = true
	noise_meter_pip_snapshot.visible = true
	noise_meter_pip_snapshot.modulate = Color(1, 1, 1, 1)
	noise_meter_pip_snapshot.centered = true
	var tex_size: Vector2 = Vector2(256.0, 256.0)
	if noise_meter_pip_snapshot.texture != null:
		tex_size = noise_meter_pip_snapshot.texture.get_size()
		if noise_meter_pip_snapshot.region_enabled and noise_meter_pip_snapshot.region_rect.size.x > 1.0 and noise_meter_pip_snapshot.region_rect.size.y > 1.0:
			# Match runtime/editor framing when the sprite shows only a cropped region from a larger texture.
			tex_size = noise_meter_pip_snapshot.region_rect.size
		if tex_size.x <= 1.0 or tex_size.y <= 1.0:
			return
	var fit: float = maxf(pip_size.x / maxf(1.0, tex_size.x), pip_size.y / maxf(1.0, tex_size.y))
	var scale_mul: float = maxf(0.05, pip_meter_scale.x)
	noise_meter_pip_snapshot.scale = Vector2.ONE * fit * scale_mul
	noise_meter_pip_snapshot.position = (pip_size * 0.5) + pip_meter_offset
	noise_meter_pip_snapshot.z_index = pip_meter_z_index

func _cache_pip_sound_source() -> void:
	if _pip_sound_source != null and is_instance_valid(_pip_sound_source):
		return
	var root: Node = get_tree().current_scene
	if root == null:
		return
	_pip_sound_source = root.find_child("Sound", true, false) as Sprite2D

func _cache_pip_runtime_target() -> void:
	if _pip_runtime_target_node != null and is_instance_valid(_pip_runtime_target_node):
		return
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var target: Node = null
	if not pip_source_target_path.is_empty():
		target = root.get_node_or_null(pip_source_target_path)
	if target == null:
		target = root.find_child("NoiseMeter", true, false)
	if target is Node2D:
		_pip_runtime_target_node = target as Node2D
	_pip_runtime_camera = root.find_child("Camera2D", true, false) as Camera2D

func _cache_pip_editor_target() -> void:
	if _pip_editor_target_node != null and is_instance_valid(_pip_editor_target_node):
		return
	if _pip_editor_scene_root == null or not is_instance_valid(_pip_editor_scene_root):
		return
	var target: Node = null
	if not pip_source_target_path.is_empty():
		target = _pip_editor_scene_root.get_node_or_null(pip_source_target_path)
	if target == null:
		target = _pip_editor_scene_root.find_child("NoiseMeter", true, false)
	if target is Node2D:
		_pip_editor_target_node = target as Node2D
	_pip_editor_camera = _pip_editor_scene_root.find_child("Camera2D", true, false) as Camera2D

func _setup_live_pip_feed() -> void:
	if noise_meter_pip_snapshot == null or noise_meter_pip_viewport == null:
		return
	noise_meter_pip_snapshot.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if Engine.is_editor_hint() and not pip_editor_preview_enabled:
		_pip_editor_texture_mode = false
		_clear_editor_pip_preview_scene()
		noise_meter_pip_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		noise_meter_pip_snapshot.texture = null
		noise_meter_pip_snapshot.region_enabled = false
		return
	if Engine.is_editor_hint() and pip_editor_preview_enabled and pip_editor_preview_scene != null:
		_pip_editor_texture_mode = false
		_ensure_editor_pip_preview_scene()
		if _pip_editor_source_viewport == null or not is_instance_valid(_pip_editor_source_viewport) or _pip_editor_source_viewport.world_2d == null:
			noise_meter_pip_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			noise_meter_pip_snapshot.texture = null
			noise_meter_pip_snapshot.region_enabled = false
			return
		noise_meter_pip_viewport.disable_3d = true
		noise_meter_pip_viewport.transparent_bg = true
		noise_meter_pip_viewport.handle_input_locally = false
		noise_meter_pip_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if _pip_editor_source_viewport != null and is_instance_valid(_pip_editor_source_viewport):
			noise_meter_pip_viewport.world_2d = _pip_editor_source_viewport.world_2d
		noise_meter_pip_snapshot.texture = noise_meter_pip_viewport.get_texture()
		noise_meter_pip_snapshot.region_enabled = false
		noise_meter_pip_snapshot.flip_h = false
		noise_meter_pip_snapshot.flip_v = false
		return
	# Texture preview is fallback-only. Prefer live scene preview for 1:1 authoring.
	if Engine.is_editor_hint() and pip_editor_preview_enabled and pip_editor_preview_texture != null:
		_clear_editor_pip_preview_scene()
		_pip_editor_texture_mode = true
		noise_meter_pip_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		noise_meter_pip_snapshot.texture = pip_editor_preview_texture
		noise_meter_pip_snapshot.region_enabled = true
		noise_meter_pip_snapshot.flip_h = false
		noise_meter_pip_snapshot.flip_v = false
		return
	_pip_editor_texture_mode = false
	_clear_editor_pip_preview_scene()
	noise_meter_pip_viewport.disable_3d = true
	noise_meter_pip_viewport.transparent_bg = true
	noise_meter_pip_viewport.handle_input_locally = false
	noise_meter_pip_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	noise_meter_pip_viewport.world_2d = get_viewport().world_2d
	noise_meter_pip_snapshot.texture = noise_meter_pip_viewport.get_texture()
	noise_meter_pip_snapshot.region_enabled = false
	noise_meter_pip_snapshot.flip_h = false
	noise_meter_pip_snapshot.flip_v = false

func _update_live_pip_region() -> void:
	if noise_meter_pip_snapshot == null or noise_meter_pip_viewport == null:
		return
	if Engine.is_editor_hint() and not pip_editor_preview_enabled:
		return
	if noise_meter_pip_snapshot.texture == null:
		return
	var root_vp: Viewport = get_viewport()
	var source_vp: Viewport = root_vp
	var using_editor_live_preview: bool = Engine.is_editor_hint() and pip_editor_preview_enabled and not _pip_editor_texture_mode
	var vp_size: Vector2 = Vector2.ZERO
	if using_editor_live_preview:
		if _pip_editor_source_viewport == null or not is_instance_valid(_pip_editor_source_viewport):
			return
		source_vp = _pip_editor_source_viewport
		vp_size = editor_preview_size
	elif _pip_editor_texture_mode:
		vp_size = noise_meter_pip_snapshot.texture.get_size()
	else:
		if root_vp == null:
			return
		vp_size = root_vp.get_visible_rect().size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		return
	var center: Vector2 = pip_source_center_px
	if using_editor_live_preview:
		if _pip_is_follow_mode():
			_cache_pip_editor_target()
			if _pip_editor_target_node != null and is_instance_valid(_pip_editor_target_node):
				center = _pip_target_screen_center(source_vp, _pip_editor_target_node)
			else:
				# Fall back to manual center in editor if target path is invalid.
				center = pip_source_center_px
	elif not _pip_editor_texture_mode:
		if _pip_is_follow_mode():
			_cache_pip_runtime_target()
			if _pip_runtime_target_node != null and is_instance_valid(_pip_runtime_target_node):
				center = _pip_target_screen_center(root_vp, _pip_runtime_target_node)
			else:
				_cache_pip_sound_source()
				if _pip_sound_source != null and is_instance_valid(_pip_sound_source):
					center = _sprite_screen_rect_in_viewport(root_vp, _pip_sound_source).get_center()
	# Treat follow offset as a general pan control in both modes.
	center += pip_source_follow_offset_px
	var cap_size: Vector2 = Vector2(maxf(8.0, pip_source_size_px.x), maxf(8.0, pip_source_size_px.y))
	var left: float = clampf(center.x - cap_size.x * 0.5, 0.0, maxf(0.0, vp_size.x - cap_size.x))
	var top: float = clampf(center.y - cap_size.y * 0.5, 0.0, maxf(0.0, vp_size.y - cap_size.y))
	_pip_last_capture_rect_screen = Rect2(left, top, cap_size.x, cap_size.y)
	_pip_last_capture_rect_valid = true
	if _pip_editor_texture_mode:
		noise_meter_pip_snapshot.region_enabled = true
		noise_meter_pip_snapshot.region_rect = Rect2(left, top, cap_size.x, cap_size.y)
		return
	var sv_size: Vector2i = Vector2i(maxi(8, int(round(cap_size.x))), maxi(8, int(round(cap_size.y))))
	if noise_meter_pip_viewport.size != sv_size:
		noise_meter_pip_viewport.size = sv_size
		_layout_noise_meter_pip()
	var main_canvas_xform: Transform2D = _pip_canvas_transform_for(source_vp)
	main_canvas_xform.origin -= Vector2(left, top)
	noise_meter_pip_viewport.canvas_transform = main_canvas_xform

func _draw() -> void:
	if Engine.is_editor_hint():
		return
	if not _pip_calibration_active:
		return
	if _pip_last_capture_rect_valid:
		draw_rect(_pip_last_capture_rect_screen, Color(0.15, 1.0, 0.35, 0.95), false, 2.0)
		var c: Vector2 = _pip_last_capture_rect_screen.get_center()
		draw_line(c + Vector2(-10, 0), c + Vector2(10, 0), Color(0.15, 1.0, 0.35, 0.95), 2.0)
		draw_line(c + Vector2(0, -10), c + Vector2(0, 10), Color(0.15, 1.0, 0.35, 0.95), 2.0)

func _ensure_editor_pip_preview_scene() -> void:
	if noise_meter_pip_viewport == null:
		return
	if _pip_editor_scene_root == null or not is_instance_valid(_pip_editor_scene_root):
		_clear_editor_pip_preview_scene()
	if _pip_editor_source_viewport == null or not is_instance_valid(_pip_editor_source_viewport):
		_pip_editor_source_viewport = SubViewport.new()
		_pip_editor_source_viewport.name = &"PipEditorSourceViewport"
		_pip_editor_source_viewport.disable_3d = true
		_pip_editor_source_viewport.transparent_bg = true
		_pip_editor_source_viewport.handle_input_locally = false
		_pip_editor_source_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_pip_editor_source_viewport)
		if Engine.is_editor_hint():
			_pip_editor_source_viewport.owner = null
	if _pip_editor_source_viewport.world_2d == null:
		_pip_editor_source_viewport.world_2d = World2D.new()
	_pip_editor_source_viewport.size = Vector2i(maxi(8, int(editor_preview_size.x)), maxi(8, int(editor_preview_size.y)))
	if _pip_editor_scene_root != null and is_instance_valid(_pip_editor_scene_root):
		return
	if pip_editor_preview_scene == null:
		return
	if _pip_editor_source_viewport == null or not is_instance_valid(_pip_editor_source_viewport):
		return
	var inst: Node = pip_editor_preview_scene.instantiate()
	if inst == null:
		return
	_pip_editor_scene_root = inst
	_pip_editor_source_viewport.add_child(inst)
	_pip_editor_target_node = null
	_activate_editor_preview_camera(inst)
	if Engine.is_editor_hint():
		inst.owner = null

func _clear_editor_pip_preview_scene() -> void:
	if _pip_editor_scene_root != null and is_instance_valid(_pip_editor_scene_root):
		if Engine.is_editor_hint():
			_pip_editor_scene_root.free()
		else:
			_pip_editor_scene_root.queue_free()
	_pip_editor_scene_root = null
	if _pip_editor_live_container != null and is_instance_valid(_pip_editor_live_container):
		if Engine.is_editor_hint():
			_pip_editor_live_container.free()
		else:
			_pip_editor_live_container.queue_free()
	_pip_editor_live_container = null
	if _pip_editor_source_viewport != null and is_instance_valid(_pip_editor_source_viewport):
		if Engine.is_editor_hint():
			_pip_editor_source_viewport.free()
		else:
			_pip_editor_source_viewport.queue_free()
	_pip_editor_source_viewport = null
	_pip_editor_target_node = null
	_pip_editor_camera = null

func _ensure_editor_live_pip_container() -> void:
	if noise_meter_pip == null:
		return
	if _pip_editor_live_container != null and is_instance_valid(_pip_editor_live_container):
		return
	_pip_editor_live_container = SubViewportContainer.new()
	_pip_editor_live_container.name = &"PipEditorLiveContainer"
	_pip_editor_live_container.anchor_left = 0.0
	_pip_editor_live_container.anchor_top = 0.0
	_pip_editor_live_container.anchor_right = 1.0
	_pip_editor_live_container.anchor_bottom = 1.0
	_pip_editor_live_container.offset_left = 0.0
	_pip_editor_live_container.offset_top = 0.0
	_pip_editor_live_container.offset_right = 0.0
	_pip_editor_live_container.offset_bottom = 0.0
	_pip_editor_live_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Must be false because the preview code resizes the SubViewport to match capture size.
	# Godot warns every frame if a stretched SubViewportContainer owns a resized SubViewport.
	_pip_editor_live_container.stretch = false
	noise_meter_pip.add_child(_pip_editor_live_container)
	if Engine.is_editor_hint():
		_pip_editor_live_container.owner = null
	if noise_meter_pip_frame != null:
		var frame_idx: int = noise_meter_pip.get_children().find(noise_meter_pip_frame)
		if frame_idx >= 0:
			noise_meter_pip.move_child(_pip_editor_live_container, frame_idx)

func _move_pip_viewport_to_editor_container() -> void:
	if _pip_editor_live_container == null or not is_instance_valid(_pip_editor_live_container):
		return
	if noise_meter_pip_viewport == null:
		return
	if noise_meter_pip_viewport.get_parent() == _pip_editor_live_container:
		return
	var old_parent: Node = noise_meter_pip_viewport.get_parent()
	if old_parent != null:
		old_parent.remove_child(noise_meter_pip_viewport)
	_pip_editor_live_container.add_child(noise_meter_pip_viewport)
	if Engine.is_editor_hint():
		noise_meter_pip_viewport.owner = null

func _restore_pip_viewport_parent() -> void:
	if noise_meter_pip == null or noise_meter_pip_viewport == null:
		return
	if noise_meter_pip_viewport.get_parent() == noise_meter_pip:
		return
	var old_parent: Node = noise_meter_pip_viewport.get_parent()
	if old_parent != null:
		old_parent.remove_child(noise_meter_pip_viewport)
	noise_meter_pip.add_child(noise_meter_pip_viewport)
	if noise_meter_pip_snapshot != null:
		var snapshot_idx: int = noise_meter_pip.get_children().find(noise_meter_pip_snapshot)
		if snapshot_idx >= 0:
			noise_meter_pip.move_child(noise_meter_pip_viewport, snapshot_idx)
	if Engine.is_editor_hint():
		noise_meter_pip_viewport.owner = null

func _disable_processing_recursive(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		if child is Node:
			_disable_processing_recursive(child as Node)

func _activate_editor_preview_camera(root: Node) -> void:
	var cam: Camera2D = root.find_child("Camera2D", true, false) as Camera2D
	if cam == null:
		return
	# The preview scene's camera script is not a tool script, so emulate its _ready() camera framing.
	cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	var zoom_scale_v: Variant = cam.get("zoom_scale")
	var zoom_scale: float = 0.84
	if zoom_scale_v is float or zoom_scale_v is int:
		zoom_scale = float(zoom_scale_v)
	cam.zoom = Vector2(zoom_scale, zoom_scale)
	_pip_editor_camera = cam
	cam.enabled = true
	cam.make_current()

func _sprite_screen_rect_in_viewport(vp: Viewport, s: Sprite2D) -> Rect2:
	if s == null or s.texture == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var local_rect: Rect2 = s.get_rect()
	var world_xf: Transform2D = s.global_transform
	var canvas_xf: Transform2D = _pip_canvas_transform_for(vp)
	var p0: Vector2 = canvas_xf * (world_xf * local_rect.position)
	var p1: Vector2 = canvas_xf * (world_xf * (local_rect.position + Vector2(local_rect.size.x, 0.0)))
	var p2: Vector2 = canvas_xf * (world_xf * (local_rect.position + Vector2(0.0, local_rect.size.y)))
	var p3: Vector2 = canvas_xf * (world_xf * (local_rect.position + local_rect.size))
	var min_x: float = minf(minf(p0.x, p1.x), minf(p2.x, p3.x))
	var min_y: float = minf(minf(p0.y, p1.y), minf(p2.y, p3.y))
	var max_x: float = maxf(maxf(p0.x, p1.x), maxf(p2.x, p3.x))
	var max_y: float = maxf(maxf(p0.y, p1.y), maxf(p2.y, p3.y))
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _pip_target_screen_center(vp: Viewport, target: Node2D) -> Vector2:
	if target == null:
		return Vector2.ZERO
	# In editor preview, non-@tool scripts may not expose their class type (e.g. `is NoiseMeterWidget` can fail),
	# so detect the meter origin generically via exported `origin_norm` on the target node.
	var origin_norm_v: Variant = target.get("origin_norm")
	if origin_norm_v is Vector2:
		var origin_norm: Vector2 = origin_norm_v as Vector2
		var sound_sprite: Sprite2D = target.get_parent() as Sprite2D
		if sound_sprite != null and sound_sprite.texture != null:
			var sound_local_rect: Rect2 = sound_sprite.get_rect()
			var local_origin: Vector2 = sound_local_rect.position + Vector2(sound_local_rect.size.x * origin_norm.x, sound_local_rect.size.y * origin_norm.y)
			var world_origin: Vector2 = sound_sprite.global_transform * local_origin
			return _pip_canvas_transform_for(vp) * world_origin
	if target is Sprite2D:
		return _sprite_screen_rect_in_viewport(vp, target as Sprite2D).get_center()
	return _pip_canvas_transform_for(vp) * target.global_position

func _pip_canvas_transform_for(vp: Viewport) -> Transform2D:
	if Engine.is_editor_hint():
		if _pip_editor_camera != null and is_instance_valid(_pip_editor_camera):
			return _pip_editor_camera.get_canvas_transform()
		if vp != null:
			return vp.get_canvas_transform()
	else:
		if _pip_runtime_camera == null or not is_instance_valid(_pip_runtime_camera):
			var root: Node = get_tree().current_scene
			if root != null:
				_pip_runtime_camera = root.find_child("Camera2D", true, false) as Camera2D
		if _pip_runtime_camera != null and is_instance_valid(_pip_runtime_camera):
			return _pip_runtime_camera.get_canvas_transform()
		if vp != null:
			return vp.get_canvas_transform()
	return Transform2D.IDENTITY

func _rebuild_drawer_track() -> void:
	if open_drawer == null:
		return
	var min_offset_y: float = _get_open_drawer_track_min()
	var max_offset_y: float = _get_open_drawer_track_max()
	# Track values are authored in design-space pixels; scale them to runtime.
	var track_scale_y: float = absf(open_drawer.scale.y)
	if track_scale_y <= 0.0001:
		track_scale_y = 1.0
	min_offset_y *= track_scale_y
	max_offset_y *= track_scale_y
	if max_offset_y < min_offset_y:
		var tmp: float = min_offset_y
		min_offset_y = max_offset_y
		max_offset_y = tmp
	_drawer_track_origin = open_drawer.position
	_drawer_min_position = _drawer_track_origin + Vector2(0.0, min_offset_y)
	_drawer_max_position = _drawer_track_origin + Vector2(0.0, max_offset_y)

func _get_open_drawer_track_min() -> float:
	if open_drawer == null:
		return 0.0
	var track0: Variant = open_drawer.get("drawer_track_y_at_0_px")
	if track0 is float or track0 is int:
		return float(track0)
	var raw_px: Variant = open_drawer.get("drawer_track_min_offset_y_px")
	if raw_px is float or raw_px is int:
		return float(raw_px)
	var raw: Variant = open_drawer.get("drawer_track_min_offset_y")
	if raw is float or raw is int:
		return float(raw)
	return 0.0

func _get_open_drawer_track_max() -> float:
	if open_drawer == null:
		return max_pull_px
	var track100: Variant = open_drawer.get("drawer_track_y_at_100_px")
	if track100 is float or track100 is int:
		return float(track100)
	var raw_px: Variant = open_drawer.get("drawer_track_max_offset_y_px")
	if raw_px is float or raw_px is int:
		return float(raw_px)
	var raw: Variant = open_drawer.get("drawer_track_max_offset_y")
	if raw is float or raw is int:
		return float(raw)
	return max_pull_px

func _sprite_global_rect(s: Sprite2D) -> Rect2:
	if s == null or s.texture == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var size: Vector2 = s.texture.get_size() * s.scale.abs()
	var top_left: Vector2 = s.global_position
	if s.centered:
		top_left -= size * 0.5
	return Rect2(top_left, size)

func _is_over_sprite(s: Sprite2D, mouse_pos: Vector2) -> bool:
	if s == null or s.texture == null:
		return false
	return _sprite_global_rect(s).has_point(mouse_pos)

func _fit_scene_to_viewport() -> void:
	_fit_scene_for_size(get_viewport_rect().size)

func _fit_scene_for_size(vp_size: Vector2) -> void:
	if background == null or background.texture == null:
		return
	_capture_design_layout_once()
	var tex_size: Vector2 = background.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return

	var scale_cover: float = maxf(vp_size.x / tex_size.x, vp_size.y / tex_size.y)
	var center: Vector2 = vp_size * 0.5

	if background != null:
		background.centered = true
		background.position = center + ((_background_design_pos - _background_design_pos) * scale_cover)
		background.scale = Vector2.ONE * scale_cover
	if open_drawer != null:
		open_drawer.centered = true
		open_drawer.position = center + ((_open_drawer_design_pos - _background_design_pos) * scale_cover)
		open_drawer.scale = Vector2.ONE * scale_cover
	if table_top != null:
		table_top.centered = true
		table_top.position = center + ((_table_top_design_pos - _background_design_pos) * scale_cover)
		table_top.scale = Vector2.ONE * scale_cover
	if case_file != null:
		case_file.centered = true
		case_file.position = center + ((_case_file_design_pos - _background_design_pos) * scale_cover)
		case_file.scale = Vector2.ONE * scale_cover
	if drawer_handle != null:
		drawer_handle.centered = true
		drawer_handle.position = center + ((_handle_design_pos - _background_design_pos) * scale_cover)
		drawer_handle.scale = _handle_design_scale * scale_cover
		drawer_handle.rotation = _handle_design_rot
	_update_handle_visual()
	_refresh_drop_zone_indicator()

func _capture_design_layout_once() -> void:
	if _layout_captured:
		return
	if background != null:
		_background_design_pos = background.position
	if open_drawer != null:
		_open_drawer_design_pos = open_drawer.position
	if table_top != null:
		_table_top_design_pos = table_top.position
	if case_file != null:
		_case_file_design_pos = case_file.position
	if drawer_handle != null:
		_handle_design_pos = drawer_handle.position
		_handle_design_scale = drawer_handle.scale
		_handle_design_rot = drawer_handle.rotation
		if open_drawer != null:
			_handle_drawer_offset_design = drawer_handle.position - open_drawer.position
	_layout_captured = true

func _apply_layer_order() -> void:
	if background != null:
		background.z_index = 0
	if open_drawer != null:
		open_drawer.z_index = 2
	if table_top != null:
		table_top.z_index = 3
	if case_file != null:
		case_file.z_index = 4
	if drawer_handle != null:
		drawer_handle.z_index = 16
	if balance_gauge != null and balance_gauge is CanvasItem:
		(balance_gauge as CanvasItem).z_index = 14
	if drop_zone_indicator != null and drop_zone_indicator is CanvasItem:
		(drop_zone_indicator as CanvasItem).z_index = 12
	if noise_meter_pip != null and noise_meter_pip is CanvasItem:
		(noise_meter_pip as CanvasItem).z_index = 10
	if noise_meter_pip_snapshot != null:
		noise_meter_pip_snapshot.z_index = pip_meter_z_index
	if _fade_rect != null:
		_fade_rect.z_index = 100

func _ensure_fade_rect() -> void:
	if _fade_rect == null:
		_fade_rect = ColorRect.new()
		_fade_rect.name = &"FadeRect"
		_fade_rect.anchor_left = 0.0
		_fade_rect.anchor_top = 0.0
		_fade_rect.anchor_right = 1.0
		_fade_rect.anchor_bottom = 1.0
		_fade_rect.offset_left = 0.0
		_fade_rect.offset_top = 0.0
		_fade_rect.offset_right = 0.0
		_fade_rect.offset_bottom = 0.0
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_rect.color = Color(0, 0, 0, 1)
		_fade_rect.modulate = Color(1, 1, 1, 0)
		add_child(_fade_rect)
	_apply_layer_order()
	_refresh_drop_zone_indicator()

func _balance_begin() -> void:
	if not balance_enabled:
		return
	_balance_value = 0.0
	_balance_velocity = 0.0
	_safe_center = 0.0
	_safe_target = _rng.randf_range(-0.85, 0.85)
	_safe_timer = 0.0
	_safe_wander_phase = _rng.randf_range(0.0, TAU)
	_scrape_accum = 0.0
	_drag_dx_accum = 0.0
	_update_handle_visual()
	if balance_gauge != null:
		_position_balance_gauge()
		balance_gauge.yellow_threshold = balance_yellow_threshold
		balance_gauge.orange_threshold = balance_orange_threshold
		balance_gauge.red_threshold = balance_red_threshold
		balance_gauge.visible = true
		balance_gauge.set_state(_balance_value, _safe_center, balance_safe_width_slow, 0.0)

func _balance_end() -> void:
	if balance_gauge != null:
		balance_gauge.visible = false
	_balance_value = 0.0
	_red_hold_accum = 0.0
	open_drawer.rotation = 0.0
	_apply_balance_transform()
	_update_handle_visual()

func _add_noise_points(amount: int, _reason: String = "") -> void:
	if amount <= 0:
		return
	if not _case_noise_cb.is_null():
		var total_v: Variant = _case_noise_cb.call(amount, _reason, {"raw_amount": amount})
		if total_v is int:
			_noise_points = maxi(0, int(total_v))
		else:
			_noise_points += amount
	else:
		_noise_points += amount
	_sync_noise_meter_pip(false)
	_update_ui()

func _reset_noise_meter_pip() -> void:
	_noise_points = 0
	_sync_noise_meter_pip(true)

func _sync_noise_meter_pip(_immediate: bool) -> void:
	pass

func _get_balance_zone(danger: float) -> int:
	var d: float = clampf(danger, 0.0, 1.0)
	var y: float = maxf(0.0, minf(balance_yellow_threshold, balance_orange_threshold))
	var o: float = maxf(y + 0.001, minf(balance_orange_threshold, balance_red_threshold))
	var r: float = maxf(o + 0.001, balance_red_threshold)
	if d <= y:
		return 0 # green
	if d <= o:
		return 1 # yellow
	if d < r:
		return 2 # orange
	return 3 # red

func _slam_close_to_min() -> void:
	if _slam_closing:
		return
	_slam_closing = true
	var tween: Tween = create_tween()
	tween.tween_method(_set_pull_ratio_visual, _pull_ratio, 0.0, maxf(0.01, balance_slam_close_duration_s)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_slam_closing = false
	)

func _trigger_lost_grip_slam() -> void:
	_drag_drawer = false
	_pull_intent_strength = 0.0
	_balance_end()
	_add_noise_points(balance_release_slam_noise + balance_red_slam_noise_bonus, "lost grip")
	_drawer_locked_open = false
	_slam_close_to_min()
	_pull_speed = 0.0

func _is_file_drop_ready() -> bool:
	return _pull_ratio >= file_ready_threshold and not _filing_in_progress and not _locked

func _get_drop_zone_rect() -> Rect2:
	if open_drawer == null or open_drawer.texture == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var drawer_rect: Rect2 = _sprite_global_rect(open_drawer)
	var sx: float = absf(open_drawer.scale.x)
	var sy: float = absf(open_drawer.scale.y)
	var design_rect: Rect2 = Rect2(335.0, 165.0, 230.0, 270.0)
	if drop_zone_indicator != null:
		var v: Variant = drop_zone_indicator.get("design_rect_px")
		if v is Rect2:
			design_rect = v
	var pos: Vector2 = drawer_rect.position + Vector2(design_rect.position.x * sx, design_rect.position.y * sy)
	var size: Vector2 = Vector2(design_rect.size.x * sx, design_rect.size.y * sy)
	return Rect2(pos, size)

func _refresh_drop_zone_indicator() -> void:
	if drop_zone_indicator == null:
		return
	var active: bool = _is_file_drop_ready()
	if drop_zone_indicator.has_method("set_active"):
		drop_zone_indicator.call("set_active", active)
	if not _is_file_drop_ready():
		drop_zone_indicator.visible = false
		return
	var r: Rect2 = _get_drop_zone_rect()
	if drop_zone_indicator.has_method("set_runtime_rect"):
		drop_zone_indicator.call("set_runtime_rect", r)
	else:
		drop_zone_indicator.global_position = r.position
		drop_zone_indicator.size = r.size
	drop_zone_indicator.visible = true

func _start_filing_sequence() -> void:
	if _filing_in_progress or _locked:
		return
	_filing_in_progress = true
	_drag_drawer = false
	_drawer_locked_open = false
	_balance_end()
	_update_handle_visual()
	if drop_zone_indicator != null:
		if drop_zone_indicator.has_method("set_active"):
			drop_zone_indicator.call("set_active", false)
		drop_zone_indicator.visible = false

	var drop_rect: Rect2 = _get_drop_zone_rect()
	var drop_center: Vector2 = drop_rect.position + (drop_rect.size * 0.5)
	if case_file != null:
		case_file.visible = true
		case_file.centered = true
		case_file.modulate = Color(1, 1, 1, 0)
		case_file.position = drop_center + Vector2(0.0, -40.0 * absf(open_drawer.scale.y))
		case_file.scale = open_drawer.scale * 0.92
		case_file.z_index = 6

	var tween: Tween = create_tween()
	if case_file != null:
		tween.tween_property(case_file, "modulate:a", 1.0, place_anim_duration_s)
		tween.parallel().tween_property(case_file, "position", drop_center, place_anim_duration_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_pull_ratio_visual, _pull_ratio, 0.0, drawer_close_duration_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _fade_rect != null:
		tween.tween_property(_fade_rect, "modulate:a", 1.0, fade_out_duration_s)
	if fade_black_hold_s > 0.0:
		tween.tween_interval(fade_black_hold_s)
	tween.tween_callback(_complete_filing_sequence)

func _set_pull_ratio_visual(v: float) -> void:
	_pull_ratio = clampf(v, 0.0, 1.0)
	_update_visual_state()
	_update_ui()

func _complete_filing_sequence() -> void:
	_locked = true
	emit_signal("finished", true, _noise_points)
	queue_free()

func _ensure_runtime_drawer_handle_parenting() -> void:
	if drawer_handle == null:
		return
	if drawer_handle.get_parent() == self:
		return
	# If the authored handle was placed under the PiP container (or any other branch),
	# move it to the scene root so it can overlay the real drawer and balance gauge.
	var gpos: Vector2 = drawer_handle.global_position
	var grot: float = drawer_handle.global_rotation
	var gscl: Vector2 = drawer_handle.global_scale
	var old_parent: Node = drawer_handle.get_parent()
	if old_parent != null:
		old_parent.remove_child(drawer_handle)
	add_child(drawer_handle)
	drawer_handle.owner = null if Engine.is_editor_hint() else drawer_handle.owner
	drawer_handle.global_position = gpos
	drawer_handle.global_rotation = grot
	drawer_handle.global_scale = gscl

func _ensure_drawer_handle_outline() -> void:
	if drawer_handle == null or drawer_handle.texture == null:
		return
	if _drawer_handle_outline != null and is_instance_valid(_drawer_handle_outline):
		return
	var outline: Sprite2D = preload("res://Scripts/ui/AlphaOutline.gd").new() as Sprite2D
	if outline == null:
		return
	_drawer_handle_outline = outline
	outline.name = "DrawerHandleHoverOutline"
	outline.texture = drawer_handle.texture
	outline.centered = drawer_handle.centered
	outline.show_behind_parent = false
	outline.z_index = drawer_handle.z_index + 1
	outline.set("outline_color", Color(1, 1, 1, 0.95))
	outline.set("outline_size", 5.5)
	outline.set("outline_softness", 0.35)
	outline.set("pulse_amount", 0.20)
	outline.visible = false
	drawer_handle.add_child(outline)
	if Engine.is_editor_hint():
		outline.owner = null
	_update_handle_visual()

func _update_handle_visual() -> void:
	if drawer_handle == null:
		return
	if open_drawer != null and drawer_handle.get_parent() == self:
		var sx: float = absf(open_drawer.scale.x)
		var sy: float = absf(open_drawer.scale.y)
		var off: Vector2 = Vector2(_handle_drawer_offset_design.x * sx, _handle_drawer_offset_design.y * sy)
		drawer_handle.position = open_drawer.position + off.rotated(open_drawer.rotation)
		drawer_handle.rotation = open_drawer.rotation + _handle_design_rot
		drawer_handle.scale = Vector2(_handle_design_scale.x * sx, _handle_design_scale.y * sy)
	drawer_handle.modulate = Color(1, 1, 1, 1)
	if _drawer_handle_outline != null and is_instance_valid(_drawer_handle_outline):
		_drawer_handle_outline.texture = drawer_handle.texture
		_drawer_handle_outline.centered = drawer_handle.centered
		var show_outline: bool = (not _drag_drawer) and (not _filing_in_progress) and (not _locked) and (not _drawer_locked_open) and _pull_ratio < 0.999
		_drawer_handle_outline.visible = show_outline
		_drawer_handle_outline.z_index = drawer_handle.z_index + 1
