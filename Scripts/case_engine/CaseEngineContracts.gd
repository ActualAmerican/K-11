@tool
extends RefCounted
class_name CaseEngineContracts

const PROFILE_CARD_VISIBLE_FIELDS: Array[String] = [
	"full_name",
	"age_years",
	"birth_month",
	"birth_day",
	"occupation_label",
	"assignment_label",
	"family_status",
	"dependents_band",
	"schedule_label",
	"tenure_label",
	"temperament",
	"criminal_history_label",
]

const PROFILE_CARD_OPTIONAL_FIELDS: Array[String] = [
	"subject_marker",
]

const PROFILE_CARD_HIDDEN_FIELDS: Array[String] = [
	"age_band",
	"life_stage",
	"latent_axes",
	"guilt_state",
	"truth_bundle",
	"conflict_audit",
]

const REQUIRED_PROFILE_BUNDLE_KEYS: Array[String] = [
	"full_name",
	"first_name",
	"last_name",
	"birth_month",
	"birth_day",
	"age_years",
	"age_band",
	"life_stage",
	"occupation_id",
	"occupation_label",
	"assignment_label",
	"family_status",
	"dependents_band",
	"schedule_tag",
	"schedule_label",
	"tenure_band",
	"tenure_label",
	"criminal_history_band",
	"criminal_history_label",
	"temperament",
	"latent_axes",
	"location_tags",
	"tool_tags",
	"access_tags",
	"typical_contact_roles",
]

const REQUIRED_NAME_ENTRY_KEYS: Array[String] = [
	"id",
	"label",
	"kind",
	"weight",
	"tags",
]

const REQUIRED_ROLE_ROW_KEYS: Array[String] = [
	"id",
	"label",
	"weight",
	"role_tags",
	"occupation_pool",
	"assignment_pool",
	"schedule_tags",
	"location_tags",
	"tool_tags",
	"access_tags",
	"typical_contact_roles",
]

const REQUIRED_OCCUPATION_ROW_KEYS: Array[String] = [
	"id",
	"label",
	"weight",
	"role_tags",
]

const REQUIRED_SCHEDULE_ROW_KEYS: Array[String] = [
	"id",
	"label",
	"time_window_tags",
	"alibi_place_tags",
]

const REQUIRED_CRIME_TYPE_ROW_KEYS: Array[String] = [
	"id",
	"crime_family",
	"label",
	"tags",
	"weight",
]

const REQUIRED_RELATIONSHIP_ARCHETYPE_KEYS: Array[String] = [
	"id",
	"contact_role",
	"label",
	"tags",
	"weight",
]

const REQUIRED_TEMPLATE_KEYS: Array[String] = [
	"tab",
	"template_id",
	"fact_type",
	"text_tpl",
	"slot_keys",
	"truth_refs",
	"anchor",
	"reliability",
]

const REQUIRED_SKELETON_KEYS: Array[String] = [
	"id",
	"crime_family",
	"crime_type",
	"required_atoms",
	"optional_atoms",
	"conflict_seeds",
	"chains",
]

const REQUIRED_SUSPECT_KEYS: Array[String] = [
	"id",
	"silhouette_label",
	"charge_sheet",
	"truth_bundle",
	"tabs",
	"deadline_s",
]

const REQUIRED_SUSPECT_TAB_KEYS: Array[String] = [
	"tab",
	"facts",
]

const TRUTH_GRAPH_REQUIRED_KEYS: Array[String] = [
	"schema_version",
	"culpability",
	"crime",
	"timeline",
	"opportunity",
	"alibi",
	"motive",
	"capability",
	"relationship",
	"twist_tags",
]

const TRUTH_GRAPH_REQUIRED_SECTIONS: Array[String] = [
	"culpability",
	"crime",
	"timeline",
	"opportunity",
	"alibi",
	"motive",
	"capability",
	"relationship",
]

const TRUTH_GRAPH_CULPABILITY_KEYS: Array[String] = ["state", "cover_posture", "pressure_bias"]
const TRUTH_GRAPH_CRIME_KEYS: Array[String] = ["family", "type", "method_class"]
const TRUTH_GRAPH_TIMELINE_KEYS: Array[String] = ["window", "anchor", "location"]
const TRUTH_GRAPH_OPPORTUNITY_KEYS: Array[String] = ["id", "class", "tool"]
const TRUTH_GRAPH_ALIBI_KEYS: Array[String] = ["truth", "place", "strength_band", "corroboration_mode"]
const TRUTH_GRAPH_MOTIVE_KEYS: Array[String] = ["id", "class", "intensity_band"]
const TRUTH_GRAPH_CAPABILITY_KEYS: Array[String] = ["tool", "access_tags", "location_tags", "skill_tags", "exposure_band"]
const TRUTH_GRAPH_RELATIONSHIP_KEYS: Array[String] = ["id", "contact_role", "contact_name"]

static func profile_card_visible_fields() -> Array[String]:
	return PROFILE_CARD_VISIBLE_FIELDS.duplicate()

static func validate_suspect_contract(suspect: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if suspect.is_empty():
		out.append("MISSING_SUSPECT")
		return out
	for key in REQUIRED_SUSPECT_KEYS:
		if not suspect.has(key):
			out.append("MISSING_SUSPECT_KEY:%s" % key)
	if str(suspect.get("id", "")).strip_edges() == "":
		out.append("EMPTY_SUSPECT_ID")
	if str(suspect.get("silhouette_label", "")).strip_edges() == "":
		out.append("EMPTY_SUSPECT_SILHOUETTE")
	if int(suspect.get("deadline_s", 0)) <= 0:
		out.append("EMPTY_SUSPECT_DEADLINE")
	var charge_sheet: Dictionary = suspect.get("charge_sheet", {}) as Dictionary
	for key in ["case_id", "title", "charges", "brief"]:
		if not charge_sheet.has(key):
			out.append("BAD_SUSPECT_CHARGE_SHEET:%s" % key)
	var truth_bundle: Dictionary = suspect.get("truth_bundle", {}) as Dictionary
	if truth_bundle.is_empty():
		out.append("MISSING_SUSPECT_TRUTH_BUNDLE")
	else:
		var truth_errors: Array[String] = validate_truth_graph(truth_bundle)
		if not truth_errors.is_empty():
			out.append("BAD_SUSPECT_TRUTH_BUNDLE:%s" % truth_errors[0])
	var tabs: Dictionary = suspect.get("tabs", {}) as Dictionary
	for tab_id in ["ALIBI", "TIMELINE", "MOTIVE", "CAPABILITY", "PROFILE"]:
		if not tabs.has(tab_id):
			out.append("MISSING_SUSPECT_TAB:%s" % tab_id)
			continue
		var tab_data: Dictionary = tabs.get(tab_id, {}) as Dictionary
		for key in REQUIRED_SUSPECT_TAB_KEYS:
			if not tab_data.has(key):
				out.append("BAD_SUSPECT_TAB:%s.%s" % [tab_id, key])
		if str(tab_data.get("tab", "")) != tab_id:
			out.append("BAD_SUSPECT_TAB_ID:%s" % tab_id)
		if not tab_data.has("fact_pool_seed_u64") and not tab_data.has("fact_pool_seed_u64_hex"):
			out.append("BAD_SUSPECT_TAB:%s.fact_pool_seed" % tab_id)
		if not (tab_data.get("facts", []) is Array):
			out.append("BAD_SUSPECT_TAB_FACTS:%s" % tab_id)
	return out

static func validate_truth_graph(truth_bundle: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not truth_bundle.has("truth_graph"):
		out.append("MISSING_TRUTH_GRAPH")
		return out

	var truth_graph_value: Variant = truth_bundle.get("truth_graph", {})
	if not (truth_graph_value is Dictionary):
		out.append("MISSING_TRUTH_GRAPH")
		return out
	var truth_graph: Dictionary = truth_graph_value as Dictionary
	if truth_graph.is_empty():
		out.append("EMPTY_TRUTH_GRAPH")
		return out

	for key in TRUTH_GRAPH_REQUIRED_KEYS:
		if not truth_graph.has(key):
			out.append("MISSING_TRUTH_GRAPH_KEY:%s" % key)
	for section_name in TRUTH_GRAPH_REQUIRED_SECTIONS:
		if not truth_graph.has(section_name):
			out.append("BAD_TRUTH_GRAPH_SECTION:%s" % section_name)
			continue
		var section_value: Variant = truth_graph.get(section_name, {})
		if not (section_value is Dictionary) or (section_value as Dictionary).is_empty():
			out.append("BAD_TRUTH_GRAPH_SECTION:%s" % section_name)
			continue
		var required_keys: Array[String] = []
		match section_name:
			"culpability":
				required_keys = TRUTH_GRAPH_CULPABILITY_KEYS
			"crime":
				required_keys = TRUTH_GRAPH_CRIME_KEYS
			"timeline":
				required_keys = TRUTH_GRAPH_TIMELINE_KEYS
			"opportunity":
				required_keys = TRUTH_GRAPH_OPPORTUNITY_KEYS
			"alibi":
				required_keys = TRUTH_GRAPH_ALIBI_KEYS
			"motive":
				required_keys = TRUTH_GRAPH_MOTIVE_KEYS
			"capability":
				required_keys = TRUTH_GRAPH_CAPABILITY_KEYS
			"relationship":
				required_keys = TRUTH_GRAPH_RELATIONSHIP_KEYS
		for section_key in required_keys:
			if not (section_value as Dictionary).has(section_key):
				out.append("BAD_TRUTH_GRAPH_KEY:%s.%s" % [section_name, section_key])

	var legacy_guilt_state: String = str(truth_bundle.get("guilt_state", ""))
	var culpability: Dictionary = truth_graph.get("culpability", {}) as Dictionary
	if not ["GUILTY", "INNOCENT", "FRAMED", "COMPLICIT"].has(legacy_guilt_state):
		out.append("BAD_TRUTH_GRAPH_GUILT_STATE")
	if legacy_guilt_state == "" or str(culpability.get("state", "")) != legacy_guilt_state:
		out.append("TRUTH_GRAPH_GUILT_MISMATCH")

	var twist_tags_value: Variant = truth_graph.get("twist_tags", [])
	if not (twist_tags_value is Array):
		out.append("BAD_TRUTH_GRAPH_TWIST_TAGS")
	else:
		var legacy_twist_tags: Variant = truth_bundle.get("twist_tags", [])
		if not (legacy_twist_tags is Array):
			out.append("TRUTH_GRAPH_LEGACY_MISMATCH:twist_tags")
		elif (legacy_twist_tags as Array) != (twist_tags_value as Array):
			out.append("TRUTH_GRAPH_LEGACY_MISMATCH:twist_tags")

	var relationship_graph: Dictionary = truth_bundle.get("relationship_graph", {}) as Dictionary
	if relationship_graph.is_empty():
		out.append("TRUTH_GRAPH_RELATIONSHIP_GRAPH_EMPTY")

	var facts: Dictionary = truth_bundle.get("facts", {}) as Dictionary
	for fact_key in ["time_window", "time_anchor", "location", "alibi_place", "tool"]:
		if not facts.has(fact_key) or str(facts.get(fact_key, "")).strip_edges() == "":
			out.append("TRUTH_GRAPH_FACTS_MISSING:%s" % fact_key)

	var crime: Dictionary = truth_graph.get("crime", {}) as Dictionary
	if str(crime.get("family", "")) != str(truth_bundle.get("crime_family", "")):
		out.append("TRUTH_GRAPH_LEGACY_MISMATCH:crime_family")
	if str(crime.get("type", "")) != str(truth_bundle.get("crime_type", "")):
		out.append("TRUTH_GRAPH_LEGACY_MISMATCH:crime_type")

	var alibi: Dictionary = truth_graph.get("alibi", {}) as Dictionary
	if str(alibi.get("truth", "")) != str(truth_bundle.get("alibi_truth", "")):
		out.append("TRUTH_GRAPH_LEGACY_MISMATCH:alibi")

	var opportunity: Dictionary = truth_graph.get("opportunity", {}) as Dictionary
	if str(opportunity.get("id", "")) != str(truth_bundle.get("opportunity", "")):
		out.append("TRUTH_GRAPH_LEGACY_MISMATCH:opportunity")

	var motive: Dictionary = truth_graph.get("motive", {}) as Dictionary
	if str(motive.get("id", "")) != str(truth_bundle.get("motive", "")):
		out.append("TRUTH_GRAPH_LEGACY_MISMATCH:motive")

	var relationship: Dictionary = truth_graph.get("relationship", {}) as Dictionary
	if str(relationship.get("id", "")) != str(truth_bundle.get("relationship", "")):
		out.append("TRUTH_GRAPH_LEGACY_MISMATCH:relationship")
	if str(relationship.get("contact_role", "")).strip_edges() == "" or str(relationship.get("contact_name", "")).strip_edges() == "":
		out.append("BAD_TRUTH_GRAPH_RELATIONSHIP_ENRICHMENT")

	var capability: Dictionary = truth_graph.get("capability", {}) as Dictionary
	if not (capability.get("access_tags", []) is Array):
		out.append("BAD_TRUTH_GRAPH_CAPABILITY")
	if not (capability.get("location_tags", []) is Array):
		out.append("BAD_TRUTH_GRAPH_CAPABILITY")
	if not (capability.get("skill_tags", []) is Array):
		out.append("BAD_TRUTH_GRAPH_CAPABILITY")
	if str(capability.get("exposure_band", "")).strip_edges() == "":
		out.append("BAD_TRUTH_GRAPH_CAPABILITY")

	return out

static func validate_anchor_guarantees(payload: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var suspect: Dictionary = payload.get("suspect", {}) as Dictionary
	var tabs: Dictionary = suspect.get("tabs", {}) as Dictionary
	var solid_anchors: Dictionary = {
		CaseEngineTypes.ANCHOR_TIMELINE: false,
		CaseEngineTypes.ANCHOR_ALIBI: false,
		CaseEngineTypes.ANCHOR_CAPABILITY: false,
		CaseEngineTypes.ANCHOR_MOTIVE: false,
		CaseEngineTypes.ANCHOR_RELATIONSHIP: false,
	}
	var any_anchors: Dictionary = {
		CaseEngineTypes.ANCHOR_TIMELINE: false,
		CaseEngineTypes.ANCHOR_ALIBI: false,
		CaseEngineTypes.ANCHOR_CAPABILITY: false,
		CaseEngineTypes.ANCHOR_MOTIVE: false,
		CaseEngineTypes.ANCHOR_RELATIONSHIP: false,
	}
	for tab_key in tabs.keys():
		var tabd: Dictionary = tabs.get(tab_key, {}) as Dictionary
		var facts: Array = tabd.get("facts", []) as Array
		for fact_v in facts:
			if not (fact_v is Dictionary):
				continue
			var fact: Dictionary = fact_v as Dictionary
			var anchor: String = str(fact.get("anchor", ""))
			if anchor == "" or not any_anchors.has(anchor):
				continue
			any_anchors[anchor] = true
			if str(fact.get("reliability", "")) == CaseEngineTypes.RELIABILITY_SOLID:
				solid_anchors[anchor] = true
	if not bool(solid_anchors.get(CaseEngineTypes.ANCHOR_TIMELINE, false)):
		out.append("MISSING_TIMELINE_ANCHOR")
	if not (
		bool(solid_anchors.get(CaseEngineTypes.ANCHOR_ALIBI, false))
		or bool(solid_anchors.get(CaseEngineTypes.ANCHOR_CAPABILITY, false))
	):
		out.append("MISSING_ALIBI_OR_CAPABILITY_ANCHOR")
	if not (
		bool(solid_anchors.get(CaseEngineTypes.ANCHOR_MOTIVE, false))
		or bool(solid_anchors.get(CaseEngineTypes.ANCHOR_RELATIONSHIP, false))
	):
		out.append("MISSING_MOTIVE_OR_RELATIONSHIP_ANCHOR")
	for anchor_name in any_anchors.keys():
		if bool(any_anchors.get(anchor_name, false)) and not bool(solid_anchors.get(anchor_name, false)):
			out.append("ANCHOR_ONLY_CORRUPTED:%s" % str(anchor_name))
	return out

static func validate_profile_bundle(profile: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key in REQUIRED_PROFILE_BUNDLE_KEYS:
		if not profile.has(key):
			out.append("MISSING_PROFILE_%s" % str(key).to_upper())
			continue
		var value: Variant = profile.get(key)
		if key == "latent_axes":
			if not (value is Dictionary) or (value as Dictionary).is_empty():
				out.append("EMPTY_PROFILE_%s" % str(key).to_upper())
		elif value is String and str(value).strip_edges() == "":
			out.append("EMPTY_PROFILE_%s" % str(key).to_upper())
		elif key in ["birth_day", "age_years"] and int(value) <= 0:
			out.append("EMPTY_PROFILE_%s" % str(key).to_upper())
	return out

static func validate_name_entry(entry: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key in REQUIRED_NAME_ENTRY_KEYS:
		if not entry.has(key):
			out.append("MISSING_NAME_%s" % str(key).to_upper())
	if str(entry.get("id", "")).strip_edges() == "":
		out.append("EMPTY_NAME_ID")
	if str(entry.get("label", "")).strip_edges() == "":
		out.append("EMPTY_NAME_LABEL")
	if int(entry.get("weight", 0)) <= 0:
		out.append("EMPTY_NAME_WEIGHT")
	if not (entry.get("tags", []) is Array):
		out.append("BAD_NAME_TAGS")
	if entry.has("kind") and not ["first", "last"].has(str(entry.get("kind", ""))):
		out.append("BAD_NAME_KIND")
	return out

static func validate_role_row(entry: Dictionary) -> Array[String]:
	var out: Array[String] = []
	out.append_array(_validate_required_keys("ROLE", entry, REQUIRED_ROLE_ROW_KEYS))
	for occ_v in entry.get("occupation_pool", []) as Array:
		if occ_v is Dictionary:
			out.append_array(validate_occupation_row(occ_v as Dictionary))
		else:
			out.append("BAD_ROLE_OCCUPATION_ENTRY")
	return out

static func validate_occupation_row(entry: Dictionary) -> Array[String]:
	return _validate_required_keys("OCCUPATION", entry, REQUIRED_OCCUPATION_ROW_KEYS)

static func validate_schedule_row(entry: Dictionary) -> Array[String]:
	return _validate_required_keys("SCHEDULE", entry, REQUIRED_SCHEDULE_ROW_KEYS)

static func validate_crime_type_row(entry: Dictionary) -> Array[String]:
	return _validate_required_keys("CRIME_TYPE", entry, REQUIRED_CRIME_TYPE_ROW_KEYS)

static func validate_relationship_row(entry: Dictionary) -> Array[String]:
	return _validate_required_keys("RELATIONSHIP", entry, REQUIRED_RELATIONSHIP_ARCHETYPE_KEYS)

static func validate_template_entry(entry: Dictionary) -> Array[String]:
	var out: Array[String] = []
	out.append_array(_validate_required_keys("TEMPLATE", entry, REQUIRED_TEMPLATE_KEYS))
	for slot_key in entry.get("slot_keys", []) as Array:
		if not (slot_key is String):
			out.append("BAD_TEMPLATE_SLOT_KEYS")
			break
	for truth_ref in entry.get("truth_refs", []) as Array:
		if not (truth_ref is String):
			out.append("BAD_TEMPLATE_TRUTH_REFS")
			break
	return out

static func validate_skeleton_entry(entry: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key in REQUIRED_SKELETON_KEYS:
		if not entry.has(key):
			out.append("MISSING_SKELETON_%s" % str(key).to_upper())
	if str(entry.get("id", "")).strip_edges() == "":
		out.append("EMPTY_SKELETON_ID")
	if str(entry.get("crime_family", "")).strip_edges() == "":
		out.append("EMPTY_SKELETON_CRIME_FAMILY")
	if str(entry.get("crime_type", "")).strip_edges() == "":
		out.append("EMPTY_SKELETON_CRIME_TYPE")
	if (entry.get("required_atoms", []) as Array).is_empty():
		out.append("EMPTY_SKELETON_REQUIRED_ATOMS")
	for atom_v in entry.get("required_atoms", []) as Array:
		if not (atom_v is Dictionary):
			out.append("BAD_SKELETON_REQUIRED_ATOM")
			continue
		var atom: Dictionary = atom_v as Dictionary
		if str(atom.get("tab", "")) == "" or str(atom.get("fact_type", "")) == "":
			out.append("BAD_SKELETON_REQUIRED_ATOM")
	for atom_v in entry.get("optional_atoms", []) as Array:
		if not (atom_v is Dictionary):
			out.append("BAD_SKELETON_OPTIONAL_ATOM")
	for seed_v in entry.get("conflict_seeds", []) as Array:
		if not (seed_v is Dictionary):
			out.append("BAD_SKELETON_CONFLICT_SEED")
			continue
		var seed: Dictionary = seed_v as Dictionary
		for key in ["group", "left", "right"]:
			if str(seed.get(key, "")) == "":
				out.append("BAD_SKELETON_CONFLICT_SEED")
				break
	return out

static func _validate_required_keys(prefix: String, entry: Dictionary, required_keys: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for key in required_keys:
		if not entry.has(key):
			out.append("MISSING_%s_%s" % [prefix, str(key).to_upper()])
			continue
		var value: Variant = entry.get(key)
		if value is String and str(value).strip_edges() == "":
			out.append("EMPTY_%s_%s" % [prefix, str(key).to_upper()])
		elif value is Array and (value as Array).is_empty():
			out.append("EMPTY_%s_%s" % [prefix, str(key).to_upper()])
		elif value is Dictionary and (value as Dictionary).is_empty():
			out.append("EMPTY_%s_%s" % [prefix, str(key).to_upper()])
	return out
