@tool
extends RefCounted
class_name CaseEngineSkeletons_v0

static func choose(crime_family: String, crime_type: String, run_seed_u64: int, suspect_index: int, reroll_index: int) -> Dictionary:
	var all: Array[Dictionary] = _all()
	var matches: Array[Dictionary] = []

	for s in all:
		if str(s.get("crime_family", "")) == crime_family and str(s.get("crime_type", "")) == crime_type:
			matches.append(s)

	if matches.is_empty():
		return {}

	var seed := SeedUtil.derive_seed(run_seed_u64, "skeleton:%s:%s" % [crime_family, crime_type], suspect_index * 1000 + reroll_index)
	var rng := SeedUtil.make_rng(seed)
	return matches[rng.randi_range(0, matches.size() - 1)]

static func _all() -> Array[Dictionary]:
	return [
		{
			"id": "fraud_invoice_manipulation_v0_a",
			"crime_family": "fraud",
			"crime_type": "invoice_manipulation",
			"required_atoms": [
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_ANCHOR, "anchor": CaseEngineTypes.ANCHOR_TIMELINE},
				{"tab": CaseEngineTypes.TAB_ALIBI, "fact_type": CaseEngineTypes.FACT_ALIBI_WITNESS, "anchor": CaseEngineTypes.ANCHOR_ALIBI},
				{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_ACCESS, "anchor": CaseEngineTypes.ANCHOR_CAPABILITY},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_RELATIONSHIP, "anchor": CaseEngineTypes.ANCHOR_RELATIONSHIP}
			],
			"optional_atoms": [
				{"tab": CaseEngineTypes.TAB_PROFILE, "fact_type": CaseEngineTypes.FACT_PROFILE_BEHAVIOR},
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_NOTE},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_PRESSURE}
			],
			"conflict_seeds": [
				{
					"group": "cg_invoice_timeline",
					"left": CaseEngineTypes.FACT_TIMELINE_ANCHOR,
					"right": CaseEngineTypes.FACT_ALIBI_WITNESS,
					"prefer_anchor": CaseEngineTypes.ANCHOR_TIMELINE,
					"prefer_fact_type": CaseEngineTypes.FACT_TIMELINE_ANCHOR
				},
				{
					"group": "cg_invoice_access",
					"left": CaseEngineTypes.FACT_CAPABILITY_ACCESS,
					"right": CaseEngineTypes.FACT_PROFILE_BEHAVIOR,
					"prefer_anchor": CaseEngineTypes.ANCHOR_CAPABILITY,
					"prefer_fact_type": CaseEngineTypes.FACT_CAPABILITY_ACCESS
				}
			],
			"chains": []
		},
		{
			"id": "embezzlement_ledger_drift_v0_a",
			"crime_family": "embezzlement",
			"crime_type": "ledger_drift",
			"required_atoms": [
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_ANCHOR, "anchor": CaseEngineTypes.ANCHOR_TIMELINE},
				{"tab": CaseEngineTypes.TAB_ALIBI, "fact_type": CaseEngineTypes.FACT_ALIBI_WITNESS, "anchor": CaseEngineTypes.ANCHOR_ALIBI},
				{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_ACCESS, "anchor": CaseEngineTypes.ANCHOR_CAPABILITY},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_RELATIONSHIP, "anchor": CaseEngineTypes.ANCHOR_RELATIONSHIP}
			],
			"optional_atoms": [
				{"tab": CaseEngineTypes.TAB_PROFILE, "fact_type": CaseEngineTypes.FACT_PROFILE_BEHAVIOR},
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_NOTE},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_PRESSURE}
			],
			"conflict_seeds": [
				{
					"group": "cg_ledger_timeline",
					"left": CaseEngineTypes.FACT_TIMELINE_ANCHOR,
					"right": CaseEngineTypes.FACT_ALIBI_WITNESS,
					"prefer_anchor": CaseEngineTypes.ANCHOR_TIMELINE,
					"prefer_fact_type": CaseEngineTypes.FACT_TIMELINE_ANCHOR
				},
				{
					"group": "cg_ledger_access",
					"left": CaseEngineTypes.FACT_CAPABILITY_ACCESS,
					"right": CaseEngineTypes.FACT_PROFILE_BEHAVIOR,
					"prefer_anchor": CaseEngineTypes.ANCHOR_CAPABILITY,
					"prefer_fact_type": CaseEngineTypes.FACT_CAPABILITY_ACCESS
				}
			],
			"chains": []
		},
		{
			"id": "sabotage_sensor_tamper_v0_a",
			"crime_family": "sabotage",
			"crime_type": "sensor_tamper",
			"required_atoms": [
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_ANCHOR, "anchor": CaseEngineTypes.ANCHOR_TIMELINE},
				{"tab": CaseEngineTypes.TAB_ALIBI, "fact_type": CaseEngineTypes.FACT_ALIBI_WITNESS, "anchor": CaseEngineTypes.ANCHOR_ALIBI},
				{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_ACCESS, "anchor": CaseEngineTypes.ANCHOR_CAPABILITY},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_RELATIONSHIP, "anchor": CaseEngineTypes.ANCHOR_RELATIONSHIP}
			],
			"optional_atoms": [
				{"tab": CaseEngineTypes.TAB_PROFILE, "fact_type": CaseEngineTypes.FACT_PROFILE_BEHAVIOR},
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_NOTE},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_PRESSURE}
			],
			"conflict_seeds": [
				{
					"group": "cg_sensor_timeline",
					"left": CaseEngineTypes.FACT_TIMELINE_ANCHOR,
					"right": CaseEngineTypes.FACT_ALIBI_WITNESS,
					"prefer_anchor": CaseEngineTypes.ANCHOR_TIMELINE,
					"prefer_fact_type": CaseEngineTypes.FACT_TIMELINE_ANCHOR
				},
				{
					"group": "cg_sensor_access",
					"left": CaseEngineTypes.FACT_CAPABILITY_ACCESS,
					"right": CaseEngineTypes.FACT_PROFILE_BEHAVIOR,
					"prefer_anchor": CaseEngineTypes.ANCHOR_CAPABILITY,
					"prefer_fact_type": CaseEngineTypes.FACT_CAPABILITY_ACCESS
				}
			],
				"chains": []
			},
		{
			"id": "fraud_invoice_manipulation_v0_b",
			"crime_family": "fraud",
			"crime_type": "invoice_manipulation",
			"required_atoms": [
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_ANCHOR, "anchor": CaseEngineTypes.ANCHOR_TIMELINE},
				{"tab": CaseEngineTypes.TAB_ALIBI, "fact_type": CaseEngineTypes.FACT_ALIBI_STATEMENT, "anchor": CaseEngineTypes.ANCHOR_ALIBI},
				{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_ACCESS, "anchor": CaseEngineTypes.ANCHOR_CAPABILITY},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_PRESSURE, "anchor": CaseEngineTypes.ANCHOR_MOTIVE}
			],
			"optional_atoms": [
				{"tab": CaseEngineTypes.TAB_ALIBI, "fact_type": CaseEngineTypes.FACT_ALIBI_WITNESS},
				{"tab": CaseEngineTypes.TAB_PROFILE, "fact_type": CaseEngineTypes.FACT_PROFILE_BEHAVIOR},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_RELATIONSHIP}
			],
			"conflict_seeds": [
				{"group":"cg_invoice_statement","left":CaseEngineTypes.FACT_ALIBI_STATEMENT,"right":CaseEngineTypes.FACT_TIMELINE_ANCHOR,"prefer_anchor":CaseEngineTypes.ANCHOR_TIMELINE,"prefer_fact_type":CaseEngineTypes.FACT_TIMELINE_ANCHOR},
				{"group":"cg_invoice_pressure","left":CaseEngineTypes.FACT_MOTIVE_PRESSURE,"right":CaseEngineTypes.FACT_PROFILE_BEHAVIOR,"prefer_anchor":CaseEngineTypes.ANCHOR_MOTIVE,"prefer_fact_type":CaseEngineTypes.FACT_MOTIVE_PRESSURE}
			],
			"chains": ["timeline_to_pressure"]
		},
		{
			"id": "fraud_expense_recode_v0_a",
			"crime_family": "fraud",
			"crime_type": "expense_recode",
			"required_atoms": [
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_ANCHOR, "anchor": CaseEngineTypes.ANCHOR_TIMELINE},
				{"tab": CaseEngineTypes.TAB_ALIBI, "fact_type": CaseEngineTypes.FACT_ALIBI_WITNESS, "anchor": CaseEngineTypes.ANCHOR_ALIBI},
				{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_ACCESS, "anchor": CaseEngineTypes.ANCHOR_CAPABILITY},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_RELATIONSHIP, "anchor": CaseEngineTypes.ANCHOR_RELATIONSHIP}
			],
			"optional_atoms": [
					{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_TRAINING},
				{"tab": CaseEngineTypes.TAB_PROFILE, "fact_type": CaseEngineTypes.FACT_PROFILE_BEHAVIOR},
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_NOTE}
			],
			"conflict_seeds": [
				{"group":"cg_expense_access","left":CaseEngineTypes.FACT_CAPABILITY_TRAINING,"right":CaseEngineTypes.FACT_ALIBI_WITNESS,"prefer_anchor":CaseEngineTypes.ANCHOR_CAPABILITY,"prefer_fact_type":CaseEngineTypes.FACT_CAPABILITY_TRAINING}
			],
			"chains": []
		},
		{
			"id": "fraud_expense_recode_v0_b",
			"crime_family": "fraud",
			"crime_type": "expense_recode",
			"required_atoms": [
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_ANCHOR, "anchor": CaseEngineTypes.ANCHOR_TIMELINE},
				{"tab": CaseEngineTypes.TAB_ALIBI, "fact_type": CaseEngineTypes.FACT_ALIBI_STATEMENT, "anchor": CaseEngineTypes.ANCHOR_ALIBI},
				{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_ACCESS, "anchor": CaseEngineTypes.ANCHOR_CAPABILITY},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_PRESSURE, "anchor": CaseEngineTypes.ANCHOR_MOTIVE}
			],
			"optional_atoms": [
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_RELATIONSHIP},
				{"tab": CaseEngineTypes.TAB_PROFILE, "fact_type": CaseEngineTypes.FACT_PROFILE_BEHAVIOR}
			],
			"conflict_seeds": [
				{"group":"cg_expense_timeline","left":CaseEngineTypes.FACT_TIMELINE_NOTE,"right":CaseEngineTypes.FACT_ALIBI_STATEMENT,"prefer_anchor":CaseEngineTypes.ANCHOR_TIMELINE,"prefer_fact_type":CaseEngineTypes.FACT_TIMELINE_NOTE}
			],
			"chains": ["profile_context"]
		},
		{
			"id": "embezzlement_ledger_drift_v0_b",
			"crime_family": "embezzlement",
			"crime_type": "ledger_drift",
			"required_atoms": [
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_ANCHOR, "anchor": CaseEngineTypes.ANCHOR_TIMELINE},
				{"tab": CaseEngineTypes.TAB_ALIBI, "fact_type": CaseEngineTypes.FACT_ALIBI_STATEMENT, "anchor": CaseEngineTypes.ANCHOR_ALIBI},
				{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_ACCESS, "anchor": CaseEngineTypes.ANCHOR_CAPABILITY},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_PRESSURE, "anchor": CaseEngineTypes.ANCHOR_MOTIVE}
			],
			"optional_atoms": [
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_RELATIONSHIP},
				{"tab": CaseEngineTypes.TAB_PROFILE, "fact_type": CaseEngineTypes.FACT_PROFILE_BEHAVIOR}
			],
			"conflict_seeds": [
				{"group":"cg_ledger_pressure","left":CaseEngineTypes.FACT_MOTIVE_PRESSURE,"right":CaseEngineTypes.FACT_ALIBI_STATEMENT,"prefer_anchor":CaseEngineTypes.ANCHOR_MOTIVE,"prefer_fact_type":CaseEngineTypes.FACT_MOTIVE_PRESSURE}
			],
			"chains": []
		},
		{
			"id": "embezzlement_float_skimming_v0_a",
			"crime_family": "embezzlement",
			"crime_type": "float_skimming",
			"required_atoms": [
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_ANCHOR, "anchor": CaseEngineTypes.ANCHOR_TIMELINE},
				{"tab": CaseEngineTypes.TAB_ALIBI, "fact_type": CaseEngineTypes.FACT_ALIBI_WITNESS, "anchor": CaseEngineTypes.ANCHOR_ALIBI},
				{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_ACCESS, "anchor": CaseEngineTypes.ANCHOR_CAPABILITY},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_PRESSURE, "anchor": CaseEngineTypes.ANCHOR_MOTIVE}
			],
			"optional_atoms": [
				{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_TRAINING},
				{"tab": CaseEngineTypes.TAB_PROFILE, "fact_type": CaseEngineTypes.FACT_PROFILE_BEHAVIOR},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_RELATIONSHIP}
			],
			"conflict_seeds": [
				{"group":"cg_float_access","left":CaseEngineTypes.FACT_CAPABILITY_ACCESS,"right":CaseEngineTypes.FACT_PROFILE_BEHAVIOR,"prefer_anchor":CaseEngineTypes.ANCHOR_CAPABILITY,"prefer_fact_type":CaseEngineTypes.FACT_CAPABILITY_ACCESS}
			],
			"chains": ["access_to_pressure"]
		},
		{
			"id": "embezzlement_float_skimming_v0_b",
			"crime_family": "embezzlement",
			"crime_type": "float_skimming",
			"required_atoms": [
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_ANCHOR, "anchor": CaseEngineTypes.ANCHOR_TIMELINE},
				{"tab": CaseEngineTypes.TAB_ALIBI, "fact_type": CaseEngineTypes.FACT_ALIBI_STATEMENT, "anchor": CaseEngineTypes.ANCHOR_ALIBI},
				{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_ACCESS, "anchor": CaseEngineTypes.ANCHOR_CAPABILITY},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_RELATIONSHIP, "anchor": CaseEngineTypes.ANCHOR_RELATIONSHIP}
			],
			"optional_atoms": [
					{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_TRAINING},
				{"tab": CaseEngineTypes.TAB_PROFILE, "fact_type": CaseEngineTypes.FACT_PROFILE_BEHAVIOR}
			],
			"conflict_seeds": [
				{"group":"cg_float_timeline","left":CaseEngineTypes.FACT_TIMELINE_NOTE,"right":CaseEngineTypes.FACT_ALIBI_STATEMENT,"prefer_anchor":CaseEngineTypes.ANCHOR_TIMELINE,"prefer_fact_type":CaseEngineTypes.FACT_TIMELINE_NOTE}
			],
			"chains": []
		},
		{
			"id": "sabotage_sensor_tamper_v0_b",
			"crime_family": "sabotage",
			"crime_type": "sensor_tamper",
			"required_atoms": [
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_ANCHOR, "anchor": CaseEngineTypes.ANCHOR_TIMELINE},
				{"tab": CaseEngineTypes.TAB_ALIBI, "fact_type": CaseEngineTypes.FACT_ALIBI_STATEMENT, "anchor": CaseEngineTypes.ANCHOR_ALIBI},
				{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_ACCESS, "anchor": CaseEngineTypes.ANCHOR_CAPABILITY},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_PRESSURE, "anchor": CaseEngineTypes.ANCHOR_MOTIVE}
			],
			"optional_atoms": [
					{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_NOTE},
					{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_TRAINING},
					{"tab": CaseEngineTypes.TAB_PROFILE, "fact_type": CaseEngineTypes.FACT_PROFILE_BEHAVIOR}
			],
			"conflict_seeds": [
				{"group":"cg_sensor_statement","left":CaseEngineTypes.FACT_TIMELINE_ANCHOR,"right":CaseEngineTypes.FACT_ALIBI_STATEMENT,"prefer_anchor":CaseEngineTypes.ANCHOR_TIMELINE,"prefer_fact_type":CaseEngineTypes.FACT_TIMELINE_ANCHOR}
			],
			"chains": []
		},
		{
			"id": "sabotage_camera_gap_v0_a",
			"crime_family": "sabotage",
			"crime_type": "camera_gap",
			"required_atoms": [
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_ANCHOR, "anchor": CaseEngineTypes.ANCHOR_TIMELINE},
				{"tab": CaseEngineTypes.TAB_ALIBI, "fact_type": CaseEngineTypes.FACT_ALIBI_WITNESS, "anchor": CaseEngineTypes.ANCHOR_ALIBI},
				{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_ACCESS, "anchor": CaseEngineTypes.ANCHOR_CAPABILITY},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_RELATIONSHIP, "anchor": CaseEngineTypes.ANCHOR_RELATIONSHIP}
			],
			"optional_atoms": [
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_NOTE},
				{"tab": CaseEngineTypes.TAB_PROFILE, "fact_type": CaseEngineTypes.FACT_PROFILE_BEHAVIOR},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_PRESSURE}
			],
			"conflict_seeds": [
				{"group":"cg_camera_timeline","left":CaseEngineTypes.FACT_TIMELINE_ANCHOR,"right":CaseEngineTypes.FACT_ALIBI_WITNESS,"prefer_anchor":CaseEngineTypes.ANCHOR_TIMELINE,"prefer_fact_type":CaseEngineTypes.FACT_TIMELINE_ANCHOR}
			],
			"chains": ["timeline_gap"]
		},
		{
			"id": "sabotage_camera_gap_v0_b",
			"crime_family": "sabotage",
			"crime_type": "camera_gap",
			"required_atoms": [
				{"tab": CaseEngineTypes.TAB_TIMELINE, "fact_type": CaseEngineTypes.FACT_TIMELINE_ANCHOR, "anchor": CaseEngineTypes.ANCHOR_TIMELINE},
				{"tab": CaseEngineTypes.TAB_ALIBI, "fact_type": CaseEngineTypes.FACT_ALIBI_STATEMENT, "anchor": CaseEngineTypes.ANCHOR_ALIBI},
				{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_ACCESS, "anchor": CaseEngineTypes.ANCHOR_CAPABILITY},
				{"tab": CaseEngineTypes.TAB_MOTIVE, "fact_type": CaseEngineTypes.FACT_MOTIVE_PRESSURE, "anchor": CaseEngineTypes.ANCHOR_MOTIVE}
			],
			"optional_atoms": [
					{"tab": CaseEngineTypes.TAB_CAPABILITY, "fact_type": CaseEngineTypes.FACT_CAPABILITY_TRAINING},
				{"tab": CaseEngineTypes.TAB_PROFILE, "fact_type": CaseEngineTypes.FACT_PROFILE_BEHAVIOR}
			],
			"conflict_seeds": [
				{"group":"cg_camera_access","left":CaseEngineTypes.FACT_CAPABILITY_TRAINING,"right":CaseEngineTypes.FACT_PROFILE_BEHAVIOR,"prefer_anchor":CaseEngineTypes.ANCHOR_CAPABILITY,"prefer_fact_type":CaseEngineTypes.FACT_CAPABILITY_TRAINING}
			],
			"chains": []
		},
	]

static func all_skeleton_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in _all():
		out.append((entry as Dictionary).duplicate(true))
	return out

static func validate_tables() -> Array[String]:
	var out: Array[String] = []
	for entry in all_skeleton_entries():
		for code in CaseEngineContracts.validate_skeleton_entry(entry):
			out.append(code)
	return out
