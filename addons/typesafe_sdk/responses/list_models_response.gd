class_name ListModelsResponse
extends RefCounted
## Models available to the account. Mirrors Python `ListModelsResponse`.
## Unknown extra fields are ignored (forward compatibility).

var models: Array[ModelMetadata] = []
var request_id: String = ""
var raw_http_response: Dictionary = {}

func _init(p_models: Array = [], p_request_id: String = "", p_raw_http_response: Dictionary = {}) -> void:
	models.clear()
	for m in p_models:
		if typeof(m) == TYPE_DICTIONARY:
			models.append(ModelMetadata.from_dict(m))
		elif m is ModelMetadata:
			models.append(m)
	request_id = p_request_id
	raw_http_response = p_raw_http_response

func get_request_id() -> String:
	return request_id

func get_raw_http_response() -> Dictionary:
	return raw_http_response

static func _header_lookup(p_headers: Dictionary, p_name: String) -> String:
	for k in p_headers:
		if str(k).to_lower() == p_name.to_lower():
			return str(p_headers[k])
	return ""

static func from_dict(p_dict: Dictionary, p_headers: Dictionary = {}, p_raw_http: Dictionary = {}) -> ListModelsResponse:
	var response = ListModelsResponse.new()
	var models_data = p_dict.get("models", [])
	response.models.clear()
	if typeof(models_data) == TYPE_ARRAY:
		for m in models_data:
			if typeof(m) == TYPE_DICTIONARY:
				response.models.append(ModelMetadata.from_dict(m))
	response.request_id = _header_lookup(p_headers, "x-typesafe-request-id")
	response.raw_http_response = p_raw_http
	if response.raw_http_response.is_empty() and not p_headers.is_empty():
		response.raw_http_response = {"headers": p_headers}
	return response