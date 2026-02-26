@tool
extends Control
class_name ComputerScreenWindow

signal open_requested

@export_group("Placement")
@export var screen_pos_local: Vector2 = Vector2(-86.0, 56.0)
@export var screen_size_local: Vector2 = Vector2(172.0, 96.0)

@export_group("Editor Preview")
@export var editor_preview_visible: bool = true
@export var editor_preview_fill: Color = Color(0.10, 1.0, 0.25, 0.10)
@export var editor_preview_border: Color = Color(0.20, 1.0, 0.35, 0.95)
@export var editor_draw_runtime_preview: bool = true
@export var editor_show_placement_outline: bool = true

@export_group("Runtime CRT Preview")
@export var runtime_preview_visible: bool = true
@export var phosphor_color: Color = Color(0.28, 1.0, 0.55, 0.95)
@export var crt_bg_color: Color = Color(0.02, 0.06, 0.04, 0.92)
@export var crt_glow_color: Color = Color(0.15, 1.0, 0.45, 0.16)
@export var crt_border_color: Color = Color(1.0, 1.0, 1.0, 0.42)
@export var crt_title: String = "K-11 TERM"
@export var crt_subtitle: String = "READY // INTERMISSION"

var _runtime_enabled: bool = false
var _blink_t: float = 0.0
var _last_actual_rect: Rect2 = Rect2()
var _last_export_rect: Rect2 = Rect2()
var _sync_initialized: bool = false

@onready var _frame: Control = $Frame
@onready var _btn: Button = $ClickCatcher

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = false
	set_process(true)
	_apply_rect()
	_cache_sync_state()
	_refresh_visibility()
	_refresh_children()
	queue_redraw()

func _process(delta: float) -> void:
	_blink_t += delta
	if Engine.is_editor_hint():
		_editor_sync_transform_and_exports()
	else:
		_apply_rect()
	_refresh_visibility()
	_refresh_children()
	queue_redraw()

func set_enabled(v: bool) -> void:
	_runtime_enabled = v
	_apply_rect()
	_refresh_visibility()
	_refresh_children()
	queue_redraw()

func _apply_rect() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	position = screen_pos_local
	size = Vector2(maxf(1.0, screen_size_local.x), maxf(1.0, screen_size_local.y))
	z_index = 20
	_cache_sync_state()

func _editor_sync_transform_and_exports() -> void:
	if not _sync_initialized:
		_apply_rect()
		_cache_sync_state()
		return

	var export_rect: Rect2 = Rect2(screen_pos_local, Vector2(maxf(1.0, screen_size_local.x), maxf(1.0, screen_size_local.y)))
	var actual_rect: Rect2 = Rect2(position, size)
	var export_changed: bool = not _rect_near(export_rect, _last_export_rect)
	var actual_changed: bool = not _rect_near(actual_rect, _last_actual_rect)

	if actual_changed and not export_changed:
		# User dragged/resized the node in editor; persist that back to exports.
		screen_pos_local = actual_rect.position
		screen_size_local = Vector2(maxf(1.0, actual_rect.size.x), maxf(1.0, actual_rect.size.y))
		export_rect = Rect2(screen_pos_local, screen_size_local)
	elif export_changed:
		# User edited inspector values; apply them to the node.
		anchor_left = 0.0
		anchor_top = 0.0
		anchor_right = 0.0
		anchor_bottom = 0.0
		position = export_rect.position
		size = export_rect.size
		z_index = 20
		actual_rect = Rect2(position, size)

	_last_export_rect = export_rect
	_last_actual_rect = actual_rect
	_sync_initialized = true

func _cache_sync_state() -> void:
	_last_export_rect = Rect2(screen_pos_local, Vector2(maxf(1.0, screen_size_local.x), maxf(1.0, screen_size_local.y)))
	_last_actual_rect = Rect2(position, size)
	_sync_initialized = true

func _rect_near(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) <= 0.01 and a.size.distance_to(b.size) <= 0.01

func _refresh_visibility() -> void:
	if Engine.is_editor_hint():
		visible = editor_preview_visible or (_runtime_enabled and runtime_preview_visible)
	else:
		visible = _runtime_enabled and runtime_preview_visible

func _refresh_children() -> void:
	if _btn != null:
		_btn.disabled = true
		_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_btn.visible = false
	if _frame != null:
		_frame.visible = false

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x <= 1.0 or r.size.y <= 1.0:
		return

	if Engine.is_editor_hint():
		if editor_draw_runtime_preview:
			_draw_crt_preview(r)
		if editor_show_placement_outline:
			draw_rect(r, editor_preview_fill, true)
			draw_rect(r, editor_preview_border, false, 2.0)
			_draw_editor_label(r)
		return

	if not (_runtime_enabled and runtime_preview_visible):
		return

	_draw_crt_preview(r)

func _draw_editor_label(r: Rect2) -> void:
	var f: Font = ThemeDB.fallback_font
	if f == null:
		return
	draw_string(f, r.position + Vector2(6, 16), "COMPUTER SCREEN", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, editor_preview_border)

func _draw_crt_preview(r: Rect2) -> void:
	draw_rect(r, crt_bg_color, true)

	# Soft inner glow
	var inset: Rect2 = r.grow(-2.0)
	draw_rect(inset, crt_glow_color, true)

	# Scanlines
	var line_color: Color = Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.10)
	var y := 1.0
	while y < r.size.y:
		draw_line(Vector2(1.0, y), Vector2(r.size.x - 1.0, y), line_color, 1.0)
		y += 3.0

	# Simple terminal text
	var f: Font = ThemeDB.fallback_font
	if f != null:
		var fs: int = int(clampf(r.size.y * 0.13, 10.0, 16.0))
		var fs2: int = maxi(9, fs - 3)
		draw_string(f, Vector2(6, 8 + fs), crt_title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12.0, fs, phosphor_color)
		draw_string(f, Vector2(6, 16 + fs + fs2), crt_subtitle, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12.0, fs2, Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.85))
		var cursor_on: bool = fmod(_blink_t, 1.0) < 0.5
		var prompt: String = ">_ " if cursor_on else ">  "
		draw_string(f, Vector2(6, r.size.y - 8), prompt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12.0, fs2, phosphor_color)

	# White alpha outline border (same visual intent as hover affordances)
	draw_rect(r, crt_border_color, false, 2.0)
