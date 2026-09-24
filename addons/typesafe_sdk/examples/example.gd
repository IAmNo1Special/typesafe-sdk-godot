# Example usage matching the Python SDK API as closely as GDScript allows.
# https://docs.typesafe.ai/sdk/python
# Attach this script to any Node in the scene tree and run the scene.
extends Node

var client: TypeSafeClient
var questions: Dictionary
var custom_retry: RetryPolicy


func _ready() -> void:
	client = TypeSafeClient.new()
	client.enter()

	client.evaluation_completed.connect(_on_evaluation_completed)
	client.evaluation_failed.connect(_on_evaluation_failed)
	# Needed if you pass p_response_model (see _run_advanced): without this
	# connection the custom response is emitted but never observed.
	client.custom_evaluation_completed.connect(_on_custom_response)

	# Python parity: questions are keyed by name; the key (not an id field)
	# selects the answer slot. instructions/criteria accept String, Dictionary,
	# or Array (structured content), or null.
	questions = {
		"billing": Noul.new("Is this ticket about billing?"),
		"tone": Choice.new(
			"What is the customer's tone?",
			{
				"calm": "Customer is polite and patient",
				"frustrated": "Customer shows signs of frustration",
				"angry": "Customer is visibly angry"
			}
		),
		"urgency": Score.new(
			"How urgent is this ticket?",
			["can wait", "this week", "today"]
		)
	}

	var state = {"document": "I was charged twice. Please fix this ASAP."}
	client.system_one(state, questions)

	# Models API (matching Python: client.models.list())
	client.models.list_completed.connect(_on_models_listed)
	client.models.list_failed.connect(_on_models_list_failed)
	client.models.list()


func _on_evaluation_completed(response: SystemOneResponse) -> void:
	print("Model: ", response.model)
	print("Usage: ", response.usage.input_tokens, " in / ", response.usage.output_tokens, " out")
	print("Request id: ", response.request_id)

	if response.has_noul("billing"):
		var billing := response.get_noul("billing")
		print("Billing (noul): ", billing.noul)

	if response.has_choice("tone"):
		var tone := response.get_choice("tone")
		print("Tone (choice): ", tone.choice, " (confidence: ", tone.confidence, ", probabilities: ", tone.probabilities, ")")

	if response.has_score("urgency"):
		var urgency := response.get_score("urgency")
		print("Urgency (score): ", urgency.score, " (confidence: ", urgency.confidence, ", legend: ", urgency.legend, ", probabilities: ", urgency.probabilities, ")")

	print("All answers: ", response.answers)
	print("All nouls: ", response.nouls)
	print("All choices: ", response.choices)
	print("All scores: ", response.scores)


func _on_custom_response(response: Variant) -> void:
	# Emitted only when system_one() is called with p_response_model.
	print("Custom response model: ", response)


func _on_evaluation_failed(error: TypeSafeError) -> void:
	print("Error: ", error.to_string())
	if error is TypeSafeRateLimitError:
		print("Retry after: ", (error as TypeSafeRateLimitError).retry_after_ms, "ms")
	elif error is TypeSafeAPITimeoutError:
		print("Timeout was: ", (error as TypeSafeAPITimeoutError).timeout)
	elif error is TypeSafeAPIResponseValidationError:
		print("Invalid field: ", (error as TypeSafeAPIResponseValidationError).field_path)
	elif error is TypeSafeAPIError:
		print("Status: ", (error as TypeSafeAPIError).status, " request_id: ", (error as TypeSafeAPIError).request_id)


func _on_models_listed(response: ListModelsResponse) -> void:
	for model in response.models:
		print("Model: ", model.name, " - ", model.description, " (", model.release_date, ")")


func _on_models_list_failed(error: TypeSafeError) -> void:
	print("Models error: ", error.to_string())


func _run_advanced() -> void:
	custom_retry = RetryPolicy.new(
		3,
		1.0,
		10.0,
		0.1,
		[429, 500, 502, 503, 504],
		true,
		true,
		true,
		[],
		null,
		60.0
	)

	client.system_one(
		{"message": "Test"},
		{"q": Noul.new("Test?")},
		"",
		custom_retry,
		-1.0,
		{"X-Custom-Header": "value"},
		{"metadata": {"source": "godot"}},
		Callable(self, "_my_response_model")
	)


func _my_response_model(raw_json: Dictionary, _headers: Dictionary) -> Variant:
	# GDScript equivalent of Python's pydantic `response_model`: build
	# whatever shape the caller wants from the raw JSON body.
	return SystemOneResponse.from_dict(raw_json, _headers)


func _exit_tree() -> void:
	client.exit()
