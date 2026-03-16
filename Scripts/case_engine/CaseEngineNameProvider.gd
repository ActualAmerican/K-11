@tool
extends RefCounted
class_name CaseEngineNameProvider

const FIRST_NAME_ROWS: Array[Dictionary] = [
	{"id":"evelyn","label":"Evelyn","kind":"first","weight":1,"tags":[]},
	{"id":"marcus","label":"Marcus","kind":"first","weight":1,"tags":[]},
	{"id":"talia","label":"Talia","kind":"first","weight":1,"tags":[]},
	{"id":"noah","label":"Noah","kind":"first","weight":1,"tags":[]},
	{"id":"mina","label":"Mina","kind":"first","weight":1,"tags":[]},
	{"id":"jared","label":"Jared","kind":"first","weight":1,"tags":[]},
	{"id":"leah","label":"Leah","kind":"first","weight":1,"tags":[]},
	{"id":"victor","label":"Victor","kind":"first","weight":1,"tags":[]},
	{"id":"rina","label":"Rina","kind":"first","weight":1,"tags":[]},
	{"id":"damon","label":"Damon","kind":"first","weight":1,"tags":[]},
	{"id":"iris","label":"Iris","kind":"first","weight":1,"tags":[]},
	{"id":"caleb","label":"Caleb","kind":"first","weight":1,"tags":[]},
	{"id":"nadia","label":"Nadia","kind":"first","weight":1,"tags":[]},
	{"id":"julian","label":"Julian","kind":"first","weight":1,"tags":[]},
	{"id":"avery","label":"Avery","kind":"first","weight":1,"tags":[]},
	{"id":"selene","label":"Selene","kind":"first","weight":1,"tags":[]},
	{"id":"marlowe","label":"Marlowe","kind":"first","weight":1,"tags":[]},
	{"id":"imani","label":"Imani","kind":"first","weight":1,"tags":[]},
	{"id":"owen","label":"Owen","kind":"first","weight":1,"tags":[]},
	{"id":"sabrina","label":"Sabrina","kind":"first","weight":1,"tags":[]},
	{"id":"elias","label":"Elias","kind":"first","weight":1,"tags":[]},
	{"id":"kiara","label":"Kiara","kind":"first","weight":1,"tags":[]},
	{"id":"reed","label":"Reed","kind":"first","weight":1,"tags":[]},
	{"id":"bianca","label":"Bianca","kind":"first","weight":1,"tags":[]},
	{"id":"samir","label":"Samir","kind":"first","weight":1,"tags":[]},
	{"id":"helena","label":"Helena","kind":"first","weight":1,"tags":[]},
	{"id":"peter","label":"Peter","kind":"first","weight":1,"tags":[]},
	{"id":"yasmin","label":"Yasmin","kind":"first","weight":1,"tags":[]},
	{"id":"connor","label":"Connor","kind":"first","weight":1,"tags":[]},
	{"id":"farah","label":"Farah","kind":"first","weight":1,"tags":[]},
]

const LAST_NAME_ROWS: Array[Dictionary] = [
	{"id":"vale","label":"Vale","kind":"last","weight":1,"tags":[]},
	{"id":"mercer","label":"Mercer","kind":"last","weight":1,"tags":[]},
	{"id":"navarro","label":"Navarro","kind":"last","weight":1,"tags":[]},
	{"id":"quinn","label":"Quinn","kind":"last","weight":1,"tags":[]},
	{"id":"dawes","label":"Dawes","kind":"last","weight":1,"tags":[]},
	{"id":"sato","label":"Sato","kind":"last","weight":1,"tags":[]},
	{"id":"bennett","label":"Bennett","kind":"last","weight":1,"tags":[]},
	{"id":"hale","label":"Hale","kind":"last","weight":1,"tags":[]},
	{"id":"marin","label":"Marin","kind":"last","weight":1,"tags":[]},
	{"id":"kessler","label":"Kessler","kind":"last","weight":1,"tags":[]},
	{"id":"wren","label":"Wren","kind":"last","weight":1,"tags":[]},
	{"id":"talbot","label":"Talbot","kind":"last","weight":1,"tags":[]},
	{"id":"morrow","label":"Morrow","kind":"last","weight":1,"tags":[]},
	{"id":"singh","label":"Singh","kind":"last","weight":1,"tags":[]},
	{"id":"foster","label":"Foster","kind":"last","weight":1,"tags":[]},
	{"id":"keane","label":"Keane","kind":"last","weight":1,"tags":[]},
	{"id":"ortega","label":"Ortega","kind":"last","weight":1,"tags":[]},
	{"id":"pryor","label":"Pryor","kind":"last","weight":1,"tags":[]},
	{"id":"ibarra","label":"Ibarra","kind":"last","weight":1,"tags":[]},
	{"id":"redding","label":"Redding","kind":"last","weight":1,"tags":[]},
	{"id":"cho","label":"Cho","kind":"last","weight":1,"tags":[]},
	{"id":"visser","label":"Visser","kind":"last","weight":1,"tags":[]},
	{"id":"abbas","label":"Abbas","kind":"last","weight":1,"tags":[]},
	{"id":"locke","label":"Locke","kind":"last","weight":1,"tags":[]},
	{"id":"pereira","label":"Pereira","kind":"last","weight":1,"tags":[]},
	{"id":"houle","label":"Houle","kind":"last","weight":1,"tags":[]},
	{"id":"reed","label":"Reed","kind":"last","weight":1,"tags":[]},
	{"id":"carmichael","label":"Carmichael","kind":"last","weight":1,"tags":[]},
	{"id":"abbott","label":"Abbott","kind":"last","weight":1,"tags":[]},
	{"id":"solis","label":"Solis","kind":"last","weight":1,"tags":[]},
]

const ROLE_PREFIXES: Dictionary = {
	"supervisor": ["Supervisor", "Lead"],
	"vendor": ["Vendor Rep"],
	"family": ["Family Contact"],
	"auditor": ["Auditor"],
}

static func name_for(role: String, run_seed_u64: int, suspect_index: int, reroll_index: int, entity_id: String) -> Dictionary:
	var seed: int = SeedUtil.derive_seed(run_seed_u64, "name:%s:%s" % [role, entity_id], suspect_index * 1000 + reroll_index)
	var rng: RandomNumberGenerator = SeedUtil.make_rng(seed)
	var combo_count: int = FIRST_NAME_ROWS.size() * LAST_NAME_ROWS.size()
	var base_combo: int = rng.randi_range(0, maxi(combo_count - 1, 0))
	var combo_index: int = (base_combo + _entity_slot(entity_id)) % maxi(combo_count, 1)
	var first_index: int = int(combo_index / maxi(LAST_NAME_ROWS.size(), 1))
	var last_index: int = combo_index % maxi(LAST_NAME_ROWS.size(), 1)
	var first_row: Dictionary = FIRST_NAME_ROWS[first_index]
	var last_row: Dictionary = LAST_NAME_ROWS[last_index]
	var first_name: String = str(first_row.get("label", ""))
	var last_name: String = str(last_row.get("label", ""))
	var prefixes: Array = ROLE_PREFIXES.get(role, []) as Array
	var prefix: String = ""
	if not prefixes.is_empty():
		prefix = str(prefixes[rng.randi_range(0, prefixes.size() - 1)])
	var name_id: String = "%s:%s:%s:%s" % [role, str(first_row.get("id", "")), str(last_row.get("id", "")), entity_id.to_lower()]
	var name_text: String = "%s %s" % [first_name, last_name]
	if prefix != "":
		name_text = "%s %s" % [prefix, name_text]
	return {
		"name_id": name_id,
		"first_name": first_name,
		"last_name": last_name,
		"full_name": "%s %s" % [first_name, last_name],
		"name_text": name_text,
	}

static func _entity_slot(entity_id: String) -> int:
	match entity_id:
		"E_SUS":
			return 0
		"E_WIT":
			return 1
		"E_SUP":
			return 2
		"E_COW":
			return 3
		"E_CON":
			return 4
		"E_AUD":
			return 5
		"E_RIV":
			return 6
		"E_SUB":
			return 7
		_:
			return abs(entity_id.hash()) % maxi(FIRST_NAME_ROWS.size() * LAST_NAME_ROWS.size(), 1)

static func all_name_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in FIRST_NAME_ROWS:
		out.append(row.duplicate(true))
	for row in LAST_NAME_ROWS:
		out.append(row.duplicate(true))
	return out

static func validate_tables() -> Array[String]:
	var out: Array[String] = []
	for row in all_name_entries():
		for code in CaseEngineContracts.validate_name_entry(row):
			out.append(code)
	return out
