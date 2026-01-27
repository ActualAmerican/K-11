extends Control

var _left_text: RichTextLabel
var _right_text: RichTextLabel

func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Dimmer
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.anchor_left = 0.0
	dim.anchor_top = 0.0
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	add_child(dim)

	# Center panel
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -520
	panel.offset_top = -300
	panel.offset_right = 520
	panel.offset_bottom = 300
	add_child(panel)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(root)

	var title := Label.new()
	title.text = "CASE FOLDER  (ESC to close)"
	root.add_child(title)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)

	var left := PanelContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(right)

	var left_v := VBoxContainer.new()
	left.add_child(left_v)

	var left_h := Label.new()
	left_h.text = "Charge Sheet (placeholder)"
	left_v.add_child(left_h)

	_left_text = RichTextLabel.new()
	_left_text.fit_content = true
	_left_text.scroll_active = true
	_left_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_v.add_child(_left_text)

	var right_v := VBoxContainer.new()
	right.add_child(right_v)

	var right_h := Label.new()
	right_h.text = "Dossier (placeholder)"
	right_v.add_child(right_h)

	_right_text = RichTextLabel.new()
	_right_text.fit_content = true
	_right_text.scroll_active = true
	_right_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_v.add_child(_right_text)

	_render_placeholder()

func set_suspect(suspect: Object) -> void:
	# Works with SuspectData without hard-typing the class here (keeps it resilient).
	if suspect == null:
		_render_placeholder()
		return

	var left_lines: Array[String] = []
	var right_lines: Array[String] = []

	if suspect.has_method("get"):
		# If SuspectData exposes dict-like access later
		pass

	# Try common fields safely
	var sid := ""
	if "suspect_id" in suspect:
		sid = str(suspect.suspect_id)
	elif suspect.has_method("get_suspect_id"):
		sid = str(suspect.call("get_suspect_id"))

	left_lines.append("[b]Suspect:[/b] %s" % sid)
	left_lines.append("")
	left_lines.append("Charge sheet content will go here (v0).")
	left_lines.append("")

	# Dump tabs/facts if present
	if "tabs" in suspect:
		var tabs = suspect.tabs
		for k in tabs.keys():
			right_lines.append("[b]%s[/b]" % str(k))
			var tabd = tabs[k]
			var facts: Array = []
			if typeof(tabd) == TYPE_DICTIONARY:
				facts = tabd.get("facts", []) as Array
			for f in facts:
				if typeof(f) == TYPE_DICTIONARY:
					var d := f as Dictionary
					var rel := str(d.get("reliability", ""))
					var txt := str(d.get("text", ""))
					if rel != "":
						right_lines.append("- [%s] %s" % [rel, txt])
					else:
						right_lines.append("- %s" % txt)
			right_lines.append("")

	_left_text.clear()
	_left_text.append_text("\n".join(left_lines))

	_right_text.clear()
	_right_text.append_text("\n".join(right_lines))

func _render_placeholder() -> void:
	_left_text.clear()
	_left_text.append_text("No suspect bound.\n\n(Once wired, this will show charge sheet fields.)")
	_right_text.clear()
	_right_text.append_text("No suspect bound.\n\n(Once wired, this will show dossier tabs & facts.)")
