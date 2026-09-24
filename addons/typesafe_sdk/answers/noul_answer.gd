class_name NoulAnswer
extends RefCounted
## Yes/no answer. Mirrors Python `NoulAnswer` (only `noul`, 0=no .. 1=yes).

var type: String = "noul"
var noul: float = 0.0

func _init(p_noul: float = 0.0) -> void:
	noul = p_noul

func _get_property_list() -> Array[Dictionary]:
	return [
		{"name": "type", "type": TYPE_STRING, "usage": PROPERTY_USAGE_READ_ONLY},
		{"name": "noul", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_READ_ONLY},
	]

func _to_string() -> String:
	return "NoulAnswer(noul=%s)" % str(noul)


static func from_dict(p_dict: Dictionary) -> NoulAnswer:
	var answer = NoulAnswer.new()
	answer.type = str(p_dict.get("type", "noul"))
	answer.noul = float(p_dict.get("noul", 0.0))
	if answer.noul < 0.0 or answer.noul > 1.0:
		push_warning("NoulAnswer: noul value %f out of range [0, 1]" % answer.noul)
	return answer


func to_dict() -> Dictionary:
	return {"type": type, "noul": noul}