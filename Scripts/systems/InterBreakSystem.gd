extends RefCounted
class_name InterBreakSystem

signal finished

enum Step { CASE_WRAP, REQUISITION, EXIT_PROMPT }

var _controller: Node = null
var _active: bool = false
var _step: int = Step.CASE_WRAP

func setup(controller: Node) -> void:
	_controller = controller

func is_active() -> bool:
	return _active

func current_step() -> int:
	return _step

func start_from_verdict() -> void:
	_active = true
	_step = Step.CASE_WRAP
	_open_step()

func advance() -> void:
	if not _active:
		return
	match _step:
		Step.CASE_WRAP:
			_step = Step.REQUISITION
			_open_step()
		Step.REQUISITION:
			_step = Step.EXIT_PROMPT
			_open_step()
		Step.EXIT_PROMPT:
			_active = false
			if _controller != null and _controller.has_method("close_overlay"):
				_controller.call("close_overlay")
			finished.emit()

func _open_step() -> void:
	if _controller == null or not _controller.has_method("open_overlay"):
		_active = false
		finished.emit()
		return

	var id := ""
	var title := ""
	var body := ""

	match _step:
		Step.CASE_WRAP:
			id = "INTERBREAK_CASE"
			title = "CASE HANDLING"
			body = "Placeholder (9.2). File the case and apply consequences."
		Step.REQUISITION:
			id = "INTERBREAK_REQ"
			title = "REQUISITION"
			body = "Placeholder (9.3). Spend REQ in the terminal."
		Step.EXIT_PROMPT:
			id = "INTERBREAK_EXIT"
			title = "EXIT PROMPT"
			body = "Placeholder (9.4). Initiate exit protocol or continue the run."

	_controller.call("open_overlay", id, {"title": title, "body": body})
