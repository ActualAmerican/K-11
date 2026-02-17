extends Node

var current_id: String = ""
var current_root: Node = null
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
	var root := Control.new()
	root.name = &"OverlayRoot"
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 0.0
	root.offset_top = 0.0
	root.offset_right = 0.0
	root.offset_bottom = 0.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(root)
	current_root = root

	var panel := Panel.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	root.add_child(panel)

	if id == "DEV_TEST":
		var label := Label.new()
		label.text = "DEV_TEST OVERLAY"
		label.position = Vector2(24, 24)
		panel.add_child(label)
	if id == "GAME_OVER":
		var dimmer := ColorRect.new()
		dimmer.color = Color(0, 0, 0, 0.75)
		dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		dimmer.anchor_left = 0.0
		dimmer.anchor_top = 0.0
		dimmer.anchor_right = 1.0
		dimmer.anchor_bottom = 1.0
		dimmer.offset_left = 0.0
		dimmer.offset_top = 0.0
		dimmer.offset_right = 0.0
		dimmer.offset_bottom = 0.0
		root.add_child(dimmer)

		var box := PanelContainer.new()
		box.anchor_left = 0.5
		box.anchor_top = 0.5
		box.anchor_right = 0.5
		box.anchor_bottom = 0.5
		box.offset_left = -260
		box.offset_top = -130
		box.offset_right = 260
		box.offset_bottom = 130
		dimmer.add_child(box)
		var box_style := StyleBoxFlat.new()
		box_style.bg_color = Color(0.08, 0.08, 0.08, 0.95)
		box.add_theme_stylebox_override("panel", box_style)

		var v := VBoxContainer.new()
		v.offset_left = 18
		v.offset_top = 18
		v.offset_right = -18
		v.offset_bottom = -18
		box.add_child(v)

		var title := Label.new()
		title.text = "GAME OVER"
		title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		v.add_child(title)

		var reason := Label.new()
		reason.text = str(payload.get("reason", "Killed"))
		reason.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
		v.add_child(reason)

		var btn_row := HBoxContainer.new()
		v.add_child(btn_row)

		var restart := Button.new()
		restart.text = "Restart"
		restart.pressed.connect(func() -> void:
			if controller != null and controller.has_method("_reset_run_state"):
				controller.call("_reset_run_state")
			elif controller != null and controller.has_method("_on_game_over_restart"):
				controller.call("_on_game_over_restart")
			elif controller != null:
				var tree := controller.get_tree()
				if tree != null:
					tree.reload_current_scene()
		)
		btn_row.add_child(restart)

		var quit := Button.new()
		quit.text = "Quit"
		quit.pressed.connect(func() -> void:
			if controller != null and controller.has_method("_on_game_over_quit"):
				controller.call("_on_game_over_quit")
		)
		btn_row.add_child(quit)
	if id == "PHONE":
		var dimmer := ColorRect.new()
		dimmer.anchor_left = 0.0
		dimmer.anchor_top = 0.0
		dimmer.anchor_right = 1.0
		dimmer.anchor_bottom = 1.0
		dimmer.offset_left = 0.0
		dimmer.offset_top = 0.0
		dimmer.offset_right = 0.0
		dimmer.offset_bottom = 0.0
		dimmer.color = Color(0, 0, 0, 0.45)
		dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		root.add_child(dimmer)

		var box := PanelContainer.new()
		box.anchor_left = 0.35
		box.anchor_top = 0.35
		box.anchor_right = 0.65
		box.anchor_bottom = 0.65
		box.offset_left = 0.0
		box.offset_top = 0.0
		box.offset_right = 0.0
		box.offset_bottom = 0.0
		root.add_child(box)

		var vbox := VBoxContainer.new()
		vbox.anchor_left = 0.0
		vbox.anchor_top = 0.0
		vbox.anchor_right = 1.0
		vbox.anchor_bottom = 1.0
		vbox.offset_left = 16
		vbox.offset_top = 16
		vbox.offset_right = -16
		vbox.offset_bottom = -16
		vbox.add_theme_constant_override("separation", 8)
		box.add_child(vbox)

		var title := Label.new()
		var stage := int(payload.get("stage", 1))
		var stages := int(payload.get("stages", 1))
		title.text = "PHONE (%d/%d)" % [stage, stages]
		vbox.add_child(title)

		var info := Label.new()
		var can_silence := bool(payload.get("can_silence", true))
		info.text = "Incoming call. Silence the phone." if can_silence else "Incoming call. Phone cannot be silenced."
		vbox.add_child(info)

		var btn := Button.new()
		btn.text = "Silence"
		btn.disabled = not can_silence
		vbox.add_child(btn)
		btn.pressed.connect(func() -> void:
			if controller != null and controller.has_method("_silence_phone"):
				controller.call("_silence_phone")
			if controller != null and controller.has_method("close_overlay"):
				controller.call("close_overlay")
		)
	if id == "REQ_TERMINAL":
		var dimmer := ColorRect.new()
		dimmer.anchor_left = 0.0
		dimmer.anchor_top = 0.0
		dimmer.anchor_right = 1.0
		dimmer.anchor_bottom = 1.0
		dimmer.offset_left = 0.0
		dimmer.offset_top = 0.0
		dimmer.offset_right = 0.0
		dimmer.offset_bottom = 0.0
		dimmer.color = Color(0, 0, 0, 0.45)
		dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		root.add_child(dimmer)

		var box := PanelContainer.new()
		box.anchor_left = 0.35
		box.anchor_top = 0.35
		box.anchor_right = 0.65
		box.anchor_bottom = 0.65
		box.offset_left = 0.0
		box.offset_top = 0.0
		box.offset_right = 0.0
		box.offset_bottom = 0.0
		root.add_child(box)

		var vbox := VBoxContainer.new()
		vbox.anchor_left = 0.0
		vbox.anchor_top = 0.0
		vbox.anchor_right = 1.0
		vbox.anchor_bottom = 1.0
		vbox.offset_left = 16
		vbox.offset_top = 16
		vbox.offset_right = -16
		vbox.offset_bottom = -16
		vbox.add_theme_constant_override("separation", 8)
		box.add_child(vbox)

		var title := Label.new()
		title.text = String(payload.get("title", "REQUISITION"))
		vbox.add_child(title)

		var info := Label.new()
		info.text = String(payload.get("body", ""))
		vbox.add_child(info)

		var btn := Button.new()
		btn.text = "Close"
		vbox.add_child(btn)
		btn.pressed.connect(func() -> void:
			if controller != null and controller.has_method("close_overlay"):
				controller.call("close_overlay")
		)
	if id == "CASE_HANDLING":
		panel.visible = false
		var bg_block: ColorRect = ColorRect.new()
		bg_block.anchor_left = 0.0
		bg_block.anchor_top = 0.0
		bg_block.anchor_right = 1.0
		bg_block.anchor_bottom = 1.0
		bg_block.offset_left = 0.0
		bg_block.offset_top = 0.0
		bg_block.offset_right = 0.0
		bg_block.offset_bottom = 0.0
		bg_block.color = Color(0, 0, 0, 1)
		bg_block.mouse_filter = Control.MOUSE_FILTER_STOP
		root.add_child(bg_block)
		var scene: PackedScene = preload("res://Scenes/CaseHandlingOverlay.tscn")
		var inst: Node = scene.instantiate()
		if inst != null:
			if inst is Control:
				var inst_ctrl: Control = inst
				inst_ctrl.anchor_left = 0.0
				inst_ctrl.anchor_top = 0.0
				inst_ctrl.anchor_right = 1.0
				inst_ctrl.anchor_bottom = 1.0
				inst_ctrl.offset_left = 0.0
				inst_ctrl.offset_top = 0.0
				inst_ctrl.offset_right = 0.0
				inst_ctrl.offset_bottom = 0.0
			root.add_child(inst)
			if inst.has_signal("finished"):
				inst.connect("finished", func(success: bool, noise_points: int) -> void:
					var cb_finished_v: Variant = payload.get("on_finished", null)
					if cb_finished_v is Callable:
						var cb_finished: Callable = cb_finished_v
						if cb_finished.is_valid():
							cb_finished.call(success, noise_points)
					else:
						var cb_done_v: Variant = payload.get("on_done", null)
						if cb_done_v is Callable:
							var cb_done: Callable = cb_done_v
							if cb_done.is_valid():
								cb_done.call(noise_points)
					close()
				)
			if inst.has_signal("cancelled"):
				inst.connect("cancelled", func() -> void:
					var cb_cancel_v: Variant = payload.get("on_cancel", null)
					if cb_cancel_v is Callable:
						var cb_cancel: Callable = cb_cancel_v
						if cb_cancel.is_valid():
							cb_cancel.call()
					close()
				)
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
		root.add_child(case_root)

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
	if id == "INTERBREAK_CASE" or id == "INTERBREAK_REQ" or id == "INTERBREAK_EXIT":
		if current_root != null:
			current_root.queue_free()
		var ib_layer := CanvasLayer.new()
		ib_layer.layer = 220
		ib_layer.name = &"InterBreakOverlay"
		get_tree().current_scene.add_child(ib_layer)
		current_root = ib_layer
		current_id = id

		var ib_root := Control.new()
		ib_root.name = &"Root"
		ib_root.anchor_left = 0
		ib_root.anchor_top = 0
		ib_root.anchor_right = 1
		ib_root.anchor_bottom = 1
		ib_root.mouse_filter = Control.MOUSE_FILTER_STOP
		ib_layer.add_child(ib_root)

		var ib_dimmer := ColorRect.new()
		ib_dimmer.color = Color(0, 0, 0, 0.55)
		ib_dimmer.anchor_left = 0
		ib_dimmer.anchor_top = 0
		ib_dimmer.anchor_right = 1
		ib_dimmer.anchor_bottom = 1
		ib_root.add_child(ib_dimmer)

		var ib_panel := PanelContainer.new()
		ib_panel.anchor_left = 0.5
		ib_panel.anchor_top = 0.5
		ib_panel.anchor_right = 0.5
		ib_panel.anchor_bottom = 0.5
		ib_panel.offset_left = -380
		ib_panel.offset_top = -160
		ib_panel.offset_right = 380
		ib_panel.offset_bottom = 160
		ib_root.add_child(ib_panel)

		var ib_vb := VBoxContainer.new()
		ib_vb.add_theme_constant_override("separation", 10)
		ib_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ib_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ib_panel.add_child(ib_vb)

		var ib_title := Label.new()
		ib_title.text = String(payload.get("title", "INTERBREAK"))
		ib_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ib_vb.add_child(ib_title)

		var ib_body := Label.new()
		ib_body.text = String(payload.get("body", ""))
		ib_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ib_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ib_vb.add_child(ib_body)

		var ib_continue := Button.new()
		ib_continue.text = "Continue"
		ib_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ib_continue.pressed.connect(func() -> void:
			if controller != null:
				controller.call("_on_interbreak_continue")
		)
		ib_vb.add_child(ib_continue)

func close() -> void:
	if current_root != null:
		current_root.queue_free()
	current_root = null
	current_id = ""

func is_open() -> bool:
	return current_root != null
