class_name AsyncTypeSafeClient
extends TypeSafeClient
## Asynchronous client. Mirrors Python `AsyncTypeSafeClient`.
##
## In Godot all HTTP is non-blocking: [method TypeSafeClient.system_one] queues
## the request and emits `evaluation_completed` / `evaluation_failed`, and
## `models.list()` emits `list_completed` / `list_failed`. Await them:
## `await client.evaluation_completed`.
## This class exists for API parity; behavior matches [TypeSafeClient].
## Remember to `await`/`aclose()` symmetry: use [method aclose] (alias of close).


func _init(p_api_key: Variant = null, p_model: Variant = null, p_base_url: Variant = null, p_timeout: float = -1.0, p_retry: RetryPolicy = null, p_headers: Dictionary = {}) -> void:
	super._init(p_api_key, p_model, p_base_url, p_timeout, p_retry, p_headers)


func aclose() -> void:
	close()
