@tool
extends Panel
class_name DrawerDropZoneIndicator

@export var design_rect_px: Rect2 = Rect2(335.0, 165.0, 230.0, 270.0)
@export var preview_drawer_path: NodePath = NodePath("../OpenDrawer")
@export var preview_against_drawer: bool = true
@export var border_color: Color = Color(0.2, 1.0, 0.2, 1.0)
@export var fill_color: Color = Color(0.2, 1.0, 0.2, 0.08)
@export_range(1.0, 12.0, 1.0) var border_width_px: float = 3.0
@export_range(0.0, 48.0, 1.0) var corner_radius_px: float = 14.0
@export_range(0.0, 1.0, 0.01) var base_alpha: float = 0.72
@export_range(0.0, 1.0, 0.01) var pulse_amount: float = 0.28
@export_range(0.1, 8.0, 0.1) var pulse_speed: float = 1.8
@export var preview_in_editor: bool = true

var _active: bool = false
var _style: StyleBoxFlat = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_style()
	_apply_style()
	set_process(true)
	visible = preview_in_editor if Engine.is_editor_hint() else false

func _process(_delta: float) -> void:
	_apply_style()
	if Engine.is_editor_hint():
		visible = preview_in_editor
		modulate.a = 1.0
		_update_editor_preview_rect()
		return
	if not _active:
		visible = false
		return
	visible = true
	var pulse: float = sin(Time.get_ticks_msec() * 0.001 * pulse_speed * TAU)
	modulate.a = clampf(base_alpha + (pulse * pulse_amount), 0.05, 1.0)

func set_active(active: bool) -> void:
	_active = active
	if not active and not Engine.is_editor_hint():
		visible = false

func set_runtime_rect(rect: Rect2) -> void:
	global_position = rect.position
	size = rect.size

func _update_editor_preview_rect() -> void:
	if not preview_against_drawer:
		position = design_rect_px.position
		size = design_rect_px.size
		return
	var drawer: Sprite2D = get_node_or_null(preview_drawer_path) as Sprite2D
	if drawer == null or drawer.texture == null:
		position = design_rect_px.position
		size = design_rect_px.size
		return
	var drawer_rect: Rect2 = _sprite_global_rect(drawer)
	var sx: float = absf(drawer.scale.x)
	var sy: float = absf(drawer.scale.y)
	global_position = drawer_rect.position + Vector2(design_rect_px.position.x * sx, design_rect_px.position.y * sy)
	size = Vector2(design_rect_px.size.x * sx, design_rect_px.size.y * sy)

func _sprite_global_rect(s: Sprite2D) -> Rect2:
	var sprite_size: Vector2 = s.texture.get_size() * s.scale.abs()
	var top_left: Vector2 = s.global_position
	if s.centered:
		top_left -= sprite_size * 0.5
	return Rect2(top_left, sprite_size)

func _ensure_style() -> void:
	if _style != null:
		return
	_style = StyleBoxFlat.new()
	add_theme_stylebox_override("panel", _style)

func _apply_style() -> void:
	_ensure_style()
	_style.bg_color = fill_color
	_style.border_color = border_color
	_style.set_border_width_all(int(round(border_width_px)))
	_style.set_corner_radius_all(int(round(corner_radius_px)))
