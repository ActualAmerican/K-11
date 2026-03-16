@tool
extends RefCounted
class_name CaseEngineFactAtom

static func make(
	fact_id: String,
	tab: String,
	fact_type: String,
	text: String,
	truth_refs: Array,
	slots: Dictionary,
	reliability: String,
	conflict_group: String = "",
	anchor: String = "",
	template_id: String = "",
	chain_id: String = ""
) -> Dictionary:
	return {
		"fact_id": fact_id,
		"tab": tab,
		"fact_type": fact_type,
		"text": text,
		"truth_refs": truth_refs,
		"slots": slots,
		"reliability": reliability,
		"conflict_group": conflict_group,
		"anchor": anchor,
		"template_id": template_id,
		"chain_id": chain_id,
	}
