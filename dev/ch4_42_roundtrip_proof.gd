extends SceneTree

const OUT_DIR := "res://dev/ch4_42_roundtrip_proof"
const JSON_A_PATH := OUT_DIR + "/JSON_A.json"
const JSON_B_PATH := OUT_DIR + "/JSON_B.json"
const REPORT_PATH := OUT_DIR + "/report.json"

func _init() -> void:
	var run_seed_text: String = "K11-1LU"
	var suspect_index: int = 0
	var reroll_index: int = 0
	var run_seed_u64: int = SeedUtil.parse_run_seed_to_u63(run_seed_text)
	if run_seed_u64 < 0:
		_write_report({
			"ok": false,
			"error": "BAD_SEED",
			"run_seed_text": run_seed_text,
		})
		quit(1)
		return
	run_seed_text = SeedUtil.format_run_seed_u63(run_seed_u64)

	var payload: Dictionary = CaseEngineFacade.generate_case(run_seed_u64, run_seed_text, suspect_index, reroll_index)
	if not bool(payload.get("ok", false)):
		_write_report({
			"ok": false,
			"error": str(payload.get("error", "GEN_ERROR")),
			"payload": payload,
		})
		quit(2)
		return

	var json_a: String = JSON.stringify(payload, "\t", true)
	var payload_a: Dictionary = SuspectIO.payload_from_json(json_a)
	var suspect_b: SuspectData = SuspectIO.from_json(json_a)
	if payload_a.is_empty() or suspect_b == null:
		_write_report({
			"ok": false,
			"error": "PAYLOAD_IMPORT_FAILED",
		})
		quit(3)
		return

	var json_b: String = SuspectIO.payload_to_json(suspect_b, payload_a, true)
	var dict_a: Dictionary = payload_a
	var dict_b: Dictionary = JSON.parse_string(json_b) as Dictionary
	_ensure_dir()
	SuspectIO.write_text(JSON_A_PATH, json_a)
	SuspectIO.write_text(JSON_B_PATH, json_b)

	var suspect_a_dict: Dictionary = dict_a.get("suspect", {}) as Dictionary
	var suspect_b_dict: Dictionary = dict_b.get("suspect", {}) as Dictionary
	var report: Dictionary = {
		"ok": true,
		"run_seed_text": run_seed_text,
		"run_seed_u64_hex": SeedUtil.hex16(run_seed_u64),
		"suspect_index": suspect_index,
		"reroll_index": reroll_index,
		"load_path": "SuspectIO.payload_from_json -> SuspectIO.payload_to_json",
		"json_a_path": ProjectSettings.globalize_path(JSON_A_PATH),
		"json_b_path": ProjectSettings.globalize_path(JSON_B_PATH),
		"checks": {
			"suspect_truth_bundle_present_a": not (suspect_a_dict.get("truth_bundle", {}) as Dictionary).is_empty(),
			"suspect_truth_bundle_present_b": not (suspect_b_dict.get("truth_bundle", {}) as Dictionary).is_empty(),
			"debug_truth_bundle_present_a": not (((suspect_a_dict.get("debug", {}) as Dictionary).get("case_engine_truth_bundle", {}) as Dictionary).is_empty()),
			"debug_truth_bundle_present_b": not (((suspect_b_dict.get("debug", {}) as Dictionary).get("case_engine_truth_bundle", {}) as Dictionary).is_empty()),
			"id_match": str(suspect_a_dict.get("id", "")) == str(suspect_b_dict.get("id", "")),
			"silhouette_label_match": str(suspect_a_dict.get("silhouette_label", "")) == str(suspect_b_dict.get("silhouette_label", "")),
			"deadline_s_match": int(suspect_a_dict.get("deadline_s", 0)) == int(suspect_b_dict.get("deadline_s", 0)),
			"truth_bundle_match": _canonical_json(suspect_a_dict.get("truth_bundle", {})) == _canonical_json(suspect_b_dict.get("truth_bundle", {})),
			"tab_fact_ids_match": _tab_fact_ids(suspect_a_dict.get("tabs", {}) as Dictionary) == _tab_fact_ids(suspect_b_dict.get("tabs", {}) as Dictionary),
			"tab_pool_seed_metadata_match": _tab_pool_seed_map(suspect_a_dict.get("tabs", {}) as Dictionary) == _tab_pool_seed_map(suspect_b_dict.get("tabs", {}) as Dictionary),
			"top_level_fingerprint_match": str(dict_a.get("fingerprint", "")) == str(dict_b.get("fingerprint", "")),
			"top_level_truth_bundle_match": _canonical_json(dict_a.get("truth_bundle", {})) == _canonical_json(dict_b.get("truth_bundle", {})),
		},
		"field_values": {
			"id_a": str(suspect_a_dict.get("id", "")),
			"id_b": str(suspect_b_dict.get("id", "")),
			"silhouette_label_a": str(suspect_a_dict.get("silhouette_label", "")),
			"silhouette_label_b": str(suspect_b_dict.get("silhouette_label", "")),
			"deadline_s_a": int(suspect_a_dict.get("deadline_s", 0)),
			"deadline_s_b": int(suspect_b_dict.get("deadline_s", 0)),
			"tab_fact_ids_a": _tab_fact_ids(suspect_a_dict.get("tabs", {}) as Dictionary),
			"tab_fact_ids_b": _tab_fact_ids(suspect_b_dict.get("tabs", {}) as Dictionary),
			"tab_pool_seed_metadata_a": _tab_pool_seed_map(suspect_a_dict.get("tabs", {}) as Dictionary),
			"tab_pool_seed_metadata_b": _tab_pool_seed_map(suspect_b_dict.get("tabs", {}) as Dictionary),
		},
	}
	_write_report(report)
	quit(0)

func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

func _write_report(report: Dictionary) -> void:
	_ensure_dir()
	SuspectIO.write_text(REPORT_PATH, JSON.stringify(report, "\t", true))

func _canonical_json(value: Variant) -> String:
	return JSON.stringify(_canonicalize(value))

func _canonicalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var src: Dictionary = value as Dictionary
			var keys: Array = src.keys()
			keys.sort()
			var out: Dictionary = {}
			for key in keys:
				out[key] = _canonicalize(src[key])
			return out
		TYPE_ARRAY:
			var src_array: Array = value as Array
			var out_array: Array = []
			out_array.resize(src_array.size())
			for i in range(src_array.size()):
				out_array[i] = _canonicalize(src_array[i])
			return out_array
		_:
			return value

func _tab_fact_ids(tabs: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var tab_ids: Array = tabs.keys()
	tab_ids.sort()
	for tab_id_v in tab_ids:
		var tab_id: String = str(tab_id_v)
		var fact_ids: Array[String] = []
		var tab_data: Dictionary = tabs.get(tab_id, {}) as Dictionary
		for fact_v in tab_data.get("facts", []) as Array:
			if fact_v is Dictionary:
				fact_ids.append(str((fact_v as Dictionary).get("fact_id", "")))
		out[tab_id] = fact_ids
	return out

func _tab_pool_seed_map(tabs: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var tab_ids: Array = tabs.keys()
	tab_ids.sort()
	for tab_id_v in tab_ids:
		var tab_id: String = str(tab_id_v)
		var tab_data: Dictionary = tabs.get(tab_id, {}) as Dictionary
		out[tab_id] = {
			"fact_pool_seed_u64_hex": str(tab_data.get("fact_pool_seed_u64_hex", "")),
			"fact_pool_seed_u64": int(tab_data.get("fact_pool_seed_u64", 0)),
		}
	return out
