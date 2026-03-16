@tool
extends RefCounted
class_name CaseFolderRender

static func build_pages(case_payload: Dictionary, show_truth: bool = false) -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	pages.append(_page("CHARGE_SHEET", "Charge Sheet", render_charge_sheet(case_payload), "FOLDER", true))
	pages.append(_page("DOSSIER", "Dossier", render_dossier_summary(case_payload), "FOLDER", true))
	pages.append(_page("PROFILE", "Profile", render_profile_page(case_payload), "FOLDER", true))
	pages.append(_page("PROFILE_NOTES", "Profile Notes", render_profile_notes_page(case_payload), "EVIDENCE", true))
	pages.append(_page("ALIBI", "Alibi Evidence", render_evidence_page(case_payload, "ALIBI"), "EVIDENCE", true))
	pages.append(_page("TIMELINE", "Timeline Evidence", render_evidence_page(case_payload, "TIMELINE"), "EVIDENCE", true))
	pages.append(_page("CAPABILITY", "Capability Evidence", render_evidence_page(case_payload, "CAPABILITY"), "EVIDENCE", true))
	pages.append(_page("MOTIVE", "Motive Evidence", render_evidence_page(case_payload, "MOTIVE"), "EVIDENCE", true))
	if show_truth:
		pages.append(_page("DEV_APPENDIX", "DEV Appendix", render_dev_appendix(case_payload, "DEV_APPENDIX"), "DEV", false))
	return pages

static func render_page_text(case_payload: Dictionary, page_id: String, show_truth: bool = false) -> String:
	var pages: Array[Dictionary] = build_pages(case_payload, show_truth)
	for page_v in pages:
		var page: Dictionary = page_v as Dictionary
		if str(page.get("page_id", "")) == page_id:
			return str(page.get("body", ""))
	return ""

static func build_spreads(case_payload: Dictionary, show_truth: bool = false) -> Array[Dictionary]:
	var pages_by_id: Dictionary = {}
	var pages: Array[Dictionary] = build_pages(case_payload, show_truth)
	for page_v in pages:
		var page: Dictionary = page_v as Dictionary
		pages_by_id[str(page.get("page_id", ""))] = page

	var spreads: Array[Dictionary] = []
	spreads.append(_spread("Spread 1", _page_or_blank(pages_by_id, "CHARGE_SHEET"), _page_or_blank(pages_by_id, "DOSSIER")))
	spreads.append(_spread("Spread 2", _page_or_blank(pages_by_id, "PROFILE"), _page_or_blank(pages_by_id, "PROFILE_NOTES")))
	spreads.append(_spread("Spread 3", _page_or_blank(pages_by_id, "ALIBI"), _page_or_blank(pages_by_id, "TIMELINE")))
	spreads.append(_spread("Spread 4", _page_or_blank(pages_by_id, "CAPABILITY"), _page_or_blank(pages_by_id, "MOTIVE")))
	var right_page: Dictionary = _blank_page()
	if show_truth and pages_by_id.has("DEV_APPENDIX"):
		right_page = pages_by_id.get("DEV_APPENDIX", {}) as Dictionary
	spreads.append(_spread("Spread 5", _blank_page(), right_page))
	return spreads

static func render_charge_sheet(case_payload: Dictionary) -> String:
	var suspect: Dictionary = case_payload.get("suspect", {}) as Dictionary
	var charge_sheet: Dictionary = suspect.get("charge_sheet", {}) as Dictionary
	if charge_sheet.is_empty():
		return "No case file available."

	var lines: Array[String] = []
	var title: String = str(charge_sheet.get("title", ""))
	if title != "":
		lines.append(title)

	var charges: Array = charge_sheet.get("charges", []) as Array
	if not charges.is_empty():
		lines.append("")
		lines.append("Charges")
		for charge in charges:
			lines.append("- %s" % str(charge))

	var brief: String = str(charge_sheet.get("brief", ""))
	if brief != "":
		lines.append("")
		lines.append(brief)

	var deadline_s: int = int(suspect.get("deadline_s", 0))
	if deadline_s > 0:
		lines.append("")
		lines.append("Response Window: %ds" % deadline_s)

	var silhouette_label: String = str(suspect.get("silhouette_label", ""))
	if silhouette_label != "":
		lines.append("Subject Marker: %s" % silhouette_label)
	return "\n".join(lines)

static func render_dossier_summary(case_payload: Dictionary) -> String:
	var suspect: Dictionary = case_payload.get("suspect", {}) as Dictionary
	if suspect.is_empty():
		return "No dossier available."

	var lines: Array[String] = []
	var silhouette_label: String = str(suspect.get("silhouette_label", ""))
	if silhouette_label != "":
		lines.append("Subject Marker: %s" % silhouette_label)

	var truth_bundle: Dictionary = case_payload.get("truth_bundle", {}) as Dictionary
	var profile_bundle: Dictionary = truth_bundle.get("profile_bundle", {}) as Dictionary
	if not profile_bundle.is_empty():
		var human_profile: Dictionary = CaseEngineProfileTables_v0.human_profile_fields(profile_bundle)
		var full_name: String = str(profile_bundle.get("full_name", ""))
		var assignment_label: String = str(profile_bundle.get("assignment_label", ""))
		var occupation: String = str(human_profile.get("occupation", ""))
		var role_family: String = str(human_profile.get("role_family", ""))
		var schedule_label: String = str(profile_bundle.get("schedule_label", human_profile.get("schedule", "")))
		var tenure_label: String = str(profile_bundle.get("tenure_label", human_profile.get("tenure", "")))
		if full_name != "":
			lines.append("Name: %s" % full_name)
		if assignment_label != "":
			lines.append("Assignment: %s" % assignment_label)
		elif occupation != "":
			lines.append("Assignment: %s" % occupation)
		elif role_family != "":
			lines.append("Assignment: %s" % role_family)
		if schedule_label != "":
			lines.append("Schedule: %s" % schedule_label)
		if tenure_label != "":
			lines.append("Tenure: %s" % tenure_label)

	var deadline_s: int = int(suspect.get("deadline_s", 0))
	if deadline_s > 0:
		lines.append("Review Window: %ds" % deadline_s)
	return "\n".join(lines)

static func render_profile_page(case_payload: Dictionary) -> String:
	var lines: Array[String] = []
	var suspect: Dictionary = case_payload.get("suspect", {}) as Dictionary
	var truth_bundle: Dictionary = case_payload.get("truth_bundle", {}) as Dictionary
	var profile_bundle: Dictionary = truth_bundle.get("profile_bundle", {}) as Dictionary
	lines.append("Subject Profile Card")
	lines.append("")
	var silhouette_label: String = str(suspect.get("silhouette_label", ""))
	if silhouette_label != "":
		lines.append("Subject Marker: %s" % silhouette_label)
	for field_name in CaseEngineContracts.profile_card_visible_fields():
		if field_name == "birth_day":
			continue
		var label: String = _profile_card_label(str(field_name))
		var value: String = _profile_card_value(profile_bundle, str(field_name))
		lines.append("%s: %s" % [label, _fallback_text(value)])
	return "\n".join(lines)

static func render_profile_notes_page(case_payload: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Profile Notes")
	lines.append("")
	var facts: Array = _facts_for_tab(case_payload, "PROFILE")
	if facts.is_empty():
		lines.append("No profile notes recorded.")
		return "\n".join(lines)
	for fact_v in facts:
		if fact_v is Dictionary:
			var fact: Dictionary = fact_v as Dictionary
			lines.append("%s %s" % [_reliability_badge(str(fact.get("reliability", ""))), str(fact.get("text", ""))])
	return "\n".join(lines)

static func render_evidence_page(case_payload: Dictionary, tab_id: String) -> String:
	var lines: Array[String] = []
	lines.append("%s Evidence" % _humanize_tab(tab_id))
	lines.append("")
	var facts: Array = _facts_for_tab(case_payload, tab_id)
	if facts.is_empty():
		lines.append("No entries recorded.")
		return "\n".join(lines)
	for fact_v in facts:
		if fact_v is Dictionary:
			var fact: Dictionary = fact_v as Dictionary
			var conflict_group: String = str(fact.get("conflict_group", ""))
			var marker: String = " ( )" if conflict_group != "" else ""
			lines.append("%s %s%s" % [_reliability_badge(str(fact.get("reliability", ""))), str(fact.get("text", "")), marker])
	return "\n".join(lines)

static func render_dev_appendix(case_payload: Dictionary, page: String, tab_id: String = "") -> String:
	var truth_bundle: Dictionary = case_payload.get("truth_bundle", {}) as Dictionary
	var lines: Array[String] = []
	lines.append("DEV Appendix")
	lines.append("Page: %s" % _humanize_token(page))
	if tab_id != "":
		lines.append("Tab: %s" % _humanize_tab(tab_id))

	if truth_bundle.is_empty():
		lines.append("No truth bundle available.")
		return "\n".join(lines)

	lines.append("Guilt State: %s" % str(truth_bundle.get("guilt_state", "")))
	lines.append("Crime Family: %s" % _humanize_token(str(truth_bundle.get("crime_family", ""))))
	lines.append("Crime Type: %s" % _humanize_token(str(truth_bundle.get("crime_type", ""))))
	lines.append("Opportunity: %s" % _humanize_token(str(truth_bundle.get("opportunity", ""))))
	lines.append("Alibi Truth: %s" % _humanize_token(str(truth_bundle.get("alibi_truth", ""))))
	lines.append("Motive: %s" % _humanize_token(str(truth_bundle.get("motive", ""))))
	lines.append("Relationship: %s" % _humanize_token(str(truth_bundle.get("relationship", ""))))
	lines.append("Variant Skeleton: %s" % str(truth_bundle.get("variant_skeleton_id", "")))
	lines.append("Fingerprint: %s" % str(case_payload.get("fingerprint", "")))

	var profile_bundle: Dictionary = truth_bundle.get("profile_bundle", {}) as Dictionary
	if not profile_bundle.is_empty():
		lines.append("")
		lines.append("Profile Bundle")
		lines.append(" Role Family: %s" % _humanize_token(str(profile_bundle.get("role_family", ""))))
		lines.append(" Schedule: %s" % _humanize_token(str(profile_bundle.get("schedule_tag", ""))))
		lines.append(" Tenure: %s" % _humanize_token(str(profile_bundle.get("tenure_band", ""))))
		lines.append(" Life Stage: %s" % _humanize_token(str(profile_bundle.get("life_stage", ""))))

	var conflict_audit: Dictionary = truth_bundle.get("conflict_audit", {}) as Dictionary
	if not conflict_audit.is_empty():
		lines.append("")
		lines.append("Conflict Audit")
		var repaired: Array = conflict_audit.get("repaired_groups", []) as Array
		var failed: Array = conflict_audit.get("failed_groups", []) as Array
		lines.append(" Repaired: %s" % _join_values(repaired))
		lines.append(" Failed: %s" % _join_values(failed))

	return "\n".join(lines)

static func _page(page_id: String, title: String, body: String, section: String, player_facing: bool) -> Dictionary:
	return {
		"page_id": page_id,
		"title": title,
		"body": body,
		"section": section,
		"player_facing": player_facing,
	}

static func _spread(title: String, left_page: Dictionary, right_page: Dictionary) -> Dictionary:
	return {
		"title": title,
		"left_page": left_page,
		"right_page": right_page,
	}

static func _page_or_blank(pages_by_id: Dictionary, page_id: String) -> Dictionary:
	if pages_by_id.has(page_id):
		return pages_by_id.get(page_id, {}) as Dictionary
	return _blank_page()

static func _blank_page() -> Dictionary:
	return _page("", "", "", "BLANK", true)

static func _facts_for_tab(case_payload: Dictionary, tab_id: String) -> Array:
	var suspect: Dictionary = case_payload.get("suspect", {}) as Dictionary
	var tabs: Dictionary = suspect.get("tabs", {}) as Dictionary
	var tabd: Dictionary = tabs.get(tab_id, {}) as Dictionary
	return tabd.get("facts", []) as Array

static func _humanize_tab(tab_id: String) -> String:
	match tab_id:
		"ALIBI":
			return "Alibi"
		"TIMELINE":
			return "Timeline"
		"MOTIVE":
			return "Motive"
		"CAPABILITY":
			return "Capability"
		"PROFILE":
			return "Profile"
		_:
			return _humanize_token(tab_id)

static func _reliability_badge(reliability: String) -> String:
	match reliability.strip_edges().to_upper():
		"SOLID":
			return "[Solid]"
		"SHAKY", "QUESTIONABLE":
			return "[Shaky]"
		"CORRUPTED":
			return "[Corrupted]"
		_:
			return "[Unknown]"

static func _humanize_token(token: String) -> String:
	if token == "":
		return ""
	var parts: PackedStringArray = token.replace("-", "_").split("_", false)
	for i in range(parts.size()):
		parts[i] = parts[i].capitalize()
	return " ".join(parts)

static func _join_values(values: Array) -> String:
	if values.is_empty():
		return "(none)"
	var out: PackedStringArray = []
	for value in values:
		out.append(str(value))
	return ", ".join(out)

static func _fallback_text(value: String) -> String:
	if value.strip_edges() == "":
		return "Not listed"
	return value

static func _humanize_dependents(value: String) -> String:
	match value:
		"0":
			return "0"
		"1_2":
			return "1-2"
		"3_plus":
			return "3+"
		_:
			return _humanize_token(value)

static func _profile_card_label(field_name: String) -> String:
	match field_name:
		"full_name":
			return "Name"
		"age_years":
			return "Age"
		"birth_month":
			return "Birthday"
		"occupation_label":
			return "Occupation"
		"assignment_label":
			return "Assignment"
		"family_status":
			return "Family Status"
		"dependents_band":
			return "Dependents"
		"schedule_label":
			return "Schedule"
		"tenure_label":
			return "Tenure"
		"temperament":
			return "Temperament"
		"criminal_history_label":
			return "Criminal Record"
		_:
			return _humanize_token(field_name)

static func _profile_card_value(profile_bundle: Dictionary, field_name: String) -> String:
	match field_name:
		"full_name":
			return str(profile_bundle.get("full_name", ""))
		"age_years":
			var age_years: int = int(profile_bundle.get("age_years", 0))
			return "" if age_years <= 0 else str(age_years)
		"birth_month":
			var birth_month: String = str(profile_bundle.get("birth_month", ""))
			var birth_day: int = int(profile_bundle.get("birth_day", 0))
			if birth_month == "" or birth_day <= 0:
				return ""
			return "%s %d" % [birth_month, birth_day]
		"occupation_label":
			return str(profile_bundle.get("occupation_label", ""))
		"assignment_label":
			return str(profile_bundle.get("assignment_label", ""))
		"family_status":
			return _humanize_token(str(profile_bundle.get("family_status", "")))
		"dependents_band":
			return _humanize_dependents(str(profile_bundle.get("dependents_band", "")))
		"schedule_label":
			return str(profile_bundle.get("schedule_label", ""))
		"tenure_label":
			return str(profile_bundle.get("tenure_label", ""))
		"temperament":
			return str(profile_bundle.get("temperament_label", profile_bundle.get("temperament", "")))
		"criminal_history_label":
			return str(profile_bundle.get("criminal_history_label", ""))
		_:
			return str(profile_bundle.get(field_name, ""))

static func validate_render_contract() -> Array[String]:
	var out: Array[String] = []
	var visible_fields: Array[String] = CaseEngineContracts.profile_card_visible_fields()
	for field_name in visible_fields:
		if CaseEngineContracts.PROFILE_CARD_HIDDEN_FIELDS.has(field_name):
			out.append("VISIBLE_FIELD_IS_HIDDEN:%s" % field_name)
		if _profile_card_label(field_name).strip_edges() == "":
			out.append("MISSING_PROFILE_CARD_LABEL:%s" % field_name)
	var profile_page: String = render_profile_page({"suspect": {}, "truth_bundle": {"profile_bundle": {}}})
	if profile_page.find("[Solid]") >= 0 or profile_page.find("[Shaky]") >= 0 or profile_page.find("[Corrupted]") >= 0:
		out.append("PROFILE_CARD_RELIABILITY_LEAK")
	return out
