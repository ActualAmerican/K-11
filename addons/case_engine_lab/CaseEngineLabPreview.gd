@tool
extends RefCounted
class_name CaseEngineLabPreview

const CaseFolderRender = preload("res://Scripts/case_engine/CaseFolderRender.gd")

static func render(case_payload: Dictionary, show_truth: bool) -> String:
	if case_payload.is_empty():
		return ""
	var pages: Array[Dictionary] = CaseFolderRender.build_pages(case_payload, show_truth)
	var sections: Array[String] = []
	for page_v in pages:
		var page: Dictionary = page_v as Dictionary
		var title: String = str(page.get("title", ""))
		var body: String = str(page.get("body", ""))
		if title != "":
			sections.append(title + "\n\n" + body)
		else:
			sections.append(body)
	return "\n\n".join(sections)

static func render_page(case_payload: Dictionary, page: String, evidence_tab: String, show_truth: bool = false) -> String:
	if case_payload.is_empty():
		return ""
	if not bool(case_payload.get("ok", false)):
		return "No case."
	var page_id: String = page
	if page == "EVIDENCE":
		page_id = evidence_tab
	var body: String = CaseFolderRender.render_page_text(case_payload, page_id, false)
	if not show_truth:
		return body
	return body + "\n\n" + CaseFolderRender.render_dev_appendix(case_payload, page_id, evidence_tab)
