@tool
extends Control
class_name PipAuthoringBase

enum PipSourceMode {
	MANUAL,
	FOLLOW_TARGET,
}

@export_group("PiP Authoring")
@export var pip_source_mode: PipSourceMode = PipSourceMode.FOLLOW_TARGET
@export var pip_source_target_path: NodePath = NodePath("")
@export var pip_source_center_px: Vector2 = Vector2(330.0, 260.0)
@export var pip_source_size_px: Vector2 = Vector2(420.0, 280.0)
@export var pip_source_follow_offset_px: Vector2 = Vector2.ZERO

@export_group("PiP Authoring Editor Preview")
@export var editor_preview_size: Vector2 = Vector2(1920.0, 1080.0)
@export var pip_editor_preview_scene: PackedScene
@export var pip_author_preview_scene: PackedScene
@export_file("*.tscn") var pip_author_preview_scene_path: String = ""

func _pip_is_follow_mode() -> bool:
	return pip_source_mode == PipSourceMode.FOLLOW_TARGET

func pip_get_capture_rect_px(source_size_px: Vector2, follow_anchor_center_px: Vector2 = Vector2.ZERO) -> Rect2:
	var cap_size := Vector2(maxf(8.0, pip_source_size_px.x), maxf(8.0, pip_source_size_px.y))
	var center := pip_source_center_px
	if _pip_is_follow_mode() and follow_anchor_center_px != Vector2.ZERO:
		center = follow_anchor_center_px
	center += pip_source_follow_offset_px
	var left := clampf(center.x - cap_size.x * 0.5, 0.0, maxf(0.0, source_size_px.x - cap_size.x))
	var top := clampf(center.y - cap_size.y * 0.5, 0.0, maxf(0.0, source_size_px.y - cap_size.y))
	return Rect2(left, top, cap_size.x, cap_size.y)

func pip_set_capture_from_rect_px(rect_px: Rect2, follow_anchor_center_px: Vector2 = Vector2.ZERO) -> void:
	var clamped_size := Vector2(maxf(8.0, rect_px.size.x), maxf(8.0, rect_px.size.y))
	pip_source_size_px = clamped_size
	var center := rect_px.get_center()
	if _pip_is_follow_mode() and follow_anchor_center_px != Vector2.ZERO:
		pip_source_follow_offset_px = center - follow_anchor_center_px
	else:
		pip_source_center_px = center

