class_name Choice
extends Question
## Selects between named alternatives. Mirrors Python `Choice`.
## `criteria` is REQUIRED: Dictionary mapping option name -> JSONContent or null.
## Max 255 options per the API.

var criteria: Dictionary = {}


func _init(p_instructions: Variant = null, p_criteria: Dictionary = {}) -> void:
	super._init(p_instructions)
	criteria = p_criteria


func get_type() -> String:
	return "choice"


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["type"] = "choice"
	data["criteria"] = criteria
	return data
