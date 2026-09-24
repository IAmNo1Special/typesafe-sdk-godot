class_name TypeSafeAuthenticationError
extends TypeSafeAPIError

func _init(p_status_code: int, p_body: Variant, p_headers: Dictionary = {}, p_message: String = "", p_endpoint: String = "") -> void:
	super._init(p_status_code, p_body, p_headers, p_message, p_endpoint)