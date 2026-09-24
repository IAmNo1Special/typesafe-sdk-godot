class_name Models
extends Node
## Models API resource, reached through `TypeSafeClient.models`.
## Mirrors Python `Models.list()` / `AsyncModels.list()`.

signal list_completed(response: ListModelsResponse)
signal list_failed(error: TypeSafeError)

var config: TypeSafeConfig

var _pending_requests: Dictionary = {}
var _request_counter: int = 0

const _PROTECTED_HEADERS: Array = ["authorization", "accept", "user-agent"]


func _init(p_config: TypeSafeConfig) -> void:
	config = p_config


## List the models available to the account.
## `p_extra_headers` cannot override authentication, SDK identification,
## or Accept (they remain protected, matching Python).
func list(p_retry: RetryPolicy = null, p_timeout: float = -1.0, p_extra_headers: Variant = null) -> Error:
	if config.api_key.strip_edges() == "":
		var key_err := TypeSafeError.new("TypeSafeClient: TypeSafe API key is missing. Set TYPESAFE_API_KEY environment variable or pass api_key to constructor.")
		call_deferred("emit_signal", "list_failed", key_err)
		return ERR_UNCONFIGURED

	_ensure_in_tree()

	var extra: Dictionary = p_extra_headers if typeof(p_extra_headers) == TYPE_DICTIONARY else {}
	var retry: RetryPolicy = p_retry if p_retry != null else RetryPolicy.default()
	var timeout := p_timeout if p_timeout >= 0.0 else config.timeout

	var headers := _build_headers(extra)
	var headers_dict := _headers_to_dict(headers)

	var request_id := _request_counter
	_request_counter += 1

	var http := HTTPRequest.new()
	http.timeout = timeout
	add_child(http)

	_pending_requests[request_id] = {
		"http": http,
		"retry": retry,
		"attempt": 0,
		"timeout": timeout,
		"start_time": Time.get_ticks_msec() / 1000.0,
		"headers": headers,
		"headers_dict": headers_dict,
	}
	http.request_completed.connect(_on_request_completed.bind(request_id))

	TypeSafeLogger.log_request("GET", config.models_url(), headers_dict, null)
	var error := http.request(config.models_url(), headers, HTTPClient.METHOD_GET, "")
	if error != OK:
		_cleanup_request(request_id)
		var conn_err := TypeSafeAPIConnectionError.new("Failed to send request: %s" % error)
		call_deferred("emit_signal", "list_failed", conn_err)
		return error

	return OK


func _build_headers(p_extra_headers: Dictionary) -> PackedStringArray:
	var headers: PackedStringArray = [
		"Authorization: Bearer " + config.api_key,
		"Accept: application/json",
		"User-Agent: %s/%s" % [TypeSafeConstants.SDK_NAME, TypeSafeConstants.SDK_VERSION],
	]
	for key in config.default_headers:
		if not _is_protected_header(str(key)):
			headers.append("%s: %s" % [str(key), str(config.default_headers[key])])
	for key in p_extra_headers:
		if not _is_protected_header(str(key)):
			headers.append("%s: %s" % [str(key), str(p_extra_headers[key])])
		else:
			TypeSafeLogger.warning("Ignoring extra header '%s': authentication, SDK identification, and Accept remain protected." % str(key))
	return headers


func _is_protected_header(p_name: String) -> bool:
	return p_name.strip_edges().to_lower() in _PROTECTED_HEADERS


func _ensure_in_tree() -> void:
	if is_inside_tree():
		return
	var parent := get_parent()
	if parent != null and parent.has_method("enter"):
		parent.call("enter")
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.root.add_child(self)


func _on_request_completed(result: int, response_code: int, response_headers: PackedStringArray, body: PackedByteArray, request_id: int) -> void:
	if not _pending_requests.has(request_id):
		return
	var pending: Dictionary = _pending_requests[request_id]
	var retry: RetryPolicy = pending.get("retry", RetryPolicy.default())
	var attempt: int = int(pending.get("attempt", 0))
	var timeout: float = float(pending.get("timeout", config.timeout))
	var start_time: float = float(pending.get("start_time", 0.0))

	var body_str := body.get_string_from_utf8()
	var resp_headers := _headers_to_dict(response_headers)

	if result != HTTPRequest.RESULT_SUCCESS:
		var fail_err := _handle_request_failure(result, timeout)
		TypeSafeLogger.log_response(response_code, resp_headers, body_str)
		pending["last_headers"] = resp_headers
		if retry.is_retryable(fail_err) and _within_budget(retry, attempt, start_time, resp_headers):
			_schedule_retry(request_id, resp_headers)
			return
		_cleanup_request(request_id)
		list_failed.emit(fail_err)
		return

	var json := JSON.new()
	if json.parse(body_str) != OK:
		TypeSafeLogger.log_response(response_code, resp_headers, body_str)
		_cleanup_request(request_id)
		list_failed.emit(TypeSafeAPIResponseValidationError.new(response_code, body_str, resp_headers, "root", config.models_url()))
		return

	if response_code != 200:
		TypeSafeLogger.log_response(response_code, resp_headers, json.data)
		var api_err := _create_api_error(response_code, json.data, resp_headers)
		pending["last_headers"] = resp_headers
		if retry.is_retryable(api_err) and _within_budget(retry, attempt, start_time, resp_headers):
			_schedule_retry(request_id, resp_headers)
			return
		_cleanup_request(request_id)
		list_failed.emit(api_err)
		return

	TypeSafeLogger.log_response(response_code, resp_headers, json.data)
	if typeof(json.data) != TYPE_DICTIONARY:
		_cleanup_request(request_id)
		list_failed.emit(TypeSafeAPIResponseValidationError.new(response_code, body_str, resp_headers, "root", config.models_url()))
		return

	var raw_http := {"status": response_code, "headers": resp_headers, "body": body_str}
	_cleanup_request(request_id)
	var response := ListModelsResponse.from_dict(json.data as Dictionary, resp_headers, raw_http)
	list_completed.emit(response)


func _handle_request_failure(result: int, timeout: float) -> TypeSafeError:
	if result == HTTPRequest.RESULT_TIMEOUT:
		return TypeSafeAPITimeoutError.new(timeout)
	return TypeSafeAPIConnectionError.new("HTTP request failed: %d" % result)


func _create_api_error(status_code: int, body: Variant, headers: Dictionary) -> TypeSafeAPIError:
	var endpoint := config.models_url()
	var msg := ""
	if typeof(body) == TYPE_DICTIONARY:
		for k in ["message", "error", "detail"]:
			if (body as Dictionary).has(k):
				msg = str((body as Dictionary)[k])
				break

	match status_code:
		400:
			return TypeSafeBadRequestError.new(status_code, body, headers, msg, endpoint)
		401:
			return TypeSafeAuthenticationError.new(status_code, body, headers, msg, endpoint)
		403:
			return TypeSafePermissionDeniedError.new(status_code, body, headers, msg, endpoint)
		404:
			return TypeSafeNotFoundError.new(status_code, body, headers, msg, endpoint)
		422:
			return TypeSafeUnprocessableEntityError.new(status_code, body, headers, msg, endpoint)
		429:
			return TypeSafeRateLimitError.new(status_code, body, headers, msg, endpoint)
		_:
			if status_code >= 500:
				return TypeSafeInternalServerError.new(status_code, body, headers, msg, endpoint)
			return TypeSafeAPIError.new(status_code, body, headers, msg, endpoint)


func _within_budget(retry: RetryPolicy, attempt: int, start_time: float, resp_headers: Dictionary) -> bool:
	if attempt >= retry.max_retries:
		return false
	if not retry.has_timeout_budget():
		return true
	var elapsed := (Time.get_ticks_msec() / 1000.0) - start_time
	var delay := retry.calculate_backoff(attempt + 1)
	var retry_after := retry.get_retry_after(resp_headers)
	if retry_after > 0.0:
		delay = maxf(delay, retry_after)
	return elapsed + delay < float(retry.timeout)


func _schedule_retry(request_id: int, resp_headers: Dictionary) -> void:
	if not _pending_requests.has(request_id):
		return
	var pending: Dictionary = _pending_requests[request_id]
	var retry: RetryPolicy = pending.get("retry", RetryPolicy.default())
	var attempt_next: int = int(pending.get("attempt", 0)) + 1
	var delay := retry.calculate_backoff(attempt_next)
	var retry_after := retry.get_retry_after(resp_headers)
	if retry_after > 0.0:
		delay = maxf(delay, retry_after)

	if retry.has_timeout_budget():
		var elapsed := (Time.get_ticks_msec() / 1000.0) - float(pending.get("start_time", 0.0))
		if elapsed + delay >= float(retry.timeout):
			_cleanup_request(request_id)
			list_failed.emit(TypeSafeAPITimeoutError.new(float(retry.timeout)))
			return

	_pending_requests[request_id] = pending
	var timer := Timer.new()
	timer.wait_time = maxf(delay, 0.0)
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_on_retry_timer_timeout.bind(timer, request_id))
	timer.start()


func _on_retry_timer_timeout(timer: Timer, request_id: int) -> void:
	if is_instance_valid(timer):
		timer.queue_free()
	if not _pending_requests.has(request_id):
		return
	var pending: Dictionary = _pending_requests[request_id]
	pending["attempt"] = int(pending.get("attempt", 0)) + 1
	var http: HTTPRequest = pending.get("http")
	_pending_requests[request_id] = pending
	if http == null or not is_instance_valid(http):
		_cleanup_request(request_id)
		list_failed.emit(TypeSafeAPIConnectionError.new("Retry failed: HTTP client was freed."))
		return
	TypeSafeLogger.debug("Retrying models.list request (attempt %d)." % int(pending["attempt"]))
	var error := http.request(config.models_url(), pending.get("headers", PackedStringArray()), HTTPClient.METHOD_GET, "")
	if error != OK:
		_cleanup_request(request_id)
		list_failed.emit(TypeSafeAPIConnectionError.new("Failed to resend request: %s" % error))


func _cleanup_request(request_id: int) -> void:
	if _pending_requests.has(request_id):
		var pending: Dictionary = _pending_requests[request_id]
		var http: HTTPRequest = pending.get("http")
		_pending_requests.erase(request_id)
		if http != null and is_instance_valid(http):
			if http.request_completed.is_connected(_on_request_completed):
				http.request_completed.disconnect(_on_request_completed)
			http.queue_free()


func _headers_to_dict(headers: PackedStringArray) -> Dictionary:
	var dict := {}
	for h in headers:
		var parts := h.split(":", true, 1)
		if parts.size() == 2:
			dict[str(parts[0]).strip_edges()] = str(parts[1]).strip_edges()
	return dict


func close() -> void:
	for request_id in _pending_requests.keys():
		_cleanup_request(request_id)
