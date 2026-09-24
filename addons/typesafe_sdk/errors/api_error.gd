class_name TypeSafeAPIError
extends TypeSafeError
## Unsuccessful HTTP response. Mirrors Python `TypeSafeAPIError`.
## `status` is the canonical name (Python); `status_code` is kept as alias.

var status: int = 0
var status_code: int = 0
var body: Variant
var headers: Dictionary = {}
var endpoint: String = ""
var request_id: Variant = null

func _init(p_status_code: int, p_body: Variant, p_headers: Dictionary = {}, p_message: String = "", p_endpoint: String = "") -> void:
	super._init(p_message)
	status = p_status_code
	status_code = p_status_code
	body = p_body
	headers = p_headers
	endpoint = p_endpoint
	request_id = _extract_request_id(p_headers)

static func _extract_request_id(p_headers: Dictionary) -> Variant:
	for k in p_headers:
		if str(k).to_lower() == "x-typesafe-request-id":
			var v := str(p_headers[k])
			return v if v != "" else null
	return null

func get_request_id() -> Variant:
	return request_id

func _to_string() -> String:
	var msg = "%d" % status
	if message != "":
		msg += " %s" % message
	if endpoint != "":
		msg = "%s: %s" % [endpoint, msg]
	if request_id != null and str(request_id) != "":
		msg += " (request_id=%s)" % str(request_id)
	return msg