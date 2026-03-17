extends SceneTree

const GameControllerScript = preload("res://Scripts/systems/GameController.gd")

func _init() -> void:
	print("SMOKE preload ok")
	var controller := GameControllerScript.new()
	print("SMOKE new ok")
	var json_text := SuspectIO.read_text("res://dev/ch4_42_roundtrip_proof/JSON_A.json")
	var suspect := SuspectIO.from_json(json_text)
	print("SMOKE from_json ok")
	controller.call("_apply_imported_suspect", suspect, "smoke")
	print("SMOKE apply ok")
	quit()
