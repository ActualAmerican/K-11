@tool
extends EditorPlugin

var _dock: Control = null
var _bottom_button: Button = null

func _enter_tree() -> void:
	_dock = preload("res://addons/case_engine_lab/CaseEngineLabDock.tscn").instantiate()
	_dock.name = "Case Engine Lab"
	_bottom_button = add_control_to_bottom_panel(_dock, "Case Engine Lab")
	if _bottom_button != null:
		make_bottom_panel_item_visible(_dock)

func _exit_tree() -> void:
	if _dock != null:
		if _bottom_button != null:
			remove_control_from_bottom_panel(_dock)
			_bottom_button = null
		else:
			remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
