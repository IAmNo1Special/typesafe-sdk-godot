class_name TypeSafeLogger
extends RefCounted

# Mirrors Python SDK logging to the `typesafe_sdk` logger.
# Level comes from TYPESAFE_LOG_LEVEL (debug/info/warning/error/off).
# info: one summary line per request; debug: also headers + bodies.
# Secret headers (authorization, api keys, cookies, token/secret in name)
# are redacted. Bodies are NOT redacted (matching Python).

const LEVEL_OFF: int = 0
const LEVEL_ERROR: int = 1
const LEVEL_WARNING: int = 2
const LEVEL_INFO: int = 3
const LEVEL_DEBUG: int = 4

static var _level: int = -1


static func level() -> int:
	if _level < 0:
		_level = _level_from_env()
	return _level


static func reset_level_cache() -> void:
	_level = -1


static func _level_from_env() -> int:
	var raw := OS.get_environment(TypeSafeConstants.LOG_LEVEL_ENV)
	if raw == "":
		return LEVEL_WARNING
	match raw.strip_edges().to_lower():
		"debug":
			return LEVEL_DEBUG
		"info":
			return LEVEL_INFO
		"warning":
			return LEVEL_WARNING
		"error":
			return LEVEL_ERROR
		"off", "none", "disabled":
			return LEVEL_OFF
		_:
			return LEVEL_WARNING


static func is_secret_header(p_name: String) -> bool:
	var n := p_name.strip_edges().to_lower()
	if n == "authorization" or n == "cookie" or n == "set-cookie":
		return true
	if n == "x-api-key" or n == "api-key" or n == "apikey":
		return true
	if n.contains("token") or n.contains("secret") or n.contains("api_key") or n.contains("api-key"):
		return true
	return false


static func redact_headers(p_headers: Dictionary) -> Dictionary:
	var out := {}
	for k in p_headers:
		var ks := str(k)
		if is_secret_header(ks):
			out[ks] = "[REDACTED]"
		else:
			out[ks] = p_headers[k]
	return out


static func debug(p_msg: String) -> void:
	if level() >= LEVEL_DEBUG:
		print("[typesafe_sdk][DEBUG] ", p_msg)


static func info(p_msg: String) -> void:
	if level() >= LEVEL_INFO:
		print("[typesafe_sdk][INFO] ", p_msg)


static func warning(p_msg: String) -> void:
	if level() >= LEVEL_WARNING:
		push_warning("[typesafe_sdk] " + p_msg)


static func error(p_msg: String) -> void:
	if level() >= LEVEL_ERROR:
		push_error("[typesafe_sdk] " + p_msg)


static func log_request(p_method: String, p_url: String, p_headers: Dictionary, p_body: Variant) -> void:
	if level() < LEVEL_INFO:
		return
	info("%s %s" % [p_method, p_url])
	if level() >= LEVEL_DEBUG:
		debug("request headers: " + JSON.stringify(redact_headers(p_headers)))
		if p_body != null:
			debug("request body: " + JSON.stringify(p_body))


static func log_response(p_status: int, p_headers: Dictionary, p_body: Variant) -> void:
	if level() < LEVEL_INFO:
		return
	info("response status: %d" % p_status)
	if level() >= LEVEL_DEBUG:
		debug("response headers: " + JSON.stringify(redact_headers(p_headers)))
		if p_body != null:
			var body_str := p_body if typeof(p_body) == TYPE_STRING else JSON.stringify(p_body)
			debug("response body: " + str(body_str))
