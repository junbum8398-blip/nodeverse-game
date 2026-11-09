extends SceneTree

func _initialize() -> void:
	_run_tests()

func _run_tests() -> void:
	await process_frame
	await process_frame
	print("\n=== [ONLINE TELEMETRY TEST START] ===")
	
	var nm = root.get_node_or_null("NetworkManager")
	if nm == null:
		print("FAIL: NetworkManager not found!")
		quit(1)
		return
	
	print("PASS: NetworkManager ready. Target: ", nm.get_full_url())
	
	# Send test dummy events
	print("TEST: Sending mini-game events to server...")
	nm.start_task("ST01_ARRAY", {"stage": "Array Storage", "goal": "Index 1 insert 20"})
	nm.start_attempt("ST01_ARRAY", 1, {"arr": [10, 30, 40], "tray": 20})
	nm.record_operation("crate_shift", true, "", {"from": 2, "to": 3}, {"from": 1, "to": 2})
	nm.record_operation("crate_insert", true, "", {}, {}, {"value": 20, "slot": 1})
	nm.complete_attempt("ST01_ARRAY", true, "", {"moves": 2, "mistakes": 0, "stars": 3})
	nm.complete_task("ST01_ARRAY", {"total_moves": 2, "stars": 3, "status": "perfect_clear"})
	
	# Wait for HTTP requests to flush
	await create_timer(1.5).timeout
	
	print("INFO: Status: ", nm.call("_status_to_string", nm.current_status))
	print("INFO: Total Sent Success: ", nm.total_sent_success)
	print("INFO: Total Sent Failed: ", nm.total_sent_failed)
	print("INFO: Last Latency: ", nm.last_latency_ms, "ms")
	
	if nm.total_sent_success >= 5 and nm.total_sent_failed == 0:
		print("PASS: All 5 mini-game events successfully transmitted and acknowledged (200 OK)!")
	else:
		print("FAIL: Expected at least 5 successes, got: ", nm.total_sent_success)
		quit(1)
		return
		
	print("=== [ONLINE TELEMETRY TEST COMPLETE] ===\n")
	quit(0)
