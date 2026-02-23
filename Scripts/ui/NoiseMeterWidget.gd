@tool
extends Node2D
class_name NoiseMeterWidget

@export var min_angle_deg: float = -110.0
@export var max_angle_deg: float = 110.0
@export var angle_offset_deg: float = 0.0

@export var origin_norm: Vector2 = Vector2(0.5, 0.75)
@export var needle_len_norm: float = 0.45
@export var smoothing: float = 12.0

@export var needle_color: Color = Color(1, 0, 0)
@export var needle_width_px: float = 4.0
@export var needle_tip_len_px: float = 18.0
@export var draw_needle: bool = true

@export var hub_outer_color: Color = Color(0, 0, 0)
@export var hub_inner_color: Color = Color(1, 1, 1)
@export var hub_outer_radius_px: float = 6.0
@export var hub_inner_radius_px: float = 4.0

@export var label_offset_norm: Vector2 = Vector2(0.0, 0.20)
@export var label_size_px: Vector2 = Vector2(120, 34)
@export var scale_enabled: bool = true
@export var scale_tick_radius_norm: float = 0.23
@export var scale_major_tick_len_norm: float = 0.035
@export var scale_minor_tick_len_norm: float = 0.018
@export var scale_major_tick_width_px: float = 3.0
@export var scale_minor_tick_width_px: float = 2.0
@export var scale_tick_color: Color = Color(0, 0, 0, 1)

@export var scale_major_ticks: PackedInt32Array = PackedInt32Array([0, 20, 40, 60, 80, 100])
@export var scale_minor_ticks_per_segment: int = 4

@export var scale_band_enabled: bool = true
@export var scale_band_radius_norm: float = 0.26
@export var scale_band_width_px: float = 6.0
@export var scale_band_stops: PackedInt32Array = PackedInt32Array([0, 40, 70, 90, 100])
@export var scale_band_colors: PackedColorArray = PackedColorArray([
	Color(0.2, 0.8, 0.2, 1),
	Color(0.9, 0.8, 0.2, 1),
	Color(0.95, 0.6, 0.2, 1),
	Color(0.9, 0.2, 0.2, 1)
])

@export var scale_label_radius_norm: float = 0.285
@export var scale_label_size_px: Vector2 = Vector2(40, 18)
@export var scale_label_offset_px: Vector2 = Vector2.ZERO
@export var scale_label_settings: LabelSettings
@export var scale_label_threshold_highlight: bool = true
@export var scale_label_normal_color: Color = Color(0, 0, 0, 1)
@export var scale_label_breached_color: Color = Color(0.9, 0.1, 0.1, 1)
@export var scale_label_include_zero: bool = false
@export var label_color: Color = Color(1, 1, 1)
@export var label_font_size: int = 22
@export var label_outline_size: int = 6
@export var label_outline_color: Color = Color(0, 0, 0)

@export var editor_preview_enabled: bool = true
@export var editor_preview_value: int = 35

var value: int = 0
var _round_peak_value: int = 0
var _needle_value: float = 0.0
var _label: Label = null
var _scale_labels: Dictionary = {}

func _ready() -> void:
	_needle_value = float(value)
	_round_peak_value = clampi(value, 0, 100)
	_ensure_label()
	_ensure_scale_labels()
	_apply_label_style()
	_layout_label()
	_layout_scale_labels()
	_update_scale_label_threshold_state()
	_update_label()
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and editor_preview_enabled:
		value = clampi(editor_preview_value, 0, 100)
		_round_peak_value = value

	var a := 1.0
	if smoothing > 0.0:
		a = clampf(smoothing * delta, 0.0, 1.0)

	_needle_value = lerpf(_needle_value, float(value), a)

	_apply_label_style()
	_update_label()
	_layout_label()
	_ensure_scale_labels()
	_layout_scale_labels()
	_update_scale_label_threshold_state()
	queue_redraw()

func set_noise_value(v: int, immediate: bool = false) -> void:
	value = clampi(v, 0, 100)
	if immediate:
		_needle_value = float(value)
		_round_peak_value = value
	else:
		_round_peak_value = maxi(_round_peak_value, value)
	_update_label()
	_layout_label()
	_update_scale_label_threshold_state()
	queue_redraw()

func _draw() -> void:
	var size := _parent_tex_size()
	var s := minf(size.x, size.y)
	if s <= 0.001:
		return
	var tl := _tex_top_left(size)
	var origin := tl + Vector2(size.x * origin_norm.x, size.y * origin_norm.y)
	var needle_len := maxf(0.0, s * needle_len_norm)

	var t := clampf(_needle_value / 100.0, 0.0, 1.0)
	if scale_enabled:
		_draw_scale(size, s, tl, origin)
	var ang := deg_to_rad(lerpf(min_angle_deg, max_angle_deg, t) + angle_offset_deg)

	if draw_needle:
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)

		var tip := origin + dir * needle_len
		var tip_len := clampf(needle_tip_len_px, 0.0, maxf(0.0, needle_len - 0.5))
		var base := tip - dir * tip_len

		var hw := needle_width_px * 0.5
		var o1 := origin + perp * hw
		var o2 := origin - perp * hw
		var b1 := base + perp * hw
		var b2 := base - perp * hw
		# Guard against degenerate/self-intersecting polygons in tiny PiP render sizes.
		var poly := PackedVector2Array([o1, b1, tip, b2, o2])
		var poly_area: float = 0.0
		for i in range(poly.size()):
			var a: Vector2 = poly[i]
			var b: Vector2 = poly[(i + 1) % poly.size()]
			poly_area += (a.x * b.y) - (b.x * a.y)
		poly_area = absf(poly_area) * 0.5
		if poly_area > 0.01 and needle_len > 1.0 and hw > 0.05:
			draw_polygon(
				poly,
				PackedColorArray([needle_color, needle_color, needle_color, needle_color, needle_color])
			)
		else:
			draw_line(origin, tip, needle_color, maxf(1.0, needle_width_px))

		draw_circle(origin, hub_outer_radius_px, hub_outer_color)
		draw_circle(origin, hub_inner_radius_px, hub_inner_color)

func _ensure_label() -> void:
	_label = get_node_or_null("NoiseValue") as Label
	if _label != null:
		return
	_label = Label.new()
	_label.name = "NoiseValue"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.show_behind_parent = true
	_label.size = label_size_px
	add_child(_label)
	if Engine.is_editor_hint():
		_label.owner = null
	_apply_label_style()

func _ensure_scale_label_settings() -> void:
	if scale_label_settings != null:
		return
	scale_label_settings = LabelSettings.new()
	scale_label_settings.font_size = 12
	scale_label_settings.font_color = Color(0, 0, 0, 1)
	scale_label_settings.outline_size = 0
	scale_label_settings.outline_color = Color(1, 1, 1, 1)

func _ensure_scale_labels() -> void:
	if not scale_enabled:
		for k in _scale_labels.keys():
			var lab: Label = _scale_labels[k] as Label
			if is_instance_valid(lab):
				lab.queue_free()
		_scale_labels.clear()
		return

	_ensure_scale_label_settings()

	if scale_major_ticks.is_empty():
		scale_major_ticks = PackedInt32Array([0, 20, 40, 60, 80, 100])

	var needed := {}
	for v in scale_major_ticks:
		var key := int(v)
		needed[key] = true

		var lab: Label = null
		if _scale_labels.has(key) and is_instance_valid(_scale_labels[key]):
			lab = _scale_labels[key] as Label

		if lab == null:
			lab = Label.new()
			lab.name = "Scale_%d" % key
			lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			add_child(lab)
			_scale_labels[key] = lab

		lab.label_settings = scale_label_settings
		lab.size = scale_label_size_px
		lab.text = str(key)

	for k in _scale_labels.keys():
		if not needed.has(k):
			var old: Label = _scale_labels[k] as Label
			if is_instance_valid(old):
				old.queue_free()
			_scale_labels.erase(k)

func _layout_scale_labels() -> void:
	if not scale_enabled:
		return
	var size := _parent_tex_size()
	var s := minf(size.x, size.y)
	var tl := _tex_top_left(size)
	var origin := tl + Vector2(size.x * origin_norm.x, size.y * origin_norm.y)

	var r := s * scale_label_radius_norm
	for k in _scale_labels.keys():
		var lab: Label = _scale_labels[k] as Label
		if not is_instance_valid(lab):
			continue
		var t := clampf(float(k) / 100.0, 0.0, 1.0)
		var ang := deg_to_rad(lerpf(min_angle_deg, max_angle_deg, t) + angle_offset_deg)
		var dir := Vector2(cos(ang), sin(ang))
		var p := origin + dir * r + scale_label_offset_px
		lab.position = p - (lab.size * 0.5)

func _update_scale_label_threshold_state() -> void:
	if _scale_labels.is_empty():
		return
	var curr: int = clampi(_round_peak_value, 0, 100)
	var normal_col: Color = _safe_color(scale_label_normal_color, Color(0, 0, 0, 1))
	var breached_col: Color = _safe_color(scale_label_breached_color, Color(0.9, 0.1, 0.1, 1))
	for k in _scale_labels.keys():
		var lab: Label = _scale_labels[k] as Label
		if not is_instance_valid(lab):
			continue
		var tick_val: int = int(k)
		var breached: bool = curr >= tick_val
		if not scale_label_include_zero and tick_val == 0:
			breached = false
		var ls: LabelSettings = lab.label_settings
		if ls == null:
			_ensure_scale_label_settings()
			ls = scale_label_settings.duplicate() as LabelSettings
			lab.label_settings = ls
		elif ls == scale_label_settings:
			ls = scale_label_settings.duplicate() as LabelSettings
			lab.label_settings = ls
		ls.font_color = breached_col if (scale_label_threshold_highlight and breached) else normal_col

func _safe_color(v: Variant, fallback: Color) -> Color:
	if typeof(v) == TYPE_COLOR:
		return v as Color
	return fallback

func _apply_label_style() -> void:
	if _label == null:
		return
	_label.size = label_size_px

	var ls := _label.label_settings
	if ls == null:
		ls = LabelSettings.new()
		_label.label_settings = ls

	ls.font_size = label_font_size
	ls.font_color = _safe_color(label_color, Color(1, 1, 1, 1))
	ls.outline_size = label_outline_size
	ls.outline_color = _safe_color(label_outline_color, Color(0, 0, 0, 1))

func _update_label() -> void:
	if _label != null:
		_label.text = str(value)

func _layout_label() -> void:
	if _label == null:
		return
	var size := _parent_tex_size()
	var s := minf(size.x, size.y)
	var tl := _tex_top_left(size)
	var origin := tl + Vector2(size.x * origin_norm.x, size.y * origin_norm.y)
	var off := Vector2(size.x * label_offset_norm.x, s * label_offset_norm.y)
	_label.position = origin + off - (_label.size * 0.5)

func _draw_scale(_size: Vector2, s: float, _tl: Vector2, origin: Vector2) -> void:
	if scale_band_enabled:
		_draw_scale_bands(s, origin)
	var majors: Array[int] = []
	if scale_major_ticks.is_empty():
		scale_major_ticks = PackedInt32Array([0, 20, 40, 60, 80, 100])
	for v in scale_major_ticks:
		majors.append(int(v))
	majors.sort()

	var r := s * scale_tick_radius_norm
	var major_len := s * scale_major_tick_len_norm
	var minor_len := s * scale_minor_tick_len_norm

	for i in range(majors.size()):
		var v := majors[i]
		_draw_tick(origin, r, major_len, scale_major_tick_width_px, v)

		if i < majors.size() - 1 and scale_minor_ticks_per_segment >= 2:
			var v2 := majors[i + 1]
			for j in range(1, scale_minor_ticks_per_segment):
				var vv := lerpf(float(v), float(v2), float(j) / float(scale_minor_ticks_per_segment))
				_draw_tick(origin, r, minor_len, scale_minor_tick_width_px, int(round(vv)))

func _draw_tick(origin: Vector2, radius: float, tick_len: float, tick_w: float, v: int) -> void:
	var t := clampf(float(v) / 100.0, 0.0, 1.0)
	var ang := deg_to_rad(lerpf(min_angle_deg, max_angle_deg, t) + angle_offset_deg)
	var dir := Vector2(cos(ang), sin(ang))
	var a := origin + dir * radius
	var b := origin + dir * (radius + tick_len)
	draw_line(a, b, scale_tick_color, tick_w)

func _draw_scale_bands(s: float, origin: Vector2) -> void:
	if scale_band_stops.size() < 2 or scale_band_colors.is_empty():
		return
	var r := s * scale_band_radius_norm
	var count := scale_band_stops.size() - 1
	for i in range(count):
		var v0 := int(scale_band_stops[i])
		var v1 := int(scale_band_stops[i + 1])
		var t0 := clampf(float(v0) / 100.0, 0.0, 1.0)
		var t1 := clampf(float(v1) / 100.0, 0.0, 1.0)
		if t1 <= t0:
			continue
		var ang0 := deg_to_rad(lerpf(min_angle_deg, max_angle_deg, t0) + angle_offset_deg)
		var ang1 := deg_to_rad(lerpf(min_angle_deg, max_angle_deg, t1) + angle_offset_deg)
		var color_idx := mini(i, scale_band_colors.size() - 1)
		draw_arc(origin, r, ang0, ang1, 24, scale_band_colors[color_idx], scale_band_width_px)

func _tex_top_left(size: Vector2) -> Vector2:
	var p := get_parent()
	if p is Sprite2D:
		var sp := p as Sprite2D
		if sp.centered:
			return -size * 0.5
	return Vector2.ZERO

func set_layout_norm(origin: Vector2, needle_len: float, label_off: Vector2) -> void:
	origin_norm = origin
	needle_len_norm = needle_len
	label_offset_norm = label_off
	_layout_label()
	queue_redraw()

func _parent_tex_size() -> Vector2:
	var p := get_parent()
	if p is Sprite2D:
		var sp := p as Sprite2D
		if sp.texture != null:
			return sp.texture.get_size()
	return Vector2(256, 256)
