@tool
extends RefCounted
class_name CaseEngineContent_v0

static func crime_families() -> Array[String]:
	var out: Array[String] = []
	for row_v in crime_type_rows():
		var row: Dictionary = row_v as Dictionary
		var family: String = str(row.get("crime_family", ""))
		if family != "" and not out.has(family):
			out.append(family)
	return out

static func crime_types_for_family(family: String) -> Array[String]:
	var out: Array[String] = []
	for row_v in crime_type_rows():
		var row: Dictionary = row_v as Dictionary
		if str(row.get("crime_family", "")) == family:
			out.append(str(row.get("id", "")))
	if out.is_empty():
		out.append("policy_breach")
	return out

static func crime_type_rows() -> Array[Dictionary]:
	return [
		{"id":"invoice_manipulation","crime_family":"fraud","label":"Invoice Manipulation","tags":["finance","paper_trail"],"weight":1},
		{"id":"expense_recode","crime_family":"fraud","label":"Expense Recode","tags":["finance","approvals"],"weight":1},
		{"id":"ledger_drift","crime_family":"embezzlement","label":"Ledger Drift","tags":["finance","records"],"weight":1},
		{"id":"float_skimming","crime_family":"embezzlement","label":"Float Skimming","tags":["cash","records"],"weight":1},
		{"id":"sensor_tamper","crime_family":"sabotage","label":"Sensor Tamper","tags":["security","systems"],"weight":1},
		{"id":"camera_gap","crime_family":"sabotage","label":"Camera Gap","tags":["security","surveillance"],"weight":1},
	]

static func opportunities() -> Array[String]:
	return ["night_shift", "handoff_gap", "badge_override", "service_window"]

static func alibi_truths() -> Array[String]:
	return ["verified", "partial", "unverified"]

static func motives() -> Array[String]:
	return ["debt", "career_pressure", "retaliation", "coercion"]

static func relationships() -> Array[String]:
	return [
		"manager",
		"coworker",
		"vendor_contact",
		"family_contact",
		"auditor_contact",
		"subordinate_contact",
		"lender_contact",
		"former_partner",
		"friend_contact",
		"neighbor_contact",
	]

static func tabs_templates() -> Dictionary:
	return {
		CaseEngineTypes.TAB_TIMELINE: [
			{"tab":CaseEngineTypes.TAB_TIMELINE,"template_id":"timeline_anchor_entry","fact_type":CaseEngineTypes.FACT_TIMELINE_ANCHOR,"text_tpl":"Badge reader logs entry at {time_anchor} near {location}.","slot_keys":["time_anchor","location"],"truth_refs":["opportunity","facts.time_anchor","facts.location"],"anchor":CaseEngineTypes.ANCHOR_TIMELINE,"reliability":CaseEngineTypes.RELIABILITY_SOLID,"conflict_group":"timeline_window"},
			{"tab":CaseEngineTypes.TAB_TIMELINE,"template_id":"timeline_anchor_exit","fact_type":CaseEngineTypes.FACT_TIMELINE_ANCHOR,"text_tpl":"Camera frame shows movement through {location} at {time_anchor}.","slot_keys":["time_anchor","location"],"truth_refs":["facts.time_window","facts.location"],"anchor":CaseEngineTypes.ANCHOR_TIMELINE,"reliability":CaseEngineTypes.RELIABILITY_SOLID,"conflict_group":"timeline_window"},
			{"tab":CaseEngineTypes.TAB_TIMELINE,"template_id":"timeline_anchor_corridor","fact_type":CaseEngineTypes.FACT_TIMELINE_ANCHOR,"text_tpl":"Checkpoint note places the subject passing {location} around {time_anchor}.","slot_keys":["location","time_anchor"],"truth_refs":["facts.location","facts.time_anchor"],"anchor":CaseEngineTypes.ANCHOR_TIMELINE,"reliability":CaseEngineTypes.RELIABILITY_SOLID,"conflict_group":"timeline_window"},
			{"tab":CaseEngineTypes.TAB_TIMELINE,"template_id":"timeline_note","fact_type":CaseEngineTypes.FACT_TIMELINE_NOTE,"text_tpl":"Maintenance note from {coworker_name} places the subject near {location}.","slot_keys":["coworker_name","location"],"truth_refs":["facts.coworker_name","facts.location"],"anchor":CaseEngineTypes.ANCHOR_TIMELINE,"reliability":CaseEngineTypes.RELIABILITY_QUESTIONABLE,"conflict_group":"timeline_window"},
			{"tab":CaseEngineTypes.TAB_TIMELINE,"template_id":"timeline_note_shift","fact_type":CaseEngineTypes.FACT_TIMELINE_NOTE,"text_tpl":"Shift handoff note records {coworker_name} clearing the subject through {location}.","slot_keys":["coworker_name","location"],"truth_refs":["facts.coworker_name","facts.location"],"anchor":CaseEngineTypes.ANCHOR_TIMELINE,"reliability":CaseEngineTypes.RELIABILITY_QUESTIONABLE,"conflict_group":"timeline_window"},
		],
		CaseEngineTypes.TAB_ALIBI: [
			{"tab":CaseEngineTypes.TAB_ALIBI,"template_id":"alibi_statement","fact_type":CaseEngineTypes.FACT_ALIBI_STATEMENT,"text_tpl":"Subject claims to be at {alibi_place} during {time_window}.","slot_keys":["alibi_place","time_window"],"truth_refs":["alibi_truth","facts.time_window"],"anchor":CaseEngineTypes.ANCHOR_ALIBI,"reliability":CaseEngineTypes.RELIABILITY_SOLID,"conflict_group":"alibi_presence"},
			{"tab":CaseEngineTypes.TAB_ALIBI,"template_id":"alibi_statement_log","fact_type":CaseEngineTypes.FACT_ALIBI_STATEMENT,"text_tpl":"Interview summary places the subject at {alibi_place} through the {time_window} window.","slot_keys":["alibi_place","time_window"],"truth_refs":["alibi_truth","facts.alibi_place","facts.time_window"],"anchor":CaseEngineTypes.ANCHOR_ALIBI,"reliability":CaseEngineTypes.RELIABILITY_SOLID,"conflict_group":"alibi_presence"},
			{"tab":CaseEngineTypes.TAB_ALIBI,"template_id":"alibi_witness","fact_type":CaseEngineTypes.FACT_ALIBI_WITNESS,"text_tpl":"{witness_name} references a meeting at {alibi_place}.","slot_keys":["witness_name","alibi_place"],"truth_refs":["alibi_truth","facts.witness_name"],"anchor":CaseEngineTypes.ANCHOR_ALIBI,"reliability":CaseEngineTypes.RELIABILITY_QUESTIONABLE,"conflict_group":"alibi_presence"},
			{"tab":CaseEngineTypes.TAB_ALIBI,"template_id":"alibi_witness_dispatch","fact_type":CaseEngineTypes.FACT_ALIBI_WITNESS,"text_tpl":"{witness_name} logs the subject near {alibi_place} before the shift break.","slot_keys":["witness_name","alibi_place"],"truth_refs":["facts.witness_name","facts.alibi_place"],"anchor":CaseEngineTypes.ANCHOR_ALIBI,"reliability":CaseEngineTypes.RELIABILITY_QUESTIONABLE,"conflict_group":"alibi_presence"},
		],
		CaseEngineTypes.TAB_CAPABILITY: [
			{"tab":CaseEngineTypes.TAB_CAPABILITY,"template_id":"capability_access","fact_type":CaseEngineTypes.FACT_CAPABILITY_ACCESS,"text_tpl":"{supervisor_name} signed off on toolchain {tool} authorization.","slot_keys":["supervisor_name","tool"],"truth_refs":["crime_type","facts.supervisor_name"],"anchor":CaseEngineTypes.ANCHOR_CAPABILITY,"reliability":CaseEngineTypes.RELIABILITY_SOLID,"conflict_group":"capability_scope"},
			{"tab":CaseEngineTypes.TAB_CAPABILITY,"template_id":"capability_access_badge","fact_type":CaseEngineTypes.FACT_CAPABILITY_ACCESS,"text_tpl":"Access roster marks the subject cleared for {tool} handling under {supervisor_name}.","slot_keys":["tool","supervisor_name"],"truth_refs":["crime_family","facts.tool","facts.supervisor_name"],"anchor":CaseEngineTypes.ANCHOR_CAPABILITY,"reliability":CaseEngineTypes.RELIABILITY_SOLID,"conflict_group":"capability_scope"},
			{"tab":CaseEngineTypes.TAB_CAPABILITY,"template_id":"capability_training","fact_type":CaseEngineTypes.FACT_CAPABILITY_TRAINING,"text_tpl":"Training ledger shows recent certification on {tool}.","slot_keys":["tool"],"truth_refs":["crime_family","facts.tool"],"anchor":CaseEngineTypes.ANCHOR_CAPABILITY,"reliability":CaseEngineTypes.RELIABILITY_QUESTIONABLE,"conflict_group":"capability_scope"},
			{"tab":CaseEngineTypes.TAB_CAPABILITY,"template_id":"capability_training_log","fact_type":CaseEngineTypes.FACT_CAPABILITY_TRAINING,"text_tpl":"Operations file notes a refresher block on {tool} procedures.","slot_keys":["tool"],"truth_refs":["facts.tool"],"anchor":CaseEngineTypes.ANCHOR_CAPABILITY,"reliability":CaseEngineTypes.RELIABILITY_QUESTIONABLE,"conflict_group":"capability_scope"},
		],
		CaseEngineTypes.TAB_MOTIVE: [
			{"tab":CaseEngineTypes.TAB_MOTIVE,"template_id":"motive_pressure","fact_type":CaseEngineTypes.FACT_MOTIVE_PRESSURE,"text_tpl":"Recent behavior indicates pressure linked to {motive}.","slot_keys":["motive"],"truth_refs":["motive"],"anchor":CaseEngineTypes.ANCHOR_MOTIVE,"reliability":CaseEngineTypes.RELIABILITY_SOLID,"conflict_group":"motive_driver"},
			{"tab":CaseEngineTypes.TAB_MOTIVE,"template_id":"motive_pressure_balance","fact_type":CaseEngineTypes.FACT_MOTIVE_PRESSURE,"text_tpl":"Supervisory notes mention strain around {motive} obligations.","slot_keys":["motive"],"truth_refs":["motive"],"anchor":CaseEngineTypes.ANCHOR_MOTIVE,"reliability":CaseEngineTypes.RELIABILITY_SOLID,"conflict_group":"motive_driver"},
			{"tab":CaseEngineTypes.TAB_MOTIVE,"template_id":"motive_relationship","fact_type":CaseEngineTypes.FACT_MOTIVE_RELATIONSHIP,"text_tpl":"Communication thread suggests dependency on {contact_role} {contact_name}.","slot_keys":["contact_role","contact_name"],"truth_refs":["relationship","facts.contact_role","facts.contact_name"],"anchor":CaseEngineTypes.ANCHOR_RELATIONSHIP,"reliability":CaseEngineTypes.RELIABILITY_SOLID,"conflict_group":"motive_driver"},
			{"tab":CaseEngineTypes.TAB_MOTIVE,"template_id":"motive_relationship_pattern","fact_type":CaseEngineTypes.FACT_MOTIVE_RELATIONSHIP,"text_tpl":"Message pattern shows repeated check-ins with {contact_role} {contact_name}.","slot_keys":["contact_role","contact_name"],"truth_refs":["relationship","facts.contact_role","facts.contact_name"],"anchor":CaseEngineTypes.ANCHOR_RELATIONSHIP,"reliability":CaseEngineTypes.RELIABILITY_SOLID,"conflict_group":"motive_driver"},
		],
		CaseEngineTypes.TAB_PROFILE: [
			{"tab":CaseEngineTypes.TAB_PROFILE,"template_id":"profile_shift","fact_type":CaseEngineTypes.FACT_PROFILE_BEHAVIOR,"text_tpl":"Assignment ledger places the subject in {occupation_label} duty on a {human_schedule} rotation.","slot_keys":["occupation_label","human_schedule"],"truth_refs":["facts.occupation_label","facts.human_schedule"],"anchor":CaseEngineTypes.ANCHOR_PROFILE,"reliability":CaseEngineTypes.RELIABILITY_SOLID,"conflict_group":"profile_context"},
			{"tab":CaseEngineTypes.TAB_PROFILE,"template_id":"profile_tenure","fact_type":CaseEngineTypes.FACT_PROFILE_BEHAVIOR,"text_tpl":"Tenure record marks the subject as {tenure_band}.","slot_keys":["tenure_band"],"truth_refs":["facts.tenure_band"],"anchor":CaseEngineTypes.ANCHOR_PROFILE,"reliability":CaseEngineTypes.RELIABILITY_SOLID,"conflict_group":"profile_context"},
			{"tab":CaseEngineTypes.TAB_PROFILE,"template_id":"profile_behavior","fact_type":CaseEngineTypes.FACT_PROFILE_BEHAVIOR,"text_tpl":"{supervisor_name} describes the subject as {human_temperament} when routines are challenged.","slot_keys":["supervisor_name","human_temperament"],"truth_refs":["facts.supervisor_name","facts.human_temperament"],"anchor":CaseEngineTypes.ANCHOR_PROFILE,"reliability":CaseEngineTypes.RELIABILITY_QUESTIONABLE,"conflict_group":"profile_context"},
			{"tab":CaseEngineTypes.TAB_PROFILE,"template_id":"profile_schedule_context","fact_type":CaseEngineTypes.FACT_PROFILE_BEHAVIOR,"text_tpl":"Schedule notes tie the subject to {human_schedule} coverage with {tenure_band} standing.","slot_keys":["human_schedule","tenure_band"],"truth_refs":["facts.human_schedule","facts.tenure_band"],"anchor":CaseEngineTypes.ANCHOR_PROFILE,"reliability":CaseEngineTypes.RELIABILITY_SOLID,"conflict_group":"profile_context"},
			{"tab":CaseEngineTypes.TAB_PROFILE,"template_id":"profile_relationship_context","fact_type":CaseEngineTypes.FACT_PROFILE_BEHAVIOR,"text_tpl":"Contact summaries show routine coordination with {contact_role} {contact_name}.","slot_keys":["contact_role","contact_name"],"truth_refs":["facts.contact_role","facts.contact_name"],"anchor":CaseEngineTypes.ANCHOR_PROFILE,"reliability":CaseEngineTypes.RELIABILITY_QUESTIONABLE,"conflict_group":"profile_context"},
			{"tab":CaseEngineTypes.TAB_PROFILE,"template_id":"profile_assignment_detail","fact_type":CaseEngineTypes.FACT_PROFILE_BEHAVIOR,"text_tpl":"Assignment sheet links the subject to {assignment_label} duty under a {human_schedule} calendar.","slot_keys":["assignment_label","human_schedule"],"truth_refs":["facts.assignment_label","facts.human_schedule"],"anchor":CaseEngineTypes.ANCHOR_PROFILE,"reliability":CaseEngineTypes.RELIABILITY_SOLID,"conflict_group":"profile_context"},
			{"tab":CaseEngineTypes.TAB_PROFILE,"template_id":"profile_temperament_note","fact_type":CaseEngineTypes.FACT_PROFILE_BEHAVIOR,"text_tpl":"Observation memo describes a {human_temperament} response pattern during routine disruptions.","slot_keys":["human_temperament"],"truth_refs":["facts.human_temperament"],"anchor":CaseEngineTypes.ANCHOR_PROFILE,"reliability":CaseEngineTypes.RELIABILITY_QUESTIONABLE,"conflict_group":"profile_context"},
		],
	}

static func all_template_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var by_tab: Dictionary = tabs_templates()
	for tab_key in by_tab.keys():
		for entry_v in by_tab.get(tab_key, []) as Array:
			if entry_v is Dictionary:
				out.append((entry_v as Dictionary).duplicate(true))
	return out

static func validate_tables() -> Array[String]:
	var out: Array[String] = []
	for row_v in crime_type_rows():
		var row: Dictionary = row_v as Dictionary
		for code in CaseEngineContracts.validate_crime_type_row(row):
			out.append(code)
	for entry in all_template_entries():
		for code in CaseEngineContracts.validate_template_entry(entry):
			out.append(code)
	return out
