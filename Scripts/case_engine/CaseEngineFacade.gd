@tool
extends RefCounted
class_name CaseEngineFacade

static func generate_case(run_seed_u64: int, run_seed_text: String, suspect_index: int, reroll_index: int = 0) -> Dictionary:
	var result: Dictionary = CaseEngineCore.generate(run_seed_u64, run_seed_text, suspect_index, reroll_index)
	if not bool(result.get("ok", false)):
		return {
			"ok": false,
			"error": str(result.get("error", "CaseEngineCore.generate failed")),
			"error_details": result.get("error_details", {}),
			"fail_stage": str(result.get("fail_stage", "")),
			"gen_trace": result.get("gen_trace", []),
			"run_seed_text": run_seed_text,
			"run_seed_u64_hex": SeedUtil.hex16(run_seed_u64),
			"suspect_index": suspect_index,
			"reroll_index": reroll_index,
		}

	var suspect_dict: Dictionary = result.get("suspect", {}) as Dictionary
	var truth_bundle: Dictionary = result.get("truth_bundle", {}) as Dictionary
	var conflict_groups: Dictionary = result.get("conflict_groups", {}) as Dictionary

	var fp_basis: Dictionary = {
		"crime_family": str(truth_bundle.get("crime_family", "")),
		"crime_type": str(truth_bundle.get("crime_type", "")),
		"opportunity": str(truth_bundle.get("opportunity", "")),
		"alibi_truth": str(truth_bundle.get("alibi_truth", "")),
		"motive": str(truth_bundle.get("motive", "")),
		"relationship": str(truth_bundle.get("relationship", "")),
		"location": str((truth_bundle.get("facts", {}) as Dictionary).get("location", "")),
		"time_window": str((truth_bundle.get("facts", {}) as Dictionary).get("time_window", "")),
	}
	var fingerprint: String = SuspectIO.fingerprint_dict(fp_basis)
	var payload: Dictionary = {
		"ok": true,
		"run_seed_text": run_seed_text,
		"run_seed_u64_hex": SeedUtil.hex16(run_seed_u64),
		"suspect_index": suspect_index,
		"reroll_index": reroll_index,
		"suspect_seed_u64_hex": str(suspect_dict.get("suspect_seed_u64_hex", "")),
		"fingerprint": fingerprint,
		"truth_bundle": truth_bundle,
		"conflict_groups": conflict_groups,
		"gen_trace": result.get("gen_trace", []),
		"suspect": suspect_dict,
	}
	var conflict_audit: Dictionary = truth_bundle.get("conflict_audit", {}) as Dictionary
	if not conflict_audit.is_empty():
		payload["conflict_audit"] = conflict_audit
	var variant_skeleton_id: String = str(truth_bundle.get("variant_skeleton_id", ""))
	if variant_skeleton_id != "":
		payload["variant_skeleton_id"] = variant_skeleton_id
	var profile_bundle: Dictionary = truth_bundle.get("profile_bundle", {}) as Dictionary
	if not profile_bundle.is_empty():
		payload["profile_bundle"] = profile_bundle
	return payload

func generate_case_instance(run_seed_u64: int, run_seed_text: String, suspect_index: int, reroll_index: int = 0) -> Dictionary:
	return generate_case(run_seed_u64, run_seed_text, suspect_index, reroll_index)
