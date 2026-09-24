class_name ModelMetadata
extends RefCounted

var name: String = ""
var description: String = ""
var release_date: String = ""

func _init(p_name: String = "", p_description: String = "", p_release_date: String = "") -> void:
	name = p_name
	description = p_description
	release_date = p_release_date

func _to_string() -> String:
	return "ModelMetadata(name=%s)" % str(name)


static func from_dict(p_dict: Dictionary) -> ModelMetadata:
	return ModelMetadata.new(
		p_dict.get("name", ""),
		p_dict.get("description", ""),
		p_dict.get("release_date", "")
	)