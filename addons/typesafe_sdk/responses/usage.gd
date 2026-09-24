class_name Usage
extends RefCounted
## Token counts. Mirrors Python `Usage`: each is int or null when unreported.

var input_tokens: Variant = null
var output_tokens: Variant = null

func _init(p_input_tokens: Variant = null, p_output_tokens: Variant = null) -> void:
	input_tokens = p_input_tokens
	output_tokens = p_output_tokens

func _get_property_list() -> Array[Dictionary]:
	return [
		{"name": "input_tokens", "type": TYPE_INT, "usage": PROPERTY_USAGE_READ_ONLY},
		{"name": "output_tokens", "type": TYPE_INT, "usage": PROPERTY_USAGE_READ_ONLY},
	]

func _to_string() -> String:
	var in_str := str(input_tokens) if input_tokens != null else "null"
	var out_str := str(output_tokens) if output_tokens != null else "null"
	return "Usage(input_tokens=%s, output_tokens=%s)" % [in_str, out_str]


static func from_dict(p_dict: Dictionary) -> Usage:
	# Unknown extra fields are ignored (forward compatibility).
	var has_in := p_dict.has("input_tokens")
	var has_out := p_dict.has("output_tokens")
	var in_tok: Variant = null
	var out_tok: Variant = null
	if has_in and p_dict["input_tokens"] != null:
		in_tok = int(p_dict["input_tokens"])
	if has_out and p_dict["output_tokens"] != null:
		out_tok = int(p_dict["output_tokens"])
	return Usage.new(in_tok, out_tok)


func to_dict() -> Dictionary:
	return {"input_tokens": input_tokens, "output_tokens": output_tokens}