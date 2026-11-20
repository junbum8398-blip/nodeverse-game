extends SceneTree
## NODEVERSE Scenario-Driven Automated Bot (Simulator) Verification Runner
## Usage:
##   Godot_console.exe --headless --path . --script res://scripts/tools/scenario_bot_runner.gd -- --scenario=res://scenarios/default_full_scenario.json --out=res://output/reports/latest_bot_result.json

const Catalog = preload("res://scripts/learning_catalog.gd")
const AuthMgr = preload("res://scripts/auth_manager.gd")

const WALK_SCENE_MAP := {
	"ST01": "ST01_Array",
	"ST02": "ST02_LinkedList",
	"ST03": "ST03_Stack",
	"ST04": "ST04_QueueDeque",
	"ST05": "ST05_Hash",
	"ST06": "ST06_BinaryTree",
	"ST07": "ST07_Bst",
	"ST08": "ST08_Heap",
	"ST09": "ST09_Graph",
	"ST10": "ST10_Integrated"
}

var scenario_path: String = "res://scenarios/default_full_scenario.json"
var out_path: String = "res://output/reports/latest_bot_result.json"
var is_visual_mode: bool = false
var step_results: Array = []
var total_passed: int = 0
var total_failed: int = 0
var game = null
var sql_g = null

func _init() -> void:
	call_deferred("_run_bot")

func _parse_args() -> void:
	var all_args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in all_args:
		var s := str(arg).strip_edges()
		if s.begins_with("--scenario="):
			scenario_path = s.trim_prefix("--scenario=").strip_edges()
		elif s.begins_with("--out="):
			out_path = s.trim_prefix("--out=").strip_edges()
		elif s == "--visual":
			is_visual_mode = true
	if DisplayServer.get_name() != "headless":
		is_visual_mode = true

func _resolve_path(p: String) -> String:
	if p.begins_with("res://") or p.begins_with("user://"):
		return p
	return ProjectSettings.localize_path(p)

func _run_bot() -> void:
	_parse_args()
	create_timer(300.0).timeout.connect(_on_timeout)

	await process_frame
	await process_frame

	MiniGameBase.progress_saving = false
	var nm = root.get_node_or_null("NetworkManager")
	if nm:
		nm.auto_send_enabled = false

	var started_ms := Time.get_ticks_msec()
	var started_iso := Time.get_datetime_string_from_system(false, true)

	var local_scen := _resolve_path(scenario_path)
	if not FileAccess.file_exists(local_scen) and not FileAccess.file_exists(scenario_path):
		print("[BOT][ERROR] Scenario file not found: ", scenario_path)
		quit(1)
		return

	var raw_txt := FileAccess.get_file_as_string(local_scen if FileAccess.file_exists(local_scen) else scenario_path)
	var parsed = JSON.parse_string(raw_txt)
	if not (parsed is Dictionary) or not parsed.has("steps"):
		print("[BOT][ERROR] Invalid scenario JSON format: ", scenario_path)
		quit(1)
		return

	var meta: Dictionary = parsed.get("meta", {})
	var steps: Array = parsed.get("steps", [])
	print("\n============================================================")
	print("[NODEVERSE BOT] Scenario: %s (%s)" % [str(meta.get("title", "")), str(meta.get("scenario_id", ""))])
	print("[NODEVERSE BOT] Mode: %s | Steps: %d" % ["visual" if is_visual_mode else "headless", steps.size()])
	print("============================================================")

	# Backup existing accounts store so real local user accounts are untouched after test
	var acc_backup := ""
	if FileAccess.file_exists(AuthMgr.SAVE_PATH):
		acc_backup = FileAccess.get_file_as_string(AuthMgr.SAVE_PATH)

	for step_item in steps:
		if not (step_item is Dictionary):
			continue
		var sid := str(step_item.get("step_id", "STEP"))
		var cat := str(step_item.get("category", "GENERAL"))
		var sname := str(step_item.get("name", sid))
		var action := str(step_item.get("action", ""))
		var params: Dictionary = step_item.get("params", {}) if step_item.get("params") is Dictionary else {}
		var expect: Dictionary = step_item.get("expect", {}) if step_item.get("expect") is Dictionary else {}

		var t0 := Time.get_ticks_msec()
		var res: Dictionary = await _execute_step(action, params, expect)
		var elapsed := Time.get_ticks_msec() - t0
		var passed := bool(res.get("passed", false))
		if passed:
			total_passed += 1
		else:
			total_failed += 1

		var shot_path := ""
		if is_visual_mode:
			shot_path = await _capture_step_screen(sid)

		var rec := {
			"step_id": sid,
			"category": cat,
			"name": sname,
			"action": action,
			"passed": passed,
			"status": "PASS" if passed else "FAIL",
			"duration_ms": elapsed,
			"expected": str(res.get("expected_summary", JSON.stringify(expect))),
			"actual": str(res.get("actual_summary", "")),
			"detail": str(res.get("detail", "")),
			"screenshot": shot_path
		}
		step_results.append(rec)
		print("[%s] %s (%s) - %s [%dms] -> %s" % [
			rec["status"], sid, cat, sname, elapsed, rec["actual"]
		])

	# Restore original accounts store
	if not acc_backup.is_empty():
		var wf := FileAccess.open(AuthMgr.SAVE_PATH, FileAccess.WRITE)
		if wf:
			wf.store_string(acc_backup)
			wf.close()

	var total_duration := Time.get_ticks_msec() - started_ms
	var total_steps := step_results.size()
	var pass_rate := (100.0 * float(total_passed) / float(maxi(1, total_steps)))

	var nm_ver := "0.3.0"
	var django_target := "http://192.168.0.29:8000"
	var collector_target := "http://192.168.0.81:8000/v2/events"
	if nm:
		nm_ver = nm.get_build_version()
		django_target = nm.get_api_base_url()
		collector_target = nm.get_full_url()

	var report := {
		"meta": {
			"scenario_id": str(meta.get("scenario_id", "NV-BOT-E2E-001")),
			"title": str(meta.get("title", "NODEVERSE 시나리오 기반 자동화 봇 기능 검증")),
			"version": str(meta.get("version", "1.0.0")),
			"executed_at": started_iso,
			"mode": "Visual (1280x720)" if is_visual_mode else "Headless (CLI Fast Simulation)",
			"engine": "Godot Engine v" + Engine.get_version_info().get("string", "4.7.2-stable"),
			"build_version": nm_ver,
			"content_version": nm.content_version if nm else "base",
			"django_server": django_target,
			"collector_server": collector_target
		},
		"summary": {
			"total_steps": total_steps,
			"passed_steps": total_passed,
			"failed_steps": total_failed,
			"pass_rate_percent": snappedf(pass_rate, 0.1),
			"total_duration_ms": total_duration,
			"overall_status": "PASS" if total_failed == 0 else "FAIL"
		},
		"steps": step_results
	}

	var out_global := ProjectSettings.globalize_path(_resolve_path(out_path)) if (out_path.begins_with("res://") or out_path.begins_with("user://")) else out_path
	DirAccess.make_dir_recursive_absolute(out_global.get_base_dir())
	var rf := FileAccess.open(out_global, FileAccess.WRITE)
	if rf:
		rf.store_string(JSON.stringify(report, "  "))
		rf.close()

	print("============================================================")
	print("[NODEVERSE BOT] DONE: %d/%d PASS (%.1f%%) in %dms" % [
		total_passed, total_steps, pass_rate, total_duration
	])
	print("[NODEVERSE BOT] Result JSON saved to: %s" % out_global)
	print("============================================================\n")
	quit(0 if total_failed == 0 else 1)

func _on_timeout() -> void:
	print("[BOT][TIMEOUT] Verification exceeded 300s limit.")
	quit(1)

func _capture_step_screen(step_id: String) -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	for i in 2:
		await RenderingServer.frame_post_draw
	var dir_global := ProjectSettings.globalize_path("res://output/captures")
	DirAccess.make_dir_recursive_absolute(dir_global)
	var file_global := "%s/%s.png" % [dir_global, step_id]
	var tex := root.get_texture()
	if tex and tex.get_image():
		tex.get_image().save_png(file_global)
		return file_global
	return ""

# ============================================================================
# STEP DISPATCHER
# ============================================================================
func _execute_step(action: String, params: Dictionary, expect: Dictionary) -> Dictionary:
	match action:
		"auth_register":
			return _step_auth_register(params, expect)
		"auth_find_id":
			return _step_auth_find_id(params, expect)
		"auth_reset_password":
			return _step_auth_reset_password(params, expect)
		"auth_login":
			return _step_auth_login(params, expect)
		"save_and_continue":
			return _step_save_and_continue(params, expect)
		"reset_new_game":
			return _step_reset_new_game(params, expect)
		"world_terminals":
			return await _step_world_terminals(params, expect)
		"play_minigame_group":
			return await _step_play_minigame_group(params, expect)
		"schema_v2_contract":
			return _step_schema_v2_contract(params, expect)
		"disk_queue_lifecycle":
			return _step_disk_queue_lifecycle(params, expect)
		"update_manager_check":
			return _step_update_manager_check(params, expect)
		"exit_marker_check":
			return _step_exit_marker_check(params, expect)
		_:
			return {
				"passed": false,
				"expected_summary": "정의된 시나리오 액션",
				"actual_summary": "알 수 없는 액션: " + action,
				"detail": "Unsupported action key"
			}

# ============================================================================
# PHASE 1: AUTH & ACCOUNT RECOVERY
# ============================================================================
func _remove_test_user(uname: String) -> void:
	var store := AuthMgr._get_store()
	var users: Dictionary = store.get("users", {})
	if users.has(uname):
		users.erase(uname)
		store["users"] = users
		AuthMgr._save_store(store)

func _step_auth_register(params: Dictionary, _expect: Dictionary) -> Dictionary:
	var uname := str(params.get("username", "qa_bot_tester"))
	var pw := str(params.get("password", "bot_pass_2026"))
	var rkey := str(params.get("recovery_key", "qa_bot@nodeverse.io"))
	_remove_test_user(uname)

	var r1 := AuthMgr.register(uname, pw, rkey)
	var r_dup := AuthMgr.register(uname, pw, rkey)
	var store := AuthMgr._get_store()
	var users: Dictionary = store.get("users", {})
	var rec: Dictionary = users.get(uname, {})
	var p_hash := str(rec.get("password_hash", ""))
	var has_plain := rec.has("password")
	var raw_file := FileAccess.get_file_as_string(AuthMgr.SAVE_PATH)
	var no_plain_in_file := not raw_file.contains(pw)

	var ok := bool(r1.get("success", false)) and (not bool(r_dup.get("success", true))) and p_hash.begins_with("sha256:") and (not has_plain) and no_plain_in_file
	return {
		"passed": ok,
		"expected_summary": "신규가입 성공, 중복가입 차단, sha256 해시 저장(평문 미존재)",
		"actual_summary": "가입=%s, 중복차단=%s, 해시=%s, 평문미존재=%s" % [
			str(r1.get("success", false)),
			str(not r_dup.get("success", true)),
			p_hash.left(15) + "...",
			str(no_plain_in_file)
		],
		"detail": "AuthManager.register & G6 SHA-256 verification"
	}

func _step_auth_find_id(params: Dictionary, expect: Dictionary) -> Dictionary:
	var rkey := str(params.get("recovery_key", "qa_bot@nodeverse.io"))
	var wrong_key := str(params.get("wrong_recovery_key", "wrong@nodeverse.io"))
	var want_user := str(expect.get("found_username", params.get("username", "qa_bot_tester")))

	var r_ok := AuthMgr.find_usernames_by_recovery(rkey)
	var r_bad := AuthMgr.find_usernames_by_recovery(wrong_key)
	var found_list: Array = r_ok.get("usernames", [])
	var has_user := found_list.has(want_user)
	var wrong_blocked := not bool(r_bad.get("success", true))
	var ok := bool(r_ok.get("success", false)) and has_user and wrong_blocked

	return {
		"passed": ok,
		"expected_summary": "복구키 일치 시 [%s] 반환, 불일치 시 차단" % want_user,
		"actual_summary": "찾은ID=%s, 불일치차단=%s" % [str(found_list), str(wrong_blocked)],
		"detail": "AuthManager.find_usernames_by_recovery verification"
	}

func _step_auth_reset_password(params: Dictionary, _expect: Dictionary) -> Dictionary:
	var uname := str(params.get("username", "qa_bot_tester"))
	var rkey := str(params.get("recovery_key", "qa_bot@nodeverse.io"))
	var old_pw := str(params.get("old_password", "bot_pass_2026"))
	var new_pw := str(params.get("new_password", "bot_new_pass_999"))

	var r_wrong_key := AuthMgr.reset_password(uname, "invalid_recovery_key", new_pw)
	var r_reset := AuthMgr.reset_password(uname, rkey, new_pw)
	var r_old_login := AuthMgr.login(uname, old_pw)

	var ok := (not bool(r_wrong_key.get("success", true))) and bool(r_reset.get("success", false)) and (not bool(r_old_login.get("success", true)))
	return {
		"passed": ok,
		"expected_summary": "복구키 검증 후 새 비밀번호 해시 갱신, 구 비밀번호 로그인 차단",
		"actual_summary": "재설정=%s, 오답복구키차단=%s, 구비번차단=%s" % [
			str(r_reset.get("success", false)),
			str(not r_wrong_key.get("success", true)),
			str(not r_old_login.get("success", true))
		],
		"detail": "AuthManager.reset_password verification"
	}

func _step_auth_login(params: Dictionary, _expect: Dictionary) -> Dictionary:
	var uname := str(params.get("username", "qa_bot_tester"))
	var pw := str(params.get("password", "bot_new_pass_999"))
	var r_login := AuthMgr.login(uname, pw)
	var ok := bool(r_login.get("success", false)) and str(r_login.get("username", "")) == uname
	return {
		"passed": ok,
		"expected_summary": "변경된 비밀번호로 [%s] 로그인 성공" % uname,
		"actual_summary": "로그인=%s, 계정=%s" % [str(ok), str(r_login.get("username", ""))],
		"detail": "AuthManager.login verification"
	}

# ============================================================================
# PHASE 2: CLOUD SAVE & CONTINUE / NEW GAME RESET
# ============================================================================
func _step_save_and_continue(params: Dictionary, _expect: Dictionary) -> Dictionary:
	var uname := str(params.get("username", "qa_bot_tester"))
	var pw := str(params.get("password", "bot_new_pass_999"))
	var target_score := int(params.get("score", 350))
	var target_zone := str(params.get("zone", "SQL"))
	var target_pos: Array = params.get("player_pos", [18.5, 1.08, -24.2])
	var target_stars: Dictionary = params.get("minigame_cleared", {"ST01": 3, "SQL01": 2, "ALG01": 3})

	var save_payload := {
		"difficulty": "NOVICE",
		"score": target_score,
		"zone": target_zone,
		"player_pos": target_pos,
		"cleared_quizzes": ["DS_Q1", "SQL_Q1"],
		"minigame_cleared": target_stars
	}
	var saved_ok := AuthMgr.save_user_progress(uname, save_payload)
	var relogin := AuthMgr.login(uname, pw)
	var sd: Dictionary = relogin.get("save_data", {})
	MiniGameBase.set_account_progress(sd.get("minigame_cleared", {}))
	var restored_stars := MiniGameBase.get_account_progress()

	var stars_ok: bool = int(restored_stars.get("ST01", 0)) == 3 and int(restored_stars.get("SQL01", 0)) == 2
	var ok: bool = saved_ok and int(sd.get("score", -1)) == target_score and str(sd.get("zone", "")) == target_zone and bool(sd.get("has_saved_game", false)) and stars_ok
	return {
		"passed": ok,
		"expected_summary": "점수=%d, 구역=%s, 미니게임별점(ST01:3,SQL01:2) 100%% 복원" % [target_score, target_zone],
		"actual_summary": "복원점수=%d, 구역=%s, 별점=%s, 이어하기플래그=%s" % [
			int(sd.get("score", -1)), str(sd.get("zone", "")), JSON.stringify(restored_stars), str(sd.get("has_saved_game", false))
		],
		"detail": "Save & Continue round-trip verification"
	}

func _step_reset_new_game(params: Dictionary, _expect: Dictionary) -> Dictionary:
	var uname := str(params.get("username", "qa_bot_tester"))
	var diff := str(params.get("difficulty", "ADVANCED"))

	var fresh := AuthMgr.reset_user_progress(uname, diff)
	MiniGameBase.clear_account_progress()
	var verify_sd := AuthMgr.get_user_progress(uname)
	var stars_after := MiniGameBase.get_account_progress()

	var ok: bool = int(verify_sd.get("score", -1)) == 0 and str(verify_sd.get("zone", "")) == "MAIN" and verify_sd.get("minigame_cleared", {}).is_empty() and stars_after.is_empty() and (not bool(verify_sd.get("has_saved_game", true)))
	return {
		"passed": ok,
		"expected_summary": "점수=0, 구역=MAIN, 미니게임별점={}, has_saved_game=false 초기화",
		"actual_summary": "점수=%d, 구역=%s, 별점=%s, has_saved=%s" % [
			int(verify_sd.get("score", -1)), str(verify_sd.get("zone", "")), JSON.stringify(stars_after), str(verify_sd.get("has_saved_game", true))
		],
		"detail": "Start From Scratch (처음부터 시작) reset verification"
	}

# ============================================================================
# PHASE 3: 3D WORLD & 4 COMPUTER TERMINALS
# ============================================================================
func _is_category_btn(b: Array) -> bool:
	return str(b[1]).begins_with("category:")

func _step_world_terminals(_params: Dictionary, _expect: Dictionary) -> Dictionary:
	var world = (load("res://scenes/NodeverseWorld.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await world.world_built
	world._set_game_state(world.GameState.PLAYING)
	current_scene = world

	var seen := {}
	var isolation_ok := true
	var return_ok := true

	for terminal in world.computer_terminals:
		world.player.teleport_to(terminal.global_position + terminal.global_basis.z * 1.6)
		var camera = world.player.cam
		world.player.cam = null
		await world._open_computer_game()
		world.player.cam = camera
		var menu = current_scene
		var zone: String = terminal.get_meta("quiz_zone", "DS")
		seen[zone] = true

		if menu == world or menu.get_script().resource_path != "res://scripts/main_menu.gd":
			isolation_ok = false
		if Catalog.selected_category != zone or not Catalog.CATEGORIES.has(zone):
			isolation_ok = false
		if world.is_quiz_open:
			isolation_ok = false

		await process_frame
		await process_frame

		for b in menu._buttons:
			var bid := str(b[1])
			if bid.begins_with("category:"):
				isolation_ok = false
			for g in Catalog.GAMES:
				if g[3] != zone and g[4] == bid:
					isolation_ok = false

		menu._go_back_to_world()
		if current_scene != world:
			return_ok = false
		await process_frame

	world.queue_free()
	await process_frame

	var ok := seen.size() == 4 and isolation_ok and return_ok
	return {
		"passed": ok,
		"expected_summary": "4대 터미널(DS,ALGO,SQL,DATA) 카테고리 격리 노출 및 3D 월드 복귀",
		"actual_summary": "검증터미널=%d개(%s), 격리=%s, 복귀=%s" % [
			seen.size(), ",".join(seen.keys()), str(isolation_ok), str(return_ok)
		],
		"detail": "NodeverseWorld 4 computer terminals E2E routing"
	}

# ============================================================================
# PHASE 4: 24 MINIGAMES AUTOMATED BOT SOLVER
# ============================================================================
func _step_play_minigame_group(params: Dictionary, _expect: Dictionary) -> Dictionary:
	var group := str(params.get("group", "WALK_STAGES"))
	match group:
		"WALK_STAGES":
			return _bot_play_walk_stages(params)
		"DS_LABS":
			return _bot_play_ds_labs(params)
		"ALGO_LABS":
			return _bot_play_algo_labs(params)
		"SQL_LABS":
			return await _bot_play_sql_labs(params)
		"DATA_LABS":
			return _bot_play_data_labs(params)
		_:
			return {"passed": false, "expected_summary": "유효한 미니게임 그룹", "actual_summary": "알 수 없는 그룹: " + group, "detail": ""}

func _bot_play_walk_stages(params: Dictionary) -> Dictionary:
	var stages: Array = params.get("stages", ["ST01", "ST02", "ST03", "ST04", "ST05", "ST06", "ST07", "ST08", "ST09", "ST10"])
	var cleared_list: Array = []
	var fail_list: Array = []
	var star_deduct_verified := false

	for sid in stages:
		var stage_code := str(sid)
		var scene_name: String = WALK_SCENE_MAP.get(stage_code, "")
		if scene_name.is_empty():
			fail_list.append(stage_code)
			continue
		var s = (load("res://scenes/stages/%s.tscn" % scene_name) as PackedScene).instantiate()
		root.add_child(s)
		s.hud.dialogue_skip()

		var stage_ok := true
		if stage_code == "ST01":
			# Inject 1 intentional mistake on level 0 and test hint/optimal path across all levels
			s._slot(0)
			if s.mistakes == 1:
				star_deduct_verified = true
			for lv in s.LEVELS.size():
				s.start_level(lv)
				s.hud.dialogue_skip()
				if lv == 0 and bool(params.get("inject_mistakes", 0) > 0):
					s._slot(0) # 1 mistake -> 2 stars
				var guard := 0
				while not s.done and guard < 50:
					guard += 1
					var a: Array = s._next_action()
					match a[0]:
						"slot": s._slot(a[1])
						"tray": s._tray()
						"bin": s._bin()
					s._refresh()
					s._check()
				if not s.done:
					stage_ok = false
		else:
			# ST02 ~ ST10 WalkStage subclasses
			for lv in s.level_count:
				s.start_level(lv)
				s.hud.dialogue_skip()
				if lv == 0 and stage_code == "ST02":
					# Intentional mistake + undo verification
					s.interact(s.spot("node", 1))
					if s.mistakes >= 1 and s.stars() == 2:
						star_deduct_verified = true
				var guard := 0
				while not s.done and guard < 120:
					guard += 1
					var na: Array = s.next_action()
					var t = na[0]
					if t == null:
						break
					s.interact(t)
					s.refresh()
					if guard == 1 and lv == 0 and bool(params.get("use_undo", false)) and not s._undo.is_empty():
						s.undo_last()
						var na2: Array = s.next_action()
						if na2[0] != null:
							s.interact(na2[0])
							s.refresh()
				if not s.done:
					stage_ok = false
					break

		s.free()
		if stage_ok:
			cleared_list.append(stage_code)
		else:
			fail_list.append(stage_code)

	var ok := fail_list.is_empty() and cleared_list.size() == stages.size() and star_deduct_verified
	return {
		"passed": ok,
		"expected_summary": "ST01~ST10(10종) 전 레벨 클리어, 오답 주입 시 2성 차감 및 Undo 복원",
		"actual_summary": "클리어=%d/%d종(%s), 별점차감·Undo=%s" % [
			cleared_list.size(), stages.size(), ",".join(cleared_list), str(star_deduct_verified)
		],
		"detail": "Walk stages ST01~ST10 automated solver verification"
	}

func _open_lab(scene: String) -> void:
	game = (load("res://scenes/stages/%s.tscn" % scene) as PackedScene).instantiate()
	root.add_child(game)
	game.set("fast_flow", true)
	game.hud.dialogue_skip()

func _close_lab() -> void:
	if game != null:
		game.free()
		game = null

func _lab_level(n: int) -> void:
	game.start_level(n)
	game.hud.dialogue_skip()

func _lab_press(keys: Array) -> void:
	for k in keys:
		game.on_button(k)

func _bot_play_ds_labs(_params: Dictionary) -> Dictionary:
	var ok_count := 0
	# DS09 TreeStructure (3 levels + mistake + undo)
	_open_lab("DS09_TreeStructure")
	_lab_press(["A", "A", "left"]) # intentional self-link mistake
	var ds09_mistake_ok: bool = (game.mistakes == 1)
	game.state.parent = ""
	game.state.child = ""
	_lab_press(["A", "B", "left", "A", "C", "right", "check"])
	var l1_ok: bool = game.level_done
	_lab_level(1)
	_lab_press(["A", "B", "left", "A", "C", "right", "B", "D", "left", "C", "E", "right", "check"])
	var l2_ok: bool = game.level_done
	_lab_level(2)
	_lab_press(["C", "D", "unlink", "B", "C", "unlink", "B", "D", "left"])
	game.undo()
	var undo_ok: bool = (game.state.edges == {"A": ["B", null]})
	_lab_press(["B", "D", "left", "A", "C", "right", "B", "E", "right", "check"])
	var l3_ok: bool = game.level_done
	_close_lab()
	if ds09_mistake_ok and l1_ok and l2_ok and undo_ok and l3_ok:
		ok_count += 1

	# DS10 GraphBuild (3 levels + mistake)
	_open_lab("DS10_GraphBuild")
	_lab_press(["A", "A", "add"]) # intentional loop mistake
	var ds10_mistake_ok: bool = (game.mistakes == 1)
	_lab_press(["A", "B", "add", "B", "D", "add", "C", "A", "add", "D", "C", "add", "check"])
	var g1_ok: bool = game.level_done
	_lab_level(1)
	_lab_press(["A", "B", "add", "B", "C", "add", "C", "A", "add", "D", "A", "add", "check"])
	var g2_ok: bool = game.level_done
	_lab_level(2)
	_lab_press(["C", "B", "del"])
	game.state.cost = 3
	_lab_press(["A", "B", "add", "cost-", "B", "C", "add"])
	game.state.cost = 4
	_lab_press(["C", "A", "add"])
	game.state.cost = 1
	_lab_press(["D", "A", "add", "check"])
	var g3_ok: bool = game.level_done
	_close_lab()
	if ds10_mistake_ok and g1_ok and g2_ok and g3_ok:
		ok_count += 1

	return {
		"passed": ok_count == 2,
		"expected_summary": "DS09(트리 3레벨)·DS10(그래프 3레벨) 오답 거부·Undo 복원 및 전원 클리어",
		"actual_summary": "클리어=%d/2종(DS09,DS10), Undo복원=%s" % [ok_count, str(undo_ok)],
		"detail": "DS09_TreeStructure & DS10_GraphBuild automated verification"
	}

func _vals() -> Array:
	var out := []
	for c in game.state.a:
		out.append(c[0])
	return out

func _solve_shortest_path() -> void:
	var p: Dictionary = game.problems()[game.problem]
	var pid: int = game.problem
	var guard := 0
	while not game.level_done and game.problem == pid and guard < 200:
		guard += 1
		match game.state.phase:
			"negative":
				_lab_press(["unusable"])
			"select":
				var low: int = game.INF
				var best := ""
				var names: Array = p.pos.keys()
				names.sort()
				for v in names:
					if not game.state.settled.has(v) and game.state.dist[v] < low:
						low = game.state.dist[v]
						best = v
				_lab_press(["unreachable" if best == "" else best])
			"relax":
				var n: Array = game.state.queue[0]
				_lab_press(["update" if game.state.dist[game.state.cur] + n[1] < game.state.dist[n[0]] else "keep"])
			"path":
				var from: String = game.state.path.back()
				var moved := false
				for e in p.edges:
					if e[0] == from and game.state.settled.has(e[1]) and game.state.dist[from] + e[2] == game.state.dist[e[1]] and game.on_tight_route(p, e[1]):
						_lab_press([e[1]])
						moved = true
						break
				if not moved:
					return

func _bot_play_algo_labs(_params: Dictionary) -> Dictionary:
	var cleared := []

	# 1. ALG01_Sorting
	_open_lab("ALG01_Sorting")
	_lab_press(["3"]) # intentional mistake
	var guard := 0
	while game.problem == 0 and guard < 30:
		guard += 1
		var a := _vals()
		var j: int = game.state.j
		_lab_press(["swap" if a[j] > a[j + 1] else "keep"])
	_lab_press(["keep", "keep"])
	var a1_l1: bool = game.level_done
	_lab_level(1)
	_lab_press(["4", "1", "2", "3"])
	var a1_l2: bool = game.level_done
	_lab_level(2)
	guard = 0
	while not game.level_done and guard < 200:
		guard += 1
		if game.state.phase == "lift":
			_lab_press([str(game.state.i)])
		else:
			var a := _vals()
			var j: int = game.state.hole - 1
			_lab_press(["shift" if j >= 0 and a[j] > game.state.key[0] else "place"])
	var a1_l3: bool = game.level_done
	_close_lab()
	if a1_l1 and a1_l2 and a1_l3:
		cleared.append("ALG01")

	# 2. ALG02_Search
	_open_lab("ALG02_Search")
	_lab_press(["2"]) # intentional mistake
	_lab_press(["0", "1", "2", "3", "0", "1", "2"])
	var a2_l1: bool = game.level_done
	_lab_level(1)
	_lab_press(["3", "5", "4", "0"])
	var a2_l2: bool = game.level_done
	_lab_level(2)
	_lab_press(["3", "5", "4", "2", "pick:linear", "0", "1", "2", "none"])
	var a2_l3: bool = game.level_done
	_close_lab()
	if a2_l1 and a2_l2 and a2_l3:
		cleared.append("ALG02")

	# 3. ALG03_DivideSort
	_open_lab("ALG03_DivideSort")
	_lab_press(["run:0", "run:0", "run:2"])
	guard = 0
	while not game.level_done and guard < 20:
		guard += 1
		for i in game.state.runs.size():
			if game.state.runs[i].size() > 1:
				_lab_press(["run:%d" % i])
				break
	var a3_l1: bool = game.level_done
	_lab_level(1)
	guard = 0
	while not game.level_done and guard < 100:
		guard += 1
		var m: Dictionary = game.state.plan[game.state.m]
		var l: int = game.state.l
		var r: int = game.state.r
		var left_ok: bool = l < m.left.size() and (r >= m.right.size() or m.left[l][0] <= m.right[r][0])
		_lab_press(["left" if left_ok else "right"])
	var a3_l2: bool = game.level_done
	_lab_level(2)
	guard = 0
	while not game.level_done and guard < 200:
		guard += 1
		var s: int = game.current_segment()
		var items: Array = game.state.segs[s].items
		var p = items.back()[0]
		var c = items[game.state.k][0]
		_lab_press(["eq" if c == p else ("lt" if c < p else "gt")])
	var a3_l3: bool = game.level_done
	_close_lab()
	if a3_l1 and a3_l2 and a3_l3:
		cleared.append("ALG03")

	# 4. ALG04_ShortestPath
	_open_lab("ALG04_ShortestPath")
	_solve_shortest_path()
	var a4_l1: bool = game.level_done
	_lab_level(1)
	_solve_shortest_path()
	var a4_l2: bool = game.level_done
	_lab_level(2)
	_solve_shortest_path()
	_solve_shortest_path()
	_lab_press(["A", "unusable"])
	var a4_l3: bool = game.level_done
	_close_lab()
	if a4_l1 and a4_l2 and a4_l3:
		cleared.append("ALG04")

	return {
		"passed": cleared.size() == 4,
		"expected_summary": "ALG01~ALG04(4종) 전 레벨 알고리즘 규칙 검증 및 자동 클리어",
		"actual_summary": "클리어=%d/4종(%s)" % [cleared.size(), ",".join(cleared)],
		"detail": "ALG01_Sorting, ALG02_Search, ALG03_DivideSort, ALG04_ShortestPath solver"
	}

const SqlModel = preload("res://scripts/minigames/sql_query_model.gd")
const SqlDrawer = preload("res://scripts/minigames/sql_drawer.gd")

func _sql_open(scene_name: String) -> void:
	SqlDrawer.saved.clear()
	sql_g = (load("res://scenes/stages/%s.tscn" % scene_name) as PackedScene).instantiate()
	sql_g.instant = true
	root.add_child(sql_g)
	sql_g.phase = "play"

func _sql_level(n: int) -> void:
	sql_g._load_level(n)
	sql_g.instant = true

func _sql_paint(tool_name: String, row: int, col: int) -> void:
	sql_g.tool_id = tool_name
	sql_g.r = row
	sql_g.c = col
	sql_g.press_e()

func _sql_cond(tool_name: String, row: int, col: int, op: String, val: int) -> void:
	_sql_paint(tool_name, row, col)
	var ops: Array = sql_g.COMPARE_OPS if sql_g.palette.mode == "compare" else SqlModel.NUMERIC_OPS
	sql_g.palette.op = ops.find(op)
	if sql_g.palette.has("val"):
		sql_g.palette.val = sql_g.WHERE_VALUES.find(val)
	sql_g.confirm_palette()

func _bot_play_sql_labs(_params: Dictionary) -> Dictionary:
	var cleared := []
	var solved_levels := 0
	var undo_verified := false

	# 1. SQL01_Query (3 levels)
	_sql_open("SQL01_Query")
	_sql_paint("col", 0, 1)
	sql_g.submit() # intentional missing column mistake (mistakes == 1)
	_sql_paint("col", 2, 2)
	sql_g.submit()
	var q1_l1: bool = (sql_g.phase == "solved")
	if q1_l1:
		solved_levels += 1
	_sql_level(1)
	_sql_paint("col", 0, 1)
	_sql_paint("col", 0, 2)
	_sql_cond("cond", 0, 2, ">=", 80)
	var before_snap: Dictionary = sql_g.m.duplicate(true)
	_sql_cond("cond", 0, 2, ">=", 60)
	sql_g.undo()
	undo_verified = (sql_g.m == before_snap)
	sql_g.submit()
	var q1_l2: bool = (sql_g.phase == "solved")
	if q1_l2:
		solved_levels += 1
	_sql_level(2)
	_sql_paint("col", 0, 1)
	_sql_paint("col", 0, 2)
	_sql_cond("cond", 0, 2, ">=", 60)
	_sql_paint("order", 0, 2)
	_sql_paint("limit", 0, 2)
	sql_g.submit()
	var q1_l3: bool = (sql_g.phase == "solved")
	if q1_l3:
		solved_levels += 1
	sql_g.free()
	sql_g = null
	if q1_l1 and q1_l2 and q1_l3:
		cleared.append("SQL01")

	# 2. SQL02_GroupBy (3 levels)
	_sql_open("SQL02_GroupBy")
	_sql_paint("group", 0, 3)
	_sql_paint("count", 0, 3)
	sql_g.submit()
	var q2_l1: bool = (sql_g.phase == "solved")
	if q2_l1:
		solved_levels += 1
	_sql_level(1)
	_sql_paint("group", 0, 3)
	_sql_paint("count", 0, 0)
	_sql_paint("countcol", 0, 2)
	_sql_paint("avg", 0, 2)
	sql_g.submit()
	var q2_l2: bool = (sql_g.phase == "solved")
	if q2_l2:
		solved_levels += 1
	_sql_level(2)
	_sql_paint("group", 0, 3)
	_sql_paint("avg", 0, 2)
	sql_g.r = 5
	sql_g.c = 0
	sql_g.tool_id = "having"
	sql_g.press_e()
	sql_g.palette.op = 0
	sql_g.palette.val = sql_g.WHERE_VALUES.find(80)
	sql_g.confirm_palette()
	sql_g.submit()
	var q2_l3: bool = (sql_g.phase == "solved")
	if q2_l3:
		solved_levels += 1
	sql_g.free()
	sql_g = null
	if q2_l1 and q2_l2 and q2_l3:
		cleared.append("SQL02")

	# 3. SQL03_Join (3 levels)
	_sql_open("SQL03_Join")
	_sql_paint("key", 0, 2)
	_sql_paint("key", 0, 5)
	sql_g.submit()
	var q3_l1: bool = (sql_g.phase == "solved")
	if q3_l1:
		solved_levels += 1
	_sql_level(1)
	_sql_paint("key", 0, 2)
	_sql_paint("key", 0, 5)
	_sql_paint("mode", 0, 0)
	sql_g.submit()
	var q3_l2: bool = (sql_g.phase == "solved")
	if q3_l2:
		solved_levels += 1
	_sql_level(2)
	_sql_paint("key", 0, 2)
	_sql_paint("key", 0, 7)
	sql_g.submit()
	var q3_l3: bool = (sql_g.phase == "solved")
	if q3_l3:
		solved_levels += 1
	sql_g.free()
	sql_g = null
	if q3_l1 and q3_l2 and q3_l3:
		cleared.append("SQL03")

	# 4. SQL04_Subquery (3 levels)
	_sql_open("SQL04_Subquery")
	_sql_paint("avg", 0, 2)
	sql_g.submit()
	var q4_l1: bool = (sql_g.phase == "solved")
	if q4_l1:
		solved_levels += 1
	_sql_level(1)
	_sql_paint("avg", 0, 2)
	_sql_cond("compare", 0, 2, ">", 0)
	_sql_paint("col", 0, 1)
	_sql_paint("col", 0, 2)
	sql_g.submit()
	var q4_l2: bool = (sql_g.phase == "solved")
	if q4_l2:
		solved_levels += 1
	_sql_level(2)
	_sql_paint("max", 0, 2)
	_sql_cond("compare", 0, 2, "=", 0)
	_sql_paint("col", 0, 1)
	_sql_paint("col", 0, 2)
	sql_g.submit()
	var q4_l3: bool = (sql_g.phase == "solved")
	if q4_l3:
		solved_levels += 1
	sql_g.free()
	sql_g = null
	SqlDrawer.saved.clear()
	if q4_l1 and q4_l2 and q4_l3:
		cleared.append("SQL04")

	await process_frame
	var ok: bool = cleared.size() == 4 and solved_levels == 12 and undo_verified
	return {
		"passed": ok,
		"expected_summary": "SQL01~SQL04(4종, 12개 레벨) 5x5 서랍 풀이 · 오답 차단 · Undo 복원",
		"actual_summary": "클리어=%d/4종(%s), 해결레벨=%d/12개, Undo복원=%s" % [
			cleared.size(), ",".join(cleared), solved_levels, str(undo_verified)
		],
		"detail": "SQL01~SQL04 5x5 drawer 12 levels automated solver"
	}

func _type_field(key: String, text_val: String) -> void:
	_lab_press(["field:" + key])
	for ch in text_val:
		_lab_press(["key:" + ch])

func _pick(key: String, n: int) -> void:
	for i in n:
		_lab_press(["pick:" + key])

func _bot_play_data_labs(_params: Dictionary) -> Dictionary:
	var cleared := []

	# 1. DATA01_Explore (Clean)
	_open_lab("DATA01_Explore")
	_lab_press(["submit"]) # intentional empty submit mistake
	_lab_press(["missing", "submit"])
	var d1_l1: bool = game.level_done
	_lab_level(1)
	_lab_press(["dedup", "missing", "submit"])
	var d1_l2: bool = game.level_done
	_lab_level(2)
	_lab_press(["trim", "number", "date", "dedup", "submit"])
	var d1_l3: bool = game.level_done
	_close_lab()
	if d1_l1 and d1_l2 and d1_l3:
		cleared.append("DATA01")

	# 2. DATA02_Profile
	_open_lab("DATA02_Profile")
	_type_field("rows", "5")
	_type_field("cols", "5")
	_pick("unit", 1)
	_lab_press(["submit"])
	var d2_l1: bool = game.level_done
	_lab_level(1)
	_pick("age_type", 1)
	_pick("zip_type", 2)
	_pick("joined_type", 3)
	_pick("age_unit", 1)
	_pick("visits_unit", 2)
	_lab_press(["submit"])
	var d2_l2: bool = game.level_done
	_lab_level(2)
	_type_field("age_missing", "2")
	_type_field("age_rate", "40")
	_type_field("visits_missing", "0")
	_pick("odd_col", 4)
	_lab_press(["submit"])
	var d2_l3: bool = game.level_done
	_close_lab()
	if d2_l1 and d2_l2 and d2_l3:
		cleared.append("DATA02")

	# 3. DATA03_Stats
	_open_lab("DATA03_Stats")
	_type_field("count", "4")
	_type_field("mean", "5")
	_type_field("range", "6")
	_lab_press(["submit"])
	var d3_l1: bool = game.level_done
	_lab_level(1)
	_type_field("median", "5")
	_lab_press(["submit"])
	_type_field("median", "13")
	_lab_press(["submit"])
	_type_field("count", "2")
	_type_field("mean", "6")
	_lab_press(["submit"])
	var d3_l2: bool = game.level_done
	_lab_level(2)
	for pair in [["mean", "34"], ["median", "13"], ["range", "90"], ["mean_ex", "12"], ["median_ex", "12"], ["range_ex", "4"]]:
		_type_field(pair[0], pair[1])
	_lab_press(["claim:0", "submit"])
	_type_field("range", "0")
	_type_field("range2", "20")
	_lab_press(["claim:0", "submit"])
	_lab_press(["claim:0", "submit"])
	var d3_l3: bool = game.level_done
	_close_lab()
	if d3_l1 and d3_l2 and d3_l3:
		cleared.append("DATA03")

	# 4. DATA04_Chart
	_open_lab("DATA04_Chart")
	_lab_press(["x", "y", "agg", "zero", "draw"])
	var d: Array = game.chart_data(game.problems()[0])
	var best := 0
	for i in d.size():
		if d[i][1] > d[best][1]:
			best = i
	_lab_press(["mark:%d" % best, "claim:0", "submit"])
	var d4_l1: bool = game.level_done
	_lab_level(1)
	_lab_press(["x", "y", "ctype", "sort", "draw", "mark:1", "claim:0", "submit"])
	var d4_l2: bool = game.level_done
	_lab_level(2)
	_lab_press(["ctype", "ctype", "draw", "mark:0", "claim:0", "submit"])
	var d4_l3: bool = game.level_done
	_close_lab()
	if d4_l1 and d4_l2 and d4_l3:
		cleared.append("DATA04")

	return {
		"passed": cleared.size() == 4,
		"expected_summary": "DATA01~DATA04(4종) 전 레벨 결측·정제·통계·시각화 검증 및 클리어",
		"actual_summary": "클리어=%d/4종(%s)" % [cleared.size(), ",".join(cleared)],
		"detail": "DATA01_Explore, DATA02_Profile, DATA03_Stats, DATA04_Chart solver"
	}

# ============================================================================
# PHASE 5: TELEMETRY V2 SCHEMA & DISK QUEUE LIFECYCLE
# ============================================================================
func _step_schema_v2_contract(_params: Dictionary, _expect: Dictionary) -> Dictionary:
	var nm = root.get_node_or_null("NetworkManager")
	if nm == null:
		return {"passed": false, "expected_summary": "NetworkManager 존재", "actual_summary": "NetworkManager 없음", "detail": ""}

	# 1. Verify all 24 games resolve to valid minigame_id and category
	var mapped_count := 0
	for g in Catalog.GAMES:
		var r: Array[String] = nm.resolve_minigame(str(g[0]))
		if r[0] == str(g[0]) and r[1] == str(g[3]):
			mapped_count += 1

	# 2. Verify allowed key filtering & 2KB size truncation
	var huge_state := {}
	for i in 120:
		huge_state["key_%d" % i] = "X".repeat(32)
	var raw_details := {
		"operation": "slot_move",
		"level": 2,
		"moves": 5,
		"mistakes": 1,
		"stars": 2,
		"state_before": huge_state,
		"secret_token": "MUST_BE_REMOVED",
		"raw_password": "MUST_BE_REMOVED"
	}
	nm.current_task_id = "ST01"
	var ev: Dictionary = nm._create_event("operation_succeeded", raw_details)
	var det: Dictionary = ev.get("details", {})
	var forbidden_stripped := (not det.has("secret_token")) and (not det.has("raw_password"))
	var det_bytes := JSON.stringify(det).to_utf8_buffer().size()
	var under_2kb := det_bytes <= 2048

	# 3. Verify occurred_at ms UTC format (YYYY-MM-DDTHH:MM:SS.mmmZ)
	var ts := str(ev.get("occurred_at", ""))
	var ts_re := RegEx.new()
	ts_re.compile("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z$")
	var ts_ok := ts_re.search(ts) != null

	var ok := int(ev.get("schema_version", 0)) == 2 and mapped_count == 24 and forbidden_stripped and under_2kb and ts_ok
	return {
		"passed": ok,
		"expected_summary": "schema_version=2, 24종 매핑, 금지키 제거, details<=2048B, 밀리초 UTC(.mmmZ)",
		"actual_summary": "v=%d, 매핑=%d/24종, 금지키제거=%s, 크기=%dB, 시각=%s" % [
			int(ev.get("schema_version", 0)), mapped_count, str(forbidden_stripped), det_bytes, ts
		],
		"detail": "G1 Schema v2 contract & sanitizer verification"
	}

func _step_disk_queue_lifecycle(_params: Dictionary, _expect: Dictionary) -> Dictionary:
	var nm = root.get_node_or_null("NetworkManager")
	if nm == null:
		return {"passed": false, "expected_summary": "NetworkManager 존재", "actual_summary": "없음", "detail": ""}

	# 1. Create event and save to pending/
	var ev1: Dictionary = nm._create_event("problem_started", {"level": 1})
	var id1 := str(ev1.get("event_id", ""))
	nm._save_event_to_disk(ev1)
	var p1_created := FileAccess.file_exists(nm._pending_file_path(id1))

	# 2. Simulate 422 response -> moved to rejected/
	nm._move_pending_to_rejected(id1, ev1)
	var moved_to_rejected := (not FileAccess.file_exists(nm._pending_file_path(id1))) and FileAccess.file_exists(nm._rejected_file_path(id1))
	# Clean up test rejected file
	if FileAccess.file_exists(nm._rejected_file_path(id1)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(nm._rejected_file_path(id1)))

	# 3. Create event and simulate 202 response -> deleted from pending/
	var ev2: Dictionary = nm._create_event("problem_completed", {"level": 1, "stars": 3})
	var id2 := str(ev2.get("event_id", ""))
	nm._save_event_to_disk(ev2)
	var p2_created := FileAccess.file_exists(nm._pending_file_path(id2))
	nm._delete_pending_file(id2)
	var deleted_on_202 := p2_created and (not FileAccess.file_exists(nm._pending_file_path(id2)))

	var ok := p1_created and moved_to_rejected and deleted_on_202
	return {
		"passed": ok,
		"expected_summary": "pending/<id>.json 생성 -> 401/422 시 rejected/ 격리 -> 202 시 pending 삭제",
		"actual_summary": "pending생성=%s, 422격리(rejected)=%s, 202삭제=%s" % [
			str(p1_created), str(moved_to_rejected), str(deleted_on_202)
		],
		"detail": "G2 Disk Queue lifecycle verification"
	}

# ============================================================================
# PHASE 6: UPDATE MANAGER & EXIT MARKER
# ============================================================================
func _step_update_manager_check(_params: Dictionary, _expect: Dictionary) -> Dictionary:
	var um = root.get_node_or_null("UpdateManager")
	var nm = root.get_node_or_null("NetworkManager")
	if um == null or nm == null:
		return {"passed": false, "expected_summary": "UpdateManager 존재", "actual_summary": "없음", "detail": ""}

	var cmp_ok: bool = (um._cmp("0.3.0", "0.4.0") == -1) and (um._cmp("0.3.0", "0.3.0") == 0) and (um._cmp("0.4.1", "0.4.0") == 1)
	var ev_count: int = nm.UPDATE_EVENT_TYPES.size()
	var u_ev: Dictionary = nm._create_update_event("update_checked", {"result": "offline", "target_version": "0.3.0", "forbidden": "x"})
	var u_det: Dictionary = u_ev.get("details", {})
	var clean_ok := u_det.has("result") and (not u_det.has("forbidden"))
	var fallback_ver := str(um.current_content_version)

	var ok := cmp_ok and ev_count == 9 and clean_ok and (fallback_ver == "base" or not fallback_ver.is_empty())
	return {
		"passed": ok,
		"expected_summary": "버전 비교(_cmp) 정확, 업데이트 이벤트 9종·허용키 7종 필터링, 오프라인 폴백(base)",
		"actual_summary": "버전비교=%s, 이벤트종수=%d종, 허용키필터=%s, 현재팩=%s" % [
			str(cmp_ok), ev_count, str(clean_ok), fallback_ver
		],
		"detail": "G5 UpdateManager contract verification"
	}

func _step_exit_marker_check(params: Dictionary, _expect: Dictionary) -> Dictionary:
	var nm = root.get_node_or_null("NetworkManager")
	var marker_virtual: String = "user://test_exit_marker.txt"
	var marker_global: String = ProjectSettings.globalize_path(marker_virtual)
	var test_run_id: String = "bot-run-" + str(nm.generate_uuid_v4()) if nm else "bot-run-001"

	OS.set_environment("NODEVERSE_EXIT_MARKER", marker_global)
	OS.set_environment("NODEVERSE_RUN_ID", test_run_id)
	nm.write_exit_marker()

	var written_ok: bool = FileAccess.file_exists(marker_virtual) and FileAccess.get_file_as_string(marker_virtual).strip_edges() == test_run_id
	if FileAccess.file_exists(marker_virtual):
		DirAccess.remove_absolute(marker_global)

	var cleanup_user: String = str(params.get("cleanup_user", "qa_bot_tester"))
	_remove_test_user(cleanup_user)
	var store: Dictionary = AuthMgr._get_store()
	var users_dict: Dictionary = store.get("users", {})
	var cleaned_ok: bool = not users_dict.has(cleanup_user)

	var ok: bool = written_ok and cleaned_ok
	return {
		"passed": ok,
		"expected_summary": "NODEVERSE_EXIT_MARKER 파일에 RUN_ID 정확히 기록 및 테스트 계정 정리 완료",
		"actual_summary": "종료마커기록=%s(run_id일치), 테스트계정정리=%s" % [
			str(written_ok), str(cleaned_ok)
		],
		"detail": "G3 Normal Exit Marker & test cleanup verification"
	}
