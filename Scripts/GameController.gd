extends Node2D

@export var dev_allow_escape_hatch: bool = true

func _unhandled_input(event: InputEvent) -> void:
	if not dev_allow_escape_hatch:
		return

	if not event.is_action_pressed("ui_cancel"):
		return

	var mode := DisplayServer.window_get_mode()

	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

		DisplayServer.window_set_size(Vector2i(1280, 720))
		var screen_size := DisplayServer.screen_get_size()
		var win_size := DisplayServer.window_get_size()
		DisplayServer.window_set_position((screen_size - win_size) / 2)

		print("[DEV] Esc -> windowed")
		get_viewport().set_input_as_handled()
		return

	get_tree().quit()
