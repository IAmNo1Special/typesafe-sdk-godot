class_name TypeSafeAPIResponseValidationError
extends TypeSafeAPIError

var field_path: String = ""

func _init(p_status_code: int, p_body: Variant, p_headers: Dictionary = {}, p_field_path: String = "", p_endpoint: String = "") -> void:
	super._init(p_status_code, p_body, p_headers, "Invalid response data at '%s'." % p_field_path, p_endpoint)
	field_path = p_field_path