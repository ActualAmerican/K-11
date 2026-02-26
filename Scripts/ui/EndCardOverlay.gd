extends Control
class_name EndCardOverlay

var controller: Node = null
var payload: Dictionary = {}

@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var stats: RichTextLabel = %Stats
@onready var play_again: Button = %PlayAgain
@onready var back_menu: Button = %BackToMenu
@onready var quit_btn: Button = %Quit

func set_controller(c: Node) -> void:
	controller = c

func configure_from_payload(p: Dictionary) -> void:
	payload = p
	_refresh()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	play_again.pressed.connect(_on_play_again)
	back_menu.pressed.connect(_on_back_to_menu)
	quit_btn.pressed.connect(_on_quit)

	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_play_again()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	var reason := str(payload.get("reason", "Exit Protocol"))
	title_label.text = str(payload.get("title", "ESCAPED"))
	subtitle_label.text = reason

	var lines := []
	lines.append("[b]Run Stats[/b]")
	lines.append("")
	lines.append("Suspects cleared: %s" % str(payload.get("suspects_cleared", "?")))
	lines.append("Noise: %s" % str(payload.get("noise", "?")))
	lines.append("Danger: %s" % str(payload.get("danger", "?")))
	lines.append("Rounds used: %s" % str(payload.get("revolver_pulls_used", "?")))
	lines.append("")
	lines.append("[i](More stats later. Menu later.)[/i]")
	stats.text = "\n".join(lines)

func _on_play_again() -> void:
	if controller != null:
		if controller.has_method("_reset_run_state"):
			controller.call("_reset_run_state")
			return
	# fallback
	get_tree().reload_current_scene()

func _on_back_to_menu() -> void:
	# menu not implemented; stub just closes overlay for now
	if controller != null and controller.has_method("close_overlay"):
		controller.call("close_overlay")

func _on_quit() -> void:
	get_tree().quit()