@tool
extends RefCounted
class_name CaseEngineProfileTables_v0

const AGE_TO_LIFE: Dictionary = {
	"18_24": ["young_adult"],
	"25_34": ["young_adult", "adult"],
	"35_49": ["adult", "midlife"],
	"50_64": ["midlife", "senior"],
	"65_plus": ["senior"],
}

const LIFE_TO_FAMILY: Dictionary = {
	"young_adult": [
		{"family_status":"single", "dependents_band":"0"},
		{"family_status":"partnered", "dependents_band":"0"},
		{"family_status":"partnered", "dependents_band":"1_2"},
	],
	"adult": [
		{"family_status":"single", "dependents_band":"0"},
		{"family_status":"partnered", "dependents_band":"0"},
		{"family_status":"married", "dependents_band":"1_2"},
		{"family_status":"married", "dependents_band":"3_plus"},
		{"family_status":"divorced", "dependents_band":"1_2"},
	],
	"midlife": [
		{"family_status":"married", "dependents_band":"1_2"},
		{"family_status":"married", "dependents_band":"3_plus"},
		{"family_status":"divorced", "dependents_band":"1_2"},
		{"family_status":"partnered", "dependents_band":"0"},
	],
	"senior": [
		{"family_status":"married", "dependents_band":"0"},
		{"family_status":"widowed", "dependents_band":"0"},
		{"family_status":"divorced", "dependents_band":"0"},
	],
}

const ROLE_FAMILIES: Array[Dictionary] = [
	{
		"id":"ops",
		"label":"Operations",
		"weight":3,
		"role_tags":["operations", "internal_staff"],
		"assignment_pool":[
			{"id":"dispatch_rotation","label":"Dispatch Rotation","weight":2},
			{"id":"storage_rotation","label":"Storage Rotation","weight":1},
		],
		"occupation_pool":[
			{"id":"dispatch_coordinator","label":"Dispatch Coordinator","weight":2,"role_tags":["dispatch", "coordination"]},
			{"id":"storage_clerk","label":"Storage Clerk","weight":1,"role_tags":["storage", "inventory"]},
			{"id":"routing_specialist","label":"Routing Specialist","weight":1,"role_tags":["routing", "handoff"]},
		],
		"schedule_tags":["day_shift", "swing_shift", "night_shift"],
		"location_tags":["archives", "dispatch_desk", "storage_wing", "service_corridor", "front_office"],
		"tool_tags":["ledger_console", "badge_terminal", "maintenance_tablet", "dispatch_console"],
		"access_tags":["keycard_access", "after_hours_access"],
		"income_proxy":"mid",
		"typical_contact_roles":["coworker", "supervisor", "vendor", "friend"],
	},
	{
		"id":"finance",
		"label":"Finance",
		"weight":3,
		"role_tags":["finance", "records", "internal_staff"],
		"assignment_pool":[
			{"id":"invoice_review","label":"Invoice Review Desk","weight":2},
			{"id":"records_audit","label":"Records Audit Queue","weight":1},
		],
		"occupation_pool":[
			{"id":"invoice_analyst","label":"Invoice Analyst","weight":2,"role_tags":["invoices", "review"]},
			{"id":"records_officer","label":"Records Officer","weight":1,"role_tags":["records", "paperwork"]},
			{"id":"payables_clerk","label":"Payables Clerk","weight":1,"role_tags":["payables", "reconciliation"]},
		],
		"schedule_tags":["day_shift", "extended_day", "audit_window_shift"],
		"location_tags":["ledger_office", "records_room", "dispatch_desk", "conference_room"],
		"tool_tags":["ledger_console", "invoice_terminal", "records_tablet", "audit_tablet"],
		"access_tags":["paper_trail_access", "system_access"],
		"income_proxy":"mid_high",
		"typical_contact_roles":["coworker", "supervisor", "vendor", "auditor", "lender"],
	},
	{
		"id":"security",
		"label":"Security",
		"weight":2,
		"role_tags":["security", "internal_staff"],
		"assignment_pool":[
			{"id":"checkpoint_watch","label":"Checkpoint Watch","weight":2},
			{"id":"camera_review","label":"Camera Review Rotation","weight":1},
		],
		"occupation_pool":[
			{"id":"checkpoint_guard","label":"Checkpoint Guard","weight":2,"role_tags":["checkpoint", "patrol"]},
			{"id":"camera_monitor","label":"Camera Monitor","weight":1,"role_tags":["monitoring", "surveillance"]},
			{"id":"patrol_sergeant","label":"Patrol Sergeant","weight":1,"role_tags":["patrol", "response"]},
		],
		"schedule_tags":["day_shift", "night_shift", "split_shift"],
		"location_tags":["checkpoint", "camera_hub", "service_corridor", "archives", "front_office"],
		"tool_tags":["badge_terminal", "camera_console", "patrol_log", "dispatch_console"],
		"access_tags":["keycard_access", "security_access"],
		"income_proxy":"mid",
		"typical_contact_roles":["coworker", "supervisor", "auditor", "neighbor"],
	},
	{
		"id":"contractor",
		"label":"Contract Services",
		"weight":1,
		"role_tags":["contractor", "external_staff"],
		"assignment_pool":[
			{"id":"maintenance_ticket_queue","label":"Maintenance Ticket Queue","weight":2},
			{"id":"overnight_service_call","label":"Overnight Service Call","weight":1},
		],
		"occupation_pool":[
			{"id":"maintenance_vendor","label":"Maintenance Vendor","weight":2,"role_tags":["maintenance", "fieldwork"]},
			{"id":"site_technician","label":"Site Technician","weight":1,"role_tags":["repair", "service"]},
			{"id":"systems_repair_agent","label":"Systems Repair Agent","weight":1,"role_tags":["repair", "systems"]},
		],
		"schedule_tags":["contractor_day", "contractor_night"],
		"location_tags":["service_corridor", "storage_wing", "maintenance_bay", "loading_dock"],
		"tool_tags":["maintenance_tablet", "field_kit", "badge_terminal", "service_scanner"],
		"access_tags":["limited_access", "escorted_access"],
		"income_proxy":"variable",
		"typical_contact_roles":["vendor", "supervisor", "former_partner"],
	},
	{
		"id":"facilities",
		"label":"Facilities",
		"weight":2,
		"role_tags":["facilities", "internal_staff"],
		"assignment_pool":[
			{"id":"maintenance_support","label":"Maintenance Support Rotation","weight":2},
			{"id":"plant_walkthrough","label":"Plant Walkthrough Detail","weight":1},
		],
		"occupation_pool":[
			{"id":"building_operator","label":"Building Operator","weight":2,"role_tags":["facilities", "systems"]},
			{"id":"utilities_tech","label":"Utilities Technician","weight":1,"role_tags":["utilities", "maintenance"]},
		],
		"schedule_tags":["day_shift", "swing_shift", "contractor_day"],
		"location_tags":["maintenance_bay", "service_corridor", "storage_wing", "loading_dock"],
		"tool_tags":["maintenance_tablet", "field_kit", "service_scanner", "badge_terminal"],
		"access_tags":["after_hours_access", "systems_access"],
		"income_proxy":"mid",
		"typical_contact_roles":["coworker", "supervisor", "vendor", "friend"],
	},
]

const SCHEDULE_ROWS: Array[Dictionary] = [
	{"id":"day_shift","label":"Day Shift","time_window_tags":["shift_start", "midday", "handoff_gap"],"alibi_place_tags":["break_room", "front_office", "ledger_office"]},
	{"id":"swing_shift","label":"Swing Shift","time_window_tags":["late_afternoon", "handoff_gap", "evening_window"],"alibi_place_tags":["dispatch_desk", "break_room", "service_corridor"]},
	{"id":"night_shift","label":"Night Shift","time_window_tags":["night_shift", "cleanup_window", "graveyard_window"],"alibi_place_tags":["checkpoint", "service_corridor", "camera_hub"]},
	{"id":"extended_day","label":"Extended Day","time_window_tags":["midday", "late_afternoon", "audit_window"],"alibi_place_tags":["ledger_office", "records_room", "conference_room"]},
	{"id":"contractor_day","label":"Contractor Day","time_window_tags":["service_window", "handoff_gap"],"alibi_place_tags":["maintenance_bay", "service_corridor"]},
	{"id":"contractor_night","label":"Contractor Night","time_window_tags":["night_shift", "service_window", "cleanup_window"],"alibi_place_tags":["maintenance_bay", "storage_wing", "service_corridor"]},
	{"id":"split_shift","label":"Split Shift","time_window_tags":["shift_start", "late_afternoon", "evening_window"],"alibi_place_tags":["front_office", "dispatch_desk", "break_room"]},
	{"id":"audit_window_shift","label":"Audit Window Shift","time_window_tags":["midday", "audit_window", "late_afternoon"],"alibi_place_tags":["conference_room", "records_room", "ledger_office"]},
]

const CRIMINAL_HISTORY_BANDS: Array[Dictionary] = [
	{"id":"clean","label":"No Prior Incidents","weight":5},
	{"id":"minor_flags","label":"Minor Administrative Flags","weight":2},
	{"id":"disciplinary_notes","label":"Disciplinary Notes On File","weight":1},
]

const TEMPERAMENT_ROWS: Array[Dictionary] = [
	{"id":"measured","label":"Measured","weight":3,"tags":["steady"]},
	{"id":"guarded","label":"Guarded","weight":2,"tags":["controlled"]},
	{"id":"reactive","label":"Reactive","weight":1,"tags":["volatile"]},
	{"id":"methodical","label":"Methodical","weight":2,"tags":["procedural"]},
]

const LATENT_AXIS_BANDS: Dictionary = {
	"composure": [
		{"id":"low","weight":1}, {"id":"mid","weight":3}, {"id":"high","weight":2}
	],
	"defensiveness": [
		{"id":"low","weight":1}, {"id":"mid","weight":3}, {"id":"high","weight":2}
	],
	"stress_reactivity": [
		{"id":"low","weight":1}, {"id":"mid","weight":3}, {"id":"high","weight":2}
	],
	"cognitive_load": [
		{"id":"low","weight":1}, {"id":"mid","weight":3}, {"id":"high","weight":2}
	],
	"narrative_control": [
		{"id":"low","weight":1}, {"id":"mid","weight":3}, {"id":"high","weight":2}
	],
	"volatility": [
		{"id":"low","weight":2}, {"id":"mid","weight":3}, {"id":"high","weight":1}
	],
}

const BIRTH_MONTHS: Array[Dictionary] = [
	{"id":"January","days":31},
	{"id":"February","days":28},
	{"id":"March","days":31},
	{"id":"April","days":30},
	{"id":"May","days":31},
	{"id":"June","days":30},
	{"id":"July","days":31},
	{"id":"August","days":31},
	{"id":"September","days":30},
	{"id":"October","days":31},
	{"id":"November","days":30},
	{"id":"December","days":31},
]

const AGE_BAND_TO_YEARS: Dictionary = {
	"18_24": [18, 24],
	"25_34": [25, 34],
	"35_49": [35, 49],
	"50_64": [50, 64],
	"65_plus": [65, 74],
}

static func build_profile(run_seed_u64: int, suspect_index: int, reroll_index: int, crime_family: String, crime_type: String) -> Dictionary:
	var seed: int = SeedUtil.derive_seed(
		run_seed_u64,
		"profile_bundle:%s:%s" % [crime_family, crime_type],
		suspect_index * 1000 + reroll_index
	)
	var rng: RandomNumberGenerator = SeedUtil.make_rng(seed)

	var age_band: String = _pick_keys(AGE_TO_LIFE, rng)
	var life_stage_v: Variant = _pick_array(AGE_TO_LIFE.get(age_band, []) as Array, rng)
	var life_stage: String = "" if life_stage_v == null else str(life_stage_v)
	var fam_row_v: Variant = _pick_array(LIFE_TO_FAMILY.get(life_stage, []) as Array, rng)
	var fam_row: Dictionary = {} if not (fam_row_v is Dictionary) else (fam_row_v as Dictionary)
	var role_row_v: Variant = _pick_array(ROLE_FAMILIES, rng)
	var role_row: Dictionary = {} if not (role_row_v is Dictionary) else (role_row_v as Dictionary)
	var occupation_row: Dictionary = _pick_weighted_row(role_row.get("occupation_pool", []) as Array, rng)
	var assignment_row: Dictionary = _pick_weighted_row(role_row.get("assignment_pool", []) as Array, rng)
	var schedule_tag_v: Variant = _pick_array(role_row.get("schedule_tags", []) as Array, rng)
	var schedule_tag: String = "" if schedule_tag_v == null else str(schedule_tag_v)
	var schedule_row: Dictionary = _schedule_row(schedule_tag)
	var tenure_band_v: Variant = _pick_array(["new_hire", "established", "long_tenure"], rng)
	var tenure_band: String = "" if tenure_band_v == null else str(tenure_band_v)
	var criminal_history_row: Dictionary = _pick_weighted_row(CRIMINAL_HISTORY_BANDS, rng)
	var temperament_row: Dictionary = _pick_weighted_row(TEMPERAMENT_ROWS, rng)
	var subject_name: Dictionary = CaseEngineNameProvider.name_for("subject", run_seed_u64, suspect_index, reroll_index, "E_SUS")
	var birth_month_row: Dictionary = _pick_weighted_row(BIRTH_MONTHS, rng)
	var birth_month: String = str(birth_month_row.get("id", "January"))
	var birth_day: int = rng.randi_range(1, maxi(int(birth_month_row.get("days", 31)), 1))
	var age_range: Array = AGE_BAND_TO_YEARS.get(age_band, [30, 30]) as Array
	var age_years: int = int(age_range[0]) if age_range.size() < 2 else rng.randi_range(int(age_range[0]), int(age_range[1]))
	var typical_contact_roles: Array = (role_row.get("typical_contact_roles", []) as Array).duplicate()
	if str(fam_row.get("family_status", "")) != "single" or str(fam_row.get("dependents_band", "")) != "0":
		if not typical_contact_roles.has("family"):
			typical_contact_roles.append("family")
	var latent_axes: Dictionary = {}
	for axis in LATENT_AXIS_BANDS.keys():
		var axis_row: Dictionary = _pick_weighted_row(LATENT_AXIS_BANDS.get(axis, []) as Array, rng)
		latent_axes[str(axis)] = str(axis_row.get("id", "mid"))

	return {
		"age_band": age_band,
		"age_years": age_years,
		"birth_month": birth_month,
		"birth_day": birth_day,
		"first_name": str(subject_name.get("first_name", "")),
		"last_name": str(subject_name.get("last_name", "")),
		"full_name": str(subject_name.get("full_name", "")),
		"life_stage": life_stage,
		"family_status": str(fam_row.get("family_status", "")),
		"dependents_band": str(fam_row.get("dependents_band", "")),
		"role_family": str(role_row.get("id", "")),
		"role_family_label": str(role_row.get("label", "")),
		"occupation_id": str(occupation_row.get("id", "")),
		"occupation_label": str(occupation_row.get("label", "")),
		"assignment_label": str(assignment_row.get("label", occupation_row.get("label", role_row.get("label", "")))),
		"schedule_tag": schedule_tag,
		"schedule_label": str(schedule_row.get("label", "")),
		"tenure_band": tenure_band,
		"tenure_label": _humanize_token(tenure_band),
		"income_proxy": str(role_row.get("income_proxy", "")),
		"criminal_history_band": str(criminal_history_row.get("id", "")),
		"criminal_history_label": str(criminal_history_row.get("label", "")),
		"temperament": str(temperament_row.get("id", "")),
		"temperament_label": str(temperament_row.get("label", "")),
		"latent_axes": latent_axes,
		"role_tags": _merge_tags(role_row.get("role_tags", []) as Array, occupation_row.get("role_tags", []) as Array),
		"location_tags": (role_row.get("location_tags", []) as Array).duplicate(),
		"tool_tags": (role_row.get("tool_tags", []) as Array).duplicate(),
		"access_tags": (role_row.get("access_tags", []) as Array).duplicate(),
		"typical_contact_roles": typical_contact_roles,
		"time_window_tags": (schedule_row.get("time_window_tags", []) as Array).duplicate(),
		"alibi_place_tags": (schedule_row.get("alibi_place_tags", []) as Array).duplicate(),
	}

static func allowed_time_windows(profile: Dictionary) -> Array:
	return (profile.get("time_window_tags", []) as Array).duplicate()

static func allowed_alibi_places(profile: Dictionary) -> Array:
	return (profile.get("alibi_place_tags", []) as Array).duplicate()

static func allowed_locations(profile: Dictionary) -> Array:
	return (profile.get("location_tags", []) as Array).duplicate()

static func allowed_tools(profile: Dictionary) -> Array:
	return (profile.get("tool_tags", []) as Array).duplicate()

static func allowed_contact_roles(profile: Dictionary) -> Array:
	return (profile.get("typical_contact_roles", []) as Array).duplicate()

static func allows_location(profile: Dictionary, location_name: String) -> bool:
	return allowed_locations(profile).has(location_name)

static func allows_tool(profile: Dictionary, tool_name: String) -> bool:
	return allowed_tools(profile).has(tool_name)

static func allows_contact_role(profile: Dictionary, contact_role: String) -> bool:
	return allowed_contact_roles(profile).has(contact_role)

static func human_profile_fields(profile: Dictionary) -> Dictionary:
	return {
		"role_family": _humanize_token(str(profile.get("role_family_label", profile.get("role_family", "")))),
		"occupation": _humanize_token(str(profile.get("occupation_label", profile.get("occupation_id", "")))),
		"assignment": _humanize_token(str(profile.get("assignment_label", profile.get("occupation_label", "")))),
		"schedule": _humanize_token(str(profile.get("schedule_label", profile.get("schedule_tag", "")))),
		"tenure": _humanize_token(str(profile.get("tenure_label", profile.get("tenure_band", "")))),
		"temperament": _humanize_token(str(profile.get("temperament_label", profile.get("temperament", "")))),
		"criminal_history": _humanize_token(str(profile.get("criminal_history_label", profile.get("criminal_history_band", "")))),
		"dependents": _humanize_dependents(str(profile.get("dependents_band", ""))),
		"birthday": "%s %s" % [str(profile.get("birth_month", "")), str(profile.get("birth_day", ""))],
	}

static func validate_profile(profile: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var age_band: String = str(profile.get("age_band", ""))
	var life_stage: String = str(profile.get("life_stage", ""))
	if not (AGE_TO_LIFE.get(age_band, []) as Array).has(life_stage):
		out.append("BAD_AGE_LIFE_STAGE")

	var fam: String = str(profile.get("family_status", ""))
	var dep: String = str(profile.get("dependents_band", ""))
	var ok_family: bool = false
	for row_v in LIFE_TO_FAMILY.get(life_stage, []):
		if row_v is Dictionary:
			var row: Dictionary = row_v as Dictionary
			if str(row.get("family_status", "")) == fam and str(row.get("dependents_band", "")) == dep:
				ok_family = true
				break
	if not ok_family:
		out.append("BAD_FAMILY_DEPENDENTS")

	var role_family: String = str(profile.get("role_family", ""))
	var role_row: Dictionary = _role_row(role_family)
	if role_row.is_empty():
		out.append("BAD_ROLE_FAMILY")

	var occupation_id: String = str(profile.get("occupation_id", ""))
	var occupation_ok: bool = false
	for occupation_v in role_row.get("occupation_pool", []) as Array:
		if occupation_v is Dictionary and str((occupation_v as Dictionary).get("id", "")) == occupation_id:
			occupation_ok = true
			break
	if not occupation_ok:
		out.append("BAD_OCCUPATION_ID")

	var schedule_tag: String = str(profile.get("schedule_tag", ""))
	if not (role_row.get("schedule_tags", []) as Array).has(schedule_tag):
		out.append("BAD_SCHEDULE_TAG")

	var schedule_row: Dictionary = _schedule_row(schedule_tag)
	if schedule_row.is_empty():
		out.append("BAD_SCHEDULE_ROW")

	if str(profile.get("occupation_label", "")) == "":
		out.append("MISSING_OCCUPATION_LABEL")
	if str(profile.get("full_name", "")) == "":
		out.append("MISSING_FULL_NAME")
	if str(profile.get("first_name", "")) == "" or str(profile.get("last_name", "")) == "":
		out.append("MISSING_NAME_PARTS")
	if str(profile.get("birth_month", "")) == "":
		out.append("MISSING_BIRTH_MONTH")
	if int(profile.get("birth_day", 0)) <= 0:
		out.append("MISSING_BIRTH_DAY")
	if int(profile.get("age_years", 0)) <= 0:
		out.append("MISSING_AGE_YEARS")
	if not _age_matches_life_stage(int(profile.get("age_years", 0)), life_stage):
		out.append("BAD_AGE_YEARS")
	if str(profile.get("temperament", "")) == "":
		out.append("MISSING_TEMPERAMENT")
	if str(profile.get("criminal_history_band", "")) == "":
		out.append("MISSING_CRIMINAL_HISTORY")
	if str(profile.get("schedule_label", "")) == "":
		out.append("MISSING_SCHEDULE_LABEL")
	if str(profile.get("tenure_label", "")) == "":
		out.append("MISSING_TENURE_LABEL")

	if (profile.get("role_tags", []) as Array).is_empty():
		out.append("EMPTY_ROLE_TAGS")
	if allowed_locations(profile).is_empty():
		out.append("EMPTY_LOCATION_TAGS")
	if allowed_tools(profile).is_empty():
		out.append("EMPTY_TOOL_TAGS")
	if allowed_contact_roles(profile).is_empty():
		out.append("EMPTY_CONTACT_ROLE_TAGS")
	if allowed_time_windows(profile).is_empty():
		out.append("EMPTY_TIME_WINDOW_TAGS")
	if allowed_alibi_places(profile).is_empty():
		out.append("EMPTY_ALIBI_PLACE_TAGS")

	var latent_axes: Dictionary = profile.get("latent_axes", {}) as Dictionary
	for axis in ["composure", "defensiveness", "stress_reactivity", "cognitive_load", "narrative_control", "volatility"]:
		if str(latent_axes.get(axis, "")) == "":
			out.append("MISSING_AXIS_%s" % str(axis).to_upper())

	return out

static func is_profile_valid(profile: Dictionary) -> bool:
	return validate_profile(profile).is_empty()

static func all_role_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in ROLE_FAMILIES:
		out.append((row as Dictionary).duplicate(true))
	return out

static func all_schedule_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in SCHEDULE_ROWS:
		out.append((row as Dictionary).duplicate(true))
	return out

static func validate_tables() -> Array[String]:
	var out: Array[String] = []
	for row in all_role_rows():
		for code in CaseEngineContracts.validate_role_row(row):
			out.append(code)
	for row in all_schedule_rows():
		for code in CaseEngineContracts.validate_schedule_row(row):
			out.append(code)
	return out

static func _role_row(role_id: String) -> Dictionary:
	for row_v in ROLE_FAMILIES:
		var row: Dictionary = row_v as Dictionary
		if str(row.get("id", "")) == role_id:
			return row
	return {}

static func _schedule_row(schedule_id: String) -> Dictionary:
	for row_v in SCHEDULE_ROWS:
		var row: Dictionary = row_v as Dictionary
		if str(row.get("id", "")) == schedule_id:
			return row
	return {}

static func _pick_keys(d: Dictionary, rng: RandomNumberGenerator) -> String:
	var keys: Array = d.keys()
	if keys.is_empty():
		return ""
	return str(keys[rng.randi_range(0, keys.size() - 1)])

static func _pick_array(values: Array, rng: RandomNumberGenerator) -> Variant:
	if values.is_empty():
		return null
	return values[rng.randi_range(0, values.size() - 1)]

static func _pick_weighted_row(rows: Array, rng: RandomNumberGenerator) -> Dictionary:
	if rows.is_empty():
		return {}
	var total_weight: int = 0
	for row_v in rows:
		if row_v is Dictionary:
			total_weight += maxi(int((row_v as Dictionary).get("weight", 1)), 1)
	var ticket: int = rng.randi_range(1, maxi(total_weight, 1))
	var running: int = 0
	for row_v in rows:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		running += maxi(int(row.get("weight", 1)), 1)
		if ticket <= running:
			return row.duplicate(true)
	return (rows[0] as Dictionary).duplicate(true)

static func _merge_tags(a: Array, b: Array) -> Array:
	var out: Array = []
	for v in a:
		if not out.has(v):
			out.append(v)
	for v in b:
		if not out.has(v):
			out.append(v)
	return out

static func _humanize_token(token: String) -> String:
	if token == "":
		return ""
	var parts: PackedStringArray = token.replace("-", "_").split("_", false)
	for i in range(parts.size()):
		parts[i] = parts[i].capitalize()
	return " ".join(parts)

static func _humanize_dependents(v: String) -> String:
	match v:
		"0":
			return "0"
		"1_2":
			return "1-2"
		"3_plus":
			return "3+"
		_:
			return _humanize_token(v)

static func _age_matches_life_stage(age_years: int, life_stage: String) -> bool:
	match life_stage:
		"young_adult":
			return age_years >= 18 and age_years <= 34
		"adult":
			return age_years >= 25 and age_years <= 49
		"midlife":
			return age_years >= 35 and age_years <= 64
		"senior":
			return age_years >= 50
		_:
			return false
