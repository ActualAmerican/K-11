@tool
extends RefCounted
class_name CaseEngineCore

static func generate(run_seed_u64: int, run_seed_text: String, suspect_index: int, reroll_index: int) -> Dictionary:
	var gen_trace: Array = []
	var fail_stage := "START"
	_trace_push(gen_trace, "START", {
		"run_seed_u64": SeedUtil.hex16(run_seed_u64),
		"run_seed_text": run_seed_text,
		"suspect_index": suspect_index,
		"reroll_index": reroll_index,
	})

	var core_seed: int = SeedUtil.derive_seed(run_seed_u64, "case_engine_core", suspect_index * 1000 + reroll_index)
	var suspect_seed: int = SeedUtil.derive_seed(run_seed_u64, "suspect", suspect_index)
	var rng: RandomNumberGenerator = SeedUtil.make_rng(core_seed)
	var seed_trace: Dictionary = {
		"run_seed_text": SeedUtil.format_run_seed_u63(run_seed_u64),
		"run_seed_input_text": run_seed_text,
		"run_seed_u64_hex": SeedUtil.hex16(run_seed_u64),
		"suspect_index": suspect_index,
		"reroll_index": reroll_index,
		"suspect_seed_u64_hex": SeedUtil.hex16(suspect_seed),
		"core_seed_u64_hex": SeedUtil.hex16(core_seed),
		"named_subseeds": {
			"case_engine_core": SeedUtil.hex16(core_seed),
		},
	}
	fail_stage = "AUTHORING_CONTRACT"
	var authoring_errors: Array[String] = _run_authoring_self_check()
	_trace_push(gen_trace, "AUTHORING_CONTRACT", {
		"error_count": authoring_errors.size(),
	})
	if not authoring_errors.is_empty():
		var first_codes: Array[String] = []
		for i in range(mini(authoring_errors.size(), 5)):
			first_codes.append(str(authoring_errors[i]))
		return _gen_fail_stage(fail_stage, "AUTHORING_CONTRACT_FAILED", {
			"codes": first_codes,
		}, gen_trace)

	var families: Array[String] = CaseEngineContent_v0.crime_families()
	var crime_family: String = families[rng.randi_range(0, families.size() - 1)]
	var types: Array[String] = CaseEngineContent_v0.crime_types_for_family(crime_family)
	var crime_type: String = types[rng.randi_range(0, types.size() - 1)]
	var guilt_state: String = _pick_guilt_state(rng)
	var opportunity_pool: Array[String] = CaseEngineContent_v0.opportunities()
	var motive_pool: Array[String] = CaseEngineContent_v0.motives()
	var relation_pool: Array[String] = CaseEngineContent_v0.relationships()

	fail_stage = "TRUTH_BUNDLE"
	var truth_bundle: Dictionary = {
		"crime_family": crime_family,
		"crime_type": crime_type,
		"guilt_state": guilt_state,
		"opportunity": "",
		"alibi_truth": "",
		"motive": "",
		"relationship": "",
		"twist_tags": [],
		"facts": {}
	}
	truth_bundle["seed_trace"] = seed_trace.duplicate(true)
	_trace_push(gen_trace, "TRUTH_BUNDLE", {
		"crime_family": crime_family,
		"crime_type": crime_type,
	})

	var profile_bundle: Dictionary = CaseEngineProfileTables_v0.build_profile(
		run_seed_u64,
		suspect_index,
		reroll_index,
		crime_family,
		crime_type
	)
	truth_bundle["profile_bundle"] = profile_bundle
	_trace_push(gen_trace, "PROFILE_BUNDLE", {
		"occupation": str(profile_bundle.get("occupation_id", "")),
		"schedule": str(profile_bundle.get("schedule_tag", "")),
		"temperament": str(profile_bundle.get("temperament", "")),
	})

	var time_window_candidates: Array = ["shift_start", "handoff_gap", "cleanup_window"]
	var time_window_pool: Array = _pool_with_trace(
		CaseEngineProfileTables_v0.allowed_time_windows(profile_bundle),
		time_window_candidates,
		"time_window",
		gen_trace
	)
	var alibi_place_candidates: Array = ["break_room", "dispatch_desk", "service_corridor"]
	var alibi_place_pool: Array = _pool_with_trace(
		CaseEngineProfileTables_v0.allowed_alibi_places(profile_bundle),
		alibi_place_candidates,
		"alibi_place",
		gen_trace
	)
	var location_candidates: Array = ["archives", "dispatch_desk", "service_corridor", "storage_wing", "ledger_office", "records_room", "checkpoint", "camera_hub", "maintenance_bay"]
	var compatible_locations: Array = []
	for location_name in location_candidates:
		if CaseEngineProfileTables_v0.allowed_locations(profile_bundle).has(location_name):
			compatible_locations.append(location_name)
	var location_pool: Array = _pool_with_trace(compatible_locations, location_candidates, "location", gen_trace)
	var tool_candidates: Array = ["ledger_console", "badge_terminal", "maintenance_tablet", "invoice_terminal", "records_tablet", "camera_console", "patrol_log", "field_kit"]
	var compatible_tools: Array = []
	for tool_name in tool_candidates:
		if CaseEngineProfileTables_v0.allowed_tools(profile_bundle).has(tool_name):
			compatible_tools.append(tool_name)
	var tool_pool: Array = _pool_with_trace(compatible_tools, tool_candidates, "tool", gen_trace)
	var compatible_relationships: Array = []
	for relv in relation_pool:
		var contact_role: String = _relationship_contact_role(str(relv))
		if CaseEngineProfileTables_v0.allowed_contact_roles(profile_bundle).has(contact_role):
			compatible_relationships.append(relv)
	var relationship_pool: Array = _pool_with_trace(compatible_relationships, relation_pool, "contact_role", gen_trace)
	var selected_time_window: String = str(time_window_pool[rng.randi_range(0, time_window_pool.size() - 1)])
	var selected_time_anchor: String = _pick(_time_anchors_for_window(selected_time_window), rng)
	var selected_location: String = str(location_pool[rng.randi_range(0, location_pool.size() - 1)])
	var selected_alibi_place: String = str(alibi_place_pool[rng.randi_range(0, alibi_place_pool.size() - 1)])
	var selected_tool: String = str(tool_pool[rng.randi_range(0, tool_pool.size() - 1)])
	var relationship: String = str(relationship_pool[rng.randi_range(0, relationship_pool.size() - 1)])
	var truth_graph: Dictionary = _build_truth_graph_v0(
		rng,
		guilt_state,
		crime_family,
		crime_type,
		opportunity_pool,
		motive_pool,
		profile_bundle,
		selected_time_window,
		selected_time_anchor,
		selected_location,
		selected_alibi_place,
		selected_tool,
		relationship
	)
	truth_bundle["truth_graph"] = truth_graph
	truth_bundle["guilt_state"] = str((truth_graph.get("culpability", {}) as Dictionary).get("state", guilt_state))
	truth_bundle["opportunity"] = str((truth_graph.get("opportunity", {}) as Dictionary).get("id", ""))
	truth_bundle["alibi_truth"] = str((truth_graph.get("alibi", {}) as Dictionary).get("truth", ""))
	truth_bundle["motive"] = str((truth_graph.get("motive", {}) as Dictionary).get("id", ""))
	truth_bundle["relationship"] = str((truth_graph.get("relationship", {}) as Dictionary).get("id", relationship))
	truth_bundle["twist_tags"] = (truth_graph.get("twist_tags", []) as Array).duplicate()
	_trace_push(gen_trace, "TRUTH_GRAPH_BUILT", {
		"guilt_state": truth_bundle["guilt_state"],
		"method_class": str((truth_graph.get("crime", {}) as Dictionary).get("method_class", "")),
		"opportunity_class": str((truth_graph.get("opportunity", {}) as Dictionary).get("class", "")),
		"alibi_strength_band": str((truth_graph.get("alibi", {}) as Dictionary).get("strength_band", "")),
		"motive_intensity_band": str((truth_graph.get("motive", {}) as Dictionary).get("intensity_band", "")),
		"twist_tags": truth_bundle["twist_tags"],
		"exposure_band": str((truth_graph.get("capability", {}) as Dictionary).get("exposure_band", "")),
		"relationship_id": truth_bundle["relationship"],
	})
	var human_profile: Dictionary = CaseEngineProfileTables_v0.human_profile_fields(profile_bundle)
	truth_bundle["facts"] = {
		"time_anchor": selected_time_anchor,
		"time_window": selected_time_window,
		"location": selected_location,
		"alibi_place": selected_alibi_place,
		"tool": selected_tool,
		"shift": _pick(["A", "B", "C"], rng),
		"team": _pick(["ops", "compliance", "routing", "maintenance"], rng),
		"occupation_id": str(profile_bundle.get("occupation_id", "")),
		"occupation_label": str(profile_bundle.get("occupation_label", "")),
		"assignment_label": str(profile_bundle.get("assignment_label", "")),
		"full_name": str(profile_bundle.get("full_name", "")),
		"first_name": str(profile_bundle.get("first_name", "")),
		"last_name": str(profile_bundle.get("last_name", "")),
		"birth_month": str(profile_bundle.get("birth_month", "")),
		"birth_day": int(profile_bundle.get("birth_day", 0)),
		"age_years": int(profile_bundle.get("age_years", 0)),
		"temperament": str(profile_bundle.get("temperament", "")),
		"temperament_label": str(profile_bundle.get("temperament_label", "")),
		"criminal_history_band": str(profile_bundle.get("criminal_history_band", "")),
		"criminal_history_label": str(profile_bundle.get("criminal_history_label", "")),
		"family_status": str(profile_bundle.get("family_status", "")),
		"dependents_band": str(profile_bundle.get("dependents_band", "")),
		"schedule_label": str(profile_bundle.get("schedule_label", "")),
		"tenure_label": str(profile_bundle.get("tenure_label", "")),
		"role_family_label": str(profile_bundle.get("role_family_label", "")),
		"human_role_family": str(human_profile.get("role_family", "")),
		"human_occupation": str(human_profile.get("occupation", "")),
		"human_assignment": str(human_profile.get("assignment", "")),
		"human_schedule": str(human_profile.get("schedule", "")),
		"human_temperament": str(human_profile.get("temperament", "")),
		"human_criminal_history": str(human_profile.get("criminal_history", "")),
		"human_dependents": str(human_profile.get("dependents", "")),
		"human_birthday": str(human_profile.get("birthday", "")),
	}

	fail_stage = "RELATIONSHIP_GRAPH"
	var rel: Dictionary = CaseEngineEntityGraph.build(run_seed_u64, suspect_index, reroll_index, truth_bundle)
	truth_bundle["relationship_graph"] = rel.get("graph", {}) as Dictionary
	var truth_graph_root: Dictionary = truth_bundle.get("truth_graph", {}) as Dictionary
	var relationship_section: Dictionary = truth_graph_root.get("relationship", {}) as Dictionary
	var slot_map: Dictionary = rel.get("slots", {}) as Dictionary
	relationship_section["contact_role"] = str(slot_map.get("contact_role", relationship_section.get("contact_role", "")))
	relationship_section["contact_name"] = str(slot_map.get("contact_name", ""))
	relationship_section["contact_node_id"] = _relationship_contact_node_id(
		truth_bundle.get("relationship_graph", {}) as Dictionary,
		relationship_section["contact_role"],
		relationship_section["contact_name"]
	)
	truth_graph_root["relationship"] = relationship_section
	truth_bundle["truth_graph"] = truth_graph_root
	_trace_push(gen_trace, "RELATIONSHIP_GRAPH", {
		"has_graph": not (truth_bundle.get("relationship_graph", {}) as Dictionary).is_empty(),
	})

	var fb: Dictionary = truth_bundle.get("facts", {}) as Dictionary
	for profile_key in [
		CaseEngineTypes.PROFILE_AGE_BAND,
		CaseEngineTypes.PROFILE_LIFE_STAGE,
		CaseEngineTypes.PROFILE_FAMILY_STATUS,
		CaseEngineTypes.PROFILE_DEPENDENTS_BAND,
		CaseEngineTypes.PROFILE_ROLE_FAMILY,
		CaseEngineTypes.PROFILE_SCHEDULE_TAG,
		CaseEngineTypes.PROFILE_TENURE_BAND,
		CaseEngineTypes.PROFILE_INCOME_PROXY,
	]:
		fb[str(profile_key)] = profile_bundle.get(str(profile_key), "")

	for profile_key in [
		"occupation_id",
		"occupation_label",
		"criminal_history_band",
		"temperament",
		"role_family_label",
		"schedule_label",
		"full_name",
		"first_name",
		"last_name",
		"birth_month",
		"birth_day",
		"age_years",
		"assignment_label",
		"tenure_label",
		"temperament_label",
		"criminal_history_label",
	]:
		fb[profile_key] = profile_bundle.get(profile_key, "")

	for k in slot_map.keys():
		fb[k] = slot_map[k]
	truth_bundle["facts"] = fb
	truth_bundle["guilt_state"] = str(((truth_bundle.get("truth_graph", {}) as Dictionary).get("culpability", {}) as Dictionary).get("state", guilt_state))
	truth_bundle["opportunity"] = str(((truth_bundle.get("truth_graph", {}) as Dictionary).get("opportunity", {}) as Dictionary).get("id", truth_bundle.get("opportunity", "")))
	truth_bundle["alibi_truth"] = str(((truth_bundle.get("truth_graph", {}) as Dictionary).get("alibi", {}) as Dictionary).get("truth", truth_bundle.get("alibi_truth", "")))
	truth_bundle["motive"] = str(((truth_bundle.get("truth_graph", {}) as Dictionary).get("motive", {}) as Dictionary).get("id", truth_bundle.get("motive", "")))
	truth_bundle["relationship"] = str((relationship_section).get("id", truth_bundle.get("relationship", "")))
	truth_bundle["twist_tags"] = (((truth_bundle.get("truth_graph", {}) as Dictionary).get("twist_tags", []) as Array)).duplicate()
	fail_stage = "SKELETON_SELECT"
	_trace_push(gen_trace, "SKELETON_SELECT", {
		"crime_family": crime_family,
		"crime_type": crime_type,
	})
	var skeleton: Dictionary = CaseEngineSkeletons_v0.choose(crime_family, crime_type, run_seed_u64, suspect_index, reroll_index)
	if skeleton.is_empty():
		return _gen_fail_stage(fail_stage, "NO_VARIANT_SKELETON", {
			"crime_family": crime_family,
			"crime_type": crime_type,
		}, gen_trace)
	truth_bundle["variant_skeleton_id"] = str(skeleton.get("id", ""))
	truth_bundle["variant_required_fact_types"] = _required_skeleton_fact_types(skeleton)
	truth_bundle["variant_required_anchors"] = _required_skeleton_anchors(skeleton)
	_trace_push(gen_trace, "SKELETON_SELECTED", {
		"variant_skeleton_id": str(skeleton.get("id", "")),
		"required_atoms_expected": skeleton.get("required_atoms", []),
	})

	fail_stage = "SUSPECT_FACTORY"
	_trace_push(gen_trace, "SUSPECT_FACTORY", {})
	var suspect: SuspectData = SuspectFactory.generate(run_seed_u64, run_seed_text, suspect_index)
	if suspect == null:
		return _gen_fail_stage(fail_stage, "NULL_SUSPECT_FACTORY_RESULT", {}, gen_trace)
	var suspect_seed_trace: Dictionary = suspect.debug.get("seed_trace", {}) as Dictionary
	var unified_named_subseeds: Dictionary = {}
	var suspect_named_subseeds: Dictionary = suspect_seed_trace.get("named_subseeds", {}) as Dictionary
	for seed_name in _sorted_dictionary_keys(suspect_named_subseeds):
		unified_named_subseeds[seed_name] = str(suspect_named_subseeds.get(seed_name, ""))
	unified_named_subseeds["case_engine_core"] = SeedUtil.hex16(core_seed)
	seed_trace["named_subseeds"] = unified_named_subseeds

	# Truth-first content shaping in debug payload while keeping existing suspect structure.
	suspect.truth_guilty = guilt_state == "GUILTY" or guilt_state == "COMPLICIT"
	fail_stage = "BUILD_TABS"
	_trace_push(gen_trace, "BUILD_TABS", {
		"variant_skeleton_id": str(truth_bundle.get("variant_skeleton_id", "")),
	})
	var tab_build: Dictionary = _build_tabs(rng, truth_bundle, skeleton, run_seed_u64, suspect_index, reroll_index, gen_trace)
	if not bool(tab_build.get("ok", false)):
		var tab_error_details: Dictionary = tab_build.get("error_details", {}) as Dictionary
		if tab_error_details.is_empty():
			tab_error_details["variant_skeleton_id"] = str(skeleton.get("id", ""))
		return _gen_fail_stage(
			fail_stage,
			str(tab_build.get("error", "FAILED_BUILD_TABS")),
			tab_error_details,
			gen_trace
		)
	suspect.tabs = tab_build.get("tabs", {}) as Dictionary
	var tab_pool_seed_trace: Dictionary = tab_build.get("tab_pool_seed_trace", {}) as Dictionary
	for tab_id in _sorted_dictionary_keys(tab_pool_seed_trace):
		unified_named_subseeds["case_engine_tab_pool:%s" % tab_id] = str(tab_pool_seed_trace.get(tab_id, ""))
	seed_trace["named_subseeds"] = unified_named_subseeds
	truth_bundle["seed_trace"] = seed_trace.duplicate(true)
	suspect.debug["seed_trace"] = seed_trace.duplicate(true)

	fail_stage = "CHARGE_SHEET"
	suspect.charge_sheet = _build_charge_sheet(suspect, truth_bundle, reroll_index)
	_trace_push(gen_trace, "CHARGE_SHEET", {
		"case_id": str((suspect.charge_sheet as Dictionary).get("case_id", "")),
	})
	suspect.debug["case_engine_truth_bundle"] = truth_bundle
	suspect.debug["reroll_index"] = reroll_index

	fail_stage = "FINALIZE"
	var suspect_dict: Dictionary = SuspectIO.to_dict(suspect)
	var conflict_groups: Dictionary = _build_conflict_groups(suspect_dict)
	_trace_push(gen_trace, "FINALIZE", {
		"conflict_groups": conflict_groups.size(),
	})

	return {
		"ok": true,
		"suspect": suspect_dict,
		"truth_bundle": truth_bundle,
		"seed_trace": seed_trace,
		"gen_trace": gen_trace,
		"conflict_groups": conflict_groups,
	}

static func _trace_push(trace: Array, stage: String, info: Dictionary = {}) -> void:
	trace.append({
		"stage": stage,
		"info": info,
	})

static func _gen_fail_stage(stage: String, code: String, details: Dictionary = {}, trace: Array = []) -> Dictionary:
	return {
		"ok": false,
		"error": code,
		"error_details": details,
		"fail_stage": stage,
		"gen_trace": trace.duplicate(true),
	}

static func _run_authoring_self_check() -> Array[String]:
	return ValidatorSuite.validate_authoring_contracts()

static func _build_charge_sheet(suspect: SuspectData, truth_bundle: Dictionary, reroll_index: int) -> Dictionary:
	var cf: String = str(truth_bundle.get("crime_family", ""))
	var ct: String = str(truth_bundle.get("crime_type", ""))
	var opp: String = str(truth_bundle.get("opportunity", ""))
	var motive: String = str(truth_bundle.get("motive", ""))
	return {
		"case_id": ("CE-%s" % suspect.id) + ("" if reroll_index <= 0 else "-r%d" % reroll_index),
		"title": "%s investigation" % _title_case(ct),
		"charges": ["Policy breach", "Operational misconduct"],
		"brief": "Pattern review indicates %s activity during %s with pressure around %s." % [cf, opp, motive],
	}

static func _build_tabs(rng: RandomNumberGenerator, truth_bundle: Dictionary, skeleton: Dictionary, run_seed_u64: int, suspect_index: int, reroll_index: int, gen_trace: Array) -> Dictionary:
	var templates: Dictionary = CaseEngineContent_v0.tabs_templates()
	var atoms: Array[Dictionary] = []
	var fact_seq: int = 0
	var required_expected: Array[String] = []
	var required_produced: Array[String] = []
	for required_v in skeleton.get("required_atoms", []) as Array:
		if required_v is Dictionary:
			var required_row: Dictionary = required_v as Dictionary
			required_expected.append("%s:%s:%s" % [
				str(required_row.get("tab", "")),
				str(required_row.get("fact_type", "")),
				str(required_row.get("anchor", "")),
			])
	_trace_push(gen_trace, "BUILD_TABS_REQUIRED_EXPECTED", {
		"variant_skeleton_id": str(skeleton.get("id", "")),
		"required_atoms_expected": required_expected,
	})

	for specv in skeleton.get("required_atoms", []) as Array:
		if not (specv is Dictionary):
			continue
		var required_spec: Dictionary = specv as Dictionary
		var fact: Dictionary = _materialize_atom(rng, templates, truth_bundle, required_spec, fact_seq)
		if fact.is_empty():
			var tab: String = str(required_spec.get("tab", ""))
			var tab_templates: Array = templates.get(tab, []) as Array
			var available_template_ids: Array[String] = []
			var available_fact_types_for_tab: Array[String] = []
			for tv in tab_templates:
				if not (tv is Dictionary):
					continue
				var td: Dictionary = tv as Dictionary
				available_template_ids.append(str(td.get("template_id", "")))
				var available_fact_type: String = str(td.get("fact_type", ""))
				if not available_fact_types_for_tab.has(available_fact_type):
					available_fact_types_for_tab.append(available_fact_type)
			return {
				"ok": false,
				"error": "NO_MATERIALIZABLE_REQUIRED_ATOM",
				"error_details": {
					"variant_skeleton_id": str(truth_bundle.get("variant_skeleton_id", "")),
					"required_fact_type": str(required_spec.get("fact_type", "")),
					"required_tab": tab,
					"available_template_ids": available_template_ids,
					"available_fact_types_for_tab": available_fact_types_for_tab,
				}
			}
		atoms.append(fact)
		required_produced.append("%s:%s:%s" % [
			str(fact.get("tab", "")),
			str(fact.get("fact_type", "")),
			str(fact.get("anchor", "")),
		])
		fact_seq += 1
	_trace_push(gen_trace, "BUILD_TABS_REQUIRED_PRODUCED", {
		"variant_skeleton_id": str(skeleton.get("id", "")),
		"required_atoms_produced": required_produced,
	})

	for specv in skeleton.get("optional_atoms", []) as Array:
		if not (specv is Dictionary):
			continue
		var fact: Dictionary = _materialize_atom(rng, templates, truth_bundle, specv as Dictionary, fact_seq)
		if fact.is_empty():
			continue
		atoms.append(fact)
		fact_seq += 1

	_apply_conflict_seeds(atoms, skeleton)
	_trace_push(gen_trace, "RELIABILITY_CONFLICTS", {
		"conflict_seed_count": (skeleton.get("conflict_seeds", []) as Array).size(),
		"atom_count": atoms.size(),
	})
	var repair_result: Dictionary = _repair_conflict_groups(
		atoms,
		skeleton,
		run_seed_u64,
		suspect_index,
		reroll_index
	)
	atoms = repair_result.get("atoms", atoms)
	var salvage_result: Dictionary = _salvage_anchor_only_corrupted(
		atoms,
		skeleton,
		run_seed_u64,
		suspect_index,
		reroll_index
	)
	atoms = salvage_result.get("atoms", atoms)
	var salvage_anchor_count: int = int(salvage_result.get("salvaged_anchor_only_corrupted_count", 0))
	var salvage_anchor_names: Array = salvage_result.get("salvaged_anchor_names", []) as Array
	var second_repair_result: Dictionary = _repair_conflict_groups(
		atoms,
		skeleton,
		run_seed_u64,
		suspect_index,
		reroll_index
	)
	atoms = second_repair_result.get("atoms", atoms)
	var first_audit: Dictionary = repair_result.get("audit", {}) as Dictionary
	var second_audit: Dictionary = second_repair_result.get("audit", {}) as Dictionary
	var merged_salvage_audit: Dictionary = {
		"salvaged_anchor_only_corrupted_count": salvage_anchor_count,
		"salvaged_anchor_names": salvage_anchor_names.duplicate(),
		"salvaged_missing_conflict_group_count": maxi(int(first_audit.get("salvaged_missing_conflict_group_count", 0)), int(second_audit.get("salvaged_missing_conflict_group_count", 0))),
		"salvaged_unresolvable_conflict_group_count": maxi(int(first_audit.get("salvaged_unresolvable_conflict_group_count", 0)), int(second_audit.get("salvaged_unresolvable_conflict_group_count", 0))),
	}
	var final_conflict_audit: Dictionary = second_audit.duplicate(true)
	final_conflict_audit["salvaged_missing_conflict_group_count"] = int(merged_salvage_audit.get("salvaged_missing_conflict_group_count", 0))
	final_conflict_audit["salvaged_unresolvable_conflict_group_count"] = int(merged_salvage_audit.get("salvaged_unresolvable_conflict_group_count", 0))
	truth_bundle["conflict_audit"] = final_conflict_audit
	truth_bundle["salvage_audit"] = merged_salvage_audit
	var conflict_audit: Dictionary = truth_bundle.get("conflict_audit", {}) as Dictionary
	var conflict_groups_summary: Dictionary = {}
	var audit_groups: Dictionary = conflict_audit.get("groups", {}) as Dictionary
	for group_id in audit_groups.keys():
		var group_row: Dictionary = audit_groups.get(group_id, {}) as Dictionary
		var member_ids: Array[String] = []
		for member_v in group_row.get("members", []) as Array:
			if member_v is Dictionary:
				member_ids.append(str((member_v as Dictionary).get("fact_id", "")))
		conflict_groups_summary[str(group_id)] = {
			"members": member_ids,
			"breaker_id": str(group_row.get("breaker_id", "")),
			"repaired": bool(group_row.get("repaired", false)),
		}
	_trace_push(gen_trace, "CONFLICT_REPAIR", {
		"repaired_groups": conflict_audit.get("repaired_groups", []),
		"failed_groups": conflict_audit.get("failed_groups", []),
		"groups": conflict_groups_summary,
	})
	_trace_push(gen_trace, "VALIDATION_SALVAGE", merged_salvage_audit)
	var tab_pool_seed_trace: Dictionary = _case_engine_tab_pool_seed_trace(run_seed_u64, suspect_index, reroll_index)

	return {
		"ok": true,
		"tabs": _bucket_atoms_into_tabs(atoms, run_seed_u64, suspect_index, reroll_index),
		"tab_pool_seed_trace": tab_pool_seed_trace,
	}

static func _materialize_atom(rng: RandomNumberGenerator, templates: Dictionary, truth_bundle: Dictionary, spec: Dictionary, seq: int) -> Dictionary:
	var tab: String = str(spec.get("tab", ""))
	if tab == "":
		return {}
	var defs: Array = templates.get(tab, []) as Array
	var matches: Array[Dictionary] = []
	for defv in defs:
		if not (defv is Dictionary):
			continue
		var d: Dictionary = defv as Dictionary
		if _template_matches_spec(d, spec):
			matches.append(d)
	if matches.is_empty():
		return {}
	var chosen: Dictionary = matches[rng.randi_range(0, matches.size() - 1)]
	return _make_fact_atom(rng, tab, chosen, truth_bundle, seq)

static func _make_fact_atom(rng: RandomNumberGenerator, tab: String, d: Dictionary, truth_bundle: Dictionary, seq: int) -> Dictionary:
	var slots: Dictionary = {}
	var fact_truth: Dictionary = truth_bundle.get("facts", {}) as Dictionary
	for k in d.get("slot_keys", []) as Array:
		var key: String = str(k)
		if fact_truth.has(key):
			slots[key] = fact_truth.get(key)
		elif truth_bundle.has(key):
			slots[key] = truth_bundle.get(key)
		else:
			slots[key] = "n/a"

	var reliability: String = _apply_reliability_transform(rng, str(d.get("reliability", CaseEngineTypes.RELIABILITY_QUESTIONABLE)))

	var text: String = _render_template(str(d.get("text_tpl", "")), slots)
	var truth_refs: Array = d.get("truth_refs", []) as Array
	var normalized_refs: Array[String] = []
	for r in truth_refs:
		normalized_refs.append(str(r))

	return CaseEngineFactAtom.make(
		"%s_%02d_%s" % [tab.to_lower(), seq, str(d.get("template_id", "template"))],
		tab,
		str(d.get("fact_type", CaseEngineTypes.FACT_TYPE_OBSERVATION)),
		text,
		normalized_refs,
		slots,
		reliability,
		str(d.get("conflict_group", "")),
		str(d.get("anchor", "")),
		str(d.get("template_id", "template"))
	)

static func _template_matches_spec(template_def: Dictionary, spec: Dictionary) -> bool:
	if str(template_def.get("tab", "")) != str(spec.get("tab", "")):
		return false
	if str(template_def.get("fact_type", "")) != str(spec.get("fact_type", "")):
		return false
	var spec_anchor: String = str(spec.get("anchor", ""))
	if spec_anchor != "" and str(template_def.get("anchor", "")) != spec_anchor:
		return false
	return true

static func _apply_conflict_seeds(atoms: Array[Dictionary], skeleton: Dictionary) -> void:
	for seedv in skeleton.get("conflict_seeds", []) as Array:
		if not (seedv is Dictionary):
			continue
		var seed: Dictionary = seedv as Dictionary
		var group: String = str(seed.get("group", ""))
		var left: String = str(seed.get("left", ""))
		var right: String = str(seed.get("right", ""))
		if group == "" or left == "" or right == "":
			continue
		var left_idx: int = -1
		var right_idx: int = -1
		for i in range(atoms.size()):
			var atom: Dictionary = atoms[i]
			if str(atom.get("fact_type", "")) == left and left_idx < 0:
				left_idx = i
			elif str(atom.get("fact_type", "")) == right and right_idx < 0:
				right_idx = i
		if left_idx < 0 or right_idx < 0:
			continue
		(atoms[left_idx] as Dictionary)["conflict_group"] = group
		(atoms[right_idx] as Dictionary)["conflict_group"] = group

static func _bucket_atoms_into_tabs(atoms: Array[Dictionary], run_seed_u64: int, suspect_index: int, reroll_index: int) -> Dictionary:
	var tabs: Dictionary = {}
	var tab_order: Array[String] = [
		CaseEngineTypes.TAB_ALIBI,
		CaseEngineTypes.TAB_TIMELINE,
		CaseEngineTypes.TAB_MOTIVE,
		CaseEngineTypes.TAB_CAPABILITY,
		CaseEngineTypes.TAB_PROFILE,
	]
	for tab in tab_order:
		tabs[tab] = {
			"tab": tab,
			"fact_pool_seed_u64": _case_engine_tab_pool_seed_value(run_seed_u64, suspect_index, reroll_index, tab),
			"facts": [],
		}
	for atom in atoms:
		var tab: String = str(atom.get("tab", ""))
		if not tabs.has(tab):
			tabs[tab] = {
				"tab": tab,
				"fact_pool_seed_u64": _case_engine_tab_pool_seed_value(run_seed_u64, suspect_index, reroll_index, tab),
				"facts": [],
			}
		var facts: Array = (tabs[tab] as Dictionary).get("facts", []) as Array
		facts.append(atom)
		(tabs[tab] as Dictionary)["facts"] = facts
	return tabs

static func _apply_reliability_transform(rng: RandomNumberGenerator, reliability: String) -> String:
	if reliability != CaseEngineTypes.RELIABILITY_SOLID and rng.randf() < 0.2:
		return CaseEngineTypes.RELIABILITY_CORRUPTED
	return reliability

static func _repair_conflict_groups(
	atoms: Array,
	skeleton: Dictionary,
	run_seed_u64: int,
	suspect_index: int,
	reroll_index: int
) -> Dictionary:
	var by_group: Dictionary = {}
	for atom_v in atoms:
		if not (atom_v is Dictionary):
			continue
		var atom := atom_v as Dictionary
		var g := str(atom.get("conflict_group", ""))
		if g == "":
			continue
		if not by_group.has(g):
			by_group[g] = []
		(by_group[g] as Array).append(atom)

	var audit: Dictionary = {
		"groups": {},
		"repaired_groups": [],
		"failed_groups": [],
		"salvaged_missing_conflict_group_count": 0,
		"salvaged_unresolvable_conflict_group_count": 0,
	}

	var seed_map := _conflict_seed_map(skeleton)
	var req_anchor_map := _required_anchor_by_fact_type(skeleton)
	for group_id in _sorted_dictionary_keys(seed_map):
		if by_group.has(group_id):
			continue
		var seed_def: Dictionary = seed_map.get(group_id, {}) as Dictionary
		if _materialize_missing_conflict_group(atoms, by_group, str(group_id), seed_def):
			audit["salvaged_missing_conflict_group_count"] = int(audit.get("salvaged_missing_conflict_group_count", 0)) + 1

	var all_group_ids: Array[String] = []
	for group_id in by_group.keys():
		_append_unique_string(all_group_ids, str(group_id))
	for group_id in seed_map.keys():
		_append_unique_string(all_group_ids, str(group_id))
	all_group_ids.sort()

	for group_id in all_group_ids:
		var members: Array = by_group.get(group_id, []) as Array
		var seed_def: Dictionary = seed_map.get(str(group_id), {}) as Dictionary
		var prefer_anchor := str(seed_def.get("prefer_anchor", ""))
		var prefer_fact_type := str(seed_def.get("prefer_fact_type", ""))
		if members.is_empty():
			(audit["failed_groups"] as Array).append(str(group_id))
			continue

		var has_solid := false
		for m_v in members:
			var m := m_v as Dictionary
			if str(m.get("reliability", "")) == "SOLID":
				has_solid = true
				break

		var repaired := false
		var breaker_id := ""
		if has_solid:
			var solid_idx: int = _pick_existing_solid_breaker_index(
				members,
				prefer_anchor,
				prefer_fact_type,
				run_seed_u64,
				suspect_index,
				reroll_index,
				str(group_id)
			)
			if solid_idx >= 0 and solid_idx < members.size():
				breaker_id = str(((members[solid_idx] as Dictionary).get("fact_id", "")))
				repaired = breaker_id != ""
				if repaired:
					audit["salvaged_unresolvable_conflict_group_count"] = int(audit.get("salvaged_unresolvable_conflict_group_count", 0)) + 1
			else:
				(audit["failed_groups"] as Array).append(str(group_id))
		else:
			var pick_idx := _pick_conflict_breaker_index(
				members,
				prefer_anchor,
				prefer_fact_type,
				req_anchor_map,
				run_seed_u64,
				suspect_index,
				reroll_index,
				str(group_id)
			)
			if pick_idx >= 0 and pick_idx < members.size():
				var chosen := (members[pick_idx] as Dictionary).duplicate(true)
				chosen["reliability"] = "SOLID"

				var ftype := str(chosen.get("fact_type", ""))
				var required_anchor := str(req_anchor_map.get(ftype, ""))
				if required_anchor != "":
					chosen["anchor"] = required_anchor

				breaker_id = str(chosen.get("fact_id", ""))
				members[pick_idx] = chosen
				repaired = true
				audit["salvaged_unresolvable_conflict_group_count"] = int(audit.get("salvaged_unresolvable_conflict_group_count", 0)) + 1
			else:
				(audit["failed_groups"] as Array).append(str(group_id))

		if repaired:
			(audit["repaired_groups"] as Array).append(str(group_id))

		var group_rows: Array = []
		for m_v in members:
			var m := m_v as Dictionary
			group_rows.append({
				"fact_id": str(m.get("fact_id", "")),
				"fact_type": str(m.get("fact_type", "")),
				"reliability": str(m.get("reliability", "")),
				"anchor": str(m.get("anchor", "")),
			})

		(audit["groups"] as Dictionary)[str(group_id)] = {
			"prefer_anchor": prefer_anchor,
			"prefer_fact_type": prefer_fact_type,
			"breaker_id": breaker_id,
			"repaired": repaired,
			"members": group_rows,
		}

		var member_by_id: Dictionary = {}
		for m_v in members:
			var m := m_v as Dictionary
			member_by_id[str(m.get("fact_id", ""))] = m

		for i in range(atoms.size()):
			if atoms[i] is Dictionary:
				var a := atoms[i] as Dictionary
				var fid := str(a.get("fact_id", ""))
				if member_by_id.has(fid):
					atoms[i] = member_by_id[fid]

	return {"atoms": atoms, "audit": audit}

static func _conflict_seed_map(skeleton: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var seeds: Array = skeleton.get("conflict_seeds", []) as Array
	for s_v in seeds:
		if s_v is Dictionary:
			var s := s_v as Dictionary
			out[str(s.get("group", ""))] = s
	return out

static func _required_anchor_by_fact_type(skeleton: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var req: Array = skeleton.get("required_atoms", []) as Array
	for r_v in req:
		if r_v is Dictionary:
			var r := r_v as Dictionary
			var ft := str(r.get("fact_type", ""))
			var an := str(r.get("anchor", ""))
			if ft != "" and an != "":
				out[ft] = an
	return out

static func _pick_conflict_breaker_index(
	members: Array,
	prefer_anchor: String,
	prefer_fact_type: String,
	req_anchor_map: Dictionary,
	run_seed_u64: int,
	suspect_index: int,
	reroll_index: int,
	group_id: String
) -> int:
	if members.is_empty():
		return -1

	var best_idx := -1
	var best_score := -999999
	var tie_seed := SeedUtil.derive_seed(run_seed_u64, "conflict_breaker:%s" % group_id, suspect_index * 1000 + reroll_index)
	var rng := SeedUtil.make_rng(tie_seed)

	for i in range(members.size()):
		if not (members[i] is Dictionary):
			continue
		var m := members[i] as Dictionary
		var score := 0
		var rel := str(m.get("reliability", ""))
		var anchor := str(m.get("anchor", ""))
		var fact_type := str(m.get("fact_type", ""))

		if rel == "SOLID":
			score += 100
		if prefer_anchor != "" and anchor == prefer_anchor:
			score += 50
		if prefer_fact_type != "" and fact_type == prefer_fact_type:
			score += 40
		if anchor != "":
			score += 25
		if req_anchor_map.has(fact_type):
			score += 20

		score += rng.randi_range(0, 3)

		if score > best_score:
			best_score = score
			best_idx = i

	return best_idx

static func _pick_existing_solid_breaker_index(
	members: Array,
	prefer_anchor: String,
	prefer_fact_type: String,
	run_seed_u64: int,
	suspect_index: int,
	reroll_index: int,
	group_id: String
) -> int:
	var solid_members: Array = []
	for member_v in members:
		if member_v is Dictionary and str((member_v as Dictionary).get("reliability", "")) == "SOLID":
			solid_members.append(member_v)
	if solid_members.is_empty():
		return -1
	var local_idx: int = _pick_conflict_breaker_index(
		solid_members,
		prefer_anchor,
		prefer_fact_type,
		{},
		run_seed_u64,
		suspect_index,
		reroll_index,
		"%s:solid" % group_id
	)
	if local_idx < 0 or local_idx >= solid_members.size():
		return -1
	var picked_id: String = str((solid_members[local_idx] as Dictionary).get("fact_id", ""))
	for i in range(members.size()):
		if members[i] is Dictionary and str((members[i] as Dictionary).get("fact_id", "")) == picked_id:
			return i
	return -1

static func _materialize_missing_conflict_group(atoms: Array, by_group: Dictionary, group_id: String, seed_def: Dictionary) -> bool:
	var left_type: String = str(seed_def.get("left", ""))
	var right_type: String = str(seed_def.get("right", ""))
	if group_id == "" or left_type == "" or right_type == "":
		return false
	var left_idx: int = _pick_missing_conflict_member_index(atoms, left_type, -1)
	var right_idx: int = _pick_missing_conflict_member_index(atoms, right_type, left_idx)
	if left_idx < 0 or right_idx < 0:
		return false
	var left_atom: Dictionary = (atoms[left_idx] as Dictionary).duplicate(true)
	var right_atom: Dictionary = (atoms[right_idx] as Dictionary).duplicate(true)
	left_atom["conflict_group"] = group_id
	right_atom["conflict_group"] = group_id
	atoms[left_idx] = left_atom
	atoms[right_idx] = right_atom
	by_group[group_id] = [left_atom, right_atom]
	return true

static func _pick_missing_conflict_member_index(atoms: Array, fact_type: String, exclude_idx: int) -> int:
	for i in range(atoms.size()):
		if i == exclude_idx or not (atoms[i] is Dictionary):
			continue
		var atom: Dictionary = atoms[i] as Dictionary
		if str(atom.get("fact_type", "")) != fact_type:
			continue
		if str(atom.get("conflict_group", "")) == "":
			return i
	for i in range(atoms.size()):
		if i == exclude_idx or not (atoms[i] is Dictionary):
			continue
		var atom: Dictionary = atoms[i] as Dictionary
		if str(atom.get("fact_type", "")) == fact_type:
			return i
	return -1

static func _salvage_anchor_only_corrupted(
	atoms: Array,
	skeleton: Dictionary,
	run_seed_u64: int,
	suspect_index: int,
	reroll_index: int
) -> Dictionary:
	var anchor_to_indices: Dictionary = {}
	var required_fact_types: Dictionary = {}
	for required_v in skeleton.get("required_atoms", []) as Array:
		if required_v is Dictionary:
			var required_row: Dictionary = required_v as Dictionary
			var required_anchor: String = str(required_row.get("anchor", ""))
			var required_fact_type: String = str(required_row.get("fact_type", ""))
			if required_anchor != "" and required_fact_type != "":
				if not required_fact_types.has(required_anchor):
					required_fact_types[required_anchor] = []
				(required_fact_types[required_anchor] as Array).append(required_fact_type)
	for i in range(atoms.size()):
		if not (atoms[i] is Dictionary):
			continue
		var atom: Dictionary = atoms[i] as Dictionary
		var anchor_name: String = str(atom.get("anchor", ""))
		if anchor_name == "":
			continue
		if not anchor_to_indices.has(anchor_name):
			anchor_to_indices[anchor_name] = []
		(anchor_to_indices[anchor_name] as Array).append(i)
	var salvaged_anchor_names: Array[String] = []
	var sorted_anchor_names: Array[String] = _sorted_dictionary_keys(anchor_to_indices)
	for anchor_name in sorted_anchor_names:
		var member_indices: Array = anchor_to_indices.get(anchor_name, []) as Array
		var has_solid: bool = false
		for idx_v in member_indices:
			var atom_idx: int = int(idx_v)
			if atoms[atom_idx] is Dictionary and str((atoms[atom_idx] as Dictionary).get("reliability", "")) == "SOLID":
				has_solid = true
				break
		if has_solid:
			continue
		var pick_idx: int = _pick_anchor_salvage_index(
			atoms,
			member_indices,
			required_fact_types.get(anchor_name, []) as Array,
			run_seed_u64,
			suspect_index,
			reroll_index,
			anchor_name
		)
		if pick_idx < 0 or not (atoms[pick_idx] is Dictionary):
			continue
		var promoted: Dictionary = (atoms[pick_idx] as Dictionary).duplicate(true)
		promoted["reliability"] = "SOLID"
		atoms[pick_idx] = promoted
		salvaged_anchor_names.append(anchor_name)
	return {
		"atoms": atoms,
		"salvaged_anchor_only_corrupted_count": salvaged_anchor_names.size(),
		"salvaged_anchor_names": salvaged_anchor_names,
	}

static func _pick_anchor_salvage_index(
	atoms: Array,
	member_indices: Array,
	required_fact_types: Array,
	run_seed_u64: int,
	suspect_index: int,
	reroll_index: int,
	anchor_name: String
) -> int:
	var best_idx: int = -1
	var best_score: int = -999999
	var tie_seed := SeedUtil.derive_seed(run_seed_u64, "anchor_salvage:%s" % anchor_name, suspect_index * 1000 + reroll_index)
	var rng := SeedUtil.make_rng(tie_seed)
	for idx_v in member_indices:
		var atom_idx: int = int(idx_v)
		if atom_idx < 0 or atom_idx >= atoms.size() or not (atoms[atom_idx] is Dictionary):
			continue
		var atom: Dictionary = atoms[atom_idx] as Dictionary
		var score: int = 0
		var reliability: String = str(atom.get("reliability", ""))
		var fact_type: String = str(atom.get("fact_type", ""))
		if required_fact_types.has(fact_type):
			score += 60
		if reliability == "CORRUPTED":
			score += 30
		elif reliability == "QUESTIONABLE" or reliability == "SHAKY":
			score += 20
		if str(atom.get("conflict_group", "")) != "":
			score += 10
		score += rng.randi_range(0, 3)
		if score > best_score:
			best_score = score
			best_idx = atom_idx
	return best_idx

static func _sorted_dictionary_keys(dict: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key in dict.keys():
		out.append(str(key))
	out.sort()
	return out

static func _case_engine_tab_pool_seed_value(run_seed_u64: int, suspect_index: int, reroll_index: int, tab: String) -> int:
	return SeedUtil.derive_seed(
		run_seed_u64,
		"case_engine_tab_pool:%s" % tab,
		suspect_index * 1000 + reroll_index
	)

static func _case_engine_tab_pool_seed_trace(run_seed_u64: int, suspect_index: int, reroll_index: int) -> Dictionary:
	var out: Dictionary = {}
	for tab in [
		CaseEngineTypes.TAB_ALIBI,
		CaseEngineTypes.TAB_TIMELINE,
		CaseEngineTypes.TAB_MOTIVE,
		CaseEngineTypes.TAB_CAPABILITY,
		CaseEngineTypes.TAB_PROFILE,
	]:
		out[tab] = SeedUtil.hex16(_case_engine_tab_pool_seed_value(run_seed_u64, suspect_index, reroll_index, str(tab)))
	return out

static func _required_skeleton_fact_types(skeleton: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for atomv in skeleton.get("required_atoms", []) as Array:
		if not (atomv is Dictionary):
			continue
		var fact_type: String = str((atomv as Dictionary).get("fact_type", ""))
		if fact_type != "" and not out.has(fact_type):
			out.append(fact_type)
	return out

static func _required_skeleton_anchors(skeleton: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for atomv in skeleton.get("required_atoms", []) as Array:
		if not (atomv is Dictionary):
			continue
		var anchor: String = str((atomv as Dictionary).get("anchor", ""))
		if anchor != "" and not out.has(anchor):
			out.append(anchor)
	return out

static func _build_conflict_groups(payload: Dictionary) -> Dictionary:
	var groups: Dictionary = {}
	var tabs: Dictionary = payload.get("tabs", {}) as Dictionary
	for tab in tabs.keys():
		var tabd: Dictionary = tabs[tab] as Dictionary
		var facts: Array = tabd.get("facts", []) as Array
		for f in facts:
			if not (f is Dictionary):
				continue
			var fd: Dictionary = f as Dictionary
			var grp: String = str(fd.get("conflict_group", ""))
			if grp == "":
				continue
			if not groups.has(grp):
				groups[grp] = []
			(groups[grp] as Array).append(str(fd.get("fact_id", "")))
	return groups

static func _render_template(tpl: String, slots: Dictionary) -> String:
	var out: String = tpl
	for k in slots.keys():
		out = out.replace("{" + str(k) + "}", str(slots.get(k)))
	return out


static func _prefer_nonempty(filtered: Array, fallback: Array) -> Array:
	return filtered if not filtered.is_empty() else fallback

static func _pool_with_trace(filtered: Array, fallback: Array, label: String, gen_trace: Array) -> Array:
	var out: Array = filtered if not filtered.is_empty() else fallback
	if filtered.is_empty():
		_trace_push(gen_trace, "PROFILE_FILTER_FALLBACK", {"label": label, "fallback_count": fallback.size()})
	return out

static func _build_truth_graph_v0(
	rng: RandomNumberGenerator,
	guilt_state: String,
	crime_family: String,
	crime_type: String,
	opportunity_pool: Array[String],
	motive_pool: Array[String],
	profile_bundle: Dictionary,
	selected_time_window: String,
	selected_time_anchor: String,
	selected_location: String,
	selected_alibi_place: String,
	selected_tool: String,
	relationship: String
) -> Dictionary:
	var opportunity_row: Dictionary = _weighted_pick_rows(_opportunity_rows(guilt_state, opportunity_pool), rng)
	var alibi_row: Dictionary = _weighted_pick_rows(_alibi_rows(guilt_state), rng)
	var motive_row: Dictionary = _weighted_pick_rows(_motive_rows(guilt_state, motive_pool), rng)
	var capability_section: Dictionary = _build_capability_semantics(profile_bundle, selected_tool, guilt_state, rng)
	var twist_tags: Array[String] = _twist_tags_for_truth(guilt_state, opportunity_row, alibi_row, motive_row, capability_section, rng)
	return {
		"schema_version": 1,
		"culpability": {
			"state": guilt_state,
			"cover_posture": _cover_posture_for_guilt(guilt_state, rng),
			"pressure_bias": _pressure_bias_for_guilt(guilt_state, rng),
		},
		"crime": {
			"family": crime_family,
			"type": crime_type,
			"method_class": _method_class_for_crime(crime_family, crime_type),
		},
		"timeline": {
			"window": selected_time_window,
			"anchor": selected_time_anchor,
			"location": selected_location,
		},
		"opportunity": {
			"id": str(opportunity_row.get("id", "")),
			"class": str(opportunity_row.get("class", "")),
			"tool": selected_tool,
		},
		"alibi": {
			"truth": str(alibi_row.get("truth", "partial")),
			"place": selected_alibi_place,
			"strength_band": str(alibi_row.get("strength_band", "thin")),
			"corroboration_mode": str(alibi_row.get("corroboration_mode", "mixed")),
		},
		"motive": {
			"id": str(motive_row.get("id", "")),
			"class": str(motive_row.get("class", "")),
			"intensity_band": str(motive_row.get("intensity_band", "")),
		},
		"capability": capability_section,
		"relationship": {
			"id": relationship,
			"contact_role": _relationship_contact_role(relationship),
			"contact_node_id": "",
			"contact_name": "",
		},
		"twist_tags": twist_tags,
	}

static func _pick_guilt_state(rng: RandomNumberGenerator) -> String:
	var rows: Array[Dictionary] = [
		{"id":"GUILTY", "weight":42},
		{"id":"INNOCENT", "weight":38},
		{"id":"FRAMED", "weight":12},
		{"id":"COMPLICIT", "weight":8},
	]
	return str(_weighted_pick_rows(rows, rng).get("id", "GUILTY"))

static func _weighted_pick_rows(rows: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	if rows.is_empty():
		return {}
	var total_weight: int = 0
	for row in rows:
		total_weight += maxi(1, int(row.get("weight", 1)))
	var roll: int = rng.randi_range(1, total_weight)
	var seen: int = 0
	for row in rows:
		seen += maxi(1, int(row.get("weight", 1)))
		if roll <= seen:
			return row.duplicate(true)
	return (rows[rows.size() - 1] as Dictionary).duplicate(true)

static func _method_class_for_crime(crime_family: String, crime_type: String) -> String:
	match crime_type:
		"invoice_manipulation":
			return "approval_abuse"
		"expense_recode":
			return "accounting_mask"
		"ledger_drift":
			return "records_diversion"
		"float_skimming":
			return "cash_diversion"
		"sensor_tamper":
			return "systems_tamper"
		"camera_gap":
			return "surveillance_blindspot"
	match crime_family:
		"fraud":
			return "paper_trail_manipulation"
		"embezzlement":
			return "value_diversion"
		"sabotage":
			return "operational_disruption"
		_:
			return "general_misconduct"

static func _cover_posture_for_guilt(guilt_state: String, rng: RandomNumberGenerator) -> String:
	var weight_map: Dictionary = {
		"GUILTY": {"routine_mask": 3, "deflection": 3, "containment": 4, "confused_compliance": 1},
		"INNOCENT": {"routine_mask": 4, "deflection": 2, "containment": 1, "confused_compliance": 3},
		"FRAMED": {"routine_mask": 2, "deflection": 2, "containment": 1, "confused_compliance": 4},
		"COMPLICIT": {"routine_mask": 2, "deflection": 4, "containment": 3, "confused_compliance": 1},
	}
	var row_weights: Dictionary = weight_map.get(guilt_state, weight_map["GUILTY"]) as Dictionary
	var rows: Array[Dictionary] = [
		{"id":"routine_mask", "weight": int(row_weights.get("routine_mask", 1))},
		{"id":"deflection", "weight": int(row_weights.get("deflection", 1))},
		{"id":"containment", "weight": int(row_weights.get("containment", 1))},
		{"id":"confused_compliance", "weight": int(row_weights.get("confused_compliance", 1))},
	]
	return str(_weighted_pick_rows(rows, rng).get("id", "routine_mask"))

static func _pressure_bias_for_guilt(guilt_state: String, rng: RandomNumberGenerator) -> String:
	var weight_map: Dictionary = {
		"GUILTY": {"exposure_fear": 4, "status_protection": 3, "external_scrutiny": 1, "family_drag": 2},
		"INNOCENT": {"exposure_fear": 1, "status_protection": 2, "external_scrutiny": 4, "family_drag": 3},
		"FRAMED": {"exposure_fear": 2, "status_protection": 1, "external_scrutiny": 4, "family_drag": 2},
		"COMPLICIT": {"exposure_fear": 3, "status_protection": 4, "external_scrutiny": 1, "family_drag": 2},
	}
	var row_weights: Dictionary = weight_map.get(guilt_state, weight_map["GUILTY"]) as Dictionary
	var rows: Array[Dictionary] = [
		{"id":"exposure_fear", "weight": int(row_weights.get("exposure_fear", 1))},
		{"id":"status_protection", "weight": int(row_weights.get("status_protection", 1))},
		{"id":"external_scrutiny", "weight": int(row_weights.get("external_scrutiny", 1))},
		{"id":"family_drag", "weight": int(row_weights.get("family_drag", 1))},
	]
	return str(_weighted_pick_rows(rows, rng).get("id", "status_protection"))

static func _opportunity_rows(guilt_state: String, opportunity_pool: Array[String]) -> Array[Dictionary]:
	var class_map: Dictionary = {
		"night_shift": "off_hours_access",
		"handoff_gap": "transition_gap",
		"badge_override": "credential_leverage",
		"service_window": "routine_cover",
	}
	var state_weights: Dictionary = {
		"GUILTY": {"night_shift": 3, "handoff_gap": 4, "badge_override": 4, "service_window": 2},
		"INNOCENT": {"night_shift": 2, "handoff_gap": 3, "badge_override": 1, "service_window": 4},
		"FRAMED": {"night_shift": 2, "handoff_gap": 2, "badge_override": 1, "service_window": 4},
		"COMPLICIT": {"night_shift": 3, "handoff_gap": 4, "badge_override": 3, "service_window": 2},
	}
	var weights: Dictionary = state_weights.get(guilt_state, state_weights["GUILTY"]) as Dictionary
	var rows: Array[Dictionary] = []
	for opportunity_id in opportunity_pool:
		var id: String = str(opportunity_id)
		rows.append({
			"id": id,
			"class": str(class_map.get(id, "routine_cover")),
			"weight": int(weights.get(id, 1)),
		})
	return rows

static func _alibi_rows(guilt_state: String) -> Array[Dictionary]:
	var rows_by_state: Dictionary = {
		"GUILTY": [
			{"truth":"verified","strength_band":"thin","corroboration_mode":"statement_only","weight":2},
			{"truth":"verified","strength_band":"moderate","corroboration_mode":"mixed","weight":1},
			{"truth":"partial","strength_band":"thin","corroboration_mode":"mixed","weight":4},
			{"truth":"partial","strength_band":"moderate","corroboration_mode":"witness","weight":2},
			{"truth":"unverified","strength_band":"fragile","corroboration_mode":"statement_only","weight":3},
			{"truth":"unverified","strength_band":"thin","corroboration_mode":"mixed","weight":1},
		],
		"INNOCENT": [
			{"truth":"verified","strength_band":"robust","corroboration_mode":"mixed","weight":3},
			{"truth":"verified","strength_band":"moderate","corroboration_mode":"witness","weight":3},
			{"truth":"verified","strength_band":"thin","corroboration_mode":"statement_only","weight":1},
			{"truth":"partial","strength_band":"moderate","corroboration_mode":"mixed","weight":2},
			{"truth":"partial","strength_band":"thin","corroboration_mode":"statement_only","weight":2},
			{"truth":"unverified","strength_band":"fragile","corroboration_mode":"statement_only","weight":1},
		],
		"FRAMED": [
			{"truth":"verified","strength_band":"robust","corroboration_mode":"mixed","weight":3},
			{"truth":"verified","strength_band":"moderate","corroboration_mode":"witness","weight":2},
			{"truth":"partial","strength_band":"moderate","corroboration_mode":"mixed","weight":3},
			{"truth":"partial","strength_band":"thin","corroboration_mode":"statement_only","weight":2},
			{"truth":"unverified","strength_band":"fragile","corroboration_mode":"statement_only","weight":1},
		],
		"COMPLICIT": [
			{"truth":"verified","strength_band":"thin","corroboration_mode":"statement_only","weight":1},
			{"truth":"verified","strength_band":"moderate","corroboration_mode":"mixed","weight":2},
			{"truth":"partial","strength_band":"thin","corroboration_mode":"mixed","weight":3},
			{"truth":"partial","strength_band":"moderate","corroboration_mode":"witness","weight":2},
			{"truth":"unverified","strength_band":"fragile","corroboration_mode":"statement_only","weight":2},
			{"truth":"unverified","strength_band":"thin","corroboration_mode":"mixed","weight":1},
		],
	}
	var source_rows: Array = (rows_by_state.get(guilt_state, rows_by_state["GUILTY"]) as Array).duplicate(true)
	var out: Array[Dictionary] = []
	for row_v in source_rows:
		if row_v is Dictionary:
			out.append((row_v as Dictionary).duplicate(true))
	return out

static func _motive_rows(guilt_state: String, motive_pool: Array[String]) -> Array[Dictionary]:
	var class_map: Dictionary = {
		"debt": "financial",
		"career_pressure": "status",
		"retaliation": "grievance",
		"coercion": "leverage",
	}
	var rows_by_state: Dictionary = {
		"GUILTY": {
			"debt": {"weight":4, "intensity_band":"acute"},
			"career_pressure": {"weight":3, "intensity_band":"elevated"},
			"retaliation": {"weight":2, "intensity_band":"focused"},
			"coercion": {"weight":3, "intensity_band":"acute"},
		},
		"INNOCENT": {
			"debt": {"weight":2, "intensity_band":"managed"},
			"career_pressure": {"weight":2, "intensity_band":"elevated"},
			"retaliation": {"weight":3, "intensity_band":"focused"},
			"coercion": {"weight":2, "intensity_band":"contained"},
		},
		"FRAMED": {
			"debt": {"weight":1, "intensity_band":"managed"},
			"career_pressure": {"weight":2, "intensity_band":"elevated"},
			"retaliation": {"weight":3, "intensity_band":"focused"},
			"coercion": {"weight":3, "intensity_band":"acute"},
		},
		"COMPLICIT": {
			"debt": {"weight":3, "intensity_band":"elevated"},
			"career_pressure": {"weight":3, "intensity_band":"acute"},
			"retaliation": {"weight":2, "intensity_band":"focused"},
			"coercion": {"weight":4, "intensity_band":"acute"},
		},
	}
	var source: Dictionary = rows_by_state.get(guilt_state, rows_by_state["GUILTY"]) as Dictionary
	var rows: Array[Dictionary] = []
	for motive_id in motive_pool:
		var id: String = str(motive_id)
		var row_meta: Dictionary = source.get(id, {"weight":1, "intensity_band":"ambient"}) as Dictionary
		rows.append({
			"id": id,
			"class": str(class_map.get(id, "general_pressure")),
			"intensity_band": str(row_meta.get("intensity_band", "ambient")),
			"weight": int(row_meta.get("weight", 1)),
		})
	return rows

static func _build_capability_semantics(profile_bundle: Dictionary, selected_tool: String, guilt_state: String, rng: RandomNumberGenerator) -> Dictionary:
	var access_tags: Array = (profile_bundle.get("access_tags", []) as Array).duplicate()
	var location_tags: Array = (profile_bundle.get("location_tags", []) as Array).duplicate()
	return {
		"tool": selected_tool,
		"access_tags": access_tags,
		"location_tags": location_tags,
		"skill_tags": _skill_tags_from_profile(profile_bundle, selected_tool, location_tags),
		"exposure_band": _exposure_band_for_truth(guilt_state, access_tags, location_tags, selected_tool, rng),
	}

static func _skill_tags_from_profile(profile_bundle: Dictionary, selected_tool: String, location_tags: Array) -> Array[String]:
	var out: Array[String] = []
	var role_tags: Array = profile_bundle.get("role_tags", []) as Array
	var tool_tags: Array = profile_bundle.get("tool_tags", []) as Array
	for tag_name in role_tags:
		match str(tag_name):
			"finance":
				_append_unique_string(out, "audit_literacy")
			"systems":
				_append_unique_string(out, "systems_familiarity")
			"dispatch":
				_append_unique_string(out, "coordination_routine")
			"facilities":
				_append_unique_string(out, "site_access")
			"operations":
				_append_unique_string(out, "process_routine")
	for tool_tag in tool_tags:
		match str(tool_tag):
			"ledger_console", "invoice_terminal":
				_append_unique_string(out, "records_handling")
			"badge_terminal", "camera_console", "dispatch_console":
				_append_unique_string(out, "console_operations")
			"maintenance_tablet", "field_kit", "service_scanner":
				_append_unique_string(out, "field_operations")
	match selected_tool:
		"ledger_console", "invoice_terminal", "records_tablet":
			_append_unique_string(out, "records_handling")
		"badge_terminal", "camera_console":
			_append_unique_string(out, "credential_navigation")
		"maintenance_tablet", "field_kit":
			_append_unique_string(out, "equipment_handling")
	if location_tags.has("archives") or location_tags.has("records_room"):
		_append_unique_string(out, "records_navigation")
	if location_tags.has("service_corridor") or location_tags.has("maintenance_bay"):
		_append_unique_string(out, "back_area_routine")
	return out

static func _exposure_band_for_truth(guilt_state: String, access_tags: Array, location_tags: Array, selected_tool: String, rng: RandomNumberGenerator) -> String:
	var rows: Array[Dictionary] = [
		{"id":"LOW_VISIBILITY", "weight": 3},
		{"id":"ROUTINE_EXPOSURE", "weight": 3},
		{"id":"AUDITABLE_ACCESS", "weight": 2},
		{"id":"HIGHLY_CONSTRAINED", "weight": 1},
	]
	var weight_map: Dictionary = {
		"GUILTY": {"LOW_VISIBILITY": 2, "ROUTINE_EXPOSURE": 2, "AUDITABLE_ACCESS": 4, "HIGHLY_CONSTRAINED": 2},
		"INNOCENT": {"LOW_VISIBILITY": 2, "ROUTINE_EXPOSURE": 4, "AUDITABLE_ACCESS": 2, "HIGHLY_CONSTRAINED": 2},
		"FRAMED": {"LOW_VISIBILITY": 3, "ROUTINE_EXPOSURE": 3, "AUDITABLE_ACCESS": 2, "HIGHLY_CONSTRAINED": 2},
		"COMPLICIT": {"LOW_VISIBILITY": 1, "ROUTINE_EXPOSURE": 3, "AUDITABLE_ACCESS": 4, "HIGHLY_CONSTRAINED": 2},
	}
	var state_weights: Dictionary = weight_map.get(guilt_state, weight_map["GUILTY"]) as Dictionary
	for row_v in rows:
		var row: Dictionary = row_v as Dictionary
		var row_id: String = str(row.get("id", ""))
		row["weight"] = int(state_weights.get(row_id, 1))
		if row_id == "AUDITABLE_ACCESS" and (access_tags.has("systems_access") or selected_tool == "ledger_console"):
			row["weight"] = int(row.get("weight", 1)) + 1
		if row_id == "LOW_VISIBILITY" and (location_tags.has("service_corridor") or location_tags.has("storage_wing")):
			row["weight"] = int(row.get("weight", 1)) + 1
		if row_id == "HIGHLY_CONSTRAINED" and access_tags.has("after_hours_access"):
			row["weight"] = int(row.get("weight", 1)) + 1
	return str(_weighted_pick_rows(rows, rng).get("id", "ROUTINE_EXPOSURE"))

static func _twist_tags_for_truth(
	guilt_state: String,
	opportunity_row: Dictionary,
	alibi_row: Dictionary,
	motive_row: Dictionary,
	capability_section: Dictionary,
	rng: RandomNumberGenerator
) -> Array[String]:
	var eligible_rows: Array[Dictionary] = _twist_rows_for_state(guilt_state, opportunity_row, alibi_row, motive_row, capability_section)
	var count_rows: Array[Dictionary] = [
		{"id":"0", "weight": 10},
		{"id":"1", "weight": 4},
		{"id":"2", "weight": 1},
	]
	var target_count: int = int(str(_weighted_pick_rows(count_rows, rng).get("id", "0")))
	var tags: Array[String] = []
	var remaining_rows: Array[Dictionary] = eligible_rows.duplicate(true)
	while target_count > 0 and not remaining_rows.is_empty():
		var picked: Dictionary = _weighted_pick_rows(remaining_rows, rng)
		var tag_id: String = str(picked.get("id", ""))
		if tag_id != "" and not tags.has(tag_id):
			tags.append(tag_id)
		var next_rows: Array[Dictionary] = []
		for row_v in remaining_rows:
			var row: Dictionary = row_v as Dictionary
			if str(row.get("id", "")) != tag_id:
				next_rows.append(row)
		remaining_rows = next_rows
		target_count -= 1
	return tags

static func _twist_rows_for_state(
	guilt_state: String,
	opportunity_row: Dictionary,
	alibi_row: Dictionary,
	motive_row: Dictionary,
	capability_section: Dictionary
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var alibi_truth: String = str(alibi_row.get("truth", ""))
	var alibi_strength: String = str(alibi_row.get("strength_band", ""))
	var motive_id: String = str(motive_row.get("id", ""))
	var exposure_band: String = str(capability_section.get("exposure_band", ""))
	var opportunity_id: String = str(opportunity_row.get("id", ""))
	match guilt_state:
		"GUILTY":
			rows.append({"id":"ADMIN_ERROR","weight":2})
			rows.append({"id":"SHARED_ACCESS","weight":3 if exposure_band == "AUDITABLE_ACCESS" else 2})
			rows.append({"id":"EVIDENCE_CHAIN_GAP","weight":2 if alibi_truth == "partial" else 1})
		"INNOCENT":
			rows.append({"id":"ADMIN_ERROR","weight":3})
			rows.append({"id":"MISFILED_TIME","weight":3 if alibi_strength == "thin" else 2})
			rows.append({"id":"EVIDENCE_CHAIN_GAP","weight":2})
		"FRAMED":
			rows.append({"id":"MISFILED_TIME","weight":3})
			rows.append({"id":"THIRD_PARTY_PRESSURE","weight":3 if motive_id == "coercion" else 2})
			rows.append({"id":"COERCED_CONTACT","weight":2 if opportunity_id == "handoff_gap" else 1})
			rows.append({"id":"EVIDENCE_CHAIN_GAP","weight":2})
		"COMPLICIT":
			rows.append({"id":"SHARED_ACCESS","weight":3})
			rows.append({"id":"THIRD_PARTY_PRESSURE","weight":2 if motive_id == "coercion" else 1})
			rows.append({"id":"COERCED_CONTACT","weight":2})
			rows.append({"id":"ADMIN_ERROR","weight":1})
	return rows

static func _append_unique_string(target: Array[String], value: String) -> void:
	if value != "" and not target.has(value):
		target.append(value)

static func _relationship_contact_node_id(graph: Dictionary, contact_role: String, contact_name: String) -> String:
	var nodes: Dictionary = graph.get("nodes", {}) as Dictionary
	var node_ids: Array = nodes.keys()
	node_ids.sort()
	for node_id_v in node_ids:
		var node_id: String = str(node_id_v)
		var node: Dictionary = nodes.get(node_id, {}) as Dictionary
		if str(node.get("role", "")) == contact_role and str(node.get("name_text", "")) == contact_name:
			return node_id
	if contact_name != "":
		for node_id_v in node_ids:
			var fallback_node_id: String = str(node_id_v)
			var fallback_node: Dictionary = nodes.get(fallback_node_id, {}) as Dictionary
			if str(fallback_node.get("name_text", "")) == contact_name:
				return fallback_node_id
	return ""

static func _prefer_filtered(label: String, filtered: Array, fallback: Array, audit: Dictionary) -> Array:
	if not filtered.is_empty():
		(audit["filters"] as Dictionary)[label] = {
			"filtered_count": filtered.size(),
			"fallback_count": fallback.size(),
			"used_fallback": false,
		}
		return filtered

	(audit["filters"] as Dictionary)[label] = {
		"filtered_count": 0,
		"fallback_count": fallback.size(),
		"used_fallback": true,
	}
	(audit["fallbacks_used"] as Array).append(label)
	return fallback

static func _pick(values: Array[String], rng: RandomNumberGenerator) -> String:
	if values.is_empty():
		return ""
	return values[rng.randi_range(0, values.size() - 1)]

static func _relationship_contact_role(rel: String) -> String:
	return CaseEngineEntityGraph.contact_role_for_relationship(rel)

static func _time_anchors_for_window(time_window: String) -> Array[String]:
	match time_window:
		"shift_start":
			return ["08:05", "08:20", "09:00"]
		"midday":
			return ["11:40", "12:10", "13:05"]
		"handoff_gap":
			return ["16:50", "17:15", "17:40"]
		"late_afternoon":
			return ["15:20", "16:10", "17:05"]
		"evening_window":
			return ["18:30", "19:20", "20:10"]
		"night_shift":
			return ["22:10", "23:40", "00:15"]
		"cleanup_window":
			return ["00:45", "01:05", "01:35"]
		"graveyard_window":
			return ["02:10", "02:35", "03:05"]
		"audit_window":
			return ["14:10", "15:25", "16:15"]
		"service_window":
			return ["09:30", "13:20", "22:30"]
		_:
			return ["22:10", "23:40", "00:15", "01:05"]

static func _title_case(v: String) -> String:
	if v == "":
		return "Case"
	var p: PackedStringArray = v.split("_", false)
	for i in range(p.size()):
		p[i] = p[i].capitalize()
	return " ".join(p)
