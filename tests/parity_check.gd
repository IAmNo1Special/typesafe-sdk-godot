extends SceneTree
## Temporary headless parity check against the Python SDK behavior.
## Run: Godot_v4.7.2 --headless --path <project> --script res://tests/parity_check.gd

var _fails: int = 0


func check(p_cond: bool, p_label: String) -> void:
	if p_cond:
		print("PASS: ", p_label)
	else:
		_fails += 1
		printerr("FAIL: ", p_label)


func _init() -> void:
	# --- Questions: Python-style constructors + wire format ---
	var n := Noul.new("Is this about billing?")
	check(n.to_dict() == {"type": "noul", "instructions": "Is this about billing?"}, "noul to_dict")
	var n2 := Noul.new("Q?", {"true": "yes it is", "false": null})
	var n2d := n2.to_dict()
	check(n2d["criteria"]["true"] == "yes it is" and n2d["criteria"]["false"] == null, "noul structured criteria + null")
	var c := Choice.new("Tone?", {"calm": null, "angry": "mad"})
	var cd := c.to_dict()
	check(cd == {"type": "choice", "instructions": "Tone?", "criteria": {"calm": null, "angry": "mad"}}, "choice to_dict with null option")
	var s := Score.new("Urgent?", ["low", "high"])
	check(s.to_dict() == {"type": "score", "instructions": "Urgent?", "criteria": ["low", "high"]}, "score to_dict")
	var nstruct := Noul.new({"question": "Same person?", "candidate": {"name": "John"}})
	check(typeof(nstruct.to_dict()["instructions"]) == TYPE_DICTIONARY, "structured instructions dict")

	var client := TypeSafeClient.new("test-key-123")

	# --- Validation (mirrors Python: nonempty questions, nonempty score criteria) ---
	check(client._validate_questions({}) == ERR_INVALID_PARAMETER, "empty questions rejected")
	check(client._validate_questions({"a": Score.new("Q?", [])}) == ERR_INVALID_PARAMETER, "empty score criteria rejected")
	check(client._validate_questions({"a": {"type": "score", "instructions": "Q?", "criteria": []}}) == ERR_INVALID_PARAMETER, "empty raw score criteria rejected")
	check(client._validate_questions({"a": {"type": "choice", "instructions": "Q?"}}) == ERR_INVALID_PARAMETER, "choice without criteria rejected")
	var ok_q := {"billing": Noul.new("B?"), "tone": {"type": "choice", "instructions": "T?", "criteria": {"a": null}}, "u": Score.new("U?", ["l", "h"])}
	check(client._validate_questions(ok_q) == OK, "mixed object+raw questions accepted")
	check(client.system_one(null, ok_q) == ERR_INVALID_PARAMETER, "null state rejected")

	# --- Payload: model/state/questions + extra_body last-write-wins ---
	var payload := client._prepare_system_one("hello", {"b": Noul.new("B?")}, null, {"beam_width": 4, "model": "custom"})
	check(payload["model"] == "custom" and payload["state"] == "hello" and payload["questions"]["b"]["type"] == "noul" and payload["beam_width"] == 4, "extra_body shallow merge wins")
	var payload2 := client._prepare_system_one({"doc": "x"}, {"b": Noul.new("B?")}, "jev", {})
	check(payload2["model"] == "jev", "per-call model override")

	# --- Headers: auth + protected extras ---
	var h := client._build_headers({"X-Custom": "v", "Authorization": "hacked", "Accept": "text/plain"})
	var hd := client._headers_to_dict(h)
	check(hd.get("Authorization") == "Bearer test-key-123", "authorization protected")
	check(hd.get("Accept") == "application/json", "accept protected")
	check(hd.get("X-Custom") == "v", "custom header passes")

	# --- Response parsing ---
	var raw := {
		"model": "jev-1.13.0",
		"usage": {"input_tokens": 296, "output_tokens": 20},
		"answers": {
			"is_urgent": {"type": "noul", "noul": 0.95},
			"dept": {"type": "choice", "choice": "billing", "confidence": 0.81, "probabilities": {"billing": 0.88, "technical": 0.12}},
			"frus": {"type": "score", "score": 1.05, "confidence": 0.92, "legend": {"0": "Calm", "1": "Frustrated"}, "probabilities": {"0": 0.0, "1": 0.95, "2": 0.05}},
			"future": {"type": "quantum", "value": 1},
		},
	}
	var resp := SystemOneResponse.from_dict(raw, {"X-Typesafe-Request-Id": "req-1"}, {"status": 200})
	check(resp.model == "jev-1.13.0", "response model")
	check(resp.nouls["is_urgent"].noul == 0.95, "noul answer")
	check(resp.choices["dept"].choice == "billing" and resp.choices["dept"].confidence == 0.81, "choice answer + confidence")
	check(resp.scores["frus"].score == 1.05 and resp.scores["frus"].legend.has(1) and resp.scores["frus"].probabilities.has(1), "score answer int keys")
	check(resp.answers.size() == 3, "unknown answer kind skipped")
	check(resp.request_id == "req-1", "request_id from header")
	check(resp.usage.input_tokens == 296 and resp.usage.output_tokens == 20, "usage tokens")
	var resp2 := SystemOneResponse.from_dict({"model": "m", "answers": {}}, {}, {})
	check(resp2.usage.input_tokens == null and resp2.usage.output_tokens == null, "usage null when unreported")
	check(resp2.get_noul("missing") == null, "missing answer returns null")

	# --- Errors ---
	var rl := TypeSafeRateLimitError.new(429, {}, {"retry-after-ms": "250"}, "", "ep")
	check(rl.retry_after_ms == 250 and rl.status == 429 and rl.status_code == 429, "rate limit ms header")
	var rl2 := TypeSafeRateLimitError.new(429, {}, {"Retry-After": "2"}, "", "ep")
	check(rl2.retry_after_ms == 2000, "rate limit seconds header")
	var rl3 := TypeSafeRateLimitError.new(429, {}, {}, "", "ep")
	check(rl3.retry_after_ms == null, "rate limit absent -> null")
	var e401 := client._create_api_error(401, {"message": "bad key"}, {})
	check(e401 is TypeSafeAuthenticationError and e401.request_id == null, "401 maps + null request_id")
	check(client._create_api_error(400, {}, {}) is TypeSafeBadRequestError, "400 maps")
	check(client._create_api_error(422, {}, {}) is TypeSafeUnprocessableEntityError, "422 maps")
	check(client._create_api_error(503, {}, {}) is TypeSafeInternalServerError, "5xx maps")

	# --- RetryPolicy parity ---
	var rp := RetryPolicy.default()
	check(rp.max_retries == 2 and rp.backoff_initial == 0.5 and rp.backoff_max == 5.0 and rp.backoff_jitter == 0.25 and rp.timeout == 30.0, "retry defaults")
	check(rp.http_statuses.has(408) and rp.http_statuses.has(429) and rp.http_statuses.has(500) and rp.http_statuses.has(599) and not rp.http_statuses.has(400), "retry statuses 408/429/500-599")
	check(rp.is_retryable(TypeSafeRateLimitError.new(429, {}, {}, "", "e")), "429 retryable")
	check(not rp.is_retryable(TypeSafeBadRequestError.new(400, {}, {}, "", "e")), "400 not retryable")
	check(rp.is_retryable(TypeSafeAPIConnectionError.new("x")), "connection retryable")
	check(rp.is_retryable(TypeSafeAPITimeoutError.new(1.0)), "timeout retryable")
	var rp0 := RetryPolicy.new(2, 0.5, 5.0, 0.0)
	check(rp0.calculate_backoff(1) == 0.5 and rp0.calculate_backoff(2) == 1.0 and rp0.calculate_backoff(20) == 5.0, "backoff doubling + cap")
	check(rp.get_retry_after({"Retry-After": "2"}) == 2.0 and rp.get_retry_after({"retry-after-ms": "250"}) == 0.25 and rp.get_retry_after({}) == -1.0, "retry-after headers")
	check(not client._within_budget(RetryPolicy.no_retry(), 0, 0.0, {}), "no_retry never retries")

	# --- Config / constants ---
	check(TypeSafeConstants.DEFAULT_BASE_URL == "https://api.typesafe.ai", "const base url")
	check(TypeSafeConstants.DEFAULT_MODEL == "jev-latest", "const model")
	check(TypeSafeConstants.DEFAULT_TIMEOUT == 10.0, "const timeout")
	var cfg := TypeSafeConfig.resolve(null, null, null, -1.0, {})
	check(cfg.base_url == "https://api.typesafe.ai" and cfg.default_model == "jev-latest" and cfg.timeout == 10.0, "config defaults")
	check(cfg.system_one_url() == "https://api.typesafe.ai/v1/systemone" and cfg.models_url() == "https://api.typesafe.ai/v1/models", "endpoint urls")
	var cfg2 := TypeSafeConfig.resolve("", null, null, -1.0, {})
	check(cfg2.api_key == "", "explicit empty key does not fall back")
	var cfg3 := TypeSafeConfig.resolve("k", "https://gw.test/", null, -1.0, {})
	check(cfg3.base_url == "https://gw.test" and cfg3.system_one_url() == "https://gw.test/v1/systemone", "custom base url")

	# --- Models response ---
	var lm := ListModelsResponse.from_dict({"models": [{"name": "jev-latest", "description": "d", "release_date": "2026-01-01"}], "extra": 1}, {"x-typesafe-request-id": "m-1"}, {})
	check(lm.models.size() == 1 and lm.models[0].name == "jev-latest" and lm.request_id == "m-1", "models list parse")

	var rpcustom := RetryPolicy.new(1, 0.5, 5.0, 0.0, [429], true, true, true, [], null, 10.0)
	check(rpcustom.http_statuses == [429], "custom statuses assign")
	check(rpcustom.is_retryable(TypeSafeRateLimitError.new(429, {}, {}, "", "e")) and not rpcustom.is_retryable(TypeSafeInternalServerError.new(503, {}, {}, "", "e")), "custom statuses honored")

	# --- Async client parity ---
	var aclient := AsyncTypeSafeClient.new("k")
	check(aclient is TypeSafeClient and aclient.config.default_model == "jev-latest", "async client constructs")

	print("----")
	if _fails == 0:
		print("ALL PARITY CHECKS PASSED")
	else:
		printerr("FAILURES: %d" % _fails)
	quit(_fails)
