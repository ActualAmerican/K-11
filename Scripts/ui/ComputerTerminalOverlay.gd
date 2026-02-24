extends Control
class_name ComputerTerminalOverlay

var controller: Node = null
var current_tab: StringName = &"HOME"

@onready var title_label: Label = %Title
@onready var tab_home: Button = %TabHome
@onready var tab_req: Button = %TabReq
@onready var tab_logs: Button = %TabLogs
@onready var tab_profile: Button = %TabProfile
@onready var body: RichTextLabel = %Body
@onready var hint: Label = %Hint
@onready var close_btn: Button = %Close

func set_controller(c: Node) -> void:
	controller = c

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	tab_home.pressed.connect(func() -> void: _set_tab(&"HOME"))
	tab_req.pressed.connect(func() -> void: _set_tab(&"REQ"))
	tab_logs.pressed.connect(func() -> void: _set_tab(&"LOGS"))
	tab_profile.pressed.connect(func() -> void: _set_tab(&"PROFILE"))
	close_btn.pressed.connect(_request_close)

	_set_tab(current_tab)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_request_close()
		get_viewport().set_input_as_handled()

func _request_close() -> void:
	if controller != null and controller.has_method("close_overlay"):
		controller.call("close_overlay")

func _set_tab(tab: StringName) -> void:
	current_tab = tab

	tab_home.disabled = (tab == &"HOME")
	tab_req.disabled = (tab == &"REQ")
	tab_logs.disabled = (tab == &"LOGS")
	tab_profile.disabled = (tab == &"PROFILE")

	title_label.text = "K/11 TERMINAL  >  %s" % String(tab)
	hint.text = "ESC: close   |   Tabs: navigate   |   REQ is stubbed (Chapter 13)"

	match tab:
		&"HOME":
			body.text = "[b]HOME[/b]\n\nTerminal shell (9.3).\n\n- Provides the in-game computer environment.\n- Hosts multiple apps (REQ later).\n\n[b]Available:[/b]\n- REQ (stub)\n- LOGS (stub)\n- PROFILE (stub)"
		&"REQ":
			body.text = "[b]REQUISITION[/b]\n\n[stub]\n\nThis will become the REQ system later (Chapter 13).\nFor 9.3 we only need:\n- full-screen terminal\n- navigation works\n- close returns cleanly"
		&"LOGS":
			body.text = "[b]LOGS[/b]\n\n[stub]\n\nLater: run timeline, noise events, revolver events."
		&"PROFILE":
			body.text = "[b]PROFILE[/b]\n\n[stub]\n\nLater: suspect/run profile tools, analysis helpers."
		_:
			body.text = "[b]UNKNOWN TAB[/b]"