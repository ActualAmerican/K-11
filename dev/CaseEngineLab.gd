extends CanvasLayer

signal closed

var _controller: Node = null
var _last_payload: Dictionary = {}

@onready var SeedEdit: LineEdit = %SeedEdit
@onready var IndexSpin: SpinBox = %IndexSpin
@onready var RerollSpin: SpinBox = %RerollSpin
@onready var SummaryLabel: RichTextLabel = %SummaryLabel
@onready var ValidatorList: ItemList = %ValidatorList
@onready var JsonText: TextEdit = %JsonText

func attach(controller: Node) -> void:
	_controller = controller
	_pull_defaults_from_controller()

func _ready() -> void:
	layer = 4096
	_pull_defaults_from_controller()
	_refresh_ui({"level":"PASS","items":[]}, "")

func _pull_defaults_from_controller() -> void:
	if _controller == null:
		return
	if _controller.has_method("get"):
		if _has_prop("run_seed_text"):
			SeedEdit.text = str(_controller.get("run_seed_text"))
		if _has_prop("suspect_index"):
			IndexSpin.value = float(int(_controller.get("suspect_index")))

func _has_prop(name: String) -> bool:
	if _controller == null:
		return false
	for p in _controller.get_property_list():
		if p is Dictionary and str((p as Dictionary).get("name","")) == name:
			return true
	return false

func _on_CloseBtn_pressed() -> void:
	emit_signal("closed")
	queue_free()

func _on_GenerateBtn_pressed() -> void:
	_generate(false)

func _on_NextBtn_pressed() -> void:
	_generate(true)

func _generate(advance_index: bool) -> void:
	var run_seed_text := SeedEdit.text.strip_edges()
	if run_seed_text == "":
		run_seed_text = "K11RUN-DEV"

	var run_seed_u64: int = SeedUtil.parse_k11_seed_to_u63(run_seed_text)
	if run_seed_u64 < 0:
		run_seed_u64 = SeedUtil.derive_seed(0, run_seed_text, 0)

	var idx: int = int(IndexSpin.value)
	var rr: int = int(RerollSpin.value)

	if advance_index:
		idx += 1
		IndexSpin.value = float(idx)

	_last_payload = CaseEngineFacade.generate_case(run_seed_u64, run_seed_text, idx, rr)

	var report: Dictionary = ValidatorSuite.validate_case(_last_payload)
	var json := JSON.stringify(_last_payload, "\t", true)
	_refresh_ui(report, json)

func _refresh_ui(report: Dictionary, json: String) -> void:
	var lvl: String = str(report.get("level", "PASS"))
	var fp: String = str(_last_payload.get("fingerprint", ""))
	var seed_txt: String = str(_last_payload.get("run_seed_text", SeedEdit.text))
	var seed_hex: String = str(_last_payload.get("run_seed_u64_hex", ""))
	var sidx: String = str(_last_payload.get("suspect_index", int(IndexSpin.value)))
	var rr: String = str(_last_payload.get("reroll_index", int(RerollSpin.value)))

	SummaryLabel.clear()
	SummaryLabel.append_text("[b]Case Engine Lab[/b]\n")
	SummaryLabel.append_text("Status: %s\n" % lvl)
	SummaryLabel.append_text("seed: %s (%s)\n" % [seed_txt, seed_hex])
	SummaryLabel.append_text("suspect_index: %s  reroll_index: %s\n" % [sidx, rr])
	SummaryLabel.append_text("fingerprint: %s\n" % fp)
	var gen_trace: Array = _last_payload.get("gen_trace", []) as Array
	if not gen_trace.is_empty():
		SummaryLabel.append_text("dev_trace_steps: %d\n" % gen_trace.size())
		var last_step: Dictionary = gen_trace[gen_trace.size() - 1] as Dictionary
		SummaryLabel.append_text("dev_last_stage: %s\n" % str(last_step.get("stage", "")))

	ValidatorList.clear()
	var items: Array = report.get("items", []) as Array
	for it in items:
		if it is Dictionary:
			var d := it as Dictionary
			ValidatorList.add_item("%s %s: %s" % [d.get("level",""), d.get("code",""), d.get("msg","")])

	JsonText.text = json

func _on_ExportBtn_pressed() -> void:
	if _last_payload.is_empty():
		return
	var dir := "user://case_engine_lab/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var seed_txt: String = str(_last_payload.get("run_seed_text", "K11RUN-DEV"))
	var sidx: String = str(_last_payload.get("suspect_index", 0))
	var rr: String = str(_last_payload.get("reroll_index", 0))
	var fp: String = str(_last_payload.get("fingerprint", ""))
	var fp8 := fp.substr(0, 8) if fp.length() >= 8 else fp
	var path := "%s%s_idx%s_rr%s_%s.json" % [dir, seed_txt, sidx, rr, fp8]
	SuspectIO.write_text(path, JSON.stringify(_last_payload, "\t", true))
