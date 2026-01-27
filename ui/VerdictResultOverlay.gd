extends Control
class_name VerdictResultOverlay

signal continued

var _dimmer: ColorRect
var _panel: PanelContainer
var _title: Label
var _body: RichTextLabel
var _btn_continue: Button

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_dimmer = ColorRect.new()
	_dimmer.color = Color(0, 0, 0, 0.75)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dimmer)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(720, 0)
	_panel.add_child(vb)

	_title = Label.new()
	_title.text = "VERDICT SUBMITTED"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)

	_body = RichTextLabel.new()
	_body.fit_content = true
	_body.scroll_active = false
	_body.bbcode_enabled = true
	vb.add_child(_body)

	_btn_continue = Button.new()
	_btn_continue.text = "Continue"
	_btn_continue.pressed.connect(func():
		hide_overlay()
		continued.emit()
	)
	vb.add_child(_btn_continue)

	# Center panel
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -360
	_panel.offset_right = 360
	_panel.offset_top = -140
	_panel.offset_bottom = 140

func show_result(verdict_label: String, truth_guilty: bool, is_correct: bool, is_scapegoat: bool = false) -> void:
	visible = true
	_btn_continue.grab_focus()

	var truth_txt := "GUILTY" if truth_guilty else "INNOCENT"
	var correctness := "CORRECT" if is_correct else "INCORRECT"
	if is_scapegoat:
		correctness = "EXECUTED (YOU LIVE)"
	_btn_continue.text = "Restart" if (not is_correct and not is_scapegoat) else "Continue"

	_body.clear()
	_body.append_text("[b]Verdict:[/b] %s\n" % verdict_label)
	_body.append_text("[b]Result:[/b] %s\n" % correctness)
	_body.append_text("[b]Truth:[/b] %s\n" % truth_txt)

func hide_overlay() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_overlay()
		continued.emit()
		accept_event()
