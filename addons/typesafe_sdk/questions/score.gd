class_name Score
extends Question
## Rates along an ordered rubric. Mirrors Python `Score`.
## `criteria` is REQUIRED: non-empty ordered Array of JSONContent,
## one per score level starting at 0. API accepts 2-10 levels.

var criteria: Array = []


func _init(p_instructions: Variant = null, p_criteria: Array = []) -> void:
	super._init(p_instructions)
	criteria = p_criteria


func get_type() -> String:
	return "score"


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["type"] = "score"
	data["criteria"] = criteria
	return data
