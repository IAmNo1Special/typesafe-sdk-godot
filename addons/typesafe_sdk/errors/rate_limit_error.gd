class_name TypeSafeRateLimitError
extends TypeSafeAPIError
## Rate limit exceeded (429). Mirrors Python `TypeSafeRateLimitError`.
## `retry_after_ms` is int or null when the server sent no usable value.

var retry_after_ms: Variant = null

func _init(p_status_code: int, p_body: Variant, p_headers: Dictionary = {}, p_message: String = "", p_endpoint: String = "") -> void:
	super._init(p_status_code, p_body, p_headers, p_message, p_endpoint)
	retry_after_ms = parse_retry_after(p_headers)


static func _header_lookup(p_headers: Dictionary, p_name: String) -> String:
	for k in p_headers:
		if str(k).to_lower() == p_name.to_lower():
			return str(p_headers[k])
	return ""


static func parse_retry_after(p_headers: Dictionary) -> Variant:
	# Prefer retry-after-ms (milliseconds), else retry-after (seconds).
	var ms_raw := _header_lookup(p_headers, "retry-after-ms")
	if ms_raw != "" and ms_raw.is_valid_float():
		return int(float(ms_raw))
	var sec_raw := _header_lookup(p_headers, "retry-after")
	if sec_raw != "" and sec_raw.is_valid_float():
		return int(float(sec_raw) * 1000.0)
	return null