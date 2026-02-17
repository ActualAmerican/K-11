extends Control

signal finished(success: bool, noise_points: int)
signal cancelled()

@export var max_pull_px: float = 655.0
@export var yank_velocity_px_s: float = 1400.0
@export var yank_noise_points: int = 18
@export var auto_fit_to_viewport: bool = true

@onready var background: Sprite2D = $Background
@onready var open_drawer: Sprite2D = $OpenDrawer
@onready var table_top: Sprite2D = $TableTop
@onready var case_file: Sprite2D = $ClosedCaseFolder
@onready var label_status: Label = $StatusLabel
@onready var label_noise: Label = $NoiseLabel
@onready var btn_done: Button = $DoneButton
@onready var btn_cancel: Button = $CancelButton

var _pull_ratio: float = 0.0
var _drag_drawer: bool = false
var _drag_origin_mouse_y: float = 0.0
var _drag_origin_ratio: float = 0.0
var _noise_points: int = 0
var _last_mouse_y: float = 0.0
var _last_tick_ms: int = 0
var _locked: bool = false
var _drawer_track_origin: Vector2 = Vector2.ZERO
var _drawer_min_position: Vector2 = Vector2.ZERO
var _drawer_max_position: Vector2 = Vector2.ZERO
var _layout_captured: bool = false
var _background_design_pos: Vector2 = Vector2.ZERO
var _open_drawer_design_pos: Vector2 = Vector2.ZERO
var _table_top_design_pos: Vector2 = Vector2.ZERO
var _case_file_design_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_pull_ratio = 0.0
	_capture_design_layout_once()
	_apply_layer_order()
	if auto_fit_to_viewport:
		_fit_scene_to_viewport()

	_rebuild_drawer_track()

	case_file.visible = false
	btn_done.visible = false
	btn_done.disabled = true

	btn_cancel.pressed.connect(_on_cancel_pressed)
	if btn_done != null:
		btn_done.pressed.connect(_on_done_pressed)
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)

	_update_visual_state()
	_update_ui()

func _input(event: InputEvent) -> void:
	if _locked:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_cancel_pressed()
		return

	var now_ms: int = Time.get_ticks_msec()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_pos: Vector2 = get_viewport().get_mouse_position()
			if _is_over_sprite(open_drawer, mouse_pos):
				_drag_drawer = true
				_drag_origin_mouse_y = mouse_pos.y
				_drag_origin_ratio = _pull_ratio
				_last_mouse_y = mouse_pos.y
				_last_tick_ms = now_ms
				return
		else:
			_drag_drawer = false

	if event is InputEventMouseMotion and _drag_drawer:
		var mouse_pos2: Vector2 = get_viewport().get_mouse_position()
		var dy: float = mouse_pos2.y - _drag_origin_mouse_y
		var track_range: float = maxf(0.001, _drawer_max_position.y - _drawer_min_position.y)
		_set_pull_ratio(_drag_origin_ratio + (dy / track_range), now_ms, mouse_pos2.y)

func _set_pull_ratio(v: float, now_ms: int, mouse_y: float) -> void:
	var new_ratio: float = clampf(v, 0.0, 1.0)
	if absf(new_ratio - _pull_ratio) < 0.0001:
		return

	if _last_tick_ms > 0:
		var dt: float = float(max(1, now_ms - _last_tick_ms)) / 1000.0
		var vel: float = absf(mouse_y - _last_mouse_y) / dt
		if vel >= yank_velocity_px_s:
			_noise_points += yank_noise_points

	_last_tick_ms = now_ms
	_last_mouse_y = mouse_y

	_pull_ratio = new_ratio
	_update_visual_state()
	_update_ui()

func _update_visual_state() -> void:
	open_drawer.position = _drawer_min_position.lerp(_drawer_max_position, _pull_ratio)

func _update_ui() -> void:
	label_noise.text = "NOISE: %d" % _noise_points
	label_status.text = "Drag drawer down to open."

func _on_done_pressed() -> void:
	if _locked:
		return
	_locked = true
	emit_signal("finished", true, _noise_points)
	queue_free()

func _on_cancel_pressed() -> void:
	if _locked:
		return
	_locked = true
	emit_signal("cancelled")
	queue_free()

func _on_viewport_size_changed() -> void:
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
	if background == null or background.texture == null:
		return
	_capture_design_layout_once()
	var vp_size: Vector2 = get_viewport_rect().size
	var tex_size: Vector2 = background.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
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
	if label_status != null:
		label_status.z_index = 10
	if label_noise != null:
		label_noise.z_index = 10
	if btn_cancel != null:
		btn_cancel.z_index = 10
	if btn_done != null:
		btn_done.z_index = 10
