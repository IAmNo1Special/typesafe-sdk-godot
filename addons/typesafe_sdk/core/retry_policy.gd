class_name RetryPolicy
extends RefCounted
## Retry configuration. Mirrors Python `RetryPolicy`.
## `timeout` is total budget in seconds; <= 0 disables the limit (None in Python).

var max_retries: int = 2
var backoff_initial: float = 0.5
var backoff_max: float = 5.0
var backoff_jitter: float = 0.25
var http_statuses: Array[int] = []
var respect_retry_after: bool = true
var api_connection_error: bool = true
var api_timeout_error: bool = true
var exceptions: Array = []
var predicate: Variant = null
var timeout: float = 30.0

func _init(p_max_retries: int = 2, p_backoff_initial: float = 0.5, p_backoff_max: float = 5.0, p_backoff_jitter: float = 0.25, p_http_statuses: Array = [], p_respect_retry_after: bool = true, p_api_connection_error: bool = true, p_api_timeout_error: bool = true, p_exceptions: Array = [], p_predicate: Variant = null, p_timeout: float = 30.0) -> void:
	max_retries = p_max_retries
	backoff_initial = p_backoff_initial
	backoff_max = p_backoff_max
	backoff_jitter = p_backoff_jitter

	if p_http_statuses == null or (typeof(p_http_statuses) == TYPE_ARRAY and p_http_statuses.is_empty()):
		http_statuses = _default_statuses()
	else:
		http_statuses.clear()
		for s in p_http_statuses:
			http_statuses.append(int(s))

	respect_retry_after = p_respect_retry_after
	api_connection_error = p_api_connection_error
	api_timeout_error = p_api_timeout_error
	exceptions = p_exceptions.duplicate() if typeof(p_exceptions) == TYPE_ARRAY else []
	predicate = p_predicate
	timeout = p_timeout

	_validate()

static func _default_statuses() -> Array[int]:
	# Python default: {408, 429, *range(500, 600)}
	var out: Array[int] = [408, 429]
	for s in range(500, 600):
		out.append(s)
	return out

func _validate() -> void:
	if max_retries < 0:
		push_error("RetryPolicy: max_retries must be non-negative")
	if backoff_initial < 0:
		push_error("RetryPolicy: backoff_initial must be non-negative")
	if backoff_max < 0:
		push_error("RetryPolicy: backoff_max must be non-negative")
	if backoff_jitter < 0 or backoff_jitter > 1:
		push_error("RetryPolicy: backoff_jitter must be between 0 and 1")
	if timeout != null and typeof(timeout) == TYPE_FLOAT and (is_nan(timeout) or is_inf(timeout)):
		push_error("RetryPolicy: timeout must be a finite number of seconds or <= 0 to disable.")

func has_timeout_budget() -> bool:
	return timeout != null and float(timeout) > 0.0

func is_retryable(p_error: TypeSafeError) -> bool:
	if p_error is TypeSafeAPITimeoutError:
		if api_timeout_error:
			return true
	elif p_error is TypeSafeAPIConnectionError:
		if api_connection_error:
			return true
	elif p_error is TypeSafeAPIError:
		if http_statuses.has(p_error.status):
			return true

	# `exceptions` holds class-name strings (GDScript has no exception types).
	for exc_name in exceptions:
		if typeof(exc_name) == TYPE_STRING and p_error.get_class() == exc_name:
			return true

	if predicate != null and typeof(predicate) == TYPE_CALLABLE:
		var pred := predicate as Callable
		if pred.is_valid():
			return bool(pred.call(p_error))

	return false

func calculate_backoff(p_attempt: int) -> float:
	if backoff_initial <= 0.0 or backoff_max <= 0.0:
		return 0.0

	var exponent = maxi(p_attempt - 1, 0)
	var exponential = backoff_initial * pow(2.0, float(exponent))

	if exponential > backoff_max:
		exponential = backoff_max

	# Apply jitter: exponential * (1 - random * jitter)
	var jitter_factor = 1.0 - randf() * backoff_jitter
	var delay = exponential * jitter_factor

	return minf(exponential, roundf(delay * 1000.0) / 1000.0)

func get_retry_after(p_headers: Dictionary) -> float:
	if not respect_retry_after:
		return -1.0
	for k in p_headers:
		if str(k).to_lower() == "retry-after-ms":
			var ms_raw := str(p_headers[k])
			if ms_raw.is_valid_float():
				return float(ms_raw) / 1000.0
	for k in p_headers:
		if str(k).to_lower() == "retry-after":
			var sec_raw := str(p_headers[k])
			if sec_raw.is_valid_float():
				return float(sec_raw)
	return -1.0

static func no_retry() -> RetryPolicy:
	return RetryPolicy.new(0)

static func default() -> RetryPolicy:
	return RetryPolicy.new()