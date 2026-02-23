@tool
extends EditorPlugin

const DockScript := preload("res://addons/pip_author_preview/pip_preview_dock.gd")

var _dock: Control

func _enter_tree() -> void:
	_dock = DockScript.new()
	if _dock != null:
		_dock.set("editor_interface", get_editor_interface())
		add_control_to_bottom_panel(_dock, "PiP Author")

func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
		_dock = null
