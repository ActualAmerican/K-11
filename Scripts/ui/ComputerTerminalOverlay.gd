extends Control
class_name ComputerTerminalOverlay

const TAB_HOME := &"HOME"
const TAB_EXTRACT := &"EXTRACT"
const TAB_REQ := &"REQ"
const TAB_PROFILE := &"PROFILE"
const TAB_TELEMETRY := &"TELEMETRY"

var controller: Node = null
var current_tab: StringName = TAB_HOME
@export var phosphor_color: Color = Color(0.28, 1.0, 0.55, 0.95)
@export var bg_tint: Color = Color(0.01, 0.04, 0.02, 1.0)
@export var screen_bg: Color = Color(0.01, 0.06, 0.03, 0.96)
@export var bezel_bg: Color = Color(0.06, 0.07, 0.06, 0.95)
@export var screen_border: Color = Color(1.0, 1.0, 1.0, 0.18)
@export var shell_margin: Vector4 = Vector4(170, 110, 170, 72) # L,T,R,B
@export var glow_strength: float = 0.16
@export var scanline_alpha: float = 0.12
@export var vignette_alpha: float = 0.16

var _app_scenes: Dictionary = {
	TAB_HOME: preload("res://Scenes/TerminalAppHome.tscn"),
	TAB_EXTRACT: preload("res://Scenes/TerminalAppExtract.tscn"),
	TAB_REQ: preload("res://Scenes/TerminalAppReq.tscn"),
	TAB_PROFILE: preload("res://Scenes/TerminalAppProfile.tscn"),
	TAB_TELEMETRY: preload("res://Scenes/TerminalAppTelemetry.tscn"),
}

@onready var title_label: Label = %Title
@onready var tab_home: Button = %TabHome
@onready var tab_req: Button = %TabReq
@onready var tab_extract: Button = %TabExtract
@onready var tab_profile: Button = %TabProfile
@onready var tab_telemetry: Button = %TabTelemetry
@onready var content_mount: Control = %ContentMount
@onready var hint: Label = %Hint
@onready var close_btn: Button = %Close
@onready var bg_rect: ColorRect = $Bg
@onready var frame_panel: PanelContainer = $Frame
@onready var body_panel: PanelContainer = $Frame/Root/BodyPanel
var _fx_glow: ColorRect = null
var _fx_scanlines: TextureRect = null
var _fx_vignette: TextureRect = null
var _fx_noise_bar: ColorRect = null
var _scanline_tex: Texture2D = null
var _vignette_tex: Texture2D = null
var _flicker_t: float = 0.0

func set_controller(c: Node) -> void:
	controller = c

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_apply_shell_layout()
	_apply_retro_theme()
	_ensure_fx_overlays()
	_update_fx_colors()

	tab_home.pressed.connect(func() -> void: _set_tab(TAB_HOME))
	tab_extract.pressed.connect(func() -> void: _set_tab(TAB_EXTRACT))
	tab_req.pressed.connect(func() -> void: _set_tab(TAB_REQ))
	tab_profile.pressed.connect(func() -> void: _set_tab(TAB_PROFILE))
	tab_telemetry.pressed.connect(func() -> void: _set_tab(TAB_TELEMETRY))
	close_btn.pressed.connect(_request_close)

	_set_tab(current_tab)

func _process(delta: float) -> void:
	_flicker_t += delta
	_apply_shell_layout()
	_update_fx_runtime()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_request_close()
		get_viewport().set_input_as_handled()

func _request_close() -> void:
	if controller != null and controller.has_method("close_overlay"):
		controller.call("close_overlay")

func _is_intermission_active() -> bool:
	if controller == null:
		return false
	return bool(controller.get("_intermission_active"))

func _set_tab(tab: StringName) -> void:
	current_tab = tab

	tab_home.disabled = (tab == TAB_HOME)
	tab_extract.disabled = (tab == TAB_EXTRACT)
	tab_req.disabled = (tab == TAB_REQ)
	tab_profile.disabled = (tab == TAB_PROFILE)
	tab_telemetry.disabled = (tab == TAB_TELEMETRY)
	tab_req.modulate = Color(1, 1, 1, 1) if _is_intermission_active() else Color(1, 1, 1, 0.45)

	title_label.text = "K/11 TERMINAL  >  %s" % String(tab)
	hint.text = "ESC: close   |   Tabs: navigate   |   REQ spending: %s" % ("ON" if _is_intermission_active() else "LOCKED")
	_mount_app(current_tab)

func _mount_app(tab: StringName) -> void:
	for c in content_mount.get_children():
		c.queue_free()
	var scene: PackedScene = _app_scenes.get(tab, null) as PackedScene
	if scene == null:
		return
	var inst: Node = scene.instantiate()
	content_mount.add_child(inst)
	if inst.has_method("set_controller"):
		inst.call("set_controller", controller)
	if inst.has_method("set_intermission_active"):
		inst.call("set_intermission_active", _is_intermission_active())
	_apply_app_theme_recursive(inst)
	if inst.has_method("refresh"):
		inst.call("refresh")
	_apply_app_theme_recursive(inst)

func _apply_retro_theme() -> void:
	if bg_rect != null:
		bg_rect.color = bg_tint

	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = bezel_bg
	frame_sb.border_width_left = 2
	frame_sb.border_width_top = 2
	frame_sb.border_width_right = 2
	frame_sb.border_width_bottom = 2
	frame_sb.border_color = Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.18)
	frame_sb.shadow_color = Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.08)
	frame_sb.shadow_size = 6
	frame_sb.corner_radius_top_left = 0
	frame_sb.corner_radius_top_right = 0
	frame_sb.corner_radius_bottom_left = 0
	frame_sb.corner_radius_bottom_right = 0
	frame_panel.add_theme_stylebox_override("panel", frame_sb)

	var body_sb := StyleBoxFlat.new()
	body_sb.bg_color = screen_bg
	body_sb.border_width_left = 1
	body_sb.border_width_top = 1
	body_sb.border_width_right = 1
	body_sb.border_width_bottom = 1
	body_sb.border_color = Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.35)
	body_sb.corner_radius_top_left = 0
	body_sb.corner_radius_top_right = 0
	body_sb.corner_radius_bottom_left = 0
	body_sb.corner_radius_bottom_right = 0
	body_panel.add_theme_stylebox_override("panel", body_sb)

	for btn in [tab_home, tab_extract, tab_req, tab_profile, tab_telemetry, close_btn]:
		_style_button(btn)

	var label_color := Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.95)
	title_label.add_theme_color_override("font_color", label_color)
	title_label.add_theme_color_override("font_outline_color", Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.30))
	title_label.add_theme_constant_override("outline_size", 2)
	hint.add_theme_color_override("font_color", Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.80))
	hint.add_theme_color_override("font_outline_color", Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.22))
	hint.add_theme_constant_override("outline_size", 1)

func _style_button(btn: Button) -> void:
	if btn == null:
		return
	btn.flat = false
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0.45)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.30)
	normal.corner_radius_top_left = 0
	normal.corner_radius_top_right = 0
	normal.corner_radius_bottom_left = 0
	normal.corner_radius_bottom_right = 0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.10)
	hover.border_color = Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.75)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.18)
	pressed.border_color = Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.95)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", normal)
	btn.add_theme_color_override("font_color", Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.92))
	btn.add_theme_color_override("font_hover_color", phosphor_color)
	btn.add_theme_color_override("font_pressed_color", phosphor_color)
	btn.add_theme_color_override("font_disabled_color", Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.55))
	btn.add_theme_color_override("font_outline_color", Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.18))
	btn.add_theme_constant_override("outline_size", 1)

func _apply_app_theme_recursive(node: Node) -> void:
	if node is Label:
		_theme_label(node as Label)
	elif node is RichTextLabel:
		_theme_rich_text(node as RichTextLabel)
	elif node is Button:
		_style_button(node as Button)
	elif node is PanelContainer:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.25)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.20)
		sb.corner_radius_top_left = 0
		sb.corner_radius_top_right = 0
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_bottom_right = 0
		(node as PanelContainer).add_theme_stylebox_override("panel", sb)

	for child in node.get_children():
		if child is Node:
			_apply_app_theme_recursive(child)

func _theme_label(label: Label) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.95))
	label.add_theme_color_override("font_outline_color", Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.22))
	label.add_theme_constant_override("outline_size", 1)

func _theme_rich_text(rt: RichTextLabel) -> void:
	if rt == null:
		return
	var c: Color = Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.92)
	rt.add_theme_color_override("default_color", c)
	rt.add_theme_color_override("font_selected_color", Color.BLACK)
	rt.add_theme_color_override("selection_color", Color(c.r, c.g, c.b, 0.30))
	rt.add_theme_color_override("font_outline_color", Color(c.r, c.g, c.b, 0.20))
	rt.add_theme_constant_override("outline_size", 1)
	rt.add_theme_constant_override("line_separation", 3)

func _apply_shell_layout() -> void:
	if frame_panel == null:
		return
	frame_panel.anchor_left = 0.0
	frame_panel.anchor_top = 0.0
	frame_panel.anchor_right = 1.0
	frame_panel.anchor_bottom = 1.0
	frame_panel.offset_left = shell_margin.x
	frame_panel.offset_top = shell_margin.y
	frame_panel.offset_right = -shell_margin.z
	frame_panel.offset_bottom = -shell_margin.w

func _ensure_fx_overlays() -> void:
	if body_panel == null or content_mount == null:
		return
	if _scanline_tex == null:
		_scanline_tex = _build_scanline_texture()
	if _vignette_tex == null:
		_vignette_tex = _build_vignette_texture()

	if _fx_glow == null:
		_fx_glow = ColorRect.new()
		_fx_glow.name = "FxGlow"
		_fx_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx_glow.anchor_right = 1.0
		_fx_glow.anchor_bottom = 1.0
		_fx_glow.offset_left = 2
		_fx_glow.offset_top = 2
		_fx_glow.offset_right = -2
		_fx_glow.offset_bottom = -2
		body_panel.add_child(_fx_glow)
		body_panel.move_child(_fx_glow, 0)

	if _fx_noise_bar == null:
		_fx_noise_bar = ColorRect.new()
		_fx_noise_bar.name = "FxNoiseBar"
		_fx_noise_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx_noise_bar.anchor_right = 1.0
		_fx_noise_bar.anchor_bottom = 0.0
		_fx_noise_bar.offset_left = 0
		_fx_noise_bar.offset_top = 0
		_fx_noise_bar.offset_right = 0
		_fx_noise_bar.offset_bottom = 28
		body_panel.add_child(_fx_noise_bar)
		body_panel.move_child(_fx_noise_bar, body_panel.get_child_count() - 1)

	if _fx_vignette == null:
		_fx_vignette = TextureRect.new()
		_fx_vignette.name = "FxVignette"
		_fx_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx_vignette.anchor_right = 1.0
		_fx_vignette.anchor_bottom = 1.0
		_fx_vignette.offset_left = 0
		_fx_vignette.offset_top = 0
		_fx_vignette.offset_right = 0
		_fx_vignette.offset_bottom = 0
		_fx_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_fx_vignette.stretch_mode = TextureRect.STRETCH_SCALE
		_fx_vignette.texture = _vignette_tex
		body_panel.add_child(_fx_vignette)
		body_panel.move_child(_fx_vignette, body_panel.get_child_count() - 1)

	if _fx_scanlines == null:
		_fx_scanlines = TextureRect.new()
		_fx_scanlines.name = "FxScanlines"
		_fx_scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx_scanlines.anchor_right = 1.0
		_fx_scanlines.anchor_bottom = 1.0
		_fx_scanlines.offset_left = 0
		_fx_scanlines.offset_top = 0
		_fx_scanlines.offset_right = 0
		_fx_scanlines.offset_bottom = 0
		_fx_scanlines.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_fx_scanlines.stretch_mode = TextureRect.STRETCH_TILE
		_fx_scanlines.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_fx_scanlines.texture = _scanline_tex
		body_panel.add_child(_fx_scanlines)
		body_panel.move_child(_fx_scanlines, body_panel.get_child_count() - 1)

func _update_fx_colors() -> void:
	if _fx_glow != null:
		_fx_glow.color = Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, glow_strength)
	if _fx_noise_bar != null:
		_fx_noise_bar.color = Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, 0.03)
	if _fx_vignette != null:
		_fx_vignette.modulate = Color(1, 1, 1, vignette_alpha)
	if _fx_scanlines != null:
		_fx_scanlines.modulate = Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, scanline_alpha)

func _update_fx_runtime() -> void:
	_update_fx_colors()
	if _fx_glow != null:
		var pulse: float = 0.94 + 0.06 * sin(_flicker_t * 7.3)
		_fx_glow.color = Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, glow_strength * pulse)
	if _fx_noise_bar != null:
		var sweep: float = 0.02 + 0.02 * (0.5 + 0.5 * sin(_flicker_t * 2.2))
		_fx_noise_bar.color = Color(phosphor_color.r, phosphor_color.g, phosphor_color.b, sweep)

func _build_scanline_texture() -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(4):
		for x in range(4):
			var a: float = 0.0
			if y == 0:
				a = 0.55
			elif y == 1:
				a = 0.10
			if x == 0:
				a += 0.05
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

func _build_vignette_texture() -> Texture2D:
	var w: int = 128
	var h: int = 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var uv := Vector2(float(x) / float(w - 1), float(y) / float(h - 1))
			var p := (uv - Vector2(0.5, 0.5)) * 2.0
			var edge: float = maxf(absf(p.x), absf(p.y))
			var alpha: float = smoothstep(0.45, 1.0, edge)
			img.set_pixel(x, y, Color(0, 0, 0, alpha))
	return ImageTexture.create_from_image(img)
