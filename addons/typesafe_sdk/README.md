# TypeSafe SDK for Godot

[TypeSafe API](https://typesafe.ai) for Godot 4.7 SDK, at parity with the
[Python SDK](https://docs.typesafe.ai/sdk/python) and the
[HTTP API reference](https://docs.typesafe.ai/api).

- Endpoint: `POST {base_url}/v1/systemone`, models: `GET {base_url}/v1/models`
- Default base URL: `https://api.typesafe.ai` · default model: `jev-latest`
- Default timeout: `10.0`s per HTTP operation (config) · retry budget `30.0`s
- Env vars: `TYPESAFE_API_KEY`, `TYPESAFE_BASE_URL`, `TYPESAFE_DEFAULT_MODEL`,
  `TYPESAFE_LOG_LEVEL` (`debug`/`info`/`warning`/`error`/`off`)

## Clients

```gdscript
# Key comes from the TYPESAFE_API_KEY environment variable
# (or pass it: TypeSafeClient.new("ts-...")).
var client := TypeSafeClient.new()
add_child(client)  # must be in the scene tree (HTTP needs the tree)

client.evaluation_completed.connect(func(response: SystemOneResponse) -> void:
	print(response.nouls["billing"].noul)
)
client.evaluation_failed.connect(func(error: TypeSafeError) -> void:
	print(error.to_string())  # e.g. "401 ..." with .status / .request_id
)
client.system_one(
	{"document": "I was charged twice. Please fix this ASAP."},
	{
		"billing": Noul.new("Is this ticket about billing?"),
		"tone": Choice.new("What is the tone?", {"calm": null, "angry": null}),
		"urgency": Score.new("How urgent?", ["low", "medium", "high"]),
	},
)

# Or async/await style (emitted once per call):
# var response: SystemOneResponse = await client.evaluation_completed
```

- `await client.evaluation_completed` / `await client.models.list_completed`
  work the same way.
- `close()` frees the client node — create a new one afterwards; a closed
  client cannot be reused.
- See `examples/example.gd` for a complete runnable scene script.

## Layout

- `clients/` — `TypeSafeClient`, `AsyncTypeSafeClient`, `Models`
- `questions/` — `Question`, `Noul`, `Choice`, `Score`
- `answers/` — `NoulAnswer`, `ChoiceAnswer`, `ScoreAnswer`
- `responses/` — `SystemOneResponse`, `Usage`, `ListModelsResponse`, `ModelMetadata`
- `errors/` — `TypeSafeError` and all API/connection/timeout/validation errors
- `core/` — `TypeSafeConfig`, `TypeSafeConstants`, `TypeSafeLogger`, `RetryPolicy`
- `examples/` — runnable scene script

- `AsyncTypeSafeClient` extends `TypeSafeClient` (same signal-based async API;
  `await client.evaluation_completed`, `aclose()` alias of `close()`).
- `client.models.list()` mirrors `client.models.list()` in Python
  (`list_completed` / `list_failed` signals).
- `system_one(state, questions, model, retry, timeout, extra_headers,
  extra_body, response_model)` mirrors Python. `state` must not be null.
  Questions are keyed by name; raw Dictionaries may be mixed with objects and
  pass unknown fields (e.g. `weight`) through untouched. `extra_body` shallow
  merges last-write-wins. `response_model` is a
  `Callable(raw_json: Dictionary, headers: Dictionary) -> Variant` (GDScript
  equivalent of pydantic `response_model`); results emit
  `custom_evaluation_completed`.
- `extra_headers` cannot override `Authorization`, `Accept`, or `User-Agent`.
- Unknown answer kinds are skipped with a warning; unknown response fields are
  ignored. `response.answers` holds every answer; `.nouls` / `.choices` /
  `.scores` filter by type. `response.request_id` and
  `response.raw_http_response` mirror Python.

## Classes

- Client: `TypeSafeClient`, `AsyncTypeSafeClient`
- Questions: `Question`, `Noul`, `Choice`, `Score`
- Answers: `NoulAnswer` (noul), `ChoiceAnswer` (choice, confidence,
  probabilities), `ScoreAnswer` (score float, confidence, legend/probabilities
  keyed by int level)
- Responses: `SystemOneResponse`, `Usage` (nullable tokens),
  `ModelMetadata`, `ListModelsResponse`
- Errors: `TypeSafeError`, `TypeSafeAPIError` (`.status`/`.status_code`,
  `.body`, `.headers`, `.endpoint`, `.request_id`), `TypeSafeBadRequestError`,
  `TypeSafeAuthenticationError`, `TypeSafePermissionDeniedError`,
  `TypeSafeNotFoundError`, `TypeSafeUnprocessableEntityError`,
  `TypeSafeRateLimitError` (`.retry_after_ms`), `TypeSafeInternalServerError`,
  `TypeSafeAPIConnectionError`, `TypeSafeAPITimeoutError` (`.timeout`),
  `TypeSafeAPIResponseValidationError` (`.field_path`)
- Config: `TypeSafeConfig`, `TypeSafeConstants`, `TypeSafeLogger`,
  `RetryPolicy` (`RetryPolicy.default()` / `RetryPolicy.no_retry()`)

## Tests

- `tests/parity_check.gd` — offline checks, no key needed:
  `Godot --headless --path <project> --script res://tests/parity_check.gd`
- `tests/live_e2e_check.gd` — live round-trip, needs `TYPESAFE_API_KEY`:
  same invocation with `--script res://tests/live_e2e_check.gd`
