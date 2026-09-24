class_name SystemOneResponse
extends RefCounted
## Mirrors Python `SystemOneResponse`: answers grouped by type + metadata.
## `answers` holds every answer keyed by question name.
## Unknown answer kinds are skipped with a warning; unknown response
## fields are ignored (forward compatibility).

var model: String = ""
var usage: Usage
var answers: Dictionary = {}
var raw_answers: Dictionary = {}
var request_id: String = ""
var raw_http_response: Dictionary = {}

var _nouls: Dictionary = {}
var _choices: Dictionary = {}
var _scores: Dictionary = {}

func _init(p_model: String = "", p_usage: Usage = null, p_raw_answers: Dictionary = {}, p_request_id: String = "", p_raw_http_response: Dictionary = {}) -> void:
	model = p_model
	usage = p_usage if p_usage else Usage.new()
	raw_answers = p_raw_answers
	request_id = p_request_id
	raw_http_response = p_raw_http_response
	_parse_answers()

func _to_string() -> String:
	return "SystemOneResponse(model=%s, answers=%d, request_id=%s)" % [str(model), answers.size(), str(request_id)]


func _parse_answers() -> void:
	_nouls = {}
	_choices = {}
	_scores = {}
	answers = {}

	for key in raw_answers:
		var answer_data = raw_answers[key]
		if typeof(answer_data) != TYPE_DICTIONARY:
			continue

		var answer_type = str(answer_data.get("type", ""))
		match answer_type:
			"noul":
				var n := NoulAnswer.from_dict(answer_data)
				_nouls[key] = n
				answers[key] = n
			"choice":
				var c := ChoiceAnswer.from_dict(answer_data)
				_choices[key] = c
				answers[key] = c
			"score":
				var s := ScoreAnswer.from_dict(answer_data)
				_scores[key] = s
				answers[key] = s
			_:
				TypeSafeLogger.warning("Unknown answer kind '%s' for question '%s'; skipping." % [answer_type, str(key)])

# Accessors mirroring Python cached properties (.nouls / .choices / .scores)
func get_nouls() -> Dictionary:
	return _nouls

func get_choices() -> Dictionary:
	return _choices

func get_scores() -> Dictionary:
	return _scores

func get_answers() -> Dictionary:
	return answers

func get_noul(p_key: String) -> NoulAnswer:
	return _nouls.get(p_key)

func get_choice(p_key: String) -> ChoiceAnswer:
	return _choices.get(p_key)

func get_score(p_key: String) -> ScoreAnswer:
	return _scores.get(p_key)

func has_noul(p_key: String) -> bool:
	return _nouls.has(p_key)

func has_choice(p_key: String) -> bool:
	return _choices.has(p_key)

func has_score(p_key: String) -> bool:
	return _scores.has(p_key)

func get_request_id() -> String:
	return request_id

func get_raw_http_response() -> Dictionary:
	return raw_http_response

# Property access for Python-like API (response.nouls etc.)
func _get_property_list() -> Array[Dictionary]:
	return [
		{"name": "nouls", "type": TYPE_DICTIONARY, "usage": PROPERTY_USAGE_READ_ONLY},
		{"name": "choices", "type": TYPE_DICTIONARY, "usage": PROPERTY_USAGE_READ_ONLY},
		{"name": "scores", "type": TYPE_DICTIONARY, "usage": PROPERTY_USAGE_READ_ONLY},
		{"name": "request_id", "type": TYPE_STRING, "usage": PROPERTY_USAGE_READ_ONLY},
	]

func _get(p_property: StringName) -> Variant:
	match p_property:
		"nouls":
			return _nouls
		"choices":
			return _choices
		"scores":
			return _scores
		"request_id":
			return request_id
		_:
			return null

static func _header_lookup(p_headers: Dictionary, p_name: String) -> String:
	for k in p_headers:
		if str(k).to_lower() == p_name.to_lower():
			return str(p_headers[k])
	return ""


static func from_dict(p_dict: Dictionary, p_headers: Dictionary = {}, p_raw_http: Dictionary = {}) -> SystemOneResponse:
	var use := Usage.new()
	if p_dict.has("usage") and typeof(p_dict["usage"]) == TYPE_DICTIONARY:
		use = Usage.from_dict(p_dict["usage"])

	var answer_map: Dictionary = {}
	if p_dict.has("answers") and typeof(p_dict["answers"]) == TYPE_DICTIONARY:
		answer_map = p_dict["answers"]

	var req_id := _header_lookup(p_headers, "x-typesafe-request-id")
	var raw := p_raw_http
	if raw.is_empty() and not p_headers.is_empty():
		raw = {"headers": p_headers}
	return SystemOneResponse.new(str(p_dict.get("model", "")), use, answer_map, req_id, raw)