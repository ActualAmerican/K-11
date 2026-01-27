extends RefCounted
class_name SuspectFactory


const TAB_KEYS: Array[String] = ["ALIBI", "TIMELINE", "MOTIVE", "CAPABILITY", "PROFILE"]

static func generate(run_seed_u64: int, run_seed_text: String, suspect_index: int) -> SuspectData:
	var s: SuspectData = SuspectData.new()
	s.schema_version = SuspectData.SCHEMA_VERSION
	s.run_seed_u64 = run_seed_u64
	s.run_seed_text = run_seed_text
	s.suspect_index = suspect_index

	s.suspect_seed_u64 = SeedUtil.derive_seed(run_seed_u64, "suspect", suspect_index)
	var suspect_hex: String = SeedUtil.hex16(s.suspect_seed_u64)

	s.debug = {
		"suspect_seed_hex": suspect_hex,
		"subseeds": {}
	}

	# Stable id from seed (no content library needed for identity)
	s.id = "S-%s" % suspect_hex.substr(4, 12)

	_build_silhouette(s)
	_build_deadline(s)
	_build_truth(s)
	_build_charge_sheet(s)
	_build_tabs(s)

	return s

static func _build_silhouette(s: SuspectData) -> void:
	var seed: int = SeedUtil.derive_seed(s.suspect_seed_u64, "silhouette", 0)
	s.debug["subseeds"]["silhouette"] = SeedUtil.hex16(seed)
	var rng := SeedUtil.make_rng(seed)
	var idx: int = int(rng.randi_range(1, 10))
	s.silhouette_label = "SIL_%02d" % idx

static func _build_deadline(s: SuspectData) -> void:
	var seed: int = SeedUtil.derive_seed(s.suspect_seed_u64, "deadline", 0)
	s.debug["subseeds"]["deadline"] = SeedUtil.hex16(seed)
	var rng := SeedUtil.make_rng(seed)
	s.deadline_s = int(rng.randi_range(60, 90))

static func _build_truth(s: SuspectData) -> void:
	var seed: int = SeedUtil.derive_seed(s.suspect_seed_u64, "truth", 0)
	s.debug["subseeds"]["truth"] = SeedUtil.hex16(seed)
	var rng := SeedUtil.make_rng(seed)
	s.truth_guilty = bool(rng.randi_range(0, 1) == 1)

static func _build_charge_sheet(s: SuspectData) -> void:
	var seed: int = SeedUtil.derive_seed(s.suspect_seed_u64, "charge_sheet", 0)
	s.debug["subseeds"]["charge_sheet"] = SeedUtil.hex16(seed)
	var rng := SeedUtil.make_rng(seed)

	var case_id: String = "CASE-%04d" % int(rng.randi_range(1, 9999))

	var titles: Array[String] = [
		"Missing Intake Packet",
		"Archive Seal Irregularity",
		"Evidence Locker Discrepancy",
		"Unauthorized Terminal Access",
		"Chain-of-Custody Break"
	]
	var charges: Array[String] = [
		"Tampering with secured records",
		"Obstruction of audit process",
		"Unauthorized access to restricted area",
		"Falsification of procedural logs",
		"Negligent handling of controlled materials"
	]
	var briefs: Array[String] = [
		"A sealed packet was logged and then vanished before archiving.",
		"Two time-stamps conflict during a secured transfer window.",
		"An access record exists with no matching supervisor sign-off.",
		"An item moved between cabinets without a chain entry.",
		"A terminal session appears during a claimed absence."
	]

	var title: String = titles[int(rng.randi_range(0, titles.size() - 1))]
	var brief: String = briefs[int(rng.randi_range(0, briefs.size() - 1))]

	var n_charges: int = int(rng.randi_range(1, 3))
	var picked: Array[String] = []
	while picked.size() < n_charges:
		var c: String = charges[int(rng.randi_range(0, charges.size() - 1))]
		if not picked.has(c):
			picked.append(c)

	s.charge_sheet = {
		"case_id": case_id,
		"title": title,
		"charges": picked,
		"brief": brief
	}

static func _build_tabs(s: SuspectData) -> void:
	var tabs_out: Dictionary = {}
	for i in range(TAB_KEYS.size()):
		var tab: String = TAB_KEYS[i]
		var pool_seed: int = SeedUtil.derive_seed(s.suspect_seed_u64, "fact_pool", i)
		# Contract includes "fact pools" even if content is minimal
		tabs_out[tab] = {
			"tab": tab,
			"fact_pool_seed_u64": pool_seed,
			"facts": _build_min_facts(tab, pool_seed)
		}
	s.tabs = tabs_out

static func _build_min_facts(tab: String, pool_seed: int) -> Array[Dictionary]:
	var rng := SeedUtil.make_rng(pool_seed)

	var reliability: Array[String] = ["SOLID", "SOLID", "SOLID", "SHAKY", "CORRUPTED"]

	var facts: Array[Dictionary] = []
	# v0: 2 facts per tab (small, but proves the contract end-to-end)
	for j in range(2):
		var rel: String = reliability[int(rng.randi_range(0, reliability.size() - 1))]
		var text: String = _fact_text(tab, rng)
		facts.append({
			"fact_id": "%s-%d" % [tab.substr(0, 3), j],
			"tab": tab,
			"text": text,
			"reliability": rel,
			"conflict_group": ""
		})
	return facts

static func _fact_text(tab: String, rng: RandomNumberGenerator) -> String:
	match tab:
		"ALIBI":
			var where := ["intake desk", "records room", "hallway", "locker aisle", "terminal bay"]
			return "Claims they remained at the %s during the window." % where[int(rng.randi_range(0, where.size() - 1))]
		"TIMELINE":
			var a := int(rng.randi_range(19, 22))
			var b := int(rng.randi_range(10, 59))
			var c := int(rng.randi_range(10, 59))
			return "Two stamps appear: %02d:%02d and %02d:%02d, with no matching supervisor note." % [a, b, a, c]
		"MOTIVE":
			var why := ["disciplinary write-up", "denied transfer", "pay dock", "reassignment threat", "audit pressure"]
			return "Recent %s could explain risk-taking behavior." % why[int(rng.randi_range(0, why.size() - 1))]
		"CAPABILITY":
			var access := ["had cabinet access", "knew the lock code", "held the only spare key", "was alone on shift", "had badge clearance"]
			return "Operationally, they %s at the relevant time." % access[int(rng.randi_range(0, access.size() - 1))]
		"PROFILE":
			var tell := ["pauses on timestamps", "answers too quickly", "avoids direct eye contact", "mirrors phrasing", "changes tone mid-sentence"]
			return "Interview note: %s when pressed." % tell[int(rng.randi_range(0, tell.size() - 1))]
		_:
			return "No fact."
