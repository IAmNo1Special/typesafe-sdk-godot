@tool
extends EditorPlugin


func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	# Registers TypeSafeClient so it appears in the "Create New Node" menu
	add_custom_type(
		"TypeSafeClient", 
		"Node", 
		preload("res://addons/typesafe_sdk/clients/TypeSafeClient.gd"),
		preload("res://addons/typesafe_sdk/icon.svg")
	)


func _exit_tree() -> void:
	# Cleans up when the plugin is disabled
	remove_custom_type("TypeSafeClient")
