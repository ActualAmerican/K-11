extends RefCounted
class_name SuspectData

const SCHEMA_VERSION: int = 1

var schema_version: int = SCHEMA_VERSION

var run_seed_text: String = ""
var run_seed_u64: int = 0
var suspect_index: int = 0
var suspect_seed_u64: int = 0

var id: String = ""
var silhouette_label: String = ""
var deadline_s: int = 0
var truth_guilty: bool = false

# charge_sheet keys: case_id:String, title:String, charges:Array[String], brief:String
var charge_sheet: Dictionary = {}

# tabs keys: "ALIBI","TIMELINE","MOTIVE","CAPABILITY","PROFILE"
# each value: { tab:String, fact_pool_seed_u64:int, facts:Array[Dictionary] }
var tabs: Dictionary = {}

# debug keys: suspect_seed_hex:String, subseeds:Dictionary[String, int|String]
var debug: Dictionary = {}

func is_valid() -> bool:
	if schema_version != SCHEMA_VERSION:
		return false
	if run_seed_text.strip_edges() == "":
		return false
	if run_seed_u64 < 0:
		return false
	if suspect_seed_u64 < 0:
		return false
	if id.strip_edges() == "":
		return false
	if silhouette_label.strip_edges() == "":
		return false
	if deadline_s <= 0:
		return false
	if not charge_sheet.has("case_id") or not charge_sheet.has("title") or not charge_sheet.has("charges") or not charge_sheet.has("brief"):
		return false
	if not (tabs.has("ALIBI") and tabs.has("TIMELINE") and tabs.has("MOTIVE") and tabs.has("CAPABILITY") and tabs.has("PROFILE")):
		return false
	return true

func truth_label() -> String:
	return "GUILTY" if truth_guilty else "INNOCENT"

func short_id() -> String:
	return id

func get_debug_seed_hex() -> String:
	if debug.has("suspect_seed_hex"):
		return str(debug["suspect_seed_hex"])
	return ""

func get_deadline_label() -> String:
	return "%ds" % deadline_s
