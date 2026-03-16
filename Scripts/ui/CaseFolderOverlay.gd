extends Control

const CaseFolderRender = preload("res://Scripts/case_engine/CaseFolderRender.gd")

var _left_text: RichTextLabel
var _right_text: RichTextLabel
var _case_payload: Dictionary = {}

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
	if suspect == null:
		_case_payload = {}
		_render_placeholder()
		return
	_case_payload = _payload_from_suspect(suspect)
	_render_case()

func set_case_payload(case_payload: Dictionary) -> void:
	_case_payload = case_payload.duplicate(true)
	_render_case()

func _render_case() -> void:
	if _case_payload.is_empty():
		_render_placeholder()
		return
	_left_text.clear()
	_left_text.append_text(CaseFolderRender.render_charge_sheet(_case_payload))
	_right_text.clear()
	_right_text.append_text(CaseFolderRender.render_dossier_summary(_case_payload))

func _render_placeholder() -> void:
	_left_text.clear()
	_left_text.append_text("No case bound.\n\n(Charge sheet will appear here.)")
	_right_text.clear()
	_right_text.append_text("No case bound.\n\n(Dossier summary will appear here.)")

func _payload_from_suspect(suspect: Object) -> Dictionary:
	if not (suspect is SuspectData):
		return {}
	var suspect_dict: Dictionary = SuspectIO.to_dict(suspect as SuspectData)
	var debug_dict: Dictionary = suspect_dict.get("debug", {}) as Dictionary
	var truth_bundle: Dictionary = debug_dict.get("case_engine_truth_bundle", {}) as Dictionary
	return {
		"ok": true,
		"suspect": suspect_dict,
		"truth_bundle": truth_bundle,
	}
