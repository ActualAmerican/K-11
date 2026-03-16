@tool
extends Control

const LabPreview = preload("res://addons/case_engine_lab/CaseEngineLabPreview.gd")
const CaseEngineLabAudit = preload("res://addons/case_engine_lab/CaseEngineLabAudit.gd")
const CaseEngineFacadeScript = preload("res://Scripts/case_engine/CaseEngineFacade.gd")
const CaseFolderRender = preload("res://Scripts/case_engine/CaseFolderRender.gd")

var _last_payload: Dictionary = {}
var _last_audit: Dictionary = {}
var _last_batch_report: Dictionary = {}
var _last_csv: String = ""
var _last_generate_ms: float = 0.0
const REROLL_BUDGET: int = 12

var _last_gate_trace: Array[Dictionary] = []
var _last_gate_attempts: int = 0
var _last_gate_reject_codes: PackedStringArray = []
var _folio_spreads: Array[Dictionary] = []
var _folio_spread_index: int = 0

@onready var SeedEdit: LineEdit = %SeedEdit
@onready var IndexSpin: SpinBox = %IndexSpin
@onready var RerollSpin: SpinBox = %RerollSpin
@onready var GenerateBtn: Button = %GenerateBtn
@onready var NextBtn: Button = %NextBtn
@onready var Batch200Btn: Button = %Batch200Btn
@onready var Batch2kBtn: Button = %Batch2kBtn
@onready var ExportCsvBtn: Button = %ExportCsvBtn
@onready var ExportJsonBtn: Button = %ExportJsonBtn
@onready var ClearBtn: Button = %ClearBtn
@onready var FolioBtn: Button = %FolioBtn
@onready var Summary: RichTextLabel = %Summary
@onready var PreviewTabs: TabBar = %PreviewTabs
@onready var EvidenceTabs: TabBar = %EvidenceTabs
@onready var PreviewText: TextEdit = %PreviewText
@onready var ValidatorList: ItemList = %ValidatorList
@onready var JsonText: TextEdit = %JsonText
@onready var FaultMode: OptionButton = %FaultMode
@onready var FaultNoTimeline: CheckBox = %FaultNoTimeline
@onready var FaultGuiltTell: CheckBox = %FaultGuiltTell
@onready var FaultUnresolvable: CheckBox = %FaultUnresolvable
@onready var FaultCorruptAnchors: CheckBox = %FaultCorruptAnchors
@onready var TruthToggle: CheckBox = %TruthToggle
@onready var FolioWindow: Window = %FolioWindow
@onready var SpreadTitle: Label = %SpreadTitle
@onready var PrevSpreadBtn: Button = %PrevSpreadBtn
@onready var NextSpreadBtn: Button = %NextSpreadBtn
@onready var CloseFolioBtn: Button = %CloseFolioBtn
@onready var LeftPageTitle: Label = %LeftPageTitle
@onready var LeftPageBody: RichTextLabel = %LeftPageBody
@onready var RightPageTitle: Label = %RightPageTitle
@onready var RightPageBody: RichTextLabel = %RightPageBody

func _ready() -> void:
	FaultMode.clear()
	FaultMode.add_item("OFF", 0)
	FaultMode.add_item("ONCE", 1)
	FaultMode.add_item("ALWAYS", 2)
	FaultMode.select(0)
	_sync_fault_ui()
	Summary.custom_minimum_size.y = 96.0
	var fm_cb := Callable(self, "_on_fault_mode_selected")
	if not FaultMode.item_selected.is_connected(fm_cb):
		FaultMode.item_selected.connect(fm_cb)
	var generate_cb := Callable(self, "_on_GenerateBtn_pressed")
	if GenerateBtn != null and not GenerateBtn.pressed.is_connected(generate_cb):
		GenerateBtn.pressed.connect(generate_cb)
	var next_cb := Callable(self, "_on_NextBtn_pressed")
	if NextBtn != null and not NextBtn.pressed.is_connected(next_cb):
		NextBtn.pressed.connect(next_cb)
	var batch200_cb := Callable(self, "_on_Batch200Btn_pressed")
	if Batch200Btn != null and not Batch200Btn.pressed.is_connected(batch200_cb):
		Batch200Btn.pressed.connect(batch200_cb)
	var batch2k_cb := Callable(self, "_on_Batch2kBtn_pressed")
	if Batch2kBtn != null and not Batch2kBtn.pressed.is_connected(batch2k_cb):
		Batch2kBtn.pressed.connect(batch2k_cb)
	var export_csv_cb := Callable(self, "_on_ExportCsvBtn_pressed")
	if ExportCsvBtn != null and not ExportCsvBtn.pressed.is_connected(export_csv_cb):
		ExportCsvBtn.pressed.connect(export_csv_cb)
	var export_json_cb := Callable(self, "_on_ExportJsonBtn_pressed")
	if ExportJsonBtn != null and not ExportJsonBtn.pressed.is_connected(export_json_cb):
		ExportJsonBtn.pressed.connect(export_json_cb)
	var clear_cb := Callable(self, "_on_ClearBtn_pressed")
	if ClearBtn != null and not ClearBtn.pressed.is_connected(clear_cb):
		ClearBtn.pressed.connect(clear_cb)
	var folio_cb := Callable(self, "_on_FolioBtn_pressed")
	if FolioBtn != null and not FolioBtn.pressed.is_connected(folio_cb):
		FolioBtn.pressed.connect(folio_cb)
	_last_payload = {}
	_last_audit = {}
	_last_batch_report = {}
	_last_csv = ""
	Summary.clear()
	Summary.append_text("[b]Case Engine Lab (Editor)[/b]\n")
	Summary.append_text("Ready\n")
	ValidatorList.clear()
	PreviewText.text = ""
	JsonText.text = "Awaiting Generate..."
	_sync_preview_ui()
	_update_preview()
	if TruthToggle != null:
		var cb := Callable(self, "_on_truth_toggled")
		if not TruthToggle.toggled.is_connected(cb):
			TruthToggle.toggled.connect(cb)
	if PreviewTabs != null:
		var preview_cb := Callable(self, "_on_preview_tab_changed")
		if not PreviewTabs.tab_changed.is_connected(preview_cb):
			PreviewTabs.tab_changed.connect(preview_cb)
	if EvidenceTabs != null:
		var evidence_cb := Callable(self, "_on_evidence_tab_changed")
		if not EvidenceTabs.tab_changed.is_connected(evidence_cb):
			EvidenceTabs.tab_changed.connect(evidence_cb)
	if PrevSpreadBtn != null:
		var prev_cb := Callable(self, "_on_PrevSpreadBtn_pressed")
		if not PrevSpreadBtn.pressed.is_connected(prev_cb):
			PrevSpreadBtn.pressed.connect(prev_cb)
	if NextSpreadBtn != null:
		var next_spread_cb := Callable(self, "_on_NextSpreadBtn_pressed")
		if not NextSpreadBtn.pressed.is_connected(next_spread_cb):
			NextSpreadBtn.pressed.connect(next_spread_cb)
	if CloseFolioBtn != null:
		var close_folio_cb := Callable(self, "_on_CloseFolioBtn_pressed")
		if not CloseFolioBtn.pressed.is_connected(close_folio_cb):
			CloseFolioBtn.pressed.connect(close_folio_cb)

func _on_GenerateBtn_pressed() -> void:
	Summary.clear()
	Summary.append_text("[b]Case Engine Lab (Editor)[/b]\n")
	Summary.append_text("Generate clicked...\n")
	JsonText.text = "Running gate..."
	_generate(false)

func _on_ClearBtn_pressed() -> void:
	_last_payload = {}
	_last_audit = {}
	_last_batch_report = {}
	_last_csv = ""
	_last_generate_ms = 0.0
	_last_gate_trace = []
	_last_gate_attempts = 0
	_last_gate_reject_codes = []

	Summary.clear()
	Summary.append_text("[b]Case Engine Lab (Editor)[/b]\n")
	Summary.append_text("Ready\n")
	ValidatorList.clear()
	PreviewText.text = ""
	JsonText.text = "Awaiting Generate..."

func _on_NextBtn_pressed() -> void:
	Summary.clear()
	Summary.append_text("[b]Case Engine Lab (Editor)[/b]\n")
	Summary.append_text("Next clicked...\n")
	JsonText.text = "Running gate..."
	_generate(true)

func _on_Batch200Btn_pressed() -> void:
	_run_batch(200)

func _on_Batch2kBtn_pressed() -> void:
	_run_batch(2000)

func _on_FolioBtn_pressed() -> void:
	_build_folio_spreads()
	_folio_spread_index = 0
	_refresh_folio()
	if FolioWindow != null:
		FolioWindow.popup_centered_ratio(0.9)

func _on_ExportJsonBtn_pressed() -> void:
	if _last_payload.is_empty():
		Summary.append_text("json: none (Generate first)\n")
		return

	var dir := "user://case_engine_lab/"
	var abs_dir := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)

	var seed_txt := _safe_filename(str(_last_payload.get("run_seed_text", "K11-DEV")))
	var sidx := str(_last_payload.get("suspect_index", 0))
	var rr := str(_last_payload.get("reroll_index", 0))
	var fp := str(_last_payload.get("fingerprint", ""))
	var fp8 := fp.substr(0, 8) if fp.length() >= 8 else fp

	var path := "%s%s_idx%s_rr%s_%s.json" % [dir, seed_txt, sidx, rr, fp8]
	var abs_path := ProjectSettings.globalize_path(path)
	var audit_path := "%s%s_idx%s_rr%s_%s_audit.json" % [dir, seed_txt, sidx, rr, fp8]
	var abs_audit_path := ProjectSettings.globalize_path(audit_path)

	if not _write_json_file(path, _last_payload):
		Summary.append_text("json: failed\n")
		return
	if _last_audit.is_empty():
		_last_audit = CaseEngineLabAudit.build_case_audit(_last_payload, {"level":"REJECT","items":[]}, {
			"attempts": _last_gate_attempts,
			"final_rr": int(_last_payload.get("reroll_index", 0)),
			"reject_codes": _last_gate_reject_codes,
			"gate_ms": _last_generate_ms,
			"exhausted": false,
			"dup_rejects": 0,
		})
	var audit_saved: bool = false
	if not _last_audit.is_empty():
		audit_saved = _write_json_file(audit_path, _last_audit)

	DisplayServer.clipboard_set(abs_path)
	Summary.append_text("Saved: %s\n" % abs_path)
	if audit_saved:
		Summary.append_text("Saved: %s\n" % abs_audit_path)
	else:
		Summary.append_text("audit: failed\n")

func _on_ExportCsvBtn_pressed() -> void:
	if _last_csv == "":
		Summary.append_text("csv: none (run Batch 200/2000)\n")
		return

	var dir := "user://case_engine_lab/"
	var abs_dir := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)

	var seed_txt := _safe_filename(SeedEdit.text.strip_edges())
	if seed_txt == "":
		seed_txt = "K11-DEV"

	var path := "%s%s_batch.csv" % [dir, seed_txt]
	var abs_path := ProjectSettings.globalize_path(path)

	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		var err := FileAccess.get_open_error()
		Summary.append_text("csv: failed (%s)\n" % error_string(err))
		return

	f.store_string(_last_csv)
	f.close()

	DisplayServer.clipboard_set(abs_path)
	Summary.append_text("Saved: %s\n" % abs_path)

func _generate(advance_index: bool) -> void:
	JsonText.text = "Generating..."
	var run_seed_text := SeedEdit.text.strip_edges()
	if run_seed_text == "":
		run_seed_text = "K11-DEV"

	var run_seed_u64: int = _parse_seed_u63(run_seed_text)
	if run_seed_u64 < 0:
		_last_payload = {"ok": false, "error": "Invalid seed", "run_seed_text": run_seed_text}
		_last_gate_trace = []
		_last_gate_attempts = 0
		_last_gate_reject_codes = []
		_refresh_ui({"level":"REJECT","items":[{"level":"REJECT","code":"BAD_SEED","msg":"Invalid seed text."}]}, JSON.stringify(_last_payload, "\t", true), 0.0)
		return

	var idx: int = int(IndexSpin.value)
	var rr_start: int = int(RerollSpin.value)

	if advance_index:
		idx += 1
		IndexSpin.value = float(idx)

	var gate: Dictionary = _run_gate(run_seed_u64, run_seed_text, idx, rr_start, null)
	if gate.is_empty():
		_last_payload = {
			"ok": false,
			"error": "DOCK_EMPTY_GATE",
			"run_seed_text": run_seed_text,
			"run_seed_u64_hex": SeedUtil.hex16(run_seed_u64),
			"suspect_index": idx,
			"reroll_index": rr_start,
		}
		_last_gate_trace = []
		_last_gate_attempts = 0
		_last_gate_reject_codes = PackedStringArray(["DOCK_EMPTY_GATE"])
		_last_generate_ms = 0.0
		_last_audit = {}
		var empty_report: Dictionary = {
			"level": "REJECT",
			"items": [{"level":"REJECT","code":"DOCK_EMPTY_GATE","msg":"Dock gate returned an empty result."}]
		}
		_refresh_ui(empty_report, JSON.stringify(_last_payload, "\t", true), 0.0)
		return
	_last_payload = gate.get("payload", {}) as Dictionary
	var report: Dictionary = gate.get("report", {"level":"REJECT","items":[{"level":"REJECT","code":"GATE_EMPTY","msg":"Gate returned no payload."}]}) as Dictionary
	if _last_payload.is_empty() and report.is_empty():
		_last_payload = {
			"ok": false,
			"error": "DOCK_EMPTY_GATE",
			"run_seed_text": run_seed_text,
			"run_seed_u64_hex": SeedUtil.hex16(run_seed_u64),
			"suspect_index": idx,
			"reroll_index": rr_start,
		}
		report = {
			"level": "REJECT",
			"items": [{"level":"REJECT","code":"DOCK_EMPTY_GATE","msg":"Dock gate returned no payload or report."}]
		}

	_last_gate_trace = _to_dict_array(gate.get("trace", []))
	_last_gate_attempts = int(gate.get("attempts", 0))
	_last_gate_reject_codes = gate.get("final_reject_codes", PackedStringArray()) as PackedStringArray
	_last_generate_ms = float(gate.get("gate_ms", 0.0))
	_last_audit = CaseEngineLabAudit.build_case_audit(_last_payload, report, {
		"attempts": _last_gate_attempts,
		"final_rr": int(gate.get("final_rr", rr_start)),
		"final_outcome": str(report.get("level", "REJECT")),
		"final_reject_codes": gate.get("final_reject_codes", PackedStringArray()),
		"attempt_reject_codes": gate.get("attempt_reject_codes", PackedStringArray()),
		"attempt_history": gate.get("attempt_history", []),
		"gate_ms": _last_generate_ms,
		"exhausted": bool(gate.get("exhausted", false)),
		"dup_rejects": int(gate.get("dup_rejects", 0)),
	})
	_last_batch_report = {}

	var json := JSON.stringify(_last_payload, "\t", true)
	_refresh_ui(report, json, _last_generate_ms)
	if FolioWindow != null and FolioWindow.visible:
		_build_folio_spreads()
		_refresh_folio()

func _run_batch(n: int) -> void:
	var run_seed_text := SeedEdit.text.strip_edges()
	if run_seed_text == "":
		run_seed_text = "K11-DEV"

	var run_seed_u64: int = _parse_seed_u63(run_seed_text)
	if run_seed_u64 < 0:
		return

	var start_idx: int = int(IndexSpin.value)
	var rr_start: int = int(RerollSpin.value)

	var pass_ct := 0
	var warn_ct := 0
	var reject_ct := 0

	var total_ms: float = 0.0
	var max_gate_ms: float = 0.0
	var total_rerolls_used: int = 0
	var max_rerolls_used: int = 0
	var exhausted_ct: int = 0
	var dup_prevented: int = 0

	var final_reject_code_counts: Dictionary = {}
	var attempt_reject_code_counts: Dictionary = {}
	var seen_fp: Dictionary = {}
	var accepted_count: int = 0
	var accepted_pool_totals: Dictionary = _zero_pool_counts()
	var accepted_reliability_totals_by_tab: Dictionary = _zero_reliability_by_tab()
	var missing_strong_timeline_anchor_count: int = 0
	var missing_strong_alibi_or_capability_anchor_count: int = 0
	var missing_strong_motive_or_relationship_anchor_count: int = 0
	var missing_required_fact_type_count: int = 0
	var missing_required_anchor_count: int = 0
	var unresolved_conflict_group_count: int = 0
	var profile_card_leak_hit_count: int = 0
	var guilt_tell_hit_count: int = 0
	var first_accepted_cases: Array[Dictionary] = []
	var first_rejected_cases: Array[Dictionary] = []

	var salvaged_anchor_only_corrupted_count: int = 0
	var salvaged_missing_conflict_group_count: int = 0
	var salvaged_unresolvable_conflict_group_count: int = 0

	var rows: PackedStringArray = []
	rows.append("seed_text,seed_hex,suspect_index,reroll_index,attempts,rerolls_used,fingerprint,level,reject_codes,gate_ms")

	for i in range(n):
		var idx := start_idx + i
		var gate: Dictionary = _run_gate(run_seed_u64, run_seed_text, idx, rr_start, seen_fp)

		var payload: Dictionary = gate.get("payload", {}) as Dictionary
		var report: Dictionary = gate.get("report", {"level":"REJECT","items":[]}) as Dictionary
		var level: String = str(report.get("level", "REJECT"))
		var attempts: int = int(gate.get("attempts", 0))
		var final_rr: int = int(gate.get("final_rr", rr_start))
		var rerolls_used: int = maxi(final_rr - rr_start, 0)
		var gate_ms: float = float(gate.get("gate_ms", 0.0))
		var final_reject_codes: PackedStringArray = gate.get("final_reject_codes", PackedStringArray()) as PackedStringArray
		var attempt_reject_codes: PackedStringArray = gate.get("attempt_reject_codes", PackedStringArray()) as PackedStringArray
		var audit: Dictionary = CaseEngineLabAudit.build_case_audit(payload, report, {
			"attempts": attempts,
			"final_rr": final_rr,
			"final_outcome": level,
			"final_reject_codes": final_reject_codes,
			"attempt_reject_codes": attempt_reject_codes,
			"attempt_history": gate.get("attempt_history", []),
			"gate_ms": gate_ms,
			"exhausted": bool(gate.get("exhausted", false)),
			"dup_rejects": int(gate.get("dup_rejects", 0)),
		})
		var digest: Dictionary = CaseEngineLabAudit.compact_digest(audit)
		var final_outcome: String = str(digest.get("final_outcome", level))

		total_ms += gate_ms
		max_gate_ms = maxf(max_gate_ms, gate_ms)
		total_rerolls_used += rerolls_used
		max_rerolls_used = maxi(max_rerolls_used, rerolls_used)
		if bool(gate.get("exhausted", false)):
			exhausted_ct += 1
		dup_prevented += int(gate.get("dup_rejects", 0))

		if final_outcome == "REJECT":
			reject_ct += 1
		elif final_outcome == "WARN":
			warn_ct += 1
		else:
			pass_ct += 1

		for c in final_reject_codes:
			var code: String = str(c)
			if code == "":
				continue
			final_reject_code_counts[code] = int(final_reject_code_counts.get(code, 0)) + 1
		for c in attempt_reject_codes:
			var attempt_code: String = str(c)
			if attempt_code == "":
				continue
			attempt_reject_code_counts[attempt_code] = int(attempt_reject_code_counts.get(attempt_code, 0)) + 1

		var fp: String = str(payload.get("fingerprint", ""))
		var seed_hex: String = SeedUtil.hex16(run_seed_u64)

		rows.append("%s,%s,%d,%d,%d,%d,%s,%s,%s,%.3f" % [
			_csv(run_seed_text),
			seed_hex,
			idx,
			final_rr,
			attempts,
			rerolls_used,
			fp,
			final_outcome,
			_csv(";".join(final_reject_codes)),
			gate_ms
		])

		_last_payload = payload
		_last_audit = audit
		salvaged_anchor_only_corrupted_count += int(digest.get("salvaged_anchor_only_corrupted_count", 0))
		salvaged_missing_conflict_group_count += int(digest.get("salvaged_missing_conflict_group_count", 0))
		salvaged_unresolvable_conflict_group_count += int(digest.get("salvaged_unresolvable_conflict_group_count", 0))
		if final_outcome == "REJECT":
			if first_rejected_cases.size() < 8:
				first_rejected_cases.append(_batch_case_sample(idx, final_rr, fp, final_outcome, _string_array_from_packed(final_reject_codes), _string_array_from_packed(attempt_reject_codes), attempts, audit))
			continue
		accepted_count += 1
		if first_accepted_cases.size() < 8:
			first_accepted_cases.append(_batch_case_sample(idx, final_rr, fp, final_outcome, _string_array_from_packed(final_reject_codes), _string_array_from_packed(attempt_reject_codes), attempts, audit))
		_accumulate_pool_totals(accepted_pool_totals, audit.get("pool_structure", {}) as Dictionary)
		_accumulate_reliability_by_tab(accepted_reliability_totals_by_tab, ((audit.get("reliability_structure", {}) as Dictionary).get("by_tab", {}) as Dictionary))
		var anchor_coverage: Dictionary = audit.get("anchor_coverage", {}) as Dictionary
		if not bool(anchor_coverage.get("has_strong_timeline_anchor", false)):
			missing_strong_timeline_anchor_count += 1
		if not bool(anchor_coverage.get("has_strong_alibi_or_capability_anchor", false)):
			missing_strong_alibi_or_capability_anchor_count += 1
		if not bool(anchor_coverage.get("has_strong_motive_or_relationship_anchor", false)):
			missing_strong_motive_or_relationship_anchor_count += 1
		var skeleton_coverage: Dictionary = audit.get("skeleton_coverage", {}) as Dictionary
		if not (skeleton_coverage.get("missing_required_fact_types", []) as Array).is_empty():
			missing_required_fact_type_count += 1
		if not (skeleton_coverage.get("missing_required_anchors", []) as Array).is_empty():
			missing_required_anchor_count += 1
		unresolved_conflict_group_count += ((audit.get("conflict_audit", {}) as Dictionary).get("failed_group_ids", []) as Array).size()
		var profile_checks: Dictionary = audit.get("profile_surface_checks", {}) as Dictionary
		if bool(profile_checks.get("fixed_profile_card_leaked_reliability_badges", false)):
			profile_card_leak_hit_count += 1
		var fairness_checks: Dictionary = audit.get("player_surface_fairness_checks", {}) as Dictionary
		if not bool(fairness_checks.get("guilt_tell_check_passed", false)):
			guilt_tell_hit_count += 1

	_last_csv = "\n".join(rows)
	var avg_ms: float = total_ms / maxf(float(n), 1.0)
	var avg_rerolls: float = float(total_rerolls_used) / maxf(float(n), 1.0)
	var avg_pool_counts: Dictionary = _average_pool_totals(accepted_pool_totals, accepted_count)
	_last_batch_report = {
		"seed_text": run_seed_text,
		"seed_hex": SeedUtil.hex16(run_seed_u64),
		"start_index": start_idx,
		"count": n,
		"reroll_start": rr_start,
		"reroll_budget": REROLL_BUDGET,
		"pass_count": pass_ct,
		"warn_count": warn_ct,
		"reject_count": reject_ct,
		"duplicate_prevented_count": dup_prevented,
		"exhausted_count": exhausted_ct,
		"average_gate_ms": avg_ms,
		"max_gate_ms": max_gate_ms,
		"average_rerolls_used": avg_rerolls,
		"max_rerolls_used": max_rerolls_used,
		"reject_histogram": _sorted_histogram(final_reject_code_counts),
		"final_reject_histogram": _sorted_histogram(final_reject_code_counts),
		"attempt_reject_histogram": _sorted_histogram(attempt_reject_code_counts),
		"accepted_case_aggregate_metrics": {
			"accepted_case_count": accepted_count,
			"missing_strong_timeline_anchor_count": missing_strong_timeline_anchor_count,
			"missing_strong_alibi_or_capability_anchor_count": missing_strong_alibi_or_capability_anchor_count,
			"missing_strong_motive_or_relationship_anchor_count": missing_strong_motive_or_relationship_anchor_count,
			"missing_required_fact_type_count": missing_required_fact_type_count,
			"missing_required_anchor_count": missing_required_anchor_count,
			"unresolved_conflict_group_count": unresolved_conflict_group_count,
			"profile_card_leak_hit_count": profile_card_leak_hit_count,
			"guilt_tell_hit_count": guilt_tell_hit_count,
			"salvaged_anchor_only_corrupted_count": salvaged_anchor_only_corrupted_count,
			"salvaged_missing_conflict_group_count": salvaged_missing_conflict_group_count,
			"salvaged_unresolvable_conflict_group_count": salvaged_unresolvable_conflict_group_count,
			"average_pool_counts_by_tab": avg_pool_counts,
			"aggregate_reliability_totals_by_tab": accepted_reliability_totals_by_tab,
		},
		"first_accepted_cases": first_accepted_cases,
		"first_rejected_cases": first_rejected_cases,
	}
	_write_batch_report(run_seed_text, _last_batch_report)

	Summary.clear()
	Summary.append_text("[b]Batch Result[/b]\n")
	Summary.append_text("seed: %s (%s)\n" % [run_seed_text, SeedUtil.hex16(run_seed_u64)])
	Summary.append_text("start_idx: %d  count: %d  reroll_start: %d  budget: %d\n" % [start_idx, n, rr_start, REROLL_BUDGET])
	Summary.append_text("PASS %d  WARN %d  REJECT %d\n" % [pass_ct, warn_ct, reject_ct])
	Summary.append_text("avg_gate_ms: %.3f  max_gate_ms: %.3f\n" % [avg_ms, max_gate_ms])
	Summary.append_text("avg_rerolls_used: %.3f  max_rerolls_used: %d\n" % [avg_rerolls, max_rerolls_used])
	Summary.append_text("dup_prevented: %d  exhausted: %d\n" % [dup_prevented, exhausted_ct])
	Summary.append_text("accepted audit: missing_timeline=%d missing_alibi_or_capability=%d missing_motive_or_relationship=%d\n" % [
		missing_strong_timeline_anchor_count,
		missing_strong_alibi_or_capability_anchor_count,
		missing_strong_motive_or_relationship_anchor_count,
	])
	Summary.append_text("coverage gaps: fact_types=%d anchors=%d unresolved_groups=%d\n" % [
		missing_required_fact_type_count,
		missing_required_anchor_count,
		unresolved_conflict_group_count,
	])
	Summary.append_text("surface hits: profile_leak=%d guilt_tell=%d\n" % [
		profile_card_leak_hit_count,
		guilt_tell_hit_count,
	])
	Summary.append_text("salvage used: anchor=%d missing_conflict=%d unresolvable=%d\n" % [
		salvaged_anchor_only_corrupted_count,
		salvaged_missing_conflict_group_count,
		salvaged_unresolvable_conflict_group_count,
	])

	ValidatorList.clear()
	if final_reject_code_counts.size() > 0:
		ValidatorList.add_item("-- final reject histogram --")
		for k in final_reject_code_counts.keys():
			ValidatorList.add_item("%s: %d" % [str(k), int(final_reject_code_counts[k])])
	if attempt_reject_code_counts.size() > 0:
		ValidatorList.add_item("-- attempt reject histogram --")
		for k in attempt_reject_code_counts.keys():
			ValidatorList.add_item("%s: %d" % [str(k), int(attempt_reject_code_counts[k])])

	JsonText.text = JSON.stringify(_last_batch_report, "\t", true)
	_update_preview()

func _run_gate(run_seed_u64: int, run_seed_text: String, suspect_index: int, rr_start: int, seen_fp: Variant) -> Dictionary:
	var trace: Array[Dictionary] = []
	var attempt_reject_codes: PackedStringArray = []
	var dup_rejects: int = 0
	var attempt_history: Array[Dictionary] = []
	var seen_map: Dictionary = {}
	var has_seen_map: bool = seen_fp is Dictionary
	if has_seen_map:
		seen_map = seen_fp as Dictionary

	var rr: int = rr_start
	var attempts: int = 0
	var gate_ms: float = 0.0

	var last_payload: Dictionary = {}
	var last_report: Dictionary = {"level":"REJECT","items":[]}
	var exhausted: bool = false

	for step in range(REROLL_BUDGET + 1):
		attempts = step + 1
		var t0: int = Time.get_ticks_usec()
		var payload: Dictionary = CaseEngineFacadeScript.generate_case(run_seed_u64, run_seed_text, suspect_index, rr)
		var gen_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		gate_ms += gen_ms

		last_payload = payload
		if not bool(payload.get("ok", false)):
			var gen_code: String = "GEN_ERROR"
			attempt_reject_codes.append(gen_code)
			trace.append({"rr": rr, "level": "REJECT", "code": gen_code, "ms": gen_ms, "faults": ""})
			attempt_history.append({"rr": rr, "level": "REJECT", "reject_codes": [gen_code], "ms": gen_ms, "faults": ""})
			rr += 1
			continue

		var fp: String = str(payload.get("fingerprint", ""))
		if has_seen_map and fp != "" and seen_map.has(fp):
			var dup_code: String = "DUP_FINGERPRINT"
			dup_rejects += 1
			attempt_reject_codes.append(dup_code)
			trace.append({"rr": rr, "level": "REJECT", "code": dup_code, "ms": gen_ms, "faults": ""})
			attempt_history.append({"rr": rr, "level": "REJECT", "reject_codes": [dup_code], "ms": gen_ms, "faults": ""})
			rr += 1
			continue

		var view_payload: Dictionary = payload
		var applied_faults: PackedStringArray = []
		if _faults_enabled() and _faults_apply_this_attempt(step):
			view_payload = _inject_faults(payload)
			applied_faults = view_payload.get("_faults_applied", PackedStringArray()) as PackedStringArray

		var report: Dictionary = ValidatorSuite.validate_case(view_payload)
		last_report = report
		var level: String = str(report.get("level", "PASS"))
		var faults_text: String = ";".join(applied_faults)

		if level == "REJECT":
			var final_attempt_codes: Array[String] = _report_reject_codes(report)
			var rej_code: String = final_attempt_codes[0] if not final_attempt_codes.is_empty() else _first_reject_code(report)
			for code in final_attempt_codes:
				attempt_reject_codes.append(code)
			trace.append({"rr": rr, "level": "REJECT", "code": rej_code, "ms": gen_ms, "faults": faults_text})
			attempt_history.append({"rr": rr, "level": "REJECT", "reject_codes": final_attempt_codes, "ms": gen_ms, "faults": faults_text})
			rr += 1
			continue

		trace.append({"rr": rr, "level": level, "code": "", "ms": gen_ms, "faults": faults_text})
		attempt_history.append({"rr": rr, "level": level, "reject_codes": [], "ms": gen_ms, "faults": faults_text})
		if has_seen_map and fp != "":
			seen_map[fp] = true

		return {
			"payload": payload,
			"report": report,
			"trace": trace,
			"attempts": attempts,
			"final_rr": rr,
			"gate_ms": gate_ms,
			"reject_codes": PackedStringArray(),
			"final_reject_codes": PackedStringArray(),
			"attempt_reject_codes": attempt_reject_codes,
			"attempt_history": attempt_history,
			"dup_rejects": dup_rejects,
			"exhausted": false,
		}

	exhausted = true
	var exhausted_final_reject_codes: PackedStringArray = PackedStringArray(_report_reject_codes(last_report))
	if exhausted_final_reject_codes.is_empty() and not bool(last_payload.get("ok", false)):
		exhausted_final_reject_codes = PackedStringArray(["GEN_ERROR"])
	return {
		"payload": last_payload,
		"report": last_report,
		"trace": trace,
		"attempts": attempts,
		"final_rr": rr,
		"gate_ms": gate_ms,
		"reject_codes": exhausted_final_reject_codes,
		"final_reject_codes": exhausted_final_reject_codes,
		"attempt_reject_codes": attempt_reject_codes,
		"attempt_history": attempt_history,
		"dup_rejects": dup_rejects,
		"exhausted": exhausted,
	}

func _first_reject_code(report: Dictionary) -> String:
	var items: Array = report.get("items", []) as Array
	for it in items:
		if it is Dictionary:
			var d: Dictionary = it as Dictionary
			var lvl: String = str(d.get("level", ""))
			if lvl == "REJECT":
				var c: String = str(d.get("code", ""))
				return c if c != "" else "REJECT"
	return "REJECT"

func _to_dict_array(v: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if v is Array:
		for it in v:
			if it is Dictionary:
				out.append(it as Dictionary)
	return out

func _faults_enabled() -> bool:
	return FaultMode.selected != 0 and (FaultNoTimeline.button_pressed or FaultGuiltTell.button_pressed or FaultUnresolvable.button_pressed or FaultCorruptAnchors.button_pressed)

func _faults_apply_this_attempt(attempt_index: int) -> bool:
	if FaultMode.selected == 0:
		return false
	if FaultMode.selected == 2:
		return true
	return attempt_index == 0

func _inject_faults(payload_in: Dictionary) -> Dictionary:
	var payload: Dictionary = payload_in.duplicate(true)
	var applied: PackedStringArray = []

	var suspect: Dictionary = payload.get("suspect", {}) as Dictionary
	var tabs: Dictionary = suspect.get("tabs", {}) as Dictionary
	var conflict_groups: Dictionary = payload.get("conflict_groups", {}) as Dictionary

	if FaultGuiltTell.button_pressed:
		var cs: Dictionary = suspect.get("charge_sheet", {}) as Dictionary
		cs["brief"] = str(cs.get("brief", "")) + " guilty."
		suspect["charge_sheet"] = cs
		applied.append("GUILT_TELL")

	if FaultNoTimeline.button_pressed:
		var ttab: Dictionary = tabs.get("TIMELINE", {}) as Dictionary
		var facts: Array = ttab.get("facts", []) as Array
		for i in range(facts.size()):
			if facts[i] is Dictionary:
				var f: Dictionary = facts[i] as Dictionary
				if str(f.get("anchor", "")) == "timeline" and str(f.get("reliability", "")) == "SOLID":
					f["reliability"] = "SHAKY"
					f["anchor"] = ""
					facts[i] = f
		ttab["facts"] = facts
		tabs["TIMELINE"] = ttab
		applied.append("NO_TIMELINE")

	if FaultCorruptAnchors.button_pressed:
		for tab_key in tabs.keys():
			var tabd: Dictionary = tabs[tab_key] as Dictionary
			var facts: Array = tabd.get("facts", []) as Array
			for i in range(facts.size()):
				if facts[i] is Dictionary:
					var f: Dictionary = facts[i] as Dictionary
					var a: String = str(f.get("anchor", ""))
					if a != "" and str(f.get("reliability", "")) == "SOLID":
						f["reliability"] = "SHAKY"
						facts[i] = f
			tabd["facts"] = facts
			tabs[tab_key] = tabd
		applied.append("CORRUPT_ANCHORS")

	if FaultUnresolvable.button_pressed and conflict_groups.size() > 0:
		var first_key: String = ""
		for k in conflict_groups.keys():
			first_key = str(k)
			break
		if first_key != "":
			var ids: Array = conflict_groups[first_key] as Array
			var idset: Dictionary = {}
			for vv in ids:
				idset[str(vv)] = true

			for tab_key in tabs.keys():
				var tabd: Dictionary = tabs[tab_key] as Dictionary
				var facts: Array = tabd.get("facts", []) as Array
				for i in range(facts.size()):
					if facts[i] is Dictionary:
						var f: Dictionary = facts[i] as Dictionary
						var fid: String = str(f.get("fact_id", ""))
						if idset.has(fid) and str(f.get("reliability", "")) == "SOLID":
							f["reliability"] = "SHAKY"
							facts[i] = f
				tabd["facts"] = facts
				tabs[tab_key] = tabd
			applied.append("UNRESOLVABLE")

	suspect["tabs"] = tabs
	payload["suspect"] = suspect
	payload["conflict_groups"] = conflict_groups
	payload["_faults_applied"] = applied
	return payload

func _refresh_ui(report: Dictionary, json: String, gen_ms: float = 0.0) -> void:
	var lvl: String = str(report.get("level", "PASS"))
	var fp: String = str(_last_payload.get("fingerprint", ""))
	var seed_txt: String = str(_last_payload.get("run_seed_text", SeedEdit.text))
	var seed_hex: String = str(_last_payload.get("run_seed_u64_hex", "")) if _last_payload.has("run_seed_u64_hex") else ""
	var sidx: String = str(_last_payload.get("suspect_index", int(IndexSpin.value)))
	var rr: String = str(_last_payload.get("reroll_index", int(RerollSpin.value)))

	var truth_bundle: Dictionary = _last_payload.get("truth_bundle", {}) as Dictionary
	var suspect: Dictionary = _last_payload.get("suspect", {}) as Dictionary
	var anchor_counts: Dictionary = _anchor_counts_from_suspect(suspect)
	var conflict_groups: Dictionary = _last_payload.get("conflict_groups", {}) as Dictionary

	Summary.clear()
	Summary.append_text("[b]Case Engine Lab (Editor)[/b]\n")
	if _last_payload.is_empty():
		Summary.append_text("Ready\n")
		ValidatorList.clear()
		PreviewText.text = ""
		JsonText.text = json
		return
	Summary.append_text("Status: %s\n" % lvl)
	if seed_hex == "":
		var parsed := _parse_seed_u63(seed_txt)
		seed_hex = SeedUtil.hex16(parsed) if parsed >= 0 else ""
	Summary.append_text("seed: %s (%s)\n" % [seed_txt, seed_hex])
	Summary.append_text("suspect_index: %s  reroll_index: %s\n" % [sidx, rr])
	Summary.append_text("fingerprint: %s\n" % fp)
	Summary.append_text("generate_ms: %.3f\n" % gen_ms)
	Summary.append_text("gate_attempts: %d\n" % _last_gate_attempts)

	if not truth_bundle.is_empty():
		Summary.append_text("truth: family=%s type=%s guilt=%s opp=%s alibi=%s\n" % [
			str(truth_bundle.get("crime_family", "")),
			str(truth_bundle.get("crime_type", "")),
			str(truth_bundle.get("guilt_state", "")),
			str(truth_bundle.get("opportunity", "")),
			str(truth_bundle.get("alibi_truth", "")),
		])
		if not _last_audit.is_empty():
			var digest: Dictionary = CaseEngineLabAudit.compact_digest(_last_audit)
			var pool_counts: Dictionary = digest.get("pool_counts", {}) as Dictionary
			var reliability_totals: Dictionary = digest.get("reliability_totals", {}) as Dictionary
			Summary.append_text("pool counts: ALIBI=%d TIMELINE=%d CAPABILITY=%d MOTIVE=%d PROFILE=%d\n" % [
				int(pool_counts.get("ALIBI", 0)),
				int(pool_counts.get("TIMELINE", 0)),
				int(pool_counts.get("CAPABILITY", 0)),
				int(pool_counts.get("MOTIVE", 0)),
				int(pool_counts.get("PROFILE", 0)),
			])
			Summary.append_text("reliability totals: SOLID=%d SHAKY=%d CORRUPTED=%d\n" % [
				int(reliability_totals.get("SOLID", 0)),
				int(reliability_totals.get("SHAKY", 0)),
				int(reliability_totals.get("CORRUPTED", 0)),
			])
			Summary.append_text("required coverage: facts=%s anchors=%s\n" % [
				"OK" if bool(digest.get("required_fact_coverage_ok", false)) else "MISSING",
				"OK" if bool(digest.get("required_anchor_coverage_ok", false)) else "MISSING",
			])
			Summary.append_text("conflicts/profile/guilt: failed_groups=%d profile_leak=%s guilt_tell=%s\n" % [
				int(digest.get("failed_conflict_groups", 0)),
				"HIT" if bool(digest.get("profile_card_leak_hit", false)) else "OK",
				"OK" if bool(digest.get("guilt_tell_check_passed", false)) else "HIT",
			])
			Summary.append_text("anchor gate: timeline=%s alibi_or_capability=%s motive_or_relationship=%s\n" % [
				"OK" if bool(digest.get("strong_timeline_anchor_ok", false)) else "MISS",
				"OK" if bool(digest.get("strong_alibi_or_capability_anchor_ok", false)) else "MISS",
				"OK" if bool(digest.get("strong_motive_or_relationship_anchor_ok", false)) else "MISS",
			])

		Summary.append_text("anchors SOLID: timeline=%d alibi=%d capability=%d motive=%d relationship=%d\n" % [
			int(anchor_counts.get("timeline", 0)),
			int(anchor_counts.get("alibi", 0)),
			int(anchor_counts.get("capability", 0)),
			int(anchor_counts.get("motive", 0)),
			int(anchor_counts.get("relationship", 0)),
		])
	Summary.append_text("conflict_groups: %d\n" % conflict_groups.size())

	ValidatorList.clear()
	var items: Array = report.get("items", []) as Array
	for it in items:
		if it is Dictionary:
			var d := it as Dictionary
			ValidatorList.add_item("%s %s: %s" % [d.get("level",""), d.get("code",""), d.get("msg","")])

	if _last_gate_trace.size() > 0:
		ValidatorList.add_item("-- gate --")
		for tv in _last_gate_trace:
			var rr_line: String = str(tv.get("rr", ""))
			var lvl_line: String = str(tv.get("level", ""))
			var code_line: String = str(tv.get("code", ""))
			var ms_line: float = float(tv.get("ms", 0.0))
			var faults_line: String = str(tv.get("faults", ""))
			if code_line != "":
				if faults_line != "":
					ValidatorList.add_item("rr=%s %s %s (%.3fms) faults=%s" % [rr_line, lvl_line, code_line, ms_line, faults_line])
				else:
					ValidatorList.add_item("rr=%s %s %s (%.3fms)" % [rr_line, lvl_line, code_line, ms_line])
			else:
				if faults_line != "":
					ValidatorList.add_item("rr=%s %s (%.3fms) faults=%s" % [rr_line, lvl_line, ms_line, faults_line])
				else:
					ValidatorList.add_item("rr=%s %s (%.3fms)" % [rr_line, lvl_line, ms_line])

	if not conflict_groups.is_empty():
		ValidatorList.add_item("-- conflicts --")
		for gid in conflict_groups.keys():
			var ids: Array = conflict_groups[gid] as Array
			ValidatorList.add_item("group %s facts=%d" % [str(gid), ids.size()])

	JsonText.text = json
	_update_preview()

func _on_truth_toggled(_pressed: bool) -> void:
	_update_preview()
	if FolioWindow != null and FolioWindow.visible:
		_build_folio_spreads()
		_refresh_folio()

func _on_fault_mode_selected(_idx: int) -> void:
	_sync_fault_ui()

func _sync_fault_ui() -> void:
	var show := FaultMode.selected != 0
	FaultNoTimeline.visible = show
	FaultGuiltTell.visible = show
	FaultUnresolvable.visible = show
	FaultCorruptAnchors.visible = show

func _on_preview_tab_changed(_tab: int) -> void:
	_sync_preview_ui()
	_update_preview()

func _on_evidence_tab_changed(_tab: int) -> void:
	_update_preview()

func _sync_preview_ui() -> void:
	if EvidenceTabs != null and PreviewTabs != null:
		EvidenceTabs.visible = (PreviewTabs.current_tab == 3)

func _update_preview() -> void:
	if PreviewText == null:
		return
	if _last_payload.is_empty():
		PreviewText.text = ""
		return
	var page := _preview_page_id()
	var ev_tab := _evidence_tab_id()
	PreviewText.text = LabPreview.render_page(
		_last_payload,
		page,
		ev_tab,
		TruthToggle != null and TruthToggle.button_pressed
	)

func _build_folio_spreads() -> void:
	if _last_payload.is_empty():
		_folio_spreads = []
		return
	_folio_spreads = CaseFolderRender.build_spreads(_last_payload, TruthToggle != null and TruthToggle.button_pressed)

func _refresh_folio() -> void:
	if SpreadTitle == null:
		return
	if _folio_spreads.is_empty():
		SpreadTitle.text = "No folio available"
		LeftPageTitle.text = ""
		LeftPageBody.text = ""
		RightPageTitle.text = ""
		RightPageBody.text = ""
		return
	_folio_spread_index = clampi(_folio_spread_index, 0, _folio_spreads.size() - 1)
	var spread: Dictionary = _folio_spreads[_folio_spread_index] as Dictionary
	SpreadTitle.text = "%s (%d/%d)" % [
		str(spread.get("title", "Spread")),
		_folio_spread_index + 1,
		_folio_spreads.size(),
	]
	var left_page: Dictionary = spread.get("left_page", {}) as Dictionary
	var right_page: Dictionary = spread.get("right_page", {}) as Dictionary
	LeftPageTitle.text = str(left_page.get("title", ""))
	LeftPageBody.text = str(left_page.get("body", ""))
	RightPageTitle.text = str(right_page.get("title", ""))
	RightPageBody.text = str(right_page.get("body", ""))
	PrevSpreadBtn.disabled = _folio_spread_index <= 0
	NextSpreadBtn.disabled = _folio_spread_index >= _folio_spreads.size() - 1

func _on_PrevSpreadBtn_pressed() -> void:
	if _folio_spread_index > 0:
		_folio_spread_index -= 1
		_refresh_folio()

func _on_NextSpreadBtn_pressed() -> void:
	if _folio_spread_index < _folio_spreads.size() - 1:
		_folio_spread_index += 1
		_refresh_folio()

func _on_CloseFolioBtn_pressed() -> void:
	if FolioWindow != null:
		FolioWindow.hide()

func _preview_page_id() -> String:
	if PreviewTabs == null:
		return "DOSSIER"
	match PreviewTabs.current_tab:
		0:
			return "CHARGE_SHEET"
		1:
			return "DOSSIER"
		2:
			return "PROFILE"
		3:
			return "EVIDENCE"
	return "DOSSIER"

func _evidence_tab_id() -> String:
	if EvidenceTabs == null:
		return "ALIBI"
	match EvidenceTabs.current_tab:
		0:
			return "ALIBI"
		1:
			return "TIMELINE"
		2:
			return "CAPABILITY"
		3:
			return "MOTIVE"
		4:
			return "PROFILE_NOTES"
	return "ALIBI"

func _anchor_counts_from_suspect(suspect: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"timeline": 0,
		"alibi": 0,
		"capability": 0,
		"motive": 0,
		"relationship": 0,
	}
	if suspect.is_empty():
		return out
	var tabs: Dictionary = suspect.get("tabs", {}) as Dictionary
	for tab_key in tabs.keys():
		var tabd: Dictionary = tabs[tab_key] as Dictionary
		var facts: Array = tabd.get("facts", []) as Array
		for fv in facts:
			if not (fv is Dictionary):
				continue
			var f: Dictionary = fv as Dictionary
			if str(f.get("reliability", "")) != CaseEngineTypes.RELIABILITY_SOLID:
				continue
			var anchor: String = str(f.get("anchor", ""))
			if out.has(anchor):
				out[anchor] = int(out.get(anchor, 0)) + 1
	return out

func _parse_seed_u63(seed_text: String) -> int:
	var text := seed_text.strip_edges()
	if text == "":
		return -1

	var upper := text.to_upper()

	# K11-<base36> (matches your run-seed style)
	if upper.begins_with("K11-"):
		var suffix := upper.substr(4).strip_edges()
		var v36 := _from_base36(suffix)
		return SeedUtil.normalize_seed(v36) if v36 >= 0 else -1

	# Hex (0x... or 16-hex)
	var hx := SeedUtil.hex_to_seed_u63(text)
	if hx >= 0:
		return SeedUtil.normalize_seed(hx)

	# Digits-only integer
	var digits_only := true
	for i in range(text.length()):
		var ch: String = text[i]
		if ch < "0" or ch > "9":
			digits_only = false
			break
	if digits_only:
		return SeedUtil.normalize_seed(int(text.to_int()))

	# Convenience: raw base36 without prefix
	if _is_base36(text):
		var v := _from_base36(text)
		return SeedUtil.normalize_seed(v) if v >= 0 else -1

	return -1

func _is_base36(s: String) -> bool:
	var t := s.strip_edges().to_upper()
	if t == "":
		return false
	for i in range(t.length()):
		var ch: String = t[i]
		var ok := (ch >= "0" and ch <= "9") or (ch >= "A" and ch <= "Z")
		if not ok:
			return false
	return true

func _from_base36(s: String) -> int:
	var t := s.strip_edges().to_upper()
	if t == "":
		return -1
	var chars := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var v: int = 0
	for i in range(t.length()):
		var ch: String = t[i]
		var idx: int = chars.find(ch)
		if idx < 0:
			return -1
		v = (v * 36) + idx
	return v

func _safe_filename(s: String) -> String:
	var t := s.strip_edges()
	var out := ""
	for i in range(t.length()):
		var ch := t[i]
		var ok := (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "-" or ch == "_"
		out += ch if ok else "_"
	return out

func _csv(s: String) -> String:
	var t := s.replace("\"","\"\"")
	if t.find(",") >= 0 or t.find("\n") >= 0:
		return "\"%s\"" % t
	return t

func _write_json_file(path: String, data: Variant) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t", true))
	f.close()
	return true

func _write_batch_report(seed_text: String, batch_report: Dictionary) -> void:
	var dir := "user://case_engine_lab/"
	var abs_dir := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var report_path := "%s%s_batch_report.json" % [dir, _safe_filename(seed_text)]
	_write_json_file(report_path, batch_report)

func _zero_pool_counts() -> Dictionary:
	return {
		"ALIBI": 0,
		"TIMELINE": 0,
		"CAPABILITY": 0,
		"MOTIVE": 0,
		"PROFILE": 0,
	}

func _zero_reliability_by_tab() -> Dictionary:
	var out: Dictionary = {}
	for tab_id in ["ALIBI", "TIMELINE", "CAPABILITY", "MOTIVE", "PROFILE"]:
		out[tab_id] = {
			"SOLID": 0,
			"SHAKY": 0,
			"CORRUPTED": 0,
		}
	return out

func _accumulate_pool_totals(target: Dictionary, source: Dictionary) -> void:
	for tab_id in target.keys():
		target[tab_id] = int(target.get(tab_id, 0)) + int(source.get(tab_id, 0))

func _accumulate_reliability_by_tab(target: Dictionary, source: Dictionary) -> void:
	for tab_id in target.keys():
		var target_row: Dictionary = target.get(tab_id, {}) as Dictionary
		var source_row: Dictionary = source.get(tab_id, {}) as Dictionary
		for reliability in ["SOLID", "SHAKY", "CORRUPTED"]:
			target_row[reliability] = int(target_row.get(reliability, 0)) + int(source_row.get(reliability, 0))
		target[tab_id] = target_row

func _average_pool_totals(pool_totals: Dictionary, accepted_count: int) -> Dictionary:
	var out: Dictionary = {}
	var denom: float = maxf(float(accepted_count), 1.0)
	for tab_id in pool_totals.keys():
		out[tab_id] = float(pool_totals.get(tab_id, 0)) / denom
	return out

func _sorted_histogram(counts: Dictionary) -> Dictionary:
	var keys: Array[String] = []
	for key in counts.keys():
		keys.append(str(key))
	keys.sort()
	var out: Dictionary = {}
	for key in keys:
		out[key] = int(counts.get(key, 0))
	return out

func _string_array_from_packed(values: PackedStringArray) -> Array[String]:
	var out: Array[String] = []
	for value in values:
		out.append(str(value))
	return out

func _batch_case_sample(idx: int, final_rr: int, fingerprint: String, level: String, final_reject_codes: Array[String], attempt_reject_codes: Array[String], attempt_count: int, audit: Dictionary) -> Dictionary:
	return {
		"suspect_index": idx,
		"final_rr": final_rr,
		"fingerprint": fingerprint,
		"level": level,
		"final_outcome": level,
		"final_reject_codes": final_reject_codes,
		"attempt_reject_codes": attempt_reject_codes,
		"attempt_count": attempt_count,
		"final_audit_digest": CaseEngineLabAudit.compact_digest(audit),
	}

func _report_reject_codes(report: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var items: Array = report.get("items", []) as Array
	for item_v in items:
		if item_v is Dictionary:
			var item: Dictionary = item_v as Dictionary
			if str(item.get("level", "")) != "REJECT":
				continue
			var code: String = str(item.get("code", ""))
			if code != "" and not out.has(code):
				out.append(code)
	return out
