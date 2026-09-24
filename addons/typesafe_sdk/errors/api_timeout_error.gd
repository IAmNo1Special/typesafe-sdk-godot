class_name TypeSafeAPITimeoutError
extends TypeSafeAPIConnectionError

var timeout: float = 0.0

func _init(p_timeout: float) -> void:
	super._init("Request timed out (timeout=%.1f)." % p_timeout)
	timeout = p_timeout

func _to_string() -> String:
	return "TypeSafeAPITimeoutError: Request timed out (timeout=%.1f)." % timeout