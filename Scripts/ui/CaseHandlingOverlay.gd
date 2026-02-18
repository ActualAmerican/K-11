@tool
extends Control

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
@onready var drop_zone_indicator: Control = $DropZoneIndicator
@onready var balance_gauge: DrawerBalanceGauge = $BalanceGauge

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

func _ready() -> void:
	if Engine.is_editor_hint():
		if editor_preview_runtime_layout:
			_capture_design_layout_once()
			_fit_scene_for_size(editor_preview_size)
			_rebuild_drawer_track()
			_update_visual_state()
			_update_ui()
			set_process(true)
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_pull_ratio = 0.0
	_drawer_locked_open = false
	_capture_design_layout_once()
	_ensure_fade_rect()
	_apply_layer_order()
	if auto_fit_to_viewport:
		_fit_scene_to_viewport()

	_rebuild_drawer_track()

	case_file.visible = false
	if balance_gauge != null:
		balance_gauge.visible = false
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)

	_update_visual_state()
	_update_ui()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if not editor_preview_runtime_layout:
			return
		_fit_scene_for_size(editor_preview_size)
		_rebuild_drawer_track()
		_update_visual_state()
		_update_ui()
		return

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
			if _is_over_sprite(open_drawer, mouse_pos):
				_drag_drawer = true
				_last_tick_ms = now_ms
				_balance_begin()
				return
		else:
			var was_dragging: bool = _drag_drawer
			_drag_drawer = false
			_balance_end()
			_pull_intent_strength = 0.0
			if was_dragging and _pull_ratio < 0.999 and not _filing_in_progress and not _locked:
				_add_noise_points(balance_release_slam_noise, "drawer slam")
				_drawer_locked_open = false
				_slam_close_to_min()
				_pull_speed = 0.0

	if event is InputEventMouseMotion and _drag_drawer:
		_drag_dx_accum += event.relative.x

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
	_update_visual_state()

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
	if balance_gauge != null and balance_gauge is CanvasItem:
		(balance_gauge as CanvasItem).z_index = 14
	if drop_zone_indicator != null and drop_zone_indicator is CanvasItem:
		(drop_zone_indicator as CanvasItem).z_index = 12
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

func _add_noise_points(amount: int, _reason: String = "") -> void:
	if amount <= 0:
		return
	_noise_points += amount
	_update_ui()

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
