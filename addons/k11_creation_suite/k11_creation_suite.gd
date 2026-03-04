@tool
extends EditorPlugin

const WIPE_PATHS := [
	"user://run_ledger_v0.json",
	"user://dev_grants_v0.json",
	"user://profile_v0.json",
	"user://unlocks_v0.json",
	"user://settings_v0.json",
]

const ARM_WINDOW_MS := 2000

var _dock: VBoxContainer
var _status: Label
var _armed_at_ms: int = 0
var _grant_ids: LineEdit
var _bottom_button: Button = null

func _enter_tree() -> void:
	_dock = VBoxContainer.new()
	_dock.name = "K11 Suite"

	var title: Label = Label.new()
	title.text = "K11 Creation Suite"
	_dock.add_child(title)

	_status = Label.new()
	_status.text = "Ready."
	_dock.add_child(_status)

	var btn_open: Button = Button.new()
	btn_open.text = "Open user:// folder"
	btn_open.pressed.connect(_open_user_dir)
	_dock.add_child(btn_open)

	var sep1: HSeparator = HSeparator.new()
	_dock.add_child(sep1)

	var btn_wipe_ledger: Button = Button.new()
	btn_wipe_ledger.text = "Wipe Run Ledger"
	btn_wipe_ledger.pressed.connect(_wipe_run_ledger)
	_dock.add_child(btn_wipe_ledger)

	var btn_wipe_all: Button = Button.new()
	btn_wipe_all.text = "FACTORY RESET (2-click confirm)"
	btn_wipe_all.pressed.connect(_factory_reset_arm_or_execute)
	_dock.add_child(btn_wipe_all)

	var sep2: HSeparator = HSeparator.new()
	_dock.add_child(sep2)

	var grants_lbl: Label = Label.new()
	grants_lbl.text = "Dev Grants (stub for future unlock system)"
	_dock.add_child(grants_lbl)

	_grant_ids = LineEdit.new()
	_grant_ids.placeholder_text = "Unlock IDs (comma separated), optional"
	_dock.add_child(_grant_ids)

	var btn_grant_all: Button = Button.new()
	btn_grant_all.text = "Write dev_grants: grant_all=true"
	btn_grant_all.pressed.connect(_write_grant_all)
	_dock.add_child(btn_grant_all)

	var btn_grant_ids: Button = Button.new()
	btn_grant_ids.text = "Write dev_grants: grant_ids=[...]"
	btn_grant_ids.pressed.connect(_write_grant_ids)
	_dock.add_child(btn_grant_ids)

	var btn_clear_grants: Button = Button.new()
	btn_clear_grants.text = "Clear dev_grants"
	btn_clear_grants.pressed.connect(_clear_grants)
	_dock.add_child(btn_clear_grants)

	_bottom_button = add_control_to_bottom_panel(_dock, "K11 Suite")
	if _bottom_button != null:
		make_bottom_panel_item_visible(_dock)

func _exit_tree() -> void:
	if _dock != null:
		if _bottom_button != null:
			remove_control_from_bottom_panel(_dock)
			_bottom_button = null
		else:
			remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null

func _factory_reset_arm_or_execute() -> void:
	var now: int = Time.get_ticks_msec()
	if _armed_at_ms == 0 or (now - _armed_at_ms) > ARM_WINDOW_MS:
		_armed_at_ms = now
		_set_status("ARMED: click again within %dms" % ARM_WINDOW_MS)
		return
	_armed_at_ms = 0
	var wiped: int = 0
	for p in WIPE_PATHS:
		if _wipe_path(p):
			wiped += 1
	_set_status("Factory reset done. wiped=%d" % wiped)

func _wipe_run_ledger() -> void:
	var ok: bool = _wipe_path("user://run_ledger_v0.json")
	_set_status("Wipe Run Ledger: %s" % ("OK" if ok else "NOOP/FAIL"))

func _open_user_dir() -> void:
	var abs_path: String = ProjectSettings.globalize_path("user://")
	var uri: String = "file:///" + abs_path.replace("\\", "/")
	OS.shell_open(uri)
	_set_status("Opened user://")

func _write_grant_all() -> void:
	var data: Dictionary = {
		"grant_all": true,
		"grant_ids": [],
		"written_ms": Time.get_ticks_msec(),
	}
	_write_json("user://dev_grants_v0.json", data)
	_set_status("Wrote dev_grants: grant_all=true (stub)")

func _write_grant_ids() -> void:
	var raw: String = _grant_ids.text.strip_edges()
	var ids: Array[String] = []
	if raw != "":
		for part in raw.split(",", false):
			var s: String = String(part).strip_edges()
			if s != "":
				ids.append(s)

	var data: Dictionary = {
		"grant_all": false,
		"grant_ids": ids,
		"written_ms": Time.get_ticks_msec(),
	}
	_write_json("user://dev_grants_v0.json", data)
	_set_status("Wrote dev_grants: ids=%d (stub)" % ids.size())

func _clear_grants() -> void:
	var ok: bool = _wipe_path("user://dev_grants_v0.json")
	_set_status("Clear dev_grants: %s" % ("OK" if ok else "NOOP/FAIL"))

func _wipe_path(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var abs_path: String = ProjectSettings.globalize_path(path)
	var err: int = DirAccess.remove_absolute(abs_path)
	return err == OK

func _write_json(path: String, data: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t", true))

func _set_status(msg: String) -> void:
	if _status != null:
		_status.text = msg
