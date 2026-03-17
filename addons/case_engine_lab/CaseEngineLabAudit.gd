@tool
extends RefCounted
class_name CaseEngineLabAudit

const CaseEngineContracts = preload("res://Scripts/case_engine/CaseEngineContracts.gd")
const CaseFolderRender = preload("res://Scripts/case_engine/CaseFolderRender.gd")
const CaseEngineTypes = preload("res://Scripts/case_engine/CaseEngineTypes.gd")

const AUDIT_TABS: Array[String] = [
	CaseEngineTypes.TAB_ALIBI,
	CaseEngineTypes.TAB_TIMELINE,
	CaseEngineTypes.TAB_CAPABILITY,
	CaseEngineTypes.TAB_MOTIVE,
	CaseEngineTypes.TAB_PROFILE,
]

const AUDIT_ANCHORS: Array[String] = [
	CaseEngineTypes.ANCHOR_TIMELINE,
	CaseEngineTypes.ANCHOR_ALIBI,
	CaseEngineTypes.ANCHOR_CAPABILITY,
	CaseEngineTypes.ANCHOR_MOTIVE,
	CaseEngineTypes.ANCHOR_RELATIONSHIP,
]

static func build_case_audit(payload: Dictionary, report: Dictionary, gate_meta: Dictionary) -> Dictionary:
	var truth_bundle: Dictionary = payload.get("truth_bundle", {}) as Dictionary
	var suspect: Dictionary = payload.get("suspect", {}) as Dictionary
	var tabs: Dictionary = suspect.get("tabs", {}) as Dictionary
	var truth_graph: Dictionary = truth_bundle.get("truth_graph", {}) as Dictionary
	var gen_trace: Array = payload.get("gen_trace", []) as Array
	var conflict_audit: Dictionary = payload.get("conflict_audit", truth_bundle.get("conflict_audit", {})) as Dictionary
	var final_outcome: String = str(gate_meta.get("final_outcome", report.get("level", "REJECT")))
	var final_reject_codes: Array[String] = _string_array(gate_meta.get("final_reject_codes", _report_reject_codes(report)))
	var attempt_reject_codes: Array[String] = _string_array(gate_meta.get("attempt_reject_codes", []))
	var attempt_history: Array = gate_meta.get("attempt_history", []) as Array
	var salvage_audit: Dictionary = truth_bundle.get("salvage_audit", {}) as Dictionary

	var pool_counts: Dictionary = {}
	var reliability_by_tab: Dictionary = {}
	var reliability_totals: Dictionary = {"SOLID": 0, "SHAKY": 0, "CORRUPTED": 0}
	var solid_anchor_counts: Dictionary = {
		"timeline": 0,
		"alibi": 0,
		"capability": 0,
		"motive": 0,
		"relationship": 0,
	}
	var any_anchor_counts: Dictionary = {
		"timeline": 0,
		"alibi": 0,
		"capability": 0,
		"motive": 0,
		"relationship": 0,
	}
	var observed_fact_types: Array[String] = []
	var observed_anchors: Array[String] = []

	for tab_id in AUDIT_TABS:
		var facts: Array = _facts_for_tab(tabs, tab_id)
		pool_counts[tab_id] = facts.size()
		var tab_reliability: Dictionary = {"SOLID": 0, "SHAKY": 0, "CORRUPTED": 0}
		for fact_v in facts:
			if not (fact_v is Dictionary):
				continue
			var fact: Dictionary = fact_v as Dictionary
			var reliability: String = _normalized_reliability(str(fact.get("reliability", "")))
			if tab_reliability.has(reliability):
				tab_reliability[reliability] = int(tab_reliability.get(reliability, 0)) + 1
				reliability_totals[reliability] = int(reliability_totals.get(reliability, 0)) + 1
			var fact_type: String = str(fact.get("fact_type", "")).strip_edges()
			if fact_type != "":
				_append_unique_string(observed_fact_types, fact_type)
				var anchor: String = str(fact.get("anchor", "")).strip_edges()
				if anchor != "":
					_append_unique_string(observed_anchors, anchor)
					if any_anchor_counts.has(anchor):
						any_anchor_counts[anchor] = int(any_anchor_counts.get(anchor, 0)) + 1
					if reliability == "SOLID" and solid_anchor_counts.has(anchor):
						solid_anchor_counts[anchor] = int(solid_anchor_counts.get(anchor, 0)) + 1
		reliability_by_tab[tab_id] = tab_reliability

	observed_fact_types.sort()
	observed_anchors.sort()

	var expected_fact_types: Array[String] = _string_array(truth_bundle.get("variant_required_fact_types", []))
	var expected_anchors: Array[String] = _string_array(truth_bundle.get("variant_required_anchors", []))
	expected_fact_types.sort()
	expected_anchors.sort()

	var missing_fact_types: Array[String] = []
	for fact_type in expected_fact_types:
		if not observed_fact_types.has(fact_type):
			missing_fact_types.append(fact_type)
	var missing_anchors: Array[String] = []
	for anchor_name in expected_anchors:
		if not observed_anchors.has(anchor_name):
			missing_anchors.append(anchor_name)

	var per_group_summary: Dictionary = {}
	var groups: Dictionary = conflict_audit.get("groups", {}) as Dictionary
	for group_id_v in groups.keys():
		var group_id: String = str(group_id_v)
		var group_row: Dictionary = groups.get(group_id_v, {}) as Dictionary
		var members: Array = group_row.get("members", []) as Array
		var breaker_id: String = str(group_row.get("breaker_id", ""))
		var has_solid_breaker: bool = false
		if breaker_id != "":
			for member_v in members:
				if member_v is Dictionary:
					var member: Dictionary = member_v as Dictionary
					if str(member.get("fact_id", "")) == breaker_id and _normalized_reliability(str(member.get("reliability", ""))) == "SOLID":
						has_solid_breaker = true
						break
		per_group_summary[group_id] = {
			"member_count": members.size(),
			"breaker_id_present": breaker_id != "",
			"has_solid_breaker": has_solid_breaker,
			"group_kind": str(group_row.get("group_kind", "")),
			"ui_visible": bool(group_row.get("ui_visible", false)),
		}

	var profile_page: String = CaseFolderRender.render_profile_page(payload)
	var profile_notes_page: String = CaseFolderRender.render_profile_notes_page(payload)
	var profile_card_leaked_reliability: bool = _has_reliability_badge(profile_page)
	var profile_notes_separate: bool = profile_page.find("Profile Notes") < 0 and profile_notes_page.begins_with("Profile Notes")

	var trace_last_stage: String = ""
	if not gen_trace.is_empty():
		var last_trace: Variant = gen_trace[gen_trace.size() - 1]
		if last_trace is Dictionary:
			trace_last_stage = str((last_trace as Dictionary).get("stage", ""))

	var anchor_only_corrupted_categories: Array[String] = []
	for anchor_name in AUDIT_ANCHORS:
		if int(any_anchor_counts.get(anchor_name, 0)) > 0 and int(solid_anchor_counts.get(anchor_name, 0)) <= 0:
			anchor_only_corrupted_categories.append(anchor_name)
	var missing_strong_timeline_anchor: bool = int(solid_anchor_counts.get("timeline", 0)) <= 0
	var missing_strong_alibi_or_capability_anchor: bool = int(solid_anchor_counts.get("alibi", 0)) <= 0 and int(solid_anchor_counts.get("capability", 0)) <= 0
	var missing_strong_motive_or_relationship_anchor: bool = int(solid_anchor_counts.get("motive", 0)) <= 0 and int(solid_anchor_counts.get("relationship", 0)) <= 0
	var per_group_summary_ready: bool = true
	for group_id in per_group_summary.keys():
		var group_summary: Dictionary = per_group_summary.get(group_id, {}) as Dictionary
		if not bool(group_summary.get("breaker_id_present", false)) or not bool(group_summary.get("has_solid_breaker", false)):
			per_group_summary_ready = false
			break
	var anchor_check_passed: bool = anchor_only_corrupted_categories.is_empty() and not missing_strong_timeline_anchor and not missing_strong_alibi_or_capability_anchor and not missing_strong_motive_or_relationship_anchor
	var conflict_resolvability_check_passed: bool = (conflict_audit.get("failed_groups", []) as Array).is_empty() and per_group_summary_ready
	var final_case_consistent: bool = (
		anchor_check_passed
		and conflict_resolvability_check_passed
		and missing_fact_types.is_empty()
		and missing_anchors.is_empty()
	)
	if final_outcome == "PASS" and not final_case_consistent:
		final_outcome = "REJECT"
		_append_unique_string(final_reject_codes, "AUDIT_FINAL_CONSISTENCY_FAIL")
	var validator_level: String = str(report.get("level", "REJECT"))
	if final_outcome == "REJECT" and validator_level == "PASS":
		validator_level = "REJECT"

	return {
		"gate_result": {
			"final_outcome": final_outcome,
			"final_reject_codes": final_reject_codes,
			"attempt_reject_codes": attempt_reject_codes,
			"attempt_count": int(gate_meta.get("attempts", attempt_history.size())),
			"attempt_history": attempt_history.duplicate(true),
		},
		"case_identity": {
			"run_seed_text": str(payload.get("run_seed_text", "")),
			"run_seed_u64_hex": str(payload.get("run_seed_u64_hex", "")),
			"suspect_index": int(payload.get("suspect_index", 0)),
			"reroll_index": int(payload.get("reroll_index", 0)),
			"fingerprint": str(payload.get("fingerprint", "")),
			"variant_skeleton_id": str(truth_bundle.get("variant_skeleton_id", "")),
		},
		"truth_trace_summary": {
			"crime_family": str(truth_bundle.get("crime_family", "")),
			"crime_type": str(truth_bundle.get("crime_type", "")),
			"guilt_state": str(truth_bundle.get("guilt_state", "")),
			"opportunity": str(truth_bundle.get("opportunity", "")),
			"alibi_truth": str(truth_bundle.get("alibi_truth", "")),
			"trace_step_count": gen_trace.size(),
			"trace_last_stage": trace_last_stage,
		},
		"pool_structure": pool_counts,
		"reliability_structure": {
			"by_tab": reliability_by_tab,
			"totals": reliability_totals,
		},
		"anchor_coverage": {
			"solid_counts": solid_anchor_counts,
			"any_counts": any_anchor_counts,
			"anchor_only_corrupted_categories": anchor_only_corrupted_categories,
			"has_strong_timeline_anchor": int(solid_anchor_counts.get("timeline", 0)) > 0,
			"has_strong_alibi_or_capability_anchor": int(solid_anchor_counts.get("alibi", 0)) > 0 or int(solid_anchor_counts.get("capability", 0)) > 0,
			"has_strong_motive_or_relationship_anchor": int(solid_anchor_counts.get("motive", 0)) > 0 or int(solid_anchor_counts.get("relationship", 0)) > 0,
		},
		"skeleton_coverage": {
			"expected_required_fact_types": expected_fact_types,
			"observed_fact_types": observed_fact_types,
			"missing_required_fact_types": missing_fact_types,
			"expected_required_anchors": expected_anchors,
			"observed_anchors": observed_anchors,
			"missing_required_anchors": missing_anchors,
		},
		"conflict_audit": {
			"conflict_group_count": groups.size(),
			"repaired_group_ids": _string_array(conflict_audit.get("repaired_groups", [])),
			"failed_group_ids": _string_array(conflict_audit.get("failed_groups", [])),
			"per_group_summary": per_group_summary,
		},
		"profile_surface_checks": {
			"visible_profile_card_fields": CaseEngineContracts.profile_card_visible_fields(),
			"fixed_profile_card_leaked_reliability_badges": profile_card_leaked_reliability,
			"profile_notes_separate_from_fixed_profile_card": profile_notes_separate,
		},
		"player_surface_fairness_checks": {
			"validator_level": validator_level,
			"final_outcome": final_outcome,
			"reject_codes": final_reject_codes,
			"guilt_tell_check_passed": not _has_any_code(final_reject_codes, ["PLAYER_SURFACE_GUILT_TELL", "GUILT_TELL"]),
			"anchor_check_passed": anchor_check_passed,
			"conflict_resolvability_check_passed": conflict_resolvability_check_passed,
			"final_case_consistent": final_case_consistent,
		},
		"truth_graph_presence": {
			"has_truth_graph": not truth_graph.is_empty(),
			"sections_present": {
				"culpability": truth_graph.has("culpability"),
				"crime": truth_graph.has("crime"),
				"timeline": truth_graph.has("timeline"),
				"opportunity": truth_graph.has("opportunity"),
				"alibi": truth_graph.has("alibi"),
				"motive": truth_graph.has("motive"),
				"capability": truth_graph.has("capability"),
				"relationship": truth_graph.has("relationship"),
				"twist_tags": truth_graph.has("twist_tags"),
			},
		},
		"legacy_parity": {
			"guilt_state_matches": str(truth_bundle.get("guilt_state", "")) == str(((truth_graph.get("culpability", {}) as Dictionary).get("state", ""))),
			"crime_family_matches": str(truth_bundle.get("crime_family", "")) == str(((truth_graph.get("crime", {}) as Dictionary).get("family", ""))),
			"crime_type_matches": str(truth_bundle.get("crime_type", "")) == str(((truth_graph.get("crime", {}) as Dictionary).get("type", ""))),
			"opportunity_matches": str(truth_bundle.get("opportunity", "")) == str(((truth_graph.get("opportunity", {}) as Dictionary).get("id", ""))),
			"alibi_truth_matches": str(truth_bundle.get("alibi_truth", "")) == str(((truth_graph.get("alibi", {}) as Dictionary).get("truth", ""))),
			"motive_matches": str(truth_bundle.get("motive", "")) == str(((truth_graph.get("motive", {}) as Dictionary).get("id", ""))),
			"relationship_matches": str(truth_bundle.get("relationship", "")) == str(((truth_graph.get("relationship", {}) as Dictionary).get("id", ""))),
			"twist_tags_match": _variant_arrays_equal(truth_bundle.get("twist_tags", []), truth_graph.get("twist_tags", [])),
		},
		"required_support_data": {
			"has_relationship_graph": not (truth_bundle.get("relationship_graph", {}) as Dictionary).is_empty(),
			"facts_present": truth_bundle.has("facts") and not (truth_bundle.get("facts", {}) as Dictionary).is_empty(),
			"facts_required_keys_present": {
				"time_window": _has_truth_fact(truth_bundle, "time_window"),
				"time_anchor": _has_truth_fact(truth_bundle, "time_anchor"),
				"location": _has_truth_fact(truth_bundle, "location"),
				"alibi_place": _has_truth_fact(truth_bundle, "alibi_place"),
				"tool": _has_truth_fact(truth_bundle, "tool"),
			},
		},
		"capability_semantics": {
			"tool_present": str(((truth_graph.get("capability", {}) as Dictionary).get("tool", ""))).strip_edges() != "",
			"access_tags_present": (truth_graph.get("capability", {}) as Dictionary).get("access_tags", []) is Array,
			"location_tags_present": (truth_graph.get("capability", {}) as Dictionary).get("location_tags", []) is Array,
			"skill_tags_present": (truth_graph.get("capability", {}) as Dictionary).get("skill_tags", []) is Array,
			"exposure_band_present": str(((truth_graph.get("capability", {}) as Dictionary).get("exposure_band", ""))).strip_edges() != "",
		},
		"relationship_enrichment": {
			"contact_role_present": str(((truth_graph.get("relationship", {}) as Dictionary).get("contact_role", ""))).strip_edges() != "",
			"contact_name_present": str(((truth_graph.get("relationship", {}) as Dictionary).get("contact_name", ""))).strip_edges() != "",
			"contact_node_id_present": (truth_graph.get("relationship", {}) as Dictionary).has("contact_node_id"),
			"contact_node_id": str(((truth_graph.get("relationship", {}) as Dictionary).get("contact_node_id", ""))),
		},
		"salvage_usage": {
			"salvaged_anchor_only_corrupted_count": int(salvage_audit.get("salvaged_anchor_only_corrupted_count", 0)),
			"salvaged_missing_conflict_group_count": int(salvage_audit.get("salvaged_missing_conflict_group_count", 0)),
			"salvaged_unresolvable_conflict_group_count": int(salvage_audit.get("salvaged_unresolvable_conflict_group_count", 0)),
		},
	}

static func compact_digest(audit: Dictionary) -> Dictionary:
	var anchor_coverage: Dictionary = audit.get("anchor_coverage", {}) as Dictionary
	var skeleton_coverage: Dictionary = audit.get("skeleton_coverage", {}) as Dictionary
	var conflict_audit: Dictionary = audit.get("conflict_audit", {}) as Dictionary
	var profile_surface_checks: Dictionary = audit.get("profile_surface_checks", {}) as Dictionary
	var fairness_checks: Dictionary = audit.get("player_surface_fairness_checks", {}) as Dictionary
	var reliability_structure: Dictionary = audit.get("reliability_structure", {}) as Dictionary
	var pool_structure: Dictionary = audit.get("pool_structure", {}) as Dictionary
	return {
		"final_outcome": (audit.get("gate_result", {}) as Dictionary).get("final_outcome", ""),
		"final_reject_codes": (audit.get("gate_result", {}) as Dictionary).get("final_reject_codes", []),
		"attempt_reject_codes": (audit.get("gate_result", {}) as Dictionary).get("attempt_reject_codes", []),
		"attempt_count": int((audit.get("gate_result", {}) as Dictionary).get("attempt_count", 0)),
		"pool_counts": pool_structure,
		"reliability_totals": reliability_structure.get("totals", {}),
		"required_fact_coverage_ok": (skeleton_coverage.get("missing_required_fact_types", []) as Array).is_empty(),
		"required_anchor_coverage_ok": (skeleton_coverage.get("missing_required_anchors", []) as Array).is_empty(),
		"strong_timeline_anchor_ok": bool(anchor_coverage.get("has_strong_timeline_anchor", false)),
		"strong_alibi_or_capability_anchor_ok": bool(anchor_coverage.get("has_strong_alibi_or_capability_anchor", false)),
		"strong_motive_or_relationship_anchor_ok": bool(anchor_coverage.get("has_strong_motive_or_relationship_anchor", false)),
		"failed_conflict_groups": (conflict_audit.get("failed_group_ids", []) as Array).size(),
		"profile_card_leak_hit": bool(profile_surface_checks.get("fixed_profile_card_leaked_reliability_badges", false)),
		"profile_notes_separate": bool(profile_surface_checks.get("profile_notes_separate_from_fixed_profile_card", false)),
		"guilt_tell_check_passed": bool(fairness_checks.get("guilt_tell_check_passed", false)),
		"anchor_check_passed": bool(fairness_checks.get("anchor_check_passed", false)),
		"conflict_resolvability_check_passed": bool(fairness_checks.get("conflict_resolvability_check_passed", false)),
		"salvaged_anchor_only_corrupted_count": int((audit.get("salvage_usage", {}) as Dictionary).get("salvaged_anchor_only_corrupted_count", 0)),
		"salvaged_missing_conflict_group_count": int((audit.get("salvage_usage", {}) as Dictionary).get("salvaged_missing_conflict_group_count", 0)),
		"salvaged_unresolvable_conflict_group_count": int((audit.get("salvage_usage", {}) as Dictionary).get("salvaged_unresolvable_conflict_group_count", 0)),
	}

static func _facts_for_tab(tabs: Dictionary, tab_id: String) -> Array:
	var tab_data: Dictionary = tabs.get(tab_id, {}) as Dictionary
	return tab_data.get("facts", []) as Array

static func _normalized_reliability(value: String) -> String:
	match value.strip_edges().to_upper():
		CaseEngineTypes.RELIABILITY_SOLID:
			return "SOLID"
		CaseEngineTypes.RELIABILITY_CORRUPTED:
			return "CORRUPTED"
		"QUESTIONABLE", "SHAKY":
			return "SHAKY"
	return "SHAKY"

static func _has_reliability_badge(text: String) -> bool:
	return text.find("[Solid]") >= 0 or text.find("[Shaky]") >= 0 or text.find("[Corrupted]") >= 0

static func _has_truth_fact(truth_bundle: Dictionary, fact_key: String) -> bool:
	var facts: Dictionary = truth_bundle.get("facts", {}) as Dictionary
	return facts.has(fact_key) and str(facts.get(fact_key, "")).strip_edges() != ""

static func _report_reject_codes(report: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for item_v in report.get("items", []) as Array:
		if item_v is Dictionary:
			var item: Dictionary = item_v as Dictionary
			if str(item.get("level", "")) == "REJECT":
				_append_unique_string(out, str(item.get("code", "")))
	return out

static func _has_any_code(codes: Array[String], needles: Array[String]) -> bool:
	for needle in needles:
		if codes.has(needle):
			return true
	return false

static func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is PackedStringArray:
		for item in value:
			out.append(str(item))
	elif value is Array:
		for item in value:
			out.append(str(item))
	return out

static func _append_unique_string(arr: Array[String], value: String) -> void:
	var text: String = value.strip_edges()
	if text == "" or arr.has(text):
		return
	arr.append(text)

static func _variant_arrays_equal(left: Variant, right: Variant) -> bool:
	if not (left is Array) or not (right is Array):
		return false
	return JSON.stringify(left) == JSON.stringify(right)
