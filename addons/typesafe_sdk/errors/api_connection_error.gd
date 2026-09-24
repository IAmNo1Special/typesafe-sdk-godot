class_name TypeSafeAPIConnectionError
extends TypeSafeError

var original_error: String = ""

func _init(p_message: String = "", p_original_error: String = "") -> void:
	super._init(p_message)
	original_error = p_original_error

func _to_string() -> String:
	return "TypeSafeAPIConnectionError: %s" % (message if message != "" else original_error)