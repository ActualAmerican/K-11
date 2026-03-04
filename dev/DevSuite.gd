extends RefCounted
class_name DevSuite

const WIPE_PATHS := [
	"user://run_ledger_v0.json",
	"user://profile_v0.json",
	"user://unlocks_v0.json",
	"user://settings_v0.json",
]

const RESET_CONFIRM_WINDOW_MS := 2000

var _controller: Node = null
var _log_cb: Callable = Callable()
var _armed_at_ms: int = 0

func attach(controller: Node, log_cb: Callable) -> void:
	_controller = controller
	_log_cb = log_cb

func factory_reset_arm_or_execute() -> bool:
	var now: int = Time.get_ticks_msec()
	if _armed_at_ms == 0 or (now - _armed_at_ms) > RESET_CONFIRM_WINDOW_MS:
		_armed_at_ms = now
		_log("DEVSUITE: Factory reset ARMED. Press again within %dms." % RESET_CONFIRM_WINDOW_MS)
		return false
	_armed_at_ms = 0
	_factory_reset_execute()
	return true

func _factory_reset_execute() -> void:
	_log("DEVSUITE: Factory reset executing...")

	for p in WIPE_PATHS:
		_wipe_path(p)

	if ClassDB.class_exists("RunLedger"):
		_wipe_path("user://run_ledger_v0.json")

	if _controller != null:
		if _has_property(_controller, "forced_seed_text"):
			_controller.set("forced_seed_text", "")
		if _controller.has_method("_init_seed"):
			_controller.call("_init_seed")
		if _controller.has_method("_reset_run_state"):
			_controller.call("_reset_run_state")

	_log("DEVSUITE: Factory reset complete.")

func grant_all_unlocks() -> void:
	_log("DEVSUITE: grant_all_unlocks (stub) - Profile/Unlock system not implemented yet.")

func grant_unlock(id: String) -> void:
	_log("DEVSUITE: grant_unlock('%s') (stub) - Profile/Unlock system not implemented yet." % id)

func _wipe_path(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var abs_path: String = ProjectSettings.globalize_path(path)
	var err: int = DirAccess.remove_absolute(abs_path)
	if err == OK:
		_log("DEVSUITE: wiped %s" % path)
	else:
		_log("DEVSUITE: failed to wipe %s err=%d" % [path, err])

func _has_property(obj: Object, name: String) -> bool:
	for p in obj.get_property_list():
		if typeof(p) == TYPE_DICTIONARY and String((p as Dictionary).get("name", "")) == name:
			return true
	return false

func _log(msg: String) -> void:
	if _log_cb.is_valid():
		_log_cb.call(msg)
