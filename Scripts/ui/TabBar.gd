extends HBoxContainer

signal tab_changed(tab_id: String)

@export var default_tab: String = "ALIBI"

var current_tab: String = ""
var _buttons: Array[Button] = []

func _ready() -> void:
	_buttons.clear()

	for child in get_children():
		if child is Button:
			var b := child as Button
			b.toggle_mode = true
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b.pressed.connect(_on_button_pressed.bind(b))
			_buttons.append(b)

	if _buttons.is_empty():
		return

	var initial: Button = null

	if default_tab != "":
		for b in _buttons:
			if b.name == default_tab or b.text == default_tab:
				initial = b
				break

	if initial == null:
		for b in _buttons:
			if b.button_pressed:
				initial = b
				break

	if initial == null:
		initial = _buttons[0]

	_select(initial, false)

func _on_button_pressed(b: Button) -> void:
	_select(b, true)

func _select(b: Button, should_emit_signal: bool) -> void:
	for other in _buttons:
		other.button_pressed = (other == b)

	var tab_name: String = String(b.name)
	current_tab = tab_name if tab_name != "" else b.text

	if should_emit_signal:
		print("[K11] TAB -> %s" % current_tab)
		tab_changed.emit(current_tab)

func set_tab(tab_id: String) -> void:
	for b in _buttons:
		if b.name == tab_id or b.text == tab_id:
			_select(b, true)
			return

func get_current_tab() -> String:
	return current_tab
