class_name ScoreAnswer
extends RefCounted
## Expected score with rubric + probabilities. Mirrors Python `ScoreAnswer`.
## `score` is a probability-weighted float and may land between levels.
## `legend` / `probabilities` are keyed by int level (API sends string keys).

var type: String = "score"
var score: float = 0.0
var confidence: float = 0.0
var legend: Dictionary = {}
var probabilities: Dictionary = {}

func _init(p_score: float = 0.0, p_confidence: float = 0.0, p_legend: Dictionary = {}, p_probabilities: Dictionary = {}) -> void:
	score = p_score
	confidence = p_confidence
	legend = p_legend
	probabilities = p_probabilities

func _get_property_list() -> Array[Dictionary]:
	return [
		{"name": "type", "type": TYPE_STRING, "usage": PROPERTY_USAGE_READ_ONLY},
		{"name": "score", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_READ_ONLY},
		{"name": "confidence", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_READ_ONLY},
		{"name": "legend", "type": TYPE_DICTIONARY, "usage": PROPERTY_USAGE_READ_ONLY},
		{"name": "probabilities", "type": TYPE_DICTIONARY, "usage": PROPERTY_USAGE_READ_ONLY},
	]

static func _int_keyed(p_dict: Variant) -> Dictionary:
	var out := {}
	if typeof(p_dict) != TYPE_DICTIONARY:
		return out
	for key in p_dict:
		var int_key: int
		if typeof(key) == TYPE_INT:
			int_key = key
		elif typeof(key) == TYPE_FLOAT:
			int_key = int(key)
		else:
			# API sends level indexes as strings ("0", "1", ...).
			if not str(key).is_valid_int():
				continue
			int_key = int(str(key))
		out[int_key] = p_dict[key]
	return out


static func _float_values(p_dict: Dictionary) -> Dictionary:
	var out := {}
	for key in p_dict:
		out[key] = float(p_dict[key])
	return out


func _to_string() -> String:
	return "ScoreAnswer(score=%s, confidence=%s)" % [str(score), str(confidence)]


static func from_dict(p_dict: Dictionary) -> ScoreAnswer:
	var answer = ScoreAnswer.new()
	answer.type = str(p_dict.get("type", "score"))
	answer.score = float(p_dict.get("score", 0.0))
	answer.confidence = float(p_dict.get("confidence", 0.0))
	answer.legend = _int_keyed(p_dict.get("legend", {}))
	answer.probabilities = _float_values(_int_keyed(p_dict.get("probabilities", {})))
	return answer


func to_dict() -> Dictionary:
	var legend_out := {}
	for key in legend:
		legend_out[str(key)] = legend[key]
	var probs_out := {}
	for key in probabilities:
		probs_out[str(key)] = probabilities[key]
	return {"type": type, "score": score, "confidence": confidence, "legend": legend_out, "probabilities": probs_out}