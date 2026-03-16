@tool
extends RefCounted
class_name CaseEngineEntityGraph

const RELATIONSHIP_ARCHETYPES: Array[Dictionary] = [
	{"id":"manager","contact_role":"supervisor","label":"Manager Contact","tags":["internal","supervisor"],"weight":2},
	{"id":"coworker","contact_role":"coworker","label":"Coworker Contact","tags":["internal","peer"],"weight":2},
	{"id":"vendor_contact","contact_role":"vendor","label":"Vendor Contact","tags":["external","vendor"],"weight":1},
	{"id":"family_contact","contact_role":"family","label":"Family Contact","tags":["family","external"],"weight":1},
	{"id":"auditor_contact","contact_role":"auditor","label":"Auditor Contact","tags":["internal","oversight"],"weight":1},
	{"id":"subordinate_contact","contact_role":"subordinate","label":"Subordinate Contact","tags":["internal","hierarchy"],"weight":1},
	{"id":"lender_contact","contact_role":"lender","label":"Lender Contact","tags":["external","financial"],"weight":1},
	{"id":"former_partner","contact_role":"former_partner","label":"Former Partner","tags":["personal","external"],"weight":1},
	{"id":"friend_contact","contact_role":"friend","label":"Friend Contact","tags":["personal","social"],"weight":1},
	{"id":"neighbor_contact","contact_role":"neighbor","label":"Neighbor Contact","tags":["personal","local"],"weight":1},
]

static func build(run_seed_u64: int, suspect_index: int, reroll_index: int, truth_bundle: Dictionary) -> Dictionary:
	var graph_seed: int = SeedUtil.derive_seed(run_seed_u64, "entity_graph", suspect_index * 1000 + reroll_index)
	var rng: RandomNumberGenerator = SeedUtil.make_rng(graph_seed)
	var relationship: String = str(truth_bundle.get("relationship", ""))
	var profile_bundle: Dictionary = truth_bundle.get("profile_bundle", {}) as Dictionary
	var contact_role: String = _contact_role_from_relationship(relationship)
	var allowed_contact_roles: Array = CaseEngineProfileTables_v0.allowed_contact_roles(profile_bundle)
	var role_pool: Array[String] = ["witness", "supervisor", "coworker"]
	for role_v in allowed_contact_roles:
		var role_name: String = str(role_v)
		if role_name != "" and not role_pool.has(role_name):
			role_pool.append(role_name)
	if (profile_bundle.get("role_tags", []) as Array).has("finance") and not role_pool.has("auditor"):
		role_pool.append("auditor")
	if (profile_bundle.get("role_tags", []) as Array).has("internal_staff") and not role_pool.has("subordinate"):
		role_pool.append("subordinate")
	if (profile_bundle.get("latent_axes", {}) as Dictionary).get("defensiveness", "") == "high" and not role_pool.has("rival"):
		role_pool.append("rival")

	var ordered_roles: Array[String] = ["witness", "supervisor", "coworker"]
	for role_name in role_pool:
		if not ordered_roles.has(role_name):
			ordered_roles.append(role_name)

	var target_count: int = mini(maxi(3, 3 + rng.randi_range(0, 2)), 5)
	var selected_roles: Array[String] = []
	for role_name in ordered_roles:
		if selected_roles.size() >= target_count:
			break
		if role_name == contact_role or selected_roles.size() < 3 or rng.randf() < 0.65:
			if not selected_roles.has(role_name):
				selected_roles.append(role_name)
	if not selected_roles.has(contact_role):
		selected_roles.append(contact_role)

	var nodes: Dictionary = {}
	var used_name_ids: Dictionary = {}
	var role_to_node_ids: Dictionary = {}
	for role_name in selected_roles:
		var node_id: String = _next_node_id(role_name, role_to_node_ids)
		var node: Dictionary = _node(node_id, role_name, run_seed_u64, suspect_index, reroll_index, used_name_ids)
		nodes[node_id] = node
		if not role_to_node_ids.has(role_name):
			role_to_node_ids[role_name] = []
		(role_to_node_ids[role_name] as Array).append(node_id)

	var supervisor_id: String = _first_role_node(role_to_node_ids, "supervisor")
	var coworker_id: String = _first_role_node(role_to_node_ids, "coworker")
	var witness_id: String = _first_role_node(role_to_node_ids, "witness")
	var contact_node_id: String = _contact_node_id(role_to_node_ids, contact_role)
	var edges: Array[Dictionary] = []
	if supervisor_id != "":
		edges.append({"a":"E_SUS", "b":supervisor_id, "type":"reports_to"})
	if coworker_id != "":
		edges.append({"a":"E_SUS", "b":coworker_id, "type":"coworker"})
	if witness_id != "":
		edges.append({"a":"E_SUS", "b":witness_id, "type": _pick(["seen_by", "met_with", "mentioned_by"], rng)})
	if contact_node_id != "":
		edges.append({"a":"E_SUS", "b":contact_node_id, "type":"contact"})
	for role_name in role_to_node_ids.keys():
		var ids: Array = role_to_node_ids[role_name] as Array
		for i in range(ids.size() - 1):
			edges.append({"a":str(ids[i]), "b":str(ids[i + 1]), "type":"peer"})

	var slots: Dictionary = {
		"witness_name": _node_name(nodes, witness_id),
		"supervisor_name": _node_name(nodes, supervisor_id),
		"coworker_name": _node_name(nodes, coworker_id),
		"contact_role": contact_role,
		"contact_name": _contact_name(nodes, contact_node_id),
	}

	var graph: Dictionary = {
		"nodes": nodes,
		"edges": edges,
	}

	return {"graph": graph, "slots": slots}

static func _node(id: String, role: String, run_seed_u64: int, suspect_index: int, reroll_index: int, used_name_ids: Dictionary) -> Dictionary:
	var nm: Dictionary = CaseEngineNameProvider.name_for(role, run_seed_u64, suspect_index, reroll_index, id)
	var suffix: int = 0
	while used_name_ids.has(str(nm.get("name_id", ""))):
		suffix += 1
		nm = CaseEngineNameProvider.name_for(role, run_seed_u64, suspect_index, reroll_index + suffix, id)
	used_name_ids[str(nm.get("name_id", ""))] = true
	return {
		"id": id,
		"role": role,
		"name_id": str(nm.get("name_id", "")),
		"name_text": str(nm.get("name_text", "")),
	}

static func _contact_role_from_relationship(rel: String) -> String:
	return contact_role_for_relationship(rel)

static func contact_role_for_relationship(rel: String) -> String:
	for row_v in RELATIONSHIP_ARCHETYPES:
		var row: Dictionary = row_v as Dictionary
		if str(row.get("id", "")) == rel:
			return str(row.get("contact_role", "contact"))
	return "contact"

static func _contact_name(nodes: Dictionary, node_id: String) -> String:
	if node_id == "":
		return ""
	var n: Dictionary = nodes.get(node_id, {}) as Dictionary
	return str(n.get("name_text", ""))

static func _node_name(nodes: Dictionary, node_id: String) -> String:
	if node_id == "":
		return ""
	var node: Dictionary = nodes.get(node_id, {}) as Dictionary
	return str(node.get("name_text", ""))

static func _pick(values: Array[String], rng: RandomNumberGenerator) -> String:
	if values.is_empty():
		return ""
	return values[rng.randi_range(0, values.size() - 1)]

static func _next_node_id(role_name: String, role_to_node_ids: Dictionary) -> String:
	var prefix_map: Dictionary = {
		"witness": "E_WIT",
		"supervisor": "E_SUP",
		"coworker": "E_COW",
		"vendor": "E_VEN",
		"family": "E_FAM",
		"auditor": "E_AUD",
		"rival": "E_RIV",
		"subordinate": "E_SUB",
		"lender": "E_LEN",
		"former_partner": "E_EXP",
		"friend": "E_FRD",
		"neighbor": "E_NBR",
	}
	var prefix: String = str(prefix_map.get(role_name, "E_CON"))
	var count: int = 1
	if role_to_node_ids.has(role_name):
		count = (role_to_node_ids[role_name] as Array).size() + 1
	return prefix if count == 1 else "%s_%02d" % [prefix, count]

static func _first_role_node(role_to_node_ids: Dictionary, role_name: String) -> String:
	if not role_to_node_ids.has(role_name):
		return ""
	var ids: Array = role_to_node_ids[role_name] as Array
	return "" if ids.is_empty() else str(ids[0])

static func _contact_node_id(role_to_node_ids: Dictionary, contact_role: String) -> String:
	var preferred_role: String = contact_role
	if preferred_role == "contact":
		for fallback_role in ["vendor", "family", "coworker", "supervisor", "witness"]:
			var candidate: String = _first_role_node(role_to_node_ids, fallback_role)
			if candidate != "":
				return candidate
		return ""
	return _first_role_node(role_to_node_ids, preferred_role)

static func all_relationship_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in RELATIONSHIP_ARCHETYPES:
		out.append((row as Dictionary).duplicate(true))
	return out

static func validate_tables() -> Array[String]:
	var out: Array[String] = []
	for row in all_relationship_rows():
		for code in CaseEngineContracts.validate_relationship_row(row):
			out.append(code)
	return out
