extends SceneTree
## Headless checks for the telemetry disk queue and account switching (reliability review P2).
##   godot --headless --path game -s res://scripts/tools/test_disk_queue.gd
## Touches only its own files (names start with "zz-test-") under user://telemetry/ and removes them.
## Exit code 0 = all passed.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures += 1

func _run() -> void:
	var nm = root.get_node_or_null("/root/NetworkManager")
	if nm == null:
		print("FAIL NetworkManager autoload missing")
		quit(1)
		return
	nm._is_busy = true  # never send anything from this test
	nm._ensure_queue_dirs()
	var pending: String = nm.PENDING_DIR
	var corrupt: String = nm.CORRUPT_DIR

	# 1. atomic write: whole file, no .tmp left
	var p1 := pending + "zz-test-ok.json"
	var ok1: bool = nm._atomic_write(p1, JSON.stringify({"event_id": "zz-test-ok", "event_type": "problem_started"}))
	check(ok1 and FileAccess.file_exists(p1) and not FileAccess.file_exists(p1 + ".tmp"), "atomic write leaves only the final file")
	check(JSON.parse_string(FileAccess.get_file_as_string(p1)) is Dictionary, "written file is valid JSON")

	# 2. a failed write is detected and counted (directory does not exist)
	var before: int = nm.disk_write_failures
	var ok2: bool = nm._atomic_write("user://telemetry/zz-test-missing-dir/x/y.json", "{}")
	check(not ok2 and nm.disk_write_failures == before + 1 and nm.last_disk_error != "", "failed write is reported")

	# 3. crash leftovers and broken JSON on start-up
	_write_raw(pending + "zz-test-promote.json.tmp", JSON.stringify({"event_id": "zz-test-promote", "event_type": "problem_started", "occurred_at": "2026-11-20T00:00:00.000Z"}))
	_write_raw(pending + "zz-test-partial.json.tmp", "{\"event_id\": \"zz-te")
	_write_raw(pending + "zz-test-broken.json", "not json at all")
	nm._load_pending_from_disk()
	check(FileAccess.file_exists(pending + "zz-test-promote.json"), "complete .tmp without .json is promoted")
	check(_queue_has(nm, "zz-test-promote"), "promoted event is back in the send queue")
	check(not FileAccess.file_exists(pending + "zz-test-partial.json.tmp"), "partial .tmp leaves pending/")
	check(not FileAccess.file_exists(pending + "zz-test-broken.json"), "broken JSON leaves pending/")
	var kept := _corrupt_names(corrupt)
	check(kept.any(func(n): return n.begins_with("zz-test-partial.json.tmp.partial_write")), "partial write kept in corrupt/ with reason")
	check(kept.any(func(n): return n.begins_with("zz-test-broken.json.invalid_json")), "broken JSON kept in corrupt/ with reason")

	# 4. logout and account switch
	nm.set_active_player_id("zz-test-member-a")
	var a1: Dictionary = nm._create_event("operation_succeeded", {})
	var a2: Dictionary = nm._create_event("operation_succeeded", {})
	nm.clear_active_player_id()
	var guest: Dictionary = nm._create_event("operation_succeeded", {})
	nm.set_active_player_id("zz-test-member-b")
	var b1: Dictionary = nm._create_event("operation_succeeded", {})
	check(a1["player_id"] == "zz-test-member-a" and a2["player_id"] == "zz-test-member-a", "A's events keep A")
	check(a2["sequence"] == a1["sequence"] + 1 and a1["session_id"] == a2["session_id"], "A's session continues in order")
	check(guest["session_id"] != a1["session_id"] and guest["sequence"] == 1, "logout starts a new session at sequence 1")
	check(guest["run_id"] != a1["run_id"], "logout starts a new run")
	check(b1["player_id"] == "zz-test-member-b" and b1["session_id"] != guest["session_id"] and b1["sequence"] == 1, "B gets an independent session")
	check(b1["run_id"] != a1["run_id"] and b1["attempt_id"] != a1["attempt_id"], "B never reuses A's run or attempt")
	check(a1["player_id"] == "zz-test-member-a", "A's queued dictionaries are not rewritten by the switch")
	nm.clear_active_player_id()

	_cleanup(pending, corrupt)
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(0 if failures == 0 else 1)

func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _queue_has(nm, ev_id: String) -> bool:
	for item in nm._pending_queue:
		if str(item.get("event_id", "")) == ev_id:
			return true
	return false

func _corrupt_names(corrupt: String) -> Array:
	var d := DirAccess.open(corrupt)
	return Array(d.get_files()) if d != null else []

func _cleanup(pending: String, corrupt: String) -> void:
	for dir_path in [pending, corrupt]:
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		for n in d.get_files():
			if n.begins_with("zz-test-"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(dir_path + n))
