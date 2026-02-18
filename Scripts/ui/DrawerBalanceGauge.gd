@tool
extends Control
class_name DrawerBalanceGauge

const DEFAULT_DESIGN_RECT_PX: Rect2 = Rect2(740.0, 760.0, 440.0, 180.0)

@export var design_rect_px: Rect2 = Rect2(740.0, 760.0, 440.0, 180.0)
@export var preview_drawer_path: NodePath = NodePath("../OpenDrawer")
@export var preview_against_drawer: bool = true
@export var flip_h: bool = true
@export var preview_in_editor: bool = true
@export var yellow_threshold: float = 0.17
@export var orange_threshold: float = 0.50
@export var red_threshold: float = 0.83
@export var color_green: Color = Color(0.2, 1.0, 0.35, 1.0)
@export var color_yellow: Color = Color(0.95, 0.82, 0.18, 1.0)
@export var color_orange: Color = Color(1.0, 0.58, 0.18, 1.0)
@export var color_red: Color = Color(1.0, 0.23, 0.23, 1.0)
@export_group("Mouse Feedback")
@export var show_mouse_anchor_line: bool = true
@export var mouse_anchor_line_color: Color = Color(0.85, 1.0, 0.9, 0.55)
@export var mouse_anchor_line_width: float = 2.0
@export var show_mouse_anchor_dot: bool = true
@export var mouse_anchor_dot_color: Color = Color(0.85, 1.0, 0.9, 0.75)
@export var mouse_anchor_dot_radius: float = 3.5

@export var value: float = 0.0:
	set(v):
		value = clampf(v, -1.0, 1.0)
		queue_redraw()

@export var safe_center: float = 0.0:
	set(v):
		safe_center = clampf(v, -1.0, 1.0)
		queue_redraw()

@export var safe_width: float = 0.45:
	set(v):
		safe_width = clampf(v, 0.05, 2.0)
		queue_redraw()

@export var danger: float = 0.0:
	set(v):
		danger = clampf(v, 0.0, 1.0)
		queue_redraw()

const ANGLE_START: float = deg_to_rad(200.0)
const ANGLE_END: float = deg_to_rad(340.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		if String(preview_drawer_path) == "":
			preview_drawer_path = NodePath("../OpenDrawer")
		if design_rect_px.size.x <= 1.0 or design_rect_px.size.y <= 1.0:
			design_rect_px = DEFAULT_DESIGN_RECT_PX

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	visible = preview_in_editor
	_update_editor_preview_rect()

func set_state(p_value: float, p_center: float, p_width: float, p_danger: float) -> void:
	value = p_value
	safe_center = p_center
	safe_width = p_width
	danger = p_danger

func _t_to_angle(t: float) -> float:
	var u: float = (clampf(t, -1.0, 1.0) + 1.0) * 0.5
	if flip_h:
		return lerpf(ANGLE_END, ANGLE_START, u)
	return lerpf(ANGLE_START, ANGLE_END, u)

func _draw() -> void:
	var pad: float = 10.0
	var r: float = minf(size.x * 0.5, size.y) - pad
	if r <= 5.0:
		return

	var c: Vector2 = Vector2(size.x * 0.5, size.y - pad)
	draw_arc(c, r, ANGLE_START, ANGLE_END, 56, Color(1, 1, 1, 0.12), 8.0, true)
	_draw_zone_band(c, r)

	var ang: float = _t_to_angle(value)
	var p: Vector2 = c + Vector2(cos(ang), sin(ang)) * r
	_draw_mouse_feedback(p)
	draw_circle(p, 9.0, Color(1.0, 1.0, 1.0, 0.98))
	draw_circle(c, 3.5, Color(1, 1, 1, 0.30))

func _draw_mouse_feedback(anchor_point: Vector2) -> void:
	if not show_mouse_anchor_line and not show_mouse_anchor_dot:
		return
	if not visible:
		return
	var mouse_local: Vector2 = get_local_mouse_position()
	if show_mouse_anchor_line:
		draw_line(anchor_point, mouse_local, mouse_anchor_line_color, mouse_anchor_line_width, true)
	if show_mouse_anchor_dot:
		draw_circle(mouse_local, mouse_anchor_dot_radius, mouse_anchor_dot_color)

func _draw_zone_band(c: Vector2, r: float) -> void:
	# Render full arc as contiguous state sections (green/yellow/orange/red), no neutral gaps.
	var steps: int = 84
	var t_prev: float = -1.0
	var col_prev: Color = _zone_color_for_t(t_prev)
	for i in range(1, steps + 1):
		var t_cur: float = -1.0 + (2.0 * float(i) / float(steps))
		var col_cur: Color = _zone_color_for_t(t_cur)
		if col_cur != col_prev:
			_draw_band_section(c, r, t_prev, t_cur, col_prev)
			t_prev = t_cur
			col_prev = col_cur
	_draw_band_section(c, r, t_prev, 1.0, col_prev)

func _zone_color_for_t(t: float) -> Color:
	var y_t: float = maxf(0.0, minf(yellow_threshold, orange_threshold))
	var o_t: float = maxf(y_t + 0.001, minf(orange_threshold, red_threshold))
	var r_t: float = maxf(o_t + 0.001, red_threshold)

	# Balance visual sections across the full arc by normalizing distance
	# from safe center to the nearest arc edge range, not by safe_width.
	var max_dist: float = maxf(absf(-1.0 - safe_center), absf(1.0 - safe_center))
	if max_dist <= 0.001:
		max_dist = 1.0
	var danger_here: float = clampf(absf(t - safe_center) / max_dist, 0.0, 1.0)

	if danger_here <= y_t:
		return color_green
	if danger_here <= o_t:
		return color_yellow
	if danger_here < r_t:
		return color_orange
	return color_red

func _draw_band_section(c: Vector2, r: float, t0: float, t1: float, col: Color) -> void:
	var a_t: float = clampf(minf(t0, t1), -1.0, 1.0)
	var b_t: float = clampf(maxf(t0, t1), -1.0, 1.0)
	if b_t - a_t <= 0.002:
		return
	var a0: float = _t_to_angle(a_t)
	var a1: float = _t_to_angle(b_t)
	var start_a: float = minf(a0, a1)
	var end_a: float = maxf(a0, a1)
	draw_arc(c, r, start_a, end_a, 20, col, 10.0, true)

func _update_editor_preview_rect() -> void:
	var rect_px: Rect2 = design_rect_px
	if rect_px.size.x <= 1.0 or rect_px.size.y <= 1.0:
		rect_px = DEFAULT_DESIGN_RECT_PX
	if not preview_against_drawer:
		position = rect_px.position
		size = rect_px.size
		return
	var drawer: Sprite2D = get_node_or_null(preview_drawer_path) as Sprite2D
	if drawer == null or drawer.texture == null:
		position = rect_px.position
		size = rect_px.size
		return
	var drawer_rect: Rect2 = _sprite_global_rect(drawer)
	var sx: float = absf(drawer.scale.x)
	var sy: float = absf(drawer.scale.y)
	global_position = drawer_rect.position + Vector2(rect_px.position.x * sx, rect_px.position.y * sy)
	size = Vector2(rect_px.size.x * sx, rect_px.size.y * sy)

func _sprite_global_rect(s: Sprite2D) -> Rect2:
	var sprite_size: Vector2 = s.texture.get_size() * s.scale.abs()
	var top_left: Vector2 = s.global_position
	if s.centered:
		top_left -= sprite_size * 0.5
	return Rect2(top_left, sprite_size)
