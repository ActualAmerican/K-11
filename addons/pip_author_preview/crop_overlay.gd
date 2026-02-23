@tool
extends Control

signal crop_changed(center_px: Vector2, size_px: Vector2)

const HANDLE_RADIUS := 8.0

var source_size_px: Vector2 = Vector2(1920.0, 1080.0)
var crop_center_px: Vector2 = Vector2(960.0, 540.0)
var crop_size_px: Vector2 = Vector2(420.0, 280.0)
var display_rect_override: Rect2 = Rect2()

var _drag_mode: String = ""
var _drag_start_mouse_local: Vector2 = Vector2.ZERO
var _drag_start_center_px: Vector2 = Vector2.ZERO
var _drag_start_size_px: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_crop(center_px: Vector2, size_px: Vector2, src_size_px: Vector2, content_rect_local: Rect2 = Rect2()) -> void:
	crop_center_px = center_px
	crop_size_px = Vector2(maxf(8.0, size_px.x), maxf(8.0, size_px.y))
	source_size_px = Vector2(maxf(1.0, src_size_px.x), maxf(1.0, src_size_px.y))
	display_rect_override = content_rect_local
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_drag_mode = _hit_test_mode(mb.position)
			if _drag_mode != "":
				_drag_start_mouse_local = mb.position
				_drag_start_center_px = crop_center_px
				_drag_start_size_px = crop_size_px
				accept_event()
		else:
			if _drag_mode != "":
				_drag_mode = ""
				accept_event()
	elif event is InputEventMouseMotion and _drag_mode != "":
		var mm := event as InputEventMouseMotion
		var delta_source: Vector2 = _local_delta_to_source(mm.position - _drag_start_mouse_local)
		var center := _drag_start_center_px
		var size := _drag_start_size_px
		match _drag_mode:
			"move":
				center += delta_source
			"tl":
				var rect := Rect2(_drag_start_center_px - (_drag_start_size_px * 0.5), _drag_start_size_px)
				rect.position += delta_source
				rect.size -= delta_source
				rect = _normalize_rect(rect)
				center = rect.get_center()
				size = rect.size
			"tr":
				var rect := Rect2(_drag_start_center_px - (_drag_start_size_px * 0.5), _drag_start_size_px)
				rect.position.y += delta_source.y
				rect.size.x += delta_source.x
				rect.size.y -= delta_source.y
				rect = _normalize_rect(rect)
				center = rect.get_center()
				size = rect.size
			"bl":
				var rect := Rect2(_drag_start_center_px - (_drag_start_size_px * 0.5), _drag_start_size_px)
				rect.position.x += delta_source.x
				rect.size.x -= delta_source.x
				rect.size.y += delta_source.y
				rect = _normalize_rect(rect)
				center = rect.get_center()
				size = rect.size
			"br":
				var rect := Rect2(_drag_start_center_px - (_drag_start_size_px * 0.5), _drag_start_size_px)
				rect.size += delta_source
				rect = _normalize_rect(rect)
				center = rect.get_center()
				size = rect.size
		size = Vector2(maxf(8.0, size.x), maxf(8.0, size.y))
		center = _clamp_center(center, size)
		crop_center_px = center
		crop_size_px = size
		queue_redraw()
		crop_changed.emit(crop_center_px, crop_size_px)
		accept_event()

func _draw() -> void:
	var content: Rect2 = _content_rect()
	if content.size.x <= 1.0 or content.size.y <= 1.0:
		return
	draw_rect(content, Color(1, 1, 1, 0.08), false, 1.0)
	var r_local: Rect2 = _crop_rect_local()
	draw_rect(r_local, Color(0.1, 1.0, 0.25, 1.0), false, 2.0)
	var center_local := r_local.get_center()
	draw_line(center_local + Vector2(-10, 0), center_local + Vector2(10, 0), Color(0.1, 1.0, 0.25, 0.9), 2.0)
	draw_line(center_local + Vector2(0, -10), center_local + Vector2(0, 10), Color(0.1, 1.0, 0.25, 0.9), 2.0)
	for p in _handle_points(r_local):
		draw_circle(p, 4.0, Color(1.0, 0.6, 0.1, 1.0))

func _hit_test_mode(mouse_local: Vector2) -> String:
	var r_local := _crop_rect_local()
	var points := _handle_points(r_local)
	var names := ["tl", "tr", "bl", "br"]
	for i in range(points.size()):
		if mouse_local.distance_to(points[i]) <= HANDLE_RADIUS:
			return names[i]
	if r_local.has_point(mouse_local):
		return "move"
	return ""

func _handle_points(r: Rect2) -> Array[Vector2]:
	return [
		r.position,
		r.position + Vector2(r.size.x, 0.0),
		r.position + Vector2(0.0, r.size.y),
		r.position + r.size,
	]

func _crop_rect_local() -> Rect2:
	var rect_src := Rect2(crop_center_px - (crop_size_px * 0.5), crop_size_px)
	return _source_rect_to_local(rect_src)

func _source_rect_to_local(r_src: Rect2) -> Rect2:
	var content := _content_rect()
	var sx: float = content.size.x / maxf(1.0, source_size_px.x)
	var sy: float = content.size.y / maxf(1.0, source_size_px.y)
	return Rect2(
		content.position + Vector2(r_src.position.x * sx, r_src.position.y * sy),
		Vector2(r_src.size.x * sx, r_src.size.y * sy)
	)

func _local_delta_to_source(delta_local: Vector2) -> Vector2:
	var content := _content_rect()
	if content.size.x <= 0.0 or content.size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(
		delta_local.x * (source_size_px.x / content.size.x),
		delta_local.y * (source_size_px.y / content.size.y)
	)

func _content_rect() -> Rect2:
	if display_rect_override.size.x > 0.0 and display_rect_override.size.y > 0.0:
		return display_rect_override
	var draw_size := size
	var src := Vector2(maxf(1.0, source_size_px.x), maxf(1.0, source_size_px.y))
	var fit := minf(draw_size.x / src.x, draw_size.y / src.y)
	if fit <= 0.0:
		return Rect2(Vector2.ZERO, draw_size)
	var content_size := src * fit
	return Rect2((draw_size - content_size) * 0.5, content_size)

func _clamp_center(center: Vector2, rect_size: Vector2) -> Vector2:
	var half := rect_size * 0.5
	return Vector2(
		clampf(center.x, half.x, maxf(half.x, source_size_px.x - half.x)),
		clampf(center.y, half.y, maxf(half.y, source_size_px.y - half.y))
	)

func _normalize_rect(r: Rect2) -> Rect2:
	var x0 := minf(r.position.x, r.position.x + r.size.x)
	var y0 := minf(r.position.y, r.position.y + r.size.y)
	var x1 := maxf(r.position.x, r.position.x + r.size.x)
	var y1 := maxf(r.position.y, r.position.y + r.size.y)
	var out := Rect2(Vector2(x0, y0), Vector2(x1 - x0, y1 - y0))
	out.position.x = clampf(out.position.x, 0.0, maxf(0.0, source_size_px.x - out.size.x))
	out.position.y = clampf(out.position.y, 0.0, maxf(0.0, source_size_px.y - out.size.y))
	if out.position.x + out.size.x > source_size_px.x:
		out.size.x = maxf(8.0, source_size_px.x - out.position.x)
	if out.position.y + out.size.y > source_size_px.y:
		out.size.y = maxf(8.0, source_size_px.y - out.position.y)
	return out
