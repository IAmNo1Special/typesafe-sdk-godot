class_name Question
extends RefCounted
## Base question. Mirrors Python `Noul | Choice | Score`.
## `instructions` is JSONContent: String, Dictionary, Array, or null.
## The dict key in the `questions` map is the question id (not sent to the model).

var instructions: Variant = null


func _init(p_instructions: Variant = null) -> void:
	instructions = p_instructions


func get_type() -> String:
	return ""


func to_dict() -> Dictionary:
	var data := {"type": get_type()}
	# instructions is optional in Python; omit only when null so that
	# structured (dict/array) values round-trip untouched.
	if instructions != null:
		data["instructions"] = instructions
	return data


static func is_valid_content(p_value: Variant) -> bool:
	# JSONContent: String | Mapping | Sequence (values inside may be null).
	match typeof(p_value):
		TYPE_STRING, TYPE_DICTIONARY, TYPE_ARRAY:
			return true
		_:
			return false
