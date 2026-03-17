@tool
extends RefCounted
class_name ValidatorSuite

const LEVEL_PASS := "PASS"
const LEVEL_WARN := "WARN"
const LEVEL_REJECT := "REJECT"

static func validate_case(case_payload: Dictionary) -> Dictionary:
	var items: Array[Dictionary] = []

	if not bool(case_payload.get("ok", false)):
		items.append(_reject("GEN_ERROR", str(case_payload.get("error", "Generation failed."))))
		var fail_stage: String = str(case_payload.get("fail_stage", ""))
		if fail_stage != "":
			items.append(_warn("GEN_FAIL_STAGE", fail_stage))
		var ed: Dictionary = case_payload.get("error_details", {}) as Dictionary
		if not ed.is_empty():
			var label: String = str(ed.get("label", ""))
			var req_ft: String = str(ed.get("required_fact_type", ""))
			var pv: Array = ed.get("profile_validation_codes", []) as Array
			if label != "":
				items.append(_warn("GEN_ERROR_DETAIL", label))
			elif req_ft != "":
				items.append(_warn("GEN_ERROR_DETAIL", req_ft))
			elif not pv.is_empty():
				items.append(_warn("GEN_ERROR_DETAIL", str(pv[0])))
		return _finalize(items)

	var suspect: Dictionary = case_payload.get("suspect", {}) as Dictionary
	if suspect.is_empty():
		items.append(_reject("NO_SUSPECT", "Missing suspect dictionary."))
		return _finalize(items)

	_require_key(items, suspect, "id", "Missing suspect.id")
	_require_key(items, suspect, "charge_sheet", "Missing suspect.charge_sheet")
	_require_key(items, suspect, "tabs", "Missing suspect.tabs")
	var suspect_contract_errors: Array[String] = CaseEngineContracts.validate_suspect_contract(suspect)
	if not suspect_contract_errors.is_empty():
		items.append(_reject("BAD_SUSPECT_CONTRACT", str(suspect_contract_errors[0])))
		return _finalize(items)

	_scan_no_guilt_tells(items, suspect)

	var truth_bundle: Dictionary = case_payload.get("truth_bundle", {}) as Dictionary
	var suspect_truth_bundle: Dictionary = suspect.get("truth_bundle", {}) as Dictionary
	if not truth_bundle.is_empty() and not suspect_truth_bundle.is_empty() and truth_bundle != suspect_truth_bundle:
		items.append(_reject("TRUTH_BUNDLE_MISMATCH", "Wrapper truth bundle diverged from suspect.truth_bundle."))
		return _finalize(items)
	if truth_bundle.is_empty():
		truth_bundle = suspect_truth_bundle
	if truth_bundle.is_empty():
		items.append(_reject("NO_TRUTH_BUNDLE", "Missing truth bundle (truth-first violated)."))
		return _finalize(items)

	var truth_graph_errors: Array[String] = CaseEngineContracts.validate_truth_graph(truth_bundle)
	if not truth_graph_errors.is_empty():
		items.append(_reject("BAD_TRUTH_GRAPH", "Truth graph contract failed: %s" % str(truth_graph_errors[0])))
		return _finalize(items)

	_validate_truth_refs(items, suspect, truth_bundle)
	var authoring_errors: Array[String] = validate_authoring_contracts()
	if not authoring_errors.is_empty():
		items.append(_reject(str(authoring_errors[0].split(":", false)[0]), str(authoring_errors[0])))
		return _finalize(items)
	_validate_skeleton_coverage(items, suspect, truth_bundle)
	_validate_anchors(items, case_payload)
	_validate_conflict_groups(items, suspect, truth_bundle, case_payload.get("conflict_groups", {}) as Dictionary)
	_validate_profile_plausibility(items, truth_bundle)
	_validate_player_surface_contract(items, case_payload)

	return _finalize(items)

static func _scan_no_guilt_tells(items: Array[Dictionary], suspect: Dictionary) -> void:
	var banned: Array[String] = [
		"guilty", "innocent", "framed", "complicit",
		"did it", "didn't do it", "did not do it",
		"we know you did", "confess", "killer", "murderer",
		"culprit", "perp", "case closed"
	]

	var fields: Array[String] = []
	var charge: Dictionary = suspect.get("charge_sheet", {}) as Dictionary
	fields.append(str(charge.get("title", "")))
	fields.append(str(charge.get("brief", "")))

	var tabs: Dictionary = suspect.get("tabs", {}) as Dictionary
	for tab_key in tabs.keys():
		var tabd: Dictionary = tabs[tab_key] as Dictionary
		var facts: Array = tabd.get("facts", []) as Array
		for f in facts:
			if f is Dictionary:
				fields.append(str((f as Dictionary).get("text", "")))

	for t in fields:
		var low: String = t.to_lower()
		for b in banned:
			if low.find(b) >= 0:
				items.append(_reject("GUILT_TELL", "Banned phrase detected in surfaced text: '%s'" % b))
				return

static func _validate_truth_refs(items: Array[Dictionary], suspect: Dictionary, truth_bundle: Dictionary) -> void:
	var tabs: Dictionary = suspect.get("tabs", {}) as Dictionary
	for tab_key in tabs.keys():
		var tabd: Dictionary = tabs[tab_key] as Dictionary
		var facts: Array = tabd.get("facts", []) as Array
		for f in facts:
			if not (f is Dictionary):
				continue
			var fd: Dictionary = f as Dictionary
			var refs: Array = fd.get("truth_refs", []) as Array
			for r in refs:
				var ref: String = str(r)
				if ref == "":
					continue
				if not _has_path(truth_bundle, ref):
					items.append(_reject("BAD_TRUTH_REF", "Missing truth ref: %s" % ref))
					return

static func _validate_anchors(items: Array[Dictionary], case_payload: Dictionary) -> void:
	var anchor_errors: Array[String] = CaseEngineContracts.validate_anchor_guarantees(case_payload)
	for code in anchor_errors:
		var anchor_code: String = str(code)
		if anchor_code == "MISSING_TIMELINE_ANCHOR":
			items.append(_reject(anchor_code, "No SOLID timeline anchor."))
			return
		if anchor_code == "MISSING_ALIBI_OR_CAPABILITY_ANCHOR":
			items.append(_reject(anchor_code, "Need SOLID alibi or capability anchor."))
			return
		if anchor_code == "MISSING_MOTIVE_OR_RELATIONSHIP_ANCHOR":
			items.append(_reject(anchor_code, "Need SOLID motive or relationship anchor."))
			return
		if anchor_code.begins_with("ANCHOR_ONLY_CORRUPTED:"):
			items.append(_reject("ANCHOR_ONLY_CORRUPTED", "Anchor category present only as corrupted: %s" % anchor_code.get_slice(":", 1)))
			return

static func _validate_conflict_groups(items: Array[Dictionary], suspect: Dictionary, truth_bundle: Dictionary, conflict_groups: Dictionary) -> void:
	var conflict_audit: Dictionary = truth_bundle.get("conflict_audit", {}) as Dictionary
	var failed_groups: Array = conflict_audit.get("failed_groups", []) as Array
	if not failed_groups.is_empty():
		var failed_labels: PackedStringArray = []
		for gid in failed_groups:
			failed_labels.append(str(gid))
		items.append(_reject("UNRESOLVABLE_CONFLICT_GROUP", "Conflict group has no SOLID breaker: %s" % ",".join(failed_labels)))
		return

	var skeleton_id: String = str(truth_bundle.get("variant_skeleton_id", ""))
	if skeleton_id != "":
		var groups_audit: Dictionary = conflict_audit.get("groups", {}) as Dictionary
		var skeleton: Dictionary = _skeleton_for_id(skeleton_id)
		if not skeleton.is_empty():
			for seed_v in skeleton.get("conflict_seeds", []) as Array:
				if not (seed_v is Dictionary):
					continue
				var seed: Dictionary = seed_v as Dictionary
				var group_id: String = str(seed.get("group", ""))
				if group_id != "" and not groups_audit.has(group_id):
					items.append(_reject("MISSING_CONFLICT_GROUP", "Missing conflict group in audit: %s" % group_id))
					return
				if group_id != "":
					var group_row: Dictionary = groups_audit.get(group_id, {}) as Dictionary
					var members: Array = group_row.get("members", []) as Array
					var breaker_id: String = str(group_row.get("breaker_id", ""))
					var has_solid: bool = false
					for member_v in members:
						if member_v is Dictionary and str((member_v as Dictionary).get("reliability", "")) == CaseEngineTypes.RELIABILITY_SOLID:
							has_solid = true
							break
					if not has_solid or breaker_id == "":
						items.append(_reject("UNRESOLVABLE_CONFLICT_GROUP", "Conflict group lacks a valid breaker: %s" % group_id))
						return

	if conflict_groups.is_empty():
		return

	var rel_by_id: Dictionary = {}
	var tabs: Dictionary = suspect.get("tabs", {}) as Dictionary
	for tab_key in tabs.keys():
		var tabd: Dictionary = tabs[tab_key] as Dictionary
		var facts: Array = tabd.get("facts", []) as Array
		for f in facts:
			if f is Dictionary:
				var fd: Dictionary = f as Dictionary
				rel_by_id[str(fd.get("fact_id",""))] = str(fd.get("reliability",""))

	for grp in conflict_groups.keys():
		var ids: Array = conflict_groups[grp] as Array
		var has_solid: bool = false
		for fidv in ids:
			var fid: String = str(fidv)
			if str(rel_by_id.get(fid, "")) == "SOLID":
				has_solid = true
				break
		if not has_solid:
			items.append(_reject("UNRESOLVABLE_CONFLICT_GROUP", "Conflict group has no SOLID breaker: %s" % str(grp)))
			return

static func _validate_skeleton_coverage(items: Array[Dictionary], suspect: Dictionary, truth_bundle: Dictionary) -> void:
	var skeleton_id: String = str(truth_bundle.get("variant_skeleton_id", ""))
	if skeleton_id == "":
		items.append(_reject("NO_SKELETON", "Missing variant skeleton id."))
		return

	var required_fact_types: Array = truth_bundle.get("variant_required_fact_types", []) as Array
	var required_anchors: Array = truth_bundle.get("variant_required_anchors", []) as Array
	var found_fact_types: Dictionary = {}
	var found_anchors: Dictionary = {}

	var tabs: Dictionary = suspect.get("tabs", {}) as Dictionary
	for tab_key in tabs.keys():
		var tabd: Dictionary = tabs[tab_key] as Dictionary
		var facts: Array = tabd.get("facts", []) as Array
		for f in facts:
			if not (f is Dictionary):
				continue
			var fd: Dictionary = f as Dictionary
			var fact_type: String = str(fd.get("fact_type", ""))
			var anchor: String = str(fd.get("anchor", ""))
			if fact_type != "":
				found_fact_types[fact_type] = true
			if anchor != "":
				found_anchors[anchor] = true

	for fact_type in required_fact_types:
		var ft: String = str(fact_type)
		if ft != "" and not bool(found_fact_types.get(ft, false)):
			items.append(_reject("MISSING_REQUIRED_FACT_TYPE", "Missing required skeleton fact type: %s" % ft))
			return

	for anchor in required_anchors:
		var a: String = str(anchor)
		if a != "" and not bool(found_anchors.get(a, false)):
			items.append(_reject("MISSING_REQUIRED_SKELETON_ANCHOR", "Missing required skeleton anchor: %s" % a))
			return

static func _validate_profile_plausibility(items: Array[Dictionary], truth_bundle: Dictionary) -> void:
	var profile_bundle: Dictionary = truth_bundle.get("profile_bundle", {}) as Dictionary
	if profile_bundle.is_empty():
		items.append(_reject("NO_PROFILE_BUNDLE", "Missing profile bundle."))
		return
	
	var contract_errors: Array[String] = CaseEngineContracts.validate_profile_bundle(profile_bundle)
	if not contract_errors.is_empty():
		items.append(_reject("BAD_PROFILE_SCHEMA", "Profile contract failed: %s" % str(contract_errors[0])))
		return
	
	var profile_errors: Array[String] = CaseEngineProfileTables_v0.validate_profile(profile_bundle)
	for code in profile_errors:
		items.append(_reject("PROFILE_PLAUSIBILITY", "Profile plausibility failed: %s" % str(code)))
		return

	var allowed_time_windows: Array = CaseEngineProfileTables_v0.allowed_time_windows(profile_bundle)
	if allowed_time_windows.is_empty():
		items.append(_reject("PROFILE_PLAUSIBILITY", "Profile plausibility failed: EMPTY_ALLOWED_TIME_WINDOWS"))
		return

	var allowed_alibi_places: Array = CaseEngineProfileTables_v0.allowed_alibi_places(profile_bundle)
	if allowed_alibi_places.is_empty():
		items.append(_reject("PROFILE_PLAUSIBILITY", "Profile plausibility failed: EMPTY_ALLOWED_ALIBI_PLACES"))
		return

	var allowed_locations: Array = CaseEngineProfileTables_v0.allowed_locations(profile_bundle)
	if allowed_locations.is_empty():
		items.append(_reject("PROFILE_PLAUSIBILITY", "Profile plausibility failed: EMPTY_ALLOWED_LOCATIONS"))
		return

	var allowed_tools: Array = CaseEngineProfileTables_v0.allowed_tools(profile_bundle)
	if allowed_tools.is_empty():
		items.append(_reject("PROFILE_PLAUSIBILITY", "Profile plausibility failed: EMPTY_ALLOWED_TOOLS"))
		return

	var allowed_contact_roles: Array = CaseEngineProfileTables_v0.allowed_contact_roles(profile_bundle)
	if allowed_contact_roles.is_empty():
		items.append(_reject("PROFILE_PLAUSIBILITY", "Profile plausibility failed: EMPTY_ALLOWED_CONTACT_ROLES"))
		return
	
	var facts: Dictionary = truth_bundle.get("facts", {}) as Dictionary
	var time_window: String = str(facts.get("time_window", ""))
	if time_window != "":
		if allowed_time_windows.is_empty() or not allowed_time_windows.has(time_window):
			items.append(_reject("PROFILE_PLAUSIBILITY", "Profile plausibility failed: BAD_TIME_WINDOW"))
			return
	var alibi_place: String = str(facts.get("alibi_place", ""))
	if alibi_place != "":
		if allowed_alibi_places.is_empty() or not allowed_alibi_places.has(alibi_place):
			items.append(_reject("PROFILE_PLAUSIBILITY", "Profile plausibility failed: BAD_ALIBI_PLACE"))
			return
	
	var location: String = str(facts.get("location", ""))
	if location != "" and not allowed_locations.has(location):
		items.append(_reject("PROFILE_PLAUSIBILITY", "Profile plausibility failed: BAD_LOCATION"))
		return
	
	var tool: String = str(facts.get("tool", ""))
	if tool != "" and not allowed_tools.has(tool):
		items.append(_reject("PROFILE_PLAUSIBILITY", "Profile plausibility failed: BAD_TOOL"))
		return
	
	var contact_role: String = str(facts.get("contact_role", ""))
	if contact_role != "" and not allowed_contact_roles.has(contact_role):
		items.append(_reject("PROFILE_PLAUSIBILITY", "Profile plausibility failed: BAD_CONTACT_ROLE"))
		return

static func _validate_player_surface_contract(items: Array[Dictionary], case_payload: Dictionary) -> void:
	var profile_text: String = CaseFolderRender.render_profile_page(case_payload)
	if _has_reliability_markup(profile_text):
		items.append(_reject("PROFILE_CARD_RELIABILITY_LEAK", "Fixed profile card leaked reliability markup."))
		return
	for page_text in [
		CaseFolderRender.render_charge_sheet(case_payload),
		CaseFolderRender.render_dossier_summary(case_payload),
		CaseFolderRender.render_profile_page(case_payload),
		CaseFolderRender.render_profile_notes_page(case_payload),
		CaseFolderRender.render_evidence_page(case_payload, CaseEngineTypes.TAB_ALIBI),
		CaseFolderRender.render_evidence_page(case_payload, CaseEngineTypes.TAB_TIMELINE),
		CaseFolderRender.render_evidence_page(case_payload, CaseEngineTypes.TAB_CAPABILITY),
		CaseFolderRender.render_evidence_page(case_payload, CaseEngineTypes.TAB_MOTIVE),
	]:
		var phrase: String = _find_player_surface_guilt_tell(str(page_text))
		if phrase != "":
			items.append(_reject("PLAYER_SURFACE_GUILT_TELL", "Player-facing surface leaked forbidden text: %s" % phrase))
			return

static func validate_authoring_contracts() -> Array[String]:
	var out: Array[String] = []
	for entry in CaseEngineNameProvider.all_name_entries():
		for code in CaseEngineContracts.validate_name_entry(entry):
			out.append("BAD_NAME_POOL_SCHEMA:%s" % code)
	for entry in CaseEngineProfileTables_v0.all_role_rows():
		for code in CaseEngineContracts.validate_role_row(entry):
			out.append("BAD_ROLE_POOL_SCHEMA:%s" % code)
	for entry in CaseEngineProfileTables_v0.all_schedule_rows():
		for code in CaseEngineContracts.validate_schedule_row(entry):
			out.append("BAD_SCHEDULE_POOL_SCHEMA:%s" % code)
	for entry in CaseEngineEntityGraph.all_relationship_rows():
		for code in CaseEngineContracts.validate_relationship_row(entry):
			out.append("BAD_RELATIONSHIP_POOL_SCHEMA:%s" % code)
	for entry in CaseEngineSkeletons_v0.all_skeleton_entries():
		for code in CaseEngineContracts.validate_skeleton_entry(entry):
			out.append("BAD_SKELETON_SCHEMA:%s" % code)
	for entry in CaseEngineContent_v0.all_template_entries():
		for code in CaseEngineContracts.validate_template_entry(entry):
			out.append("BAD_TEMPLATE_SCHEMA:%s" % code)
	for code in CaseFolderRender.validate_render_contract():
		out.append("BAD_RENDER_CONTRACT:%s" % code)
	return out

static func _has_path(d: Dictionary, path: String) -> bool:
	var parts: PackedStringArray = path.split(".", false)
	var cur: Variant = d
	for p in parts:
		if typeof(cur) != TYPE_DICTIONARY:
			return false
		var cd: Dictionary = cur as Dictionary
		if not cd.has(p):
			return false
		cur = cd[p]
	return true

static func _require_key(items: Array[Dictionary], d: Dictionary, k: String, msg: String) -> void:
	if not d.has(k):
		items.append(_reject("MISSING_" + k.to_upper(), msg))

static func _finalize(items: Array[Dictionary]) -> Dictionary:
	var level: String = LEVEL_PASS
	for it in items:
		var l: String = str(it.get("level", LEVEL_PASS))
		if l == LEVEL_REJECT:
			level = LEVEL_REJECT
			break
		if l == LEVEL_WARN:
			level = LEVEL_WARN
	return {"level": level, "items": items}

static func _warn(code: String, msg: String) -> Dictionary:
	return {"level": LEVEL_WARN, "code": code, "msg": msg}

static func _reject(code: String, msg: String) -> Dictionary:
	return {"level": LEVEL_REJECT, "code": code, "msg": msg}

static func _skeleton_for_id(skeleton_id: String) -> Dictionary:
	for s in CaseEngineSkeletons_v0._all():
		if str(s.get("id", "")) == skeleton_id:
			return s
	return {}

static func _has_reliability_markup(text: String) -> bool:
	return text.find("[Solid]") >= 0 or text.find("[Shaky]") >= 0 or text.find("[Corrupted]") >= 0

static func _find_player_surface_guilt_tell(text: String) -> String:
	var low: String = text.to_lower()
	for phrase in [
		"guilt state",
		"guilty",
		"innocent",
		"culprit",
		"perp",
		"case closed",
		"conflict audit",
		"variant skeleton",
		"truth bundle",
		"fingerprint",
	]:
		if low.find(phrase) >= 0:
			return phrase
	return ""
