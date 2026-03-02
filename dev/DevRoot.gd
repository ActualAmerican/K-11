extends Node

const CTRL_GROUP := "game_controller"

var controller: Node = null
var _last_controller_id: int = -1
var _dev: DevHarness = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not DevGate.ENABLED:
		return
	_dev = DevHarness.new()
	add_child(_dev)

func _process(_delta: float) -> void:
	if not DevGate.ENABLED:
		return
	_bind_controller()
	if _dev != null:
		_dev.tick(_delta)

func _unhandled_input(event: InputEvent) -> void:
	if not DevGate.ENABLED:
		return
	if _dev == null:
		return
	if _dev.handle_input(event):
		get_viewport().set_input_as_handled()

func _bind_controller() -> void:
	var c: Node = get_node_or_null("/root/GameController")
	if c == null:
		c = get_tree().get_first_node_in_group(CTRL_GROUP)
	if c == null:
		if controller != null:
			controller = null
			_last_controller_id = -1
			if _dev != null:
				_dev.attach(null)
		return
	var id: int = c.get_instance_id()
	if id == _last_controller_id:
		return
	controller = c
	_last_controller_id = id
	if _dev != null:
		_dev.attach(controller)

func handle_case_handling_input(event: InputEvent, scene: Node) -> bool:
	if not DevGate.ENABLED:
		return false
	if _dev == null:
		return false
	return _dev.handle_case_handling_input(event, scene)

func log_line(msg: String) -> void:
	if _dev != null and _dev.has_method("_log"):
		_dev.call("_log", msg)
