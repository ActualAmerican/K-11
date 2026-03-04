extends RefCounted
class_name RunLedger

const SCHEMA_VERSION := 1
const DEFAULT_PATH := "user://run_ledger_v0.json"
const MAX_RUNS := 50

var runs: Array[Dictionary] = []
var active_run_index: int = -1

func load(path: String = DEFAULT_PATH) -> void:
	if not FileAccess.file_exists(path):
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_from_dict(parsed as Dictionary)

func save(path: String = DEFAULT_PATH) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var text: String = JSON.stringify(to_dict(), "\t", true)
	f.store_string(text)
	return true

static func wipe(path: String = DEFAULT_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return true
	var abs_path: String = ProjectSettings.globalize_path(path)
	var err: int = DirAccess.remove_absolute(abs_path)
	return err == OK

func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"runs": runs,
		"active_run_index": active_run_index,
	}

func start_run(seed_text: String, seed_u64: int, meta: Dictionary = {}) -> Dictionary:
	var now_ms: int = Time.get_ticks_msec()
	var run_id: String = "%s-%s" % [seed_text, str(now_ms)]
	var run: Dictionary = {
		"run_id": run_id,
		"seed_text": seed_text,
		"seed_u64_hex": SeedUtil.hex16(int(seed_u64)),
		"started_ms": now_ms,
		"ended_ms": 0,
		"outcome": "IN_PROGRESS",
		"meta": meta,
		"cases": [],
		"summary": {
			"suspects_completed": 0,
			"noise_peak_max": 0,
			"danger_tier_end": 0,
			"revolver_pulls_used": 0,
		}
	}
	runs.append(run)
	if runs.size() > MAX_RUNS:
		var trimmed: Array[Dictionary] = []
		var start_idx: int = runs.size() - MAX_RUNS
		for i in range(start_idx, runs.size()):
			trimmed.append(runs[i])
		runs = trimmed
	active_run_index = runs.size() - 1
	return run

func finish_run(outcome: String, meta: Dictionary = {}) -> void:
	var run: Dictionary = _active_run()
	if run.is_empty():
		return
	run["ended_ms"] = Time.get_ticks_msec()
	run["outcome"] = outcome
	for k in meta.keys():
		run["meta"][k] = meta[k]

func start_case(suspect: SuspectData, suspect_seed_text: String, suspect_index: int, meta: Dictionary = {}) -> void:
	var run: Dictionary = _active_run()
	if run.is_empty():
		return
	var now_ms: int = Time.get_ticks_msec()
	var case_id: String = "%s#%d" % [suspect.id if suspect != null else "S-UNKNOWN", now_ms]
	var c: Dictionary = {
		"case_id": case_id,
		"suspect_index": suspect_index,
		"suspect_seed_text": suspect_seed_text,
		"started_ms": now_ms,
		"ended_ms": 0,
		"outcome": "IN_PROGRESS",
		"verdict": "",
		"verdict_correct": null,
		"carry_noise_next": 0,
		"metrics": {
			"noise_start": 0,
			"noise_end": 0,
			"noise_peak": 0,
			"danger_tier_start": 0,
			"danger_tier_end": 0,
			"danger_fill_start": 0,
			"danger_fill_end": 0,
			"revolver_pulls_used_start": 0,
			"revolver_pulls_used_end": 0,
			"phone_rings": 0,
			"deadline_s": 0,
			"clock_hhmm": "",
		},
		"suspect": _suspect_player_snapshot(suspect),
		"events": [],
		"meta": meta,
	}
	run["cases"].append(c)

func finish_case(outcome: String, verdict: String, verdict_correct: Variant, carry_noise_next: int, metrics_patch: Dictionary = {}, events: Array[Dictionary] = []) -> void:
	var run: Dictionary = _active_run()
	if run.is_empty():
		return
	if run["cases"].is_empty():
		return
	var c: Dictionary = run["cases"][run["cases"].size() - 1]
	c["ended_ms"] = Time.get_ticks_msec()
	c["outcome"] = outcome
	c["verdict"] = verdict
	c["verdict_correct"] = verdict_correct
	c["carry_noise_next"] = carry_noise_next
	for k in metrics_patch.keys():
		c["metrics"][k] = metrics_patch[k]
	for e in events:
		c["events"].append(e)

	var summary: Dictionary = run.get("summary", {}) as Dictionary
	summary["suspects_completed"] = int(summary.get("suspects_completed", 0)) + 1
	summary["noise_peak_max"] = maxi(int(summary.get("noise_peak_max", 0)), int(c["metrics"].get("noise_peak", 0)))
	summary["danger_tier_end"] = int(c["metrics"].get("danger_tier_end", 0))
	summary["revolver_pulls_used"] = int(c["metrics"].get("revolver_pulls_used_end", 0))
	run["summary"] = summary

func _active_run() -> Dictionary:
	if active_run_index < 0 or active_run_index >= runs.size():
		return {}
	return runs[active_run_index]

func _suspect_player_snapshot(s: SuspectData) -> Dictionary:
	if s == null:
		return {}
	var d: Dictionary = SuspectIO.to_dict(s)
	d.erase("truth_guilty")
	d.erase("debug")
	return d

func _from_dict(d: Dictionary) -> void:
	if int(d.get("schema_version", 0)) != SCHEMA_VERSION:
		return
	var r: Variant = d.get("runs", [])
	if r is Array:
		var parsed_runs: Array[Dictionary] = []
		for item in r:
			if item is Dictionary:
				parsed_runs.append(item)
		runs = parsed_runs
	active_run_index = int(d.get("active_run_index", -1))
