extends SceneTree
## End-user style live test. Needs TYPESAFE_API_KEY in the environment.
## Covers: README flow with await, concurrent calls, bad-key 401 mapping,
## retry-against-dead-host, response_model Callable, AsyncTypeSafeClient.
## Run: Godot_v4.7.2 --headless --path <project> --script res://tests/live_e2e_check.gd

var _fails: int = 0


func check(p_cond: bool, p_label: String) -> void:
	if p_cond:
		print("PASS: ", p_label)
	else:
		_fails += 1
		printerr("FAIL: ", p_label)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# 1. README flow: new -> add to tree -> system_one -> await signal.
	var client := TypeSafeClient.new()
	get_root().add_child(client)
	await process_frame
	check(client.models.is_inside_tree(), "models resource auto-added to tree")
	var got: Array = []
	client.evaluation_completed.connect(func(r: SystemOneResponse) -> void: got.append(r))
	client.evaluation_failed.connect(func(e: TypeSafeError) -> void: got.append(e))
	var rc := client.system_one(
		"I was charged twice. Please fix this ASAP.",
		{
			"billing": Noul.new("Is this ticket about billing?"),
			"tone": Choice.new("Tone?", {"calm": null, "angry": null}),
			"urgency": Score.new("Urgent?", ["low", "high"]),
		}
	)
	check(rc == OK, "system_one returns OK")
	check(await _wait_for(func() -> bool: return got.size() > 0, 90.0), "response arrives")
	if got.size() > 0 and got[0] is SystemOneResponse:
		var r: SystemOneResponse = got[0]
		check(r.has_noul("billing") and r.has_choice("tone") and r.has_score("urgency"), "all three answer types")
		var b: NoulAnswer = r.get_noul("billing")
		var t: ChoiceAnswer = r.get_choice("tone")
		var u: ScoreAnswer = r.get_score("urgency")
		print("noul=", b.noul if b else "missing", " choice=", t.choice if t else "missing", " score=", u.score if u else "missing")
	else:
		var detail := str(got[0])
		if got[0] is TypeSafeError:
			detail = (got[0] as TypeSafeError).to_string()
		printerr("first call outcome: ", detail)
		check(false, "first call succeeds")

	# 2. Concurrent calls on the same client both complete.
	var both: Array = []
	client.evaluation_completed.connect(func(rr: SystemOneResponse) -> void: both.append(rr))
	client.system_one("The sky is blue.", {"sky": Noul.new("Is the sky blue?")})
	client.system_one("Water is wet.", {"wet": Noul.new("Is water wet?")})
	check(await _wait_for(func() -> bool: return both.size() >= 2, 90.0), "concurrent calls both complete")

	# 3. Bad key -> 401 AuthenticationError (no tokens spent).
	var bad := TypeSafeClient.new("invalid-key-xyz")
	get_root().add_child(bad)
	await process_frame
	var bad_out: Array = []
	bad.evaluation_failed.connect(func(e: TypeSafeError) -> void: bad_out.append(e))
	bad.system_one("hi", {"q": Noul.new("Q?")})
	check(await _wait_for(func() -> bool: return bad_out.size() > 0, 60.0), "bad key fails")
	if bad_out.size() > 0:
		check(bad_out[0] is TypeSafeAuthenticationError and (bad_out[0] as TypeSafeAPIError).status == 401, "bad key maps to 401 auth error")

	# 4. Dead host -> connection error AFTER retries (backoff is honored).
	var rp := RetryPolicy.new(2, 0.2, 5.0, 0.0)
	var dead := TypeSafeClient.new("k", null, "http://127.0.0.1:9", -1.0, rp)
	get_root().add_child(dead)
	await process_frame
	var dead_out: Array = []
	dead.evaluation_failed.connect(func(e: TypeSafeError) -> void: dead_out.append(e))
	var t0 := Time.get_ticks_msec()
	dead.system_one("hi", {"q": Noul.new("Q?")})
	check(await _wait_for(func() -> bool: return dead_out.size() > 0, 60.0), "dead host fails")
	var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
	print("dead-host elapsed: %.2fs" % elapsed)
	if dead_out.size() > 0:
		# Refused (connection error) or firewall-dropped (timeout) both prove
		# retries ran to budget; either is correct SDK behavior.
		check(dead_out[0] is TypeSafeAPIConnectionError, "dead host = connection/timeout error")
	check(elapsed >= 0.5, "retries actually waited (backoff honored)")

	# 5. response_model Callable (offline equivalent path via _apply_response_model).
	var applied: Array = client._apply_response_model(
		func(j: Dictionary, _h: Dictionary) -> Variant: return j.get("model", "none"),
		{"model": "jev-x"}, {}, {}, 200
	)
	check(applied[0] and str(applied[1]) == "jev-x", "response_model callable applied")

	# 6. AsyncTypeSafeClient end-user flow.
	var aclient := AsyncTypeSafeClient.new()
	get_root().add_child(aclient)
	await process_frame
	var a_out: Array = []
	aclient.evaluation_completed.connect(func(rr: SystemOneResponse) -> void: a_out.append(rr))
	aclient.evaluation_failed.connect(func(e: TypeSafeError) -> void: a_out.append(e))
	aclient.system_one("Hello.", {"greet": Noul.new("Is this a greeting?")})
	check(await _wait_for(func() -> bool: return a_out.size() > 0, 90.0), "async client responds")
	check(a_out.size() > 0 and a_out[0] is SystemOneResponse, "async client succeeds")
	aclient.aclose()

	client.close()
	bad.close()
	dead.close()
	print("----")
	if _fails == 0:
		print("E2E ALL PASSED")
	else:
		printerr("E2E FAILURES: %d" % _fails)
	quit(_fails)


func _wait_for(p_cond: Callable, p_seconds: float) -> bool:
	var start := Time.get_ticks_msec()
	while not bool(p_cond.call()):
		await process_frame
		if (Time.get_ticks_msec() - start) / 1000.0 > p_seconds:
			return false
	return true
