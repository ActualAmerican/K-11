extends Node

var current_id: String = ""
var current_root: Control = null
var _layer: CanvasLayer = null

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = &"OverlayLayer"
	_layer.layer = 200
	add_child(_layer)

func open(id: String) -> void:
	if is_open():
		close()

	current_id = id
	current_root = Control.new()
	current_root.name = &"OverlayRoot"
	current_root.anchor_left = 0.0
	current_root.anchor_top = 0.0
	current_root.anchor_right = 1.0
	current_root.anchor_bottom = 1.0
	current_root.offset_left = 0.0
	current_root.offset_top = 0.0
	current_root.offset_right = 0.0
	current_root.offset_bottom = 0.0
	current_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(current_root)

	var panel := Panel.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	current_root.add_child(panel)

	if id == "DEV_TEST":
		var label := Label.new()
		label.text = "DEV_TEST OVERLAY"
		label.position = Vector2(24, 24)
		panel.add_child(label)

func close() -> void:
	if current_root != null:
		current_root.queue_free()
	current_root = null
	current_id = ""

func is_open() -> bool:
	return current_root != null
