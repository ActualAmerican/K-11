extends Control
class_name VentExitScene

var controller: Node = null
var _removing_cover: bool = false

@onready var stage: Node2D = $Stage
@onready var wall: Sprite2D = $Stage/Wall
@onready var vent_cover: Sprite2D = $Stage/VentCover
@onready var vent_open: Sprite2D = $Stage/VentOpen
@onready var cover_btn: Button = $VentCoverClick
@onready var open_btn: Button = $VentOpenClick
@onready var hint: Label = $Hint
@onready var sub_hint: Label = $SubHint
@onready var cancel_btn: Button = $Cancel
var _vent_open_outline: Sprite2D = null
var _vent_cover_base_pos: Vector2 = Vector2.ZERO
var _vent_cover_base_rot: float = 0.0
var _vent_cover_base_scale: Vector2 = Vector2.ONE

func set_controller(c: Node) -> void:
	controller = c

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_fit_stage_to_viewport)

	cover_btn.pressed.connect(_on_cover_pressed)
	open_btn.pressed.connect(_on_open_pressed)
	cancel_btn.pressed.connect(_on_cancel)
	_ensure_open_vent_outline()
	_fit_stage_to_viewport()
	if vent_cover != null:
		_vent_cover_base_pos = vent_cover.position
		_vent_cover_base_rot = vent_cover.rotation
		_vent_cover_base_scale = vent_cover.scale

	_sync_from_controller()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_cancel()
		get_viewport().set_input_as_handled()

func _sync_from_controller() -> void:
	var removed := false
	if controller != null:
		# Public run flag (we’ll add it in the ticket): controller.exit_vent_removed
		if controller.has_method("get"):
			var v = controller.get("exit_vent_removed")
			if typeof(v) == TYPE_BOOL:
				removed = bool(v)

	vent_cover.visible = not removed
	cover_btn.visible = not removed and not _removing_cover
	cover_btn.disabled = removed or _removing_cover

	# The open vent art should always exist behind the cover; only interaction unlocks after removal.
	vent_open.visible = true
	open_btn.visible = removed
	open_btn.disabled = (not removed) or _removing_cover
	if _vent_open_outline != null:
		_vent_open_outline.visible = removed

	if not removed and vent_cover != null and not _removing_cover:
		vent_cover.position = _vent_cover_base_pos
		vent_cover.rotation = _vent_cover_base_rot
		vent_cover.scale = _vent_cover_base_scale

	hint.text = "EXIT PROTOCOL (stub)"
	if _removing_cover:
		sub_hint.text = "Removing cover..."
	else:
		sub_hint.text = "Click the vent cover to remove it." if not removed else "Click the open vent to exit."

func _ensure_open_vent_outline() -> void:
	if vent_open == null or vent_open.texture == null:
		return
	if _vent_open_outline != null:
		return
	var outline: Sprite2D = preload("res://Scripts/ui/AlphaOutline.gd").new() as Sprite2D
	if outline == null:
		return
	outline.name = "VentOpenOutline"
	outline.texture = vent_open.texture
	outline.centered = vent_open.centered
	outline.z_index = vent_open.z_index + 1
	outline.visible = false
	outline.set("outline_color", Color(1, 1, 1, 0.95))
	outline.set("outline_size", 4.0)
	outline.set("outline_softness", 0.6)
	outline.set("pulse_speed", 1.4)
	outline.set("pulse_amount", 0.32)
	vent_open.add_child(outline)
	_vent_open_outline = outline

func _on_cover_pressed() -> void:
	if _removing_cover:
		return
	_removing_cover = true
	cover_btn.disabled = true
	cover_btn.visible = false
	open_btn.disabled = true
	_play_cover_removal_anim()

func _play_cover_removal_anim() -> void:
	if vent_cover == null:
		_finish_cover_removed()
		return
	vent_cover.visible = true
	var drop_y: float = get_viewport_rect().size.y / maxf(stage.scale.y, 0.001) + 260.0
	var target_pos: Vector2 = _vent_cover_base_pos + Vector2(90.0, drop_y)
	var target_rot: float = _vent_cover_base_rot + deg_to_rad(26.0)
	var pop_scale: Vector2 = _vent_cover_base_scale * 1.08
	var final_scale: Vector2 = _vent_cover_base_scale * 1.02
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(vent_cover, "scale", pop_scale, 0.16)
	tw.parallel().tween_property(vent_cover, "rotation", _vent_cover_base_rot + deg_to_rad(6.0), 0.16)
	tw.tween_interval(0.06)
	tw.tween_property(vent_cover, "position", target_pos, 0.72)
	tw.parallel().tween_property(vent_cover, "rotation", target_rot, 0.72)
	tw.parallel().tween_property(vent_cover, "scale", final_scale, 0.72)
	tw.finished.connect(_finish_cover_removed)

func _finish_cover_removed() -> void:
	_removing_cover = false
	if controller != null:
		# Persist across suspect rounds
		controller.set("exit_vent_removed", true)
	_sync_from_controller()

func _on_open_pressed() -> void:
	if controller != null and controller.has_method("request_exit_protocol_success"):
		controller.call("request_exit_protocol_success")

func _on_cancel() -> void:
	if controller != null and controller.has_method("close_overlay"):
		controller.call("close_overlay")

func _fit_stage_to_viewport() -> void:
	if stage == null:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	stage.position = vp_size * 0.5
	if wall == null or wall.texture == null:
		return
	var tex_size: Vector2 = wall.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	# Fit the wall fully within the viewport with a small margin so the full scene reads.
	var fit_scale: float = minf(vp_size.x / tex_size.x, vp_size.y / tex_size.y) * 0.96
	stage.scale = Vector2.ONE * fit_scale
