class_name ChoiceAnswer
extends RefCounted
## Selected label + probabilities. Mirrors Python `ChoiceAnswer`.

var type: String = "choice"
var choice: String = ""
var confidence: float = 0.0
var probabilities: Dictionary = {}

func _init(p_choice: String = "", p_confidence: float = 0.0, p_probabilities: Dictionary = {}) -> void:
	choice = p_choice
	confidence = p_confidence
	probabilities = p_probabilities

func _get_property_list() -> Array[Dictionary]:
	return [
		{"name": "type", "type": TYPE_STRING, "usage": PROPERTY_USAGE_READ_ONLY},
		{"name": "choice", "type": TYPE_STRING, "usage": PROPERTY_USAGE_READ_ONLY},
		{"name": "confidence", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_READ_ONLY},
		{"name": "probabilities", "type": TYPE_DICTIONARY, "usage": PROPERTY_USAGE_READ_ONLY},
	]

func _to_string() -> String:
	return "ChoiceAnswer(choice=%s, confidence=%s)" % [str(choice), str(confidence)]


static func from_dict(p_dict: Dictionary) -> ChoiceAnswer:
	var answer = ChoiceAnswer.new()
	answer.type = str(p_dict.get("type", "choice"))
	answer.choice = str(p_dict.get("choice", ""))
	answer.confidence = float(p_dict.get("confidence", 0.0))
	var probs := p_dict.get("probabilities", {})
	answer.probabilities = probs if typeof(probs) == TYPE_DICTIONARY else {}
	return answer


func to_dict() -> Dictionary:
	return {"type": type, "choice": choice, "confidence": confidence, "probabilities": probabilities}