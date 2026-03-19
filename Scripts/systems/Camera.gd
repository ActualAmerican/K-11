# Camera.gd

extends Camera2D

@export var zoom_scale: float = 0.84
@export var mouse_pan_enabled: bool = true
@export var safe_zone_margin_px: float = 360.0
@export var snap_offset_world: float = 200.0
@export var snap_strength: float = 5.5

@export var is_overlay_open: bool = false
@export var camera_is_on: bool = true

var _camera_indicator: CanvasItem = null

func set_overlay_open(open: bool) -> void:
	is_overlay_open = open

func set_camera_power(is_on: bool) -> void:
	camera_is_on = is_on
	_apply_camera_indicator()

func is_edge_pan_enabled() -> bool:
	return mouse_pan_enabled

var _default_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	zoom = Vector2(zoom_scale, zoom_scale)
	_default_position = global_position
	_cache_camera_indicator()
	_apply_camera_indicator()

func _cache_camera_indicator() -> void:
	if is_instance_valid(_camera_indicator):
		return
	var names: Array[StringName] = [&"CameraIndicator", &"RecordingLight", &"RedLight", &"CameraLight"]
	for name in names:
		var found: Node = find_child(String(name), true, false)
		if found is CanvasItem:
			_camera_indicator = found as CanvasItem
			return

func _apply_camera_indicator() -> void:
	if not is_instance_valid(_camera_indicator):
		_cache_camera_indicator()
	if not is_instance_valid(_camera_indicator):
		return
	_camera_indicator.visible = camera_is_on
	_camera_indicator.modulate = Color(1.0, 0.2, 0.2, 1.0) if camera_is_on else Color(0.35, 0.1, 0.1, 0.6)

func snap_to_default() -> void:
	global_position = _default_position

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_edge_pan"):
		mouse_pan_enabled = not mouse_pan_enabled
		print("[CAM] edge-pan = ", ("ON" if mouse_pan_enabled else "OFF"), " | overlay_open = ", is_overlay_open)

	if not mouse_pan_enabled or is_overlay_open:
		return


	var viewport_size: Vector2 = get_viewport_rect().size
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var margin: float = max(safe_zone_margin_px, 1.0)
	var safe_rect: Rect2 = Rect2(
		Vector2(margin, margin),
		Vector2(max(viewport_size.x - margin * 2.0, 0.0), max(viewport_size.y - margin * 2.0, 0.0))
	)

	# Determine which of the 9 zones the mouse is closest to.
	var zone_x: int = 0
	var zone_y: int = 0
	if mouse.x < safe_rect.position.x:
		zone_x = -1
	elif mouse.x > safe_rect.position.x + safe_rect.size.x:
		zone_x = 1

	if mouse.y < safe_rect.position.y:
		zone_y = -1
	elif mouse.y > safe_rect.position.y + safe_rect.size.y:
		zone_y = 1

	var target: Vector2 = _default_position + Vector2(zone_x, zone_y) * snap_offset_world
	var smooth_factor: float = 1.0 - exp(-snap_strength * delta)
	global_position = global_position.lerp(target, smooth_factor)

func emit_interference(meta: Dictionary = {}) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var ctrl := root.find_child("GameController", true, false)
	if ctrl != null and ctrl.has_method("_apply_noise_trigger"):
		ctrl.call("_apply_noise_trigger", &"camera_interference", meta)
