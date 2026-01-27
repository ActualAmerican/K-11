extends Node

var current_id: String = ""
var current_root: Control = null
var _layer: CanvasLayer = null
var controller: Node = null

func set_controller(c: Node) -> void:
	controller = c

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = &"OverlayLayer"
	_layer.layer = 200
	add_child(_layer)

func open(id: String, payload: Dictionary = {}) -> void:
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
	if id == "CASE_FOLDER":
		var dimmer := ColorRect.new()
		dimmer.anchor_left = 0.0
		dimmer.anchor_top = 0.0
		dimmer.anchor_right = 1.0
		dimmer.anchor_bottom = 1.0
		dimmer.offset_left = 0.0
		dimmer.offset_top = 0.0
		dimmer.offset_right = 0.0
		dimmer.offset_bottom = 0.0
		dimmer.color = Color(0, 0, 0, 0.6)
		dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		current_root.add_child(dimmer)

		var case_root := Control.new()
		case_root.anchor_left = 0.08
		case_root.anchor_top = 0.08
		case_root.anchor_right = 0.92
		case_root.anchor_bottom = 0.92
		case_root.offset_left = 0.0
		case_root.offset_top = 0.0
		case_root.offset_right = 0.0
		case_root.offset_bottom = 0.0
		current_root.add_child(case_root)

		var case_panel := PanelContainer.new()
		case_panel.anchor_left = 0.0
		case_panel.anchor_top = 0.0
		case_panel.anchor_right = 1.0
		case_panel.anchor_bottom = 1.0
		case_panel.offset_left = 0.0
		case_panel.offset_top = 0.0
		case_panel.offset_right = 0.0
		case_panel.offset_bottom = 0.0
		case_root.add_child(case_panel)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 16)
		case_panel.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		margin.add_child(vbox)

		var title := Label.new()
		title.text = String(payload.get("title", "CASE FOLDER"))
		vbox.add_child(title)

		var close_button := Button.new()
		close_button.name = &"CaseFolderClose"
		close_button.text = "X"
		close_button.anchor_left = 1.0
		close_button.anchor_top = 0.0
		close_button.anchor_right = 1.0
		close_button.anchor_bottom = 0.0
		close_button.offset_left = -36
		close_button.offset_top = 8
		close_button.offset_right = -8
		close_button.offset_bottom = 36
		close_button.custom_minimum_size = Vector2(28, 28)
		close_button.z_index = 5
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP
		close_button.pressed.connect(func() -> void:
			if controller != null and controller.has_method("close_overlay"):
				controller.call("close_overlay")
		)
		case_root.add_child(close_button)

		var split := HSplitContainer.new()
		split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		split.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(split)

		var left_scroll := ScrollContainer.new()
		left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		split.add_child(left_scroll)

		var left_text := RichTextLabel.new()
		left_text.text = String(payload.get("left_text", ""))
		left_text.fit_content = true
		left_text.scroll_active = true
		left_text.scroll_following = false
		left_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		left_scroll.add_child(left_text)

		var right_scroll := ScrollContainer.new()
		right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		split.add_child(right_scroll)

		var right_text := RichTextLabel.new()
		right_text.text = String(payload.get("right_text", ""))
		right_text.fit_content = true
		right_text.scroll_active = true
		right_text.scroll_following = false
		right_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right_scroll.add_child(right_text)

func close() -> void:
	if current_root != null:
		current_root.queue_free()
	current_root = null
	current_id = ""

func is_open() -> bool:
	return current_root != null
