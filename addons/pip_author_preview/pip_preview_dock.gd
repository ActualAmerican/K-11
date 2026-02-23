@tool
extends VBoxContainer

const GAME_SCENE_PATH := "res://Scenes/Game.tscn"
const CASE_SCRIPT_PATH := "res://Scripts/ui/CaseHandlingScene.gd"
const CropOverlayScript := preload("res://addons/pip_author_preview/crop_overlay.gd")

var editor_interface: EditorInterface

var _status_label: Label
var _source_panel: PanelContainer
var _source_texture: TextureRect
var _source_overlay: Control
var _pip_texture: TextureRect
var _values_label: Label
var _refresh_button: Button
var _save_button: Button

var _source_vp: SubViewport
var _pip_vp: SubViewport
var _preview_root: Node
var _preview_camera: Camera2D
var _selected_case_node: Node
var _cached_preview_size: Vector2i = Vector2i.ZERO
var _suppress_writeback: bool = false
var _last_target_path: NodePath = NodePath("")

func _ready() -> void:
	name = "PiPAuthorPreviewDock"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	_ensure_preview_viewports(Vector2i(1920, 1080))
	set_process(true)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_poll_selected_case_node()
	_sync_preview()

func _build_ui() -> void:
	var toolbar := HBoxContainer.new()
	add_child(toolbar)

	_status_label = Label.new()
	_status_label.text = "Select CaseHandlingScene in the editor to author PiP."
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_status_label)

	_refresh_button = Button.new()
	_refresh_button.text = "Rebuild Preview"
	_refresh_button.pressed.connect(_rebuild_preview)
	toolbar.add_child(_refresh_button)

	_save_button = Button.new()
	_save_button.text = "Apply + Save Scene"
	_save_button.pressed.connect(_save_current_scene)
	toolbar.add_child(_save_button)

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	var left_box := VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left_box)

	_source_panel = PanelContainer.new()
	_source_panel.custom_minimum_size = Vector2(800, 450)
	_source_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_box.add_child(_source_panel)

	var source_holder := Control.new()
	source_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_source_panel.add_child(source_holder)

	_source_texture = TextureRect.new()
	_source_texture.anchor_right = 1.0
	_source_texture.anchor_bottom = 1.0
	_source_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_source_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_source_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	source_holder.add_child(_source_texture)

	_source_overlay = CropOverlayScript.new()
	_source_overlay.anchor_right = 1.0
	_source_overlay.anchor_bottom = 1.0
	_source_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_source_overlay.connect("crop_changed", _on_overlay_crop_changed)
	source_holder.add_child(_source_overlay)

	var right_box := VBoxContainer.new()
	right_box.custom_minimum_size = Vector2(340, 240)
	right_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right_box)

	var pip_panel := PanelContainer.new()
	pip_panel.custom_minimum_size = Vector2(320, 220)
	pip_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.add_child(pip_panel)

	_pip_texture = TextureRect.new()
	_pip_texture.custom_minimum_size = Vector2(300, 180)
	_pip_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_pip_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pip_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip_panel.add_child(_pip_texture)

	_values_label = Label.new()
	_values_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_values_label.text = "No target selected."
	right_box.add_child(_values_label)

func _poll_selected_case_node() -> void:
	var next_target: Node = null
	if editor_interface != null:
		var selection := editor_interface.get_selection()
		if selection != null:
			var nodes: Array = selection.get_selected_nodes()
			if nodes.size() > 0:
				for n in nodes:
					if n is Node:
						var resolved := _resolve_case_handling_target(n as Node)
						if resolved != null:
							next_target = resolved
							break
				if next_target == null and nodes[0] is Node:
					var n0 := nodes[0] as Node
					var resolved0 := _resolve_case_handling_target(n0)
					if resolved0 != null:
						next_target = resolved0
	# Fallback: bind to the currently edited scene root (selection API can lag/fail in editor UI focus changes).
	if next_target == null and editor_interface != null:
		var edited_root: Node = editor_interface.get_edited_scene_root()
		if edited_root != null:
			var resolved_root := _resolve_case_handling_target(edited_root)
			if resolved_root != null:
				next_target = resolved_root
	# Last resort: keep current binding if it is still valid.
	if next_target == null and _selected_case_node != null and is_instance_valid(_selected_case_node):
		next_target = _selected_case_node
	if next_target == _selected_case_node:
		return
	_selected_case_node = next_target
	_rebuild_preview()

func _resolve_case_handling_target(n: Node) -> Node:
	var cur: Node = n
	while cur != null:
		if _is_case_handling_scene_node(cur):
			return cur
		cur = cur.get_parent()
	return null

func _is_case_handling_scene_node(n: Node) -> bool:
	if n == null:
		return false
	var script: Script = n.get_script() as Script
	if script != null and script.resource_path == CASE_SCRIPT_PATH:
		return true
	if n.name == "CaseHandlingScene":
		if _has_pip_authoring_props(n):
			return true
	# Tool/editor instances do not always expose script methods consistently; prefer property signature.
	if _has_pip_authoring_props(n):
		return true
	return n.has_method("_update_live_pip_region") and n.has_method("_layout_noise_meter_pip")

func _has_pip_authoring_props(n: Node) -> bool:
	if n == null:
		return false
	var names := {}
	for prop in n.get_property_list():
		if prop is Dictionary and (prop as Dictionary).has("name"):
			names[(prop as Dictionary)["name"]] = true
	for p in ["pip_source_mode", "pip_source_size_px", "pip_source_center_px", "pip_source_follow_offset_px"]:
		if not names.has(p):
			return false
	return true

func _rebuild_preview() -> void:
	_last_target_path = NodePath("")
	_preview_camera = null
	if _preview_root != null and is_instance_valid(_preview_root):
		_preview_root.queue_free()
	_preview_root = null
	if _selected_case_node == null or not is_instance_valid(_selected_case_node):
		var edited_name := ""
		if editor_interface != null and editor_interface.get_edited_scene_root() != null:
			edited_name = " (edited root: %s)" % editor_interface.get_edited_scene_root().name
		_status_label.text = "Select CaseHandlingScene in the editor to author PiP.%s" % edited_name
		_values_label.text = "No target selected."
		return
	var preview_size := _selected_preview_size()
	_ensure_preview_viewports(preview_size)
	var packed: PackedScene = load(GAME_SCENE_PATH) as PackedScene
	if packed == null:
		_status_label.text = "Failed to load %s" % GAME_SCENE_PATH
		return
	var inst: Node = packed.instantiate()
	if inst == null:
		_status_label.text = "Failed to instantiate %s" % GAME_SCENE_PATH
		return
	_preview_root = inst
	_source_vp.add_child(inst)
	if Engine.is_editor_hint():
		inst.owner = null
	_find_preview_camera_and_prepare()
	_status_label.text = "Bound: %s" % _selected_case_node.name
	_refresh_status_hint()

func _selected_preview_size() -> Vector2i:
	if _selected_case_node != null and is_instance_valid(_selected_case_node):
		var v: Variant = _selected_case_node.get("editor_preview_size")
		if v is Vector2:
			var vv := v as Vector2
			return Vector2i(maxi(8, int(vv.x)), maxi(8, int(vv.y)))
	return Vector2i(1920, 1080)

func _ensure_preview_viewports(preview_size: Vector2i) -> void:
	var safe_size := Vector2i(maxi(8, preview_size.x), maxi(8, preview_size.y))
	if _source_vp == null or not is_instance_valid(_source_vp):
		_source_vp = SubViewport.new()
		_source_vp.name = &"PipAuthorSourceViewport"
		_source_vp.disable_3d = true
		_source_vp.transparent_bg = true
		_source_vp.handle_input_locally = false
		_source_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_source_vp.world_2d = World2D.new()
		add_child(_source_vp)
		_source_vp.owner = null
	if _pip_vp == null or not is_instance_valid(_pip_vp):
		_pip_vp = SubViewport.new()
		_pip_vp.name = &"PipAuthorPipViewport"
		_pip_vp.disable_3d = true
		_pip_vp.transparent_bg = true
		_pip_vp.handle_input_locally = false
		_pip_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_pip_vp)
		_pip_vp.owner = null
	_source_vp.size = safe_size
	if _source_vp.world_2d == null:
		_source_vp.world_2d = World2D.new()
	_pip_vp.world_2d = _source_vp.world_2d
	_cached_preview_size = safe_size
	_source_texture.texture = _source_vp.get_texture()
	_pip_texture.texture = _pip_vp.get_texture()

func _find_preview_camera_and_prepare() -> void:
	if _preview_root == null or not is_instance_valid(_preview_root):
		return
	var cam := _preview_root.find_child("Camera2D", true, false) as Camera2D
	if cam == null:
		return
	cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	var zoom_scale: float = 0.84
	var z_v: Variant = cam.get("zoom_scale")
	if z_v is float or z_v is int:
		zoom_scale = float(z_v)
	cam.zoom = Vector2.ONE * zoom_scale
	if _node_has_property(cam, "is_overlay_open"):
		cam.set("is_overlay_open", true)
	if _node_has_property(cam, "mouse_pan_enabled"):
		cam.set("mouse_pan_enabled", false)
	cam.enabled = true
	cam.make_current()
	_preview_camera = cam

func _sync_preview() -> void:
	if _selected_case_node == null or not is_instance_valid(_selected_case_node):
		return
	var preview_size := _selected_preview_size()
	if preview_size != _cached_preview_size:
		_rebuild_preview()
		if _selected_case_node == null or not is_instance_valid(_selected_case_node):
			return
	if _preview_root == null or not is_instance_valid(_preview_root):
		_rebuild_preview()
		if _preview_root == null or not is_instance_valid(_preview_root):
			return
	if _preview_camera == null or not is_instance_valid(_preview_camera):
		_find_preview_camera_and_prepare()
	var crop := _compute_crop_from_selected()
	if crop.size.x <= 1.0 or crop.size.y <= 1.0:
		return
	var sv_size := Vector2i(maxi(8, int(round(crop.size.x))), maxi(8, int(round(crop.size.y))))
	if _pip_vp.size != sv_size:
		_pip_vp.size = sv_size
	var xform := _preview_canvas_transform(_source_vp)
	xform.origin -= crop.position
	_pip_vp.canvas_transform = xform
	_source_overlay.set("visible", true)
	_source_overlay.call("set_crop", crop.get_center(), crop.size, Vector2(_source_vp.size), _source_texture_content_rect())
	_values_label.text = _values_text(crop)
	_refresh_status_hint()

func _compute_crop_from_selected() -> Rect2:
	var src_size := Vector2(_source_vp.size)
	var cap_size := _vec2_prop(_selected_case_node, "pip_source_size_px", Vector2(420.0, 280.0))
	cap_size = Vector2(maxf(8.0, cap_size.x), maxf(8.0, cap_size.y))
	var follow_offset := _vec2_prop(_selected_case_node, "pip_source_follow_offset_px", Vector2.ZERO)
	var mode_val := int(_selected_case_node.get("pip_source_mode"))
	var center := _vec2_prop(_selected_case_node, "pip_source_center_px", src_size * 0.5)
	if mode_val == 1:
		var base_center := _preview_follow_target_center()
		if base_center != Vector2.ZERO:
			center = base_center
		center += follow_offset
	var left := clampf(center.x - (cap_size.x * 0.5), 0.0, maxf(0.0, src_size.x - cap_size.x))
	var top := clampf(center.y - (cap_size.y * 0.5), 0.0, maxf(0.0, src_size.y - cap_size.y))
	return Rect2(left, top, cap_size.x, cap_size.y)

func _preview_follow_target_center() -> Vector2:
	if _preview_root == null or not is_instance_valid(_preview_root):
		return Vector2.ZERO
	var target_path: NodePath = _selected_case_node.get("pip_source_target_path")
	var target: Node = null
	if not target_path.is_empty():
		target = _preview_root.get_node_or_null(target_path)
	if target == null:
		var sound := _preview_root.find_child("Sound", true, false)
		if sound != null:
			target = sound.get_node_or_null(^"NoiseMeter")
	if target == null:
		target = _find_preferred_noise_meter(_preview_root)
	if target == null or not (target is Node2D):
		return Vector2.ZERO
	return _pip_target_screen_center_preview(_source_vp, target as Node2D)

func _find_preferred_noise_meter(root: Node) -> Node:
	if root == null:
		return null
	var matches: Array = []
	_collect_nodes_named(root, "NoiseMeter", matches)
	for n in matches:
		if n is Node:
			var parent := (n as Node).get_parent()
			if parent != null and parent.name == "Sound":
				return n
	if matches.size() > 0:
		return matches[0]
	return null

func _collect_nodes_named(root: Node, wanted_name: String, out: Array) -> void:
	if root.name == wanted_name:
		out.append(root)
	for child in root.get_children():
		if child is Node:
			_collect_nodes_named(child as Node, wanted_name, out)

func _pip_target_screen_center_preview(vp: Viewport, target: Node2D) -> Vector2:
	var origin_norm_v: Variant = target.get("origin_norm")
	if origin_norm_v is Vector2:
		var origin_norm := origin_norm_v as Vector2
		var sound_sprite := target.get_parent() as Sprite2D
		if sound_sprite != null and sound_sprite.texture != null:
			var sound_rect: Rect2 = sound_sprite.get_rect()
			var local_origin := sound_rect.position + Vector2(sound_rect.size.x * origin_norm.x, sound_rect.size.y * origin_norm.y)
			var world_origin := sound_sprite.global_transform * local_origin
			return _preview_canvas_transform(vp) * world_origin
	if target is Sprite2D:
		return _sprite_center_screen_preview(vp, target as Sprite2D)
	return _preview_canvas_transform(vp) * target.global_position

func _sprite_center_screen_preview(vp: Viewport, s: Sprite2D) -> Vector2:
	var local_rect := s.get_rect()
	var world_xf := s.global_transform
	var canvas_xf := _preview_canvas_transform(vp)
	var p0 := canvas_xf * (world_xf * local_rect.position)
	var p3 := canvas_xf * (world_xf * (local_rect.position + local_rect.size))
	return (p0 + p3) * 0.5

func _preview_canvas_transform(vp: Viewport) -> Transform2D:
	if _preview_camera != null and is_instance_valid(_preview_camera):
		return _preview_camera.get_canvas_transform()
	return vp.get_canvas_transform()

func _source_texture_content_rect() -> Rect2:
	if _source_texture == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var rect_size := _source_texture.size
	var tex := _source_texture.texture
	if tex == null:
		return Rect2(Vector2.ZERO, rect_size)
	var src_size := tex.get_size()
	if src_size.x <= 0.0 or src_size.y <= 0.0 or rect_size.x <= 0.0 or rect_size.y <= 0.0:
		return Rect2(Vector2.ZERO, rect_size)
	var fit := minf(rect_size.x / src_size.x, rect_size.y / src_size.y)
	if fit <= 0.0:
		return Rect2(Vector2.ZERO, rect_size)
	var draw_size := src_size * fit
	return Rect2((rect_size - draw_size) * 0.5, draw_size)

func _on_overlay_crop_changed(center_px: Vector2, size_px: Vector2) -> void:
	if _suppress_writeback:
		return
	if _selected_case_node == null or not is_instance_valid(_selected_case_node):
		return
	_suppress_writeback = true
	var mode_val := int(_selected_case_node.get("pip_source_mode"))
	if mode_val == 1:
		var base_center := _preview_follow_target_center()
		if base_center == Vector2.ZERO:
			base_center = _vec2_prop(_selected_case_node, "pip_source_center_px", center_px)
		_selected_case_node.set("pip_source_follow_offset_px", center_px - base_center)
	else:
		_selected_case_node.set("pip_source_center_px", center_px)
	_selected_case_node.set("pip_source_size_px", size_px)
	if _selected_case_node.has_method("_update_live_pip_region"):
		_selected_case_node.call_deferred("_update_live_pip_region")
	if _selected_case_node.has_method("_layout_noise_meter_pip"):
		_selected_case_node.call_deferred("_layout_noise_meter_pip")
	_values_label.text = _values_text(Rect2(center_px - size_px * 0.5, size_px))
	_suppress_writeback = false

func _vec2_prop(node: Object, prop_name: String, fallback: Vector2) -> Vector2:
	if node == null:
		return fallback
	var v: Variant = node.get(prop_name)
	if v is Vector2:
		return v as Vector2
	return fallback

func _node_has_property(obj: Object, prop_name: String) -> bool:
	if obj == null:
		return false
	for p in obj.get_property_list():
		if p is Dictionary and (p as Dictionary).get("name", "") == prop_name:
			return true
	return false

func _values_text(crop: Rect2) -> String:
	if _selected_case_node == null or not is_instance_valid(_selected_case_node):
		return "No target selected."
	var mode_val := int(_selected_case_node.get("pip_source_mode"))
	var mode_txt := "FOLLOW_TARGET" if mode_val == 1 else "MANUAL"
	var follow_offset := _vec2_prop(_selected_case_node, "pip_source_follow_offset_px", Vector2.ZERO)
	return "Mode: %s\nCenter: (%.1f, %.1f)\nSize: (%.1f, %.1f)\nRect: (%.1f, %.1f, %.1f, %.1f)\nFollow Offset: (%.1f, %.1f)" % [
		mode_txt,
		crop.get_center().x, crop.get_center().y,
		crop.size.x, crop.size.y,
		crop.position.x, crop.position.y, crop.size.x, crop.size.y,
		follow_offset.x, follow_offset.y
	]

func _save_current_scene() -> void:
	if editor_interface == null:
		return
	editor_interface.save_scene()
	_refresh_status_hint("Saved scene.")

func _refresh_status_hint(prefix: String = "") -> void:
	if _status_label == null:
		return
	if _selected_case_node == null or not is_instance_valid(_selected_case_node):
		_status_label.text = "Select CaseHandlingScene (or any child under it)."
		return
	var msg := "Bound: %s | Drag green box/corners. Click 'Apply + Save Scene' before running." % _selected_case_node.name
	if prefix != "":
		msg = "%s %s" % [prefix, msg]
	_status_label.text = msg
