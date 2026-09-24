class_name TypeSafeError
extends RefCounted

var message: String = ""

func _init(p_message: String = "") -> void:
	message = p_message

func _to_string() -> String:
	return "TypeSafeError: " + message