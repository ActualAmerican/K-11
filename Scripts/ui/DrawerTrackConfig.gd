@tool
extends Sprite2D

var _track_y_at_0_px: float = 0.0
var _track_y_at_100_px: float = 655.0
var _track_percent: float = 0.0
var _did_init: bool = false
var _base_position: Vector2 = Vector2.ZERO

@export_range(-4000.0, 4000.0, 1.0, "suffix:px") var drawer_track_y_at_0_px: float:
	get:
		return _track_y_at_0_px
	set(value):
		_track_y_at_0_px = value
		_track_percent = 0.0
		_snap_to(0.0)

@export_range(-4000.0, 4000.0, 1.0, "suffix:px") var drawer_track_y_at_100_px: float:
	get:
		return _track_y_at_100_px
	set(value):
		_track_y_at_100_px = value
		_track_percent = 100.0
		_snap_to(100.0)

@export_range(0.0, 100.0, 0.1, "suffix:%") var drawer_track_percent: float:
	get:
		return _track_percent
	set(value):
		_track_percent = clampf(value, 0.0, 100.0)
		_snap_to(_track_percent)

func _ready() -> void:
	if Engine.is_editor_hint():
		_init_from_current_once()
		_snap_to(_track_percent)
		set_process(true)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_snap_to(_track_percent)

func _init_from_current_once() -> void:
	if _did_init:
		return
	_base_position = position
	_did_init = true

func _snap_to(percent: float) -> void:
	if not Engine.is_editor_hint():
		return
	_init_from_current_once()
	var t: float = clampf(percent / 100.0, 0.0, 1.0)
	var off_y: float = lerpf(_track_y_at_0_px, _track_y_at_100_px, t)
	position = _base_position + Vector2(0.0, off_y)
