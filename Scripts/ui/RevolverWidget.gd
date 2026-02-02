extends Node2D
class_name RevolverWidget

signal verdict_click
signal verdict_boom
signal verdict_finished

const CHAMBER_COUNT := 6

@export var art_texture: Texture2D
@export var show_art: bool = true
@export var auto_layout_sockets: bool = true
@export var pivot_offset_px: Vector2 = Vector2.ZERO
@export var socket_offset_px: Vector2 = Vector2.ZERO

@export var backing_radius_px: float = 170.0
@export var chamber_radius_px: float = 26.0
@export var chamber_ring_radius_px: float = 98.0
@export var chamber_angle_offset_deg: float = -90.0

@export var color_empty: Color = Color(0.06, 0.06, 0.06, 1.0)
@export var color_live: Color = Color(0.86, 0.70, 0.24, 1.0)
@export var consumed_alpha_mult: float = 0.35
@export var show_highlight: bool = false
@export var highlight_color: Color = Color(1, 1, 1, 1.0)
@export var highlight_width_px: float = 3.0

# Cinematic tuning (matches your spec)
@export var verdict_move_duration: float = 0.45
@export var verdict_scale_mult: float = 2.6
@export var verdict_spin_turns: float = 8.0
@export var verdict_spin_duration: float = 3.20
@export var verdict_fade_duration: float = 0.75
@export var verdict_fade_lead_time: float = 0.35 # seconds before spin ends that fade must already be finished
@export var verdict_pause_after_move: float = 0.06
@export var verdict_pause_after_spin: float = 0.06

@export_range(0, 6, 1) var dev_live_rounds: int = 0:
	set(v):
		dev_live_rounds = clampi(v, 0, 6)
		if is_inside_tree():
			_dev_apply()

@export_range(0, 5, 1) var dev_current_chamber: int = 0:
	set(v):
		dev_current_chamber = clampi(v, 0, 5)
		if is_inside_tree():
			_current_index = dev_current_chamber
			_apply_visuals()

var _live := [false, false, false, false, false, false]
var _consumed := [false, false, false, false, false, false]
var _current_index: int = 0

@onready var _pivot: Node2D = $Pivot
@onready var _art: Sprite2D = $Pivot/Art
@onready var _backing: Polygon2D = $Pivot/Backing
@onready var _sockets_root: Node2D = $Pivot/Sockets
@onready var _highlight: Line2D = $Pivot/Highlight

var _socket_markers: Array[Marker2D] = []
var _chamber_polys: Array[Polygon2D] = []

var _cin_active: bool = false
var _cin_parent: Node = null
var _cin_parent_index: int = -1
var _cin_xform: Transform2D
var _cin_z_index: int = 0
var _cin_modulate: Color = Color(1, 1, 1, 1)
var _cin_pivot_rot: float = 0.0
var _cin_pivot_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	if art_texture != null:
		_art.texture = art_texture
	_rebuild()
	_dev_apply()
	_apply_visuals()

func set_art_texture(tex: Texture2D) -> void:
	art_texture = tex
	_art.texture = tex
	_rebuild()
	_apply_visuals()

func _rebuild() -> void:
	_art.visible = show_art

	var c := _get_art_center()

	# Root stays “wall anchored” (top-left), Pivot becomes true center.
	var pivot_center := c + pivot_offset_px
	_pivot.position = pivot_center
	_art.position = -pivot_center

	_backing.visible = not show_art
	_backing.position = Vector2.ZERO
	_backing.color = Color(0.18, 0.18, 0.18, 1.0)
	_backing.polygon = _make_circle_points(backing_radius_px, 48)

	_socket_markers.clear()
	_chamber_polys.clear()

	for i in range(CHAMBER_COUNT):
		var m := _sockets_root.get_node_or_null("Socket%d" % i) as Marker2D
		if m == null:
			m = Marker2D.new()
			m.name = "Socket%d" % i
			_sockets_root.add_child(m)
		_socket_markers.append(m)

		var p := m.get_node_or_null("Chamber") as Polygon2D
		if p == null:
			p = Polygon2D.new()
			p.name = "Chamber"
			m.add_child(p)
		p.z_index = 10
		p.polygon = _make_circle_points(chamber_radius_px, 32)
		_chamber_polys.append(p)

	_highlight.z_index = 11
	_highlight.width = highlight_width_px
	_highlight.default_color = highlight_color
	_highlight.closed = true
	_highlight.points = _make_circle_points(chamber_radius_px + 8.0, 40)

	if auto_layout_sockets:
		_layout_sockets()

func _layout_sockets() -> void:
	var a0 := deg_to_rad(chamber_angle_offset_deg)
	for i in range(CHAMBER_COUNT):
		var a := a0 + (TAU * float(i) / float(CHAMBER_COUNT))
		_socket_markers[i].position = Vector2(cos(a), sin(a)) * chamber_ring_radius_px + socket_offset_px

func _get_art_center() -> Vector2:
	if _art.texture != null:
		return _art.texture.get_size() * 0.5
	return Vector2.ZERO

func _dev_apply() -> void:
	for i in range(CHAMBER_COUNT):
		_live[i] = false
		_consumed[i] = false

	var picks := clampi(dev_live_rounds, 0, CHAMBER_COUNT)
	var pool: Array[int] = []
	for i in range(CHAMBER_COUNT):
		pool.append(i)

	# Fisher-Yates shuffle-ish selection
	for n in range(picks):
		var j := n + (randi() % (pool.size() - n))
		var tmp := pool[n]
		pool[n] = pool[j]
		pool[j] = tmp
		_live[pool[n]] = true
	_current_index = dev_current_chamber

func set_state_from_masks(live_mask: int, consumed_mask: int, current_index: int) -> void:
	for i in range(CHAMBER_COUNT):
		_live[i] = ((live_mask >> i) & 1) == 1
		_consumed[i] = ((consumed_mask >> i) & 1) == 1
	_current_index = clampi(current_index, 0, CHAMBER_COUNT - 1)
	_apply_visuals()

func set_current_chamber(index: int) -> void:
	_current_index = clampi(index, 0, CHAMBER_COUNT - 1)
	_apply_visuals()

func dev_add_live_round() -> bool:
	# Fill a random chamber that is empty and unconsumed (preferred).
	var candidates: Array[int] = []
	for i in range(CHAMBER_COUNT):
		if _consumed[i]:
			continue
		if _live[i]:
			continue
		candidates.append(i)

	# If none available, allow empty-but-consumed as a fallback.
	if candidates.is_empty():
		for i in range(CHAMBER_COUNT):
			if _live[i]:
				continue
			candidates.append(i)

	if candidates.is_empty():
		return false

	var idx := candidates[randi() % candidates.size()]
	_live[idx] = true
	_apply_visuals()
	return true

func _apply_visuals() -> void:
	for i in range(min(_chamber_polys.size(), CHAMBER_COUNT)):
		var c := color_live if _live[i] else color_empty
		if _consumed[i]:
			c.a *= consumed_alpha_mult
		_chamber_polys[i].color = c

	_highlight.visible = show_highlight
	_highlight.position = _socket_markers[_current_index].position
	_highlight.default_color = highlight_color

func begin_verdict_cinematic(a: Variant = null, b: Variant = null) -> void:
	# Accept:
	# begin_verdict_cinematic(host)
	# begin_verdict_cinematic(true/false)
	# begin_verdict_cinematic(host, true/false)
	# begin_verdict_cinematic(true/false, host)
	var will_boom := true
	if typeof(a) == TYPE_BOOL:
		will_boom = a
	elif typeof(b) == TYPE_BOOL:
		will_boom = b
	_start_verdict_cinematic(will_boom)

func _start_verdict_cinematic(will_boom: bool) -> void:
	if _cin_active:
		return

	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if cam.has_method("snap_to_default"):
		cam.call("snap_to_default")

	_cin_active = true
	_cin_parent = get_parent()
	_cin_parent_index = -1
	if _cin_parent != null:
		_cin_parent_index = _cin_parent.get_children().find(self)

	_cin_xform = global_transform
	_cin_z_index = z_index
	_cin_modulate = modulate
	_cin_pivot_rot = _pivot.rotation
	_cin_pivot_scale = _pivot.scale

	# Keep above wall art
	z_index = 4096
	modulate = Color(1, 1, 1, 1)

	# Move root to screen center (world coords). Camera is frozen during overlay.
	var target_center := cam.get_screen_center_position()
	var delta := target_center - _pivot.global_position
	var end_root_pos := global_position + delta

	var start_scale := _pivot.scale
	var end_scale := start_scale * verdict_scale_mult

	var start_rot := _pivot.rotation
	var end_rot := start_rot + TAU * verdict_spin_turns

	var t := create_tween()

	# Phase 1: pullout (move + scale)
	t.tween_property(self, "global_position", end_root_pos, verdict_move_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_pivot, "scale", end_scale, verdict_move_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if verdict_pause_after_move > 0.0:
		t.tween_interval(verdict_pause_after_move)

	# Phase 2: spin fast then decelerate to stop
	var fade_delay := verdict_spin_duration - verdict_fade_duration - verdict_fade_lead_time
	if fade_delay < 0.0:
		fade_delay = 0.0

	t.tween_property(_pivot, "rotation", end_rot, verdict_spin_duration)\
		.set_trans(Tween.TRANS_QUINT)\
		.set_ease(Tween.EASE_OUT)

	t.parallel().tween_property(self, "modulate:a", 0.0, verdict_fade_duration)\
		.set_delay(fade_delay)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	# End: click/boom AFTER spin, then restore
	t.tween_callback(func():
		if will_boom:
			verdict_boom.emit()
		else:
			verdict_click.emit()
		_finish_verdict_cinematic()
	)

func _finish_verdict_cinematic() -> void:
	_restore_from_cinematic()
	verdict_finished.emit()

func _restore_from_cinematic() -> void:
	if not _cin_active:
		return
	_cin_active = false
	global_transform = _cin_xform
	z_index = _cin_z_index
	modulate = _cin_modulate
	_pivot.rotation = _cin_pivot_rot
	_pivot.scale = _cin_pivot_scale

func _make_circle_points(radius: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	steps = max(steps, 3)
	for i in range(steps):
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
