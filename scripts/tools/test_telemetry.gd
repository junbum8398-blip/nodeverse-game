extends SceneTree

func _initialize() -> void:
	_run_tests()

func _run_tests() -> void:
	await process_frame
	await process_frame
	print("\n=== [TELEMETRY UNIT TEST START] ===")
	
	# 1. Check NetworkManager autoload
	var nm = root.get_node_or_null("NetworkManager")
	if nm == null:
		print("FAIL: NetworkManager not found in root!")
		quit(1)
		return
	print("PASS: NetworkManager found in root: ", nm)
	
	# 2. Check initial configuration
	print("INFO: Target Host: ", nm.target_host, ":", nm.target_port, nm.endpoint_path)
	print("INFO: Session ID: ", nm.session_id)
	print("INFO: Player ID: ", nm.player_id)
	
	# 3. Test Offline Transmission (Server not running yet)
	print("TEST: Testing transmission while offline (expecting graceful fallback)...")
	nm.send_test_dummy_event()
	
	# Wait 3.5 seconds for request to complete/fail
	await create_timer(3.5).timeout
	
	print("INFO: Status after offline test: ", nm.call("_status_to_string", nm.current_status))
	print("INFO: Last Error Msg: ", nm.last_error_message)
	print("INFO: Total Failed Count: ", nm.total_sent_failed)
	
	if nm.current_status == nm.NetStatus.OFFLINE or nm.total_sent_failed > 0:
		print("PASS: Graceful offline handling verified! Game did not crash or hang.")
	else:
		print("WARN: Unexpected status: ", nm.current_status)
		
	print("=== [TELEMETRY UNIT TEST END] ===\n")
	quit(0)
