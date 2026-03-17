@tool
extends RefCounted
class_name SuspectIO


static func to_dict(s: SuspectData) -> Dictionary:
	var d: Dictionary = {}
	d["schema_version"] = int(s.schema_version)

	d["run_seed_text"] = String(s.run_seed_text)
	d["run_seed_u64_hex"] = SeedUtil.hex16(int(s.run_seed_u64))

	d["suspect_index"] = int(s.suspect_index)
	d["suspect_seed_u64_hex"] = SeedUtil.hex16(int(s.suspect_seed_u64))

	d["id"] = String(s.id)
	d["silhouette_label"] = String(s.silhouette_label)
	d["deadline_s"] = int(s.deadline_s)
	d["truth_guilty"] = bool(s.truth_guilty)
	d["truth_bundle"] = _deep_copy_dict(s.truth_bundle)

	d["charge_sheet"] = _deep_copy_dict(s.charge_sheet)
	d["tabs"] = _deep_copy_dict(s.tabs)
	_tabs_u64_to_hex(d["tabs"])
	d["debug"] = _deep_copy_dict(s.debug)
	return d

static func from_dict(d: Dictionary) -> SuspectData:
	var sv: int = int(d.get("schema_version", 0))
	if sv != int(SuspectData.SCHEMA_VERSION):
		return null

	var s: SuspectData = SuspectData.new()
	s.schema_version = sv

	s.run_seed_text = String(d.get("run_seed_text", ""))
	s.run_seed_u64 = _read_u64(d, "run_seed_u64_hex", "run_seed_u64")

	s.suspect_index = int(d.get("suspect_index", 0))
	s.suspect_seed_u64 = _read_u64(d, "suspect_seed_u64_hex", "suspect_seed_u64")

	s.id = String(d.get("id", ""))
	s.silhouette_label = String(d.get("silhouette_label", ""))
	s.deadline_s = int(d.get("deadline_s", 0))
	s.truth_guilty = bool(d.get("truth_guilty", false))
	s.truth_bundle = _ensure_dict(d.get("truth_bundle", {}))
	if s.truth_bundle.is_empty():
		var debug_dict: Dictionary = _ensure_dict(d.get("debug", {}))
		s.truth_bundle = _ensure_dict(debug_dict.get("case_engine_truth_bundle", {}))

	s.charge_sheet = _ensure_dict(d.get("charge_sheet", {}))
	s.tabs = _ensure_dict(d.get("tabs", {}))
	_tabs_hex_to_u64(s.tabs)
	s.debug = _ensure_dict(d.get("debug", {}))

	return s

static func to_json(s: SuspectData, pretty: bool = true) -> String:
	var d := to_dict(s)
	return _stringify(d, pretty)

static func to_payload_dict(s: SuspectData, existing_payload: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = _deep_copy_dict(existing_payload)
	var suspect_dict: Dictionary = to_dict(s)
	var truth_bundle: Dictionary = _deep_copy_dict(s.truth_bundle)
	payload["ok"] = true
	payload["run_seed_text"] = String(s.run_seed_text)
	payload["run_seed_u64_hex"] = SeedUtil.hex16(int(s.run_seed_u64))
	payload["suspect_index"] = int(s.suspect_index)
	payload["suspect_seed_u64_hex"] = SeedUtil.hex16(int(s.suspect_seed_u64))
	if not payload.has("reroll_index"):
		payload["reroll_index"] = 0
	payload["suspect"] = suspect_dict
	payload["truth_bundle"] = truth_bundle

	if str(payload.get("fingerprint", "")) == "":
		payload["fingerprint"] = _case_payload_fingerprint(truth_bundle)
	if not payload.has("seed_trace"):
		var seed_trace: Dictionary = _ensure_dict(truth_bundle.get("seed_trace", {}))
		if seed_trace.is_empty():
			seed_trace = _ensure_dict((s.debug.get("seed_trace", {}) if typeof(s.debug) == TYPE_DICTIONARY else {}))
		if not seed_trace.is_empty():
			payload["seed_trace"] = seed_trace
	var variant_skeleton_id: String = str(truth_bundle.get("variant_skeleton_id", ""))
	if variant_skeleton_id != "":
		payload["variant_skeleton_id"] = variant_skeleton_id
	var conflict_audit: Dictionary = _ensure_dict(truth_bundle.get("conflict_audit", {}))
	if not conflict_audit.is_empty():
		payload["conflict_audit"] = conflict_audit
	var profile_bundle: Dictionary = _ensure_dict(truth_bundle.get("profile_bundle", {}))
	if not profile_bundle.is_empty():
		payload["profile_bundle"] = profile_bundle
	return payload

static func payload_to_json(s: SuspectData, existing_payload: Dictionary = {}, pretty: bool = true) -> String:
	return _stringify(to_payload_dict(s, existing_payload), pretty)

static func from_json(text: String) -> SuspectData:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return from_payload_dict(parsed as Dictionary)

static func payload_from_json(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var s: SuspectData = from_payload_dict(parsed as Dictionary)
	if s == null:
		return {}
	return to_payload_dict(s, parsed as Dictionary)

static func from_payload_dict(d: Dictionary) -> SuspectData:
	if _looks_like_payload_wrapper(d):
		var payload_suspect: Dictionary = _ensure_dict(d.get("suspect", {}))
		if payload_suspect.is_empty():
			return null
		var s: SuspectData = from_dict(payload_suspect)
		if s == null:
			return null
		var wrapper_truth_bundle: Dictionary = _ensure_dict(d.get("truth_bundle", {}))
		if not wrapper_truth_bundle.is_empty():
			s.truth_bundle = wrapper_truth_bundle
		return s
	return from_dict(d)

static func fingerprint_suspect(s: SuspectData) -> String:
	return fingerprint_dict(to_dict(s))

static func fingerprint_json(text: String) -> String:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return ""
	var dict: Dictionary = parsed as Dictionary
	var payload_fp: String = str(dict.get("fingerprint", ""))
	if payload_fp != "":
		return payload_fp
	var s: SuspectData = from_payload_dict(dict)
	if s == null:
		return ""
	return fingerprint_suspect(s)

static func same_fingerprint(a: String, b: String) -> bool:
	return a != "" and a == b

static func fingerprint_dict(d: Dictionary) -> String:
	var canon: Variant = _canonicalize(d)
	var json: String = JSON.stringify(canon)
	return _sha256_hex(json)

static func write_text(path: String, text: String) -> bool:
	_ensure_parent_dir(path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true

static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text

static func _stringify(d: Dictionary, pretty: bool) -> String:
	if pretty:
		return JSON.stringify(d, "\t")
	return JSON.stringify(d)

static func _sha256_hex(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()

static func _case_payload_fingerprint(truth_bundle: Dictionary) -> String:
	var facts: Dictionary = _ensure_dict(truth_bundle.get("facts", {}))
	var fp_basis: Dictionary = {
		"crime_family": str(truth_bundle.get("crime_family", "")),
		"crime_type": str(truth_bundle.get("crime_type", "")),
		"opportunity": str(truth_bundle.get("opportunity", "")),
		"alibi_truth": str(truth_bundle.get("alibi_truth", "")),
		"motive": str(truth_bundle.get("motive", "")),
		"relationship": str(truth_bundle.get("relationship", "")),
		"location": str(facts.get("location", "")),
		"time_window": str(facts.get("time_window", "")),
	}
	return fingerprint_dict(fp_basis)

static func _canonicalize(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var src: Dictionary = v as Dictionary
			var keys: Array = src.keys()
			keys.sort()
			var out: Dictionary = {}
			for k in keys:
				out[k] = _canonicalize(src[k])
			return out
		TYPE_ARRAY:
			var srca: Array = v as Array
			var outa: Array = []
			outa.resize(srca.size())
			for i in range(srca.size()):
				outa[i] = _canonicalize(srca[i])
			return outa
		_:
			return v

static func _tabs_u64_to_hex(tabs: Dictionary) -> void:
	for key in tabs.keys():
		var tab_data: Variant = tabs.get(key, null)
		if typeof(tab_data) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = tab_data as Dictionary
		if d.has("fact_pool_seed_u64"):
			var v: Variant = d.get("fact_pool_seed_u64", 0)
			var as_int: int = int(v)
			d["fact_pool_seed_u64_hex"] = SeedUtil.hex16(as_int)
			d.erase("fact_pool_seed_u64")

static func _tabs_hex_to_u64(tabs: Dictionary) -> void:
	for key in tabs.keys():
		var tab_data: Variant = tabs.get(key, null)
		if typeof(tab_data) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = tab_data as Dictionary
		var u64: int = _read_u64(d, "fact_pool_seed_u64_hex", "fact_pool_seed_u64")
		d["fact_pool_seed_u64"] = u64
		if d.has("fact_pool_seed_u64_hex"):
			d.erase("fact_pool_seed_u64_hex")

static func _read_u64(d: Dictionary, hex_key: String, int_key: String) -> int:
	var hx: Variant = d.get(hex_key, null)
	if typeof(hx) == TYPE_STRING:
		var pv: int = SeedUtil.hex_to_seed_u63(String(hx))
		if pv >= 0:
			return pv

	var iv: Variant = d.get(int_key, 0)
	if typeof(iv) == TYPE_INT:
		return SeedUtil.normalize_seed(int(iv))
	if typeof(iv) == TYPE_FLOAT:
		return SeedUtil.normalize_seed(int(iv))
	return 0

static func _ensure_parent_dir(path: String) -> void:
	var dir: String = path.get_base_dir()
	if dir == "":
		return
	DirAccess.make_dir_recursive_absolute(dir)

static func _looks_like_payload_wrapper(d: Dictionary) -> bool:
	if d.has("suspect"):
		var suspect_value: Variant = d.get("suspect", null)
		return typeof(suspect_value) == TYPE_DICTIONARY
	return false

static func _ensure_dict(v: Variant) -> Dictionary:
	if typeof(v) == TYPE_DICTIONARY:
		return _deep_copy_dict(v as Dictionary)
	return {}

static func _deep_copy_dict(d: Dictionary) -> Dictionary:
	return d.duplicate(true)
