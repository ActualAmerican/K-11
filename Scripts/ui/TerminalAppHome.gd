extends Control
class_name TerminalAppHome

var controller: Node = null
var _is_intermission: bool = false

@onready var title_label: Label = %Title
@onready var body: RichTextLabel = %Body
@onready var banner: Label = %Banner

func set_controller(c: Node) -> void:
	controller = c

func set_intermission_active(v: bool) -> void:
	_is_intermission = v
	refresh()

func refresh() -> void:
	title_label.text = "HOME"

	var state_txt := "ACTIVE"
	if _is_intermission:
		state_txt = "INTERMISSION"

	var suspect_idx := _safe_get_int("suspect_index", -1)
	var noise := _safe_get_int("_noise_value", -1) # may not exist; will show '?'
	var danger := _safe_get_int("_danger_points", -1)

	var lines := []
	lines.append("[b]STATE:[/b] %s" % state_txt)
	if suspect_idx >= 0:
		lines.append("[b]Suspect:[/b] %d" % suspect_idx)
	lines.append("")
	lines.append("[b]APPS:[/b]")
	lines.append("- EXTRACT (stub)")
	lines.append("- REQUISITION (view anytime; spend intermission-only)")
	lines.append("- PROFILE (stub)")
	lines.append("- TELEMETRY (stub)")
	lines.append("")
	lines.append("[b]NOTES:[/b]")
	lines.append("- 9.3 is the terminal shell + router.")
	lines.append("- Chapter 13 implements the REQ shop logic.")
	body.text = "\n".join(lines)

	banner.visible = not _is_intermission
	if not _is_intermission:
		banner.text = "REQ spending locked until intermission."
	else:
		banner.text = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()

func _safe_get_int(key: String, fallback: int) -> int:
	if controller == null:
		return fallback
	var v = controller.get(key)
	if v == null:
		return fallback
	if typeof(v) == TYPE_INT:
		return int(v)
	return fallback
