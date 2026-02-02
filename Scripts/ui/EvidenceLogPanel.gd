extends PanelContainer
class_name EvidenceLogPanel

@export var show_all_tabs: bool = false
@export var max_lines: int = 200
@export var debug_force_visible: bool = false

var _entries: Array[Dictionary] = []
var _active_tab: String = ""
var _rt: RichTextLabel

func _ready() -> void:
	_rt = find_child("EvidenceRichText", true, false) as RichTextLabel
	if _rt == null:
		_build_fallback_ui()
	_apply_debug_style()
	_render()

func _apply_debug_style() -> void:
	# Make the panel obviously visible during v0.
	if debug_force_visible:
		visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.06, 0.82)
	sb.border_color = Color(0.9, 0.9, 1.0, 0.18)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)

	if _rt != null:
		_rt.add_theme_color_override("default_color", Color(0.92, 0.95, 1.0, 1.0))
		_rt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
		_rt.add_theme_constant_override("outline_size", 1)

func set_entries(entries: Array, active_tab: String = "") -> void:
	_entries = []
	for e in entries:
		if typeof(e) == TYPE_DICTIONARY:
			_entries.append(e)
	_active_tab = active_tab
	_render()

func set_active_tab(tab_id: String) -> void:
	_active_tab = tab_id
	_render()

func clear() -> void:
	_entries.clear()
	_render()

func _render() -> void:
	if _rt == null:
		return

	var lines: Array[String] = []
	var count: int = 0

	for e in _entries:
		if count >= max_lines:
			break
		var tab: String = String(e.get("tab", ""))
		if not show_all_tabs and _active_tab != "" and tab != _active_tab:
			continue

		lines.append(_format_entry(e))
		count += 1

	if lines.is_empty():
		var t := _active_tab
		if t == "":
			t = "ALL"
		_rt.text = "(no entries for %s)" % t
	else:
		_rt.text = "\n".join(lines)

func _format_entry(e: Dictionary) -> String:
	var tab: String = String(e.get("tab", ""))
	var rel: String = String(e.get("reliability", "")).strip_edges().to_upper()
	var text: String = String(e.get("text", ""))

	var badge: String = "[UNK]"
	match rel:
		"SOLID":
			badge = "[SOLID]"
		"SHAKY":
			badge = "[SHAKY]"
		"CORRUPTED":
			badge = "[CORRUPTED]"

	var conflict_mark: String = ""
	if bool(e.get("conflict", false)):
		conflict_mark = " ( )"

	var prefix: String = ""
	if show_all_tabs and tab != "":
		prefix = "[%s] %s" % [tab, badge]
	else:
		prefix = badge

	return ("%s %s%s" % [prefix, text, conflict_mark]).strip_edges()

func _build_fallback_ui() -> void:
	var sc := ScrollContainer.new()
	sc.name = &"Scroll"
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(sc)

	_rt = RichTextLabel.new()
	_rt.name = &"EvidenceRichText"
	_rt.fit_content = true
	_rt.scroll_active = true
	_rt.scroll_following = false
	_rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(_rt)
