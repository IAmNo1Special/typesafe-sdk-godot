class_name Noul
extends Question
## Yes/no question. Mirrors Python `Noul`.
## `criteria` maps "true"/"false" to JSONContent (or null for undescribed).

var criteria: Variant = null


func _init(p_instructions: Variant = null, p_criteria: Variant = null) -> void:
	super._init(p_instructions)
	criteria = p_criteria


func get_type() -> String:
	return "noul"


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["type"] = "noul"
	if criteria != null:
		data["criteria"] = criteria
	return data
