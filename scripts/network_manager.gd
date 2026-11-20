class_name NetworkManagerClass
extends Node

## NODEVERSE Network & Mini-Game Telemetry Manager (G1~G6 Compliant)
## - G1: Event Schema v2 (/v2/events), 8 learning events, 9 allowed detail keys, <=2KB, ms UTC timestamp
## - G2: Disk Queue (user://telemetry/pending/<event_id>.json, rejected/ on 401/422, 1s..60s backoff, max 5000)
## - G3: Normal Exit Marker (NODEVERSE_EXIT_MARKER + NODEVERSE_RUN_ID on WM_CLOSE_REQUEST)
## - G5: Update Events (9 types) & Required Update pause mode (learning events queued on disk only)
## - G6: NODEVERSE_PLAYER_ID env var / persistent install UUID

const LearningCatalog = preload("res://scripts/learning_catalog.gd")

signal status_changed(new_status: String, message: String)
signal event_transmitted(event_type: String, is_success: bool, status_code: int, response_info: String)
signal log_appended(log_data: Dictionary)

enum NetStatus {
	IDLE,
	CONNECTING,
	CONNECTED,
	SENDING,
	OFFLINE,
	ERROR
}

const CONFIG_PATH: String = "user://network_config.json"
const INSTALL_ID_PATH: String = "user://install_id.txt"
const PENDING_DIR: String = "user://telemetry/pending/"
const REJECTED_DIR: String = "user://telemetry/rejected/"
const DEFAULT_HOST: String = "192.168.0.81"
const DEFAULT_PORT: int = 8000
const DEFAULT_ENDPOINT: String = "/v2/events"
const DEFAULT_API_HOST: String = "192.168.0.29" # Django 서버 (회원·저장·업데이트)
const DEFAULT_API_PORT: int = 8000
const DEFAULT_AUTH_TOKEN: String = "replace-with-a-long-random-local-key"
const DEFAULT_TIMEOUT: float = 3.0
const MAX_QUEUE_SIZE: int = 5000
const MAX_DISK_QUEUE_FILES: int = 5000
const MAX_LOG_SIZE: int = 100
const MAX_DETAILS_BYTES: int = 2048
const BACKOFF_MIN_SEC: float = 1.0
const BACKOFF_MAX_SEC: float = 60.0

const ALLOWED_LEARNING_DETAIL_KEYS: Array[String] = [
	"operation",
	"failure_reason",
	"level",
	"moves",
	"mistakes",
	"stars",
	"hint_id",
	"state_before",
	"state_after"
]

const ALLOWED_UPDATE_DETAIL_KEYS: Array[String] = [
	"target_version",
	"result",
	"kind",
	"failure_reason",
	"bytes",
	"duration_ms",
	"from_version"
]

const UPDATE_EVENT_TYPES: Array[String] = [
	"update_checked",
	"update_prompted",
	"update_accepted",
	"update_dismissed",
	"pack_download_started",
	"pack_download_succeeded",
	"pack_download_failed",
	"pack_mounted",
	"build_changed"
]

# Configuration
var target_host: String = DEFAULT_HOST
var target_port: int = DEFAULT_PORT
var endpoint_path: String = DEFAULT_ENDPOINT
var api_host: String = DEFAULT_API_HOST
var api_port: int = DEFAULT_API_PORT
var auth_token: String = DEFAULT_AUTH_TOKEN
var auto_send_enabled: bool = true
var request_timeout: float = DEFAULT_TIMEOUT

# G5 Required-Update Mode: when true, learning events are written to disk queue only, while update events still transmit
var learning_events_paused: bool = false

# Runtime State
var current_status: NetStatus = NetStatus.IDLE
var last_status_code: int = 0
var last_latency_ms: int = 0
var last_error_message: String = ""
var total_sent_success: int = 0
var total_sent_failed: int = 0

# Identifiers & Versions
var session_id: String = ""
var current_run_id: String = ""
var current_attempt_id: String = ""
var current_task_id: String = "ST01"
var content_version: String = "base"
var sequence_num: int = 1
var player_id: String = ""

# Internals
var _http_request: HTTPRequest
var _pending_queue: Array = []
var _offline_backlog: Array = []
var _last_fail_time: int = 0
var _retry_backoff_sec: float = BACKOFF_MIN_SEC
var _retry_scheduled: bool = false
var _is_busy: bool = false
var _active_request_type: String = ""
var _active_event_id: String = ""
var _request_start_time: int = 0
var _logs: Array = []
var _debug_panel_scene: PackedScene = null
var _debug_panel_instance: CanvasLayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_queue_dirs()
	load_config()
	_init_session()

	_http_request = HTTPRequest.new()
	_http_request.name = "TelemetryHTTP"
	_http_request.timeout = request_timeout
	_http_request.request_completed.connect(_on_http_request_completed)
	add_child(_http_request)

	_init_debug_overlay()
	if auto_send_enabled and DisplayServer.get_name() != "headless":
		_load_pending_from_disk()
	log_message("네트워크 매니저 초기화 완료 (v2 대상: %s:%d%s)" % [target_host, target_port, endpoint_path], "info")

# ==========================================
# G3: NORMAL EXIT MARKER
# ==========================================
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		write_exit_marker()

static func write_exit_marker() -> void:
	var path := OS.get_environment("NODEVERSE_EXIT_MARKER").strip_edges()
	var rid := OS.get_environment("NODEVERSE_RUN_ID").strip_edges()
	if path != "" and rid != "":
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(rid)
			f.close()

func quit_game(exit_code: int = 0) -> void:
	write_exit_marker()
	if get_tree():
		get_tree().quit(exit_code)

# ==========================================
# SESSION & PLAYER ID (G6)
# ==========================================
func _init_session() -> void:
	session_id = generate_uuid_v4()
	var env_run := OS.get_environment("NODEVERSE_RUN_ID").strip_edges()
	current_run_id = env_run if not env_run.is_empty() else generate_uuid_v4()
	current_attempt_id = generate_uuid_v4()
	sequence_num = 1
	_update_player_id()

func _get_or_create_install_id() -> String:
	if FileAccess.file_exists(INSTALL_ID_PATH):
		var rf := FileAccess.open(INSTALL_ID_PATH, FileAccess.READ)
		if rf != null:
			var existing := rf.get_as_text().strip_edges()
			rf.close()
			if not existing.is_empty():
				return existing
	var new_id := generate_uuid_v4()
	var wf := FileAccess.open(INSTALL_ID_PATH, FileAccess.WRITE)
	if wf != null:
		wf.store_string(new_id)
		wf.close()
	return new_id

func _update_player_id() -> void:
	var env_pid := OS.get_environment("NODEVERSE_PLAYER_ID").strip_edges()
	if not env_pid.is_empty():
		player_id = env_pid
		return
	var auth_mgr_class = load("res://scripts/auth_manager.gd")
	if auth_mgr_class:
		var store = auth_mgr_class._get_store()
		var u = str(store.get("last_user", "")).strip_edges()
		if not u.is_empty() and u != "Guest":
			var users: Dictionary = store.get("users", {})
			if users.has(u) and users[u] is Dictionary:
				if not str(users[u].get("server_player_id", "")).is_empty():
					player_id = str(users[u]["server_player_id"])
					return
				if users[u].has("user_id"):
					player_id = str(users[u]["user_id"])
					return
			player_id = u
			return
	player_id = _get_or_create_install_id()

## Sync verified player login with Dashboard Django API: POST /api/game/player-login
## Gracefully falls back to local UUID if server is offline or GAME_SERVER_API_KEY is unset.
func sync_player_login(member_id: String, display_name: String) -> void:
	var mid := member_id.strip_edges()
	var dname := display_name.strip_edges()
	if mid.is_empty() or dname.is_empty():
		return
	if not auto_send_enabled or DisplayServer.get_name() == "headless":
		return
	var req := HTTPRequest.new()
	req.timeout = request_timeout
	add_child(req)
	var url := get_base_url() + "/api/game/player-login"
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % auth_token
	])
	var payload := JSON.stringify({"member_id": mid, "display_name": dname})
	req.request_completed.connect(func(result: int, code: int, _hdrs: PackedStringArray, body: PackedByteArray):
		req.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 201):
			var parsed = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Dictionary and parsed.get("player") is Dictionary:
				var server_pid := str(parsed["player"].get("player_id", "")).strip_edges()
				if not server_pid.is_empty():
					player_id = server_pid
					var auth_cls = load("res://scripts/auth_manager.gd")
					if auth_cls:
						auth_cls.set_server_player_id(dname, server_pid)
					log_message("서버 플레이어 로그인 연동 완료 (%s -> %s)" % [dname, server_pid], "success")
					return
		log_message("서버 로그인 연동 대기/오프라인 (코드: %d, 로컬 계정으로 정상 진행)" % code, "info")
	)
	var err := req.request(url, headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		req.queue_free()

## Online-first DB Auth & Cloud Save helper: POST /api/game/auth/<action> (Django Server)
## Returns {"online": true/false, "code": HTTP status, "data": Dictionary}
func game_auth_request(action: String, payload: Dictionary) -> Dictionary:
	if DisplayServer.get_name() == "headless":
		return {"online": false, "code": 0, "data": {}}
	var req := HTTPRequest.new()
	req.timeout = request_timeout
	add_child(req)
	var url := get_api_base_url() + "/api/game/auth/" + action
	var headers := PackedStringArray(["Content-Type: application/json; charset=utf-8"])
	var body_dict := payload.duplicate()
	body_dict["install_id"] = _get_or_create_install_id()
	body_dict["build_version"] = get_build_version()
	body_dict["content_version"] = content_version
	var err := req.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body_dict))
	if err != OK:
		req.queue_free()
		return {"online": false, "code": 0, "data": {}}
	var r: Array = await req.request_completed
	req.queue_free()
	var result: int = int(r[0])
	var code: int = int(r[1])
	var body: PackedByteArray = r[3]
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	var is_server_reply: bool = parsed is Dictionary and parsed.has("success")
	if result != HTTPRequest.RESULT_SUCCESS or code == 0 or code >= 500 or not is_server_reply:
		return {"online": false, "code": code, "data": {}}
	return {"online": true, "code": code, "data": parsed}

## Fire-and-forget Cloud Save sync: POST /api/game/auth/save (Django Server)
func sync_cloud_save(username: String, save_data: Dictionary) -> void:
	var u := username.strip_edges()
	if u.is_empty() or u == "Guest" or DisplayServer.get_name() == "headless":
		return
	var req := HTTPRequest.new()
	req.timeout = request_timeout
	add_child(req)
	var url := get_api_base_url() + "/api/game/auth/save"
	var headers := PackedStringArray(["Content-Type: application/json; charset=utf-8"])
	var payload := JSON.stringify({"username": u, "save_data": save_data})
	req.request_completed.connect(func(_res: int, _code: int, _hdrs: PackedStringArray, _body: PackedByteArray):
		req.queue_free()
	)
	var err := req.request(url, headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		req.queue_free()

func set_content_version(ver: String) -> void:
	content_version = ver.strip_edges() if not ver.strip_edges().is_empty() else "base"

static func get_build_version() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", "0.3.0")).strip_edges()
	return v if not v.is_empty() else "0.3.0"

static func resolve_minigame(raw_id: String) -> Array[String]:
	var cleaned := raw_id.strip_edges().to_upper()
	if cleaned.begins_with("ST01"):
		cleaned = "ST01"
	for g in LearningCatalog.GAMES:
		if str(g[0]).to_upper() == cleaned or str(g[4]).to_upper() == cleaned:
			return [str(g[0]), str(g[3])]
	for g in LearningCatalog.GAMES:
		if cleaned.begins_with(str(g[0]).to_upper()):
			return [str(g[0]), str(g[3])]
	return ["ST01", "DS"]

static func is_update_event(ev_type: String) -> bool:
	return ev_type in UPDATE_EVENT_TYPES

func _init_debug_overlay() -> void:
	var panel_path = "res://scenes/tools/NetworkDebugPanel.tscn"
	if ResourceLoader.exists(panel_path):
		_debug_panel_scene = load(panel_path)
		if _debug_panel_scene:
			_debug_panel_instance = _debug_panel_scene.instantiate() as CanvasLayer
			add_child(_debug_panel_instance)
	if DisplayServer.get_name() != "headless":
		var bot_path := "res://scripts/tools/live_test_bot_overlay.gd"
		if ResourceLoader.exists(bot_path):
			var bot_cls = load(bot_path)
			if bot_cls != null:
				var bot_inst = bot_cls.new()
				call_deferred("_attach_bot_overlay", bot_inst)

func _attach_bot_overlay(bot_inst: Node) -> void:
	if get_tree() and get_tree().root and get_tree().root.get_node_or_null("LiveTestBotOverlay") == null:
		get_tree().root.add_child(bot_inst)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F6:
			toggle_debug_panel()

func toggle_debug_panel() -> void:
	if _debug_panel_instance and is_instance_valid(_debug_panel_instance):
		if _debug_panel_instance.has_method("toggle_panel"):
			_debug_panel_instance.call("toggle_panel")
		elif _debug_panel_instance.has_node("Panel"):
			var p = _debug_panel_instance.get_node("Panel")
			p.visible = not p.visible

# ==========================================
# CONFIGURATION
# ==========================================
func load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(txt) == OK and json.data is Dictionary:
		var d: Dictionary = json.data
		target_host = str(d.get("host", DEFAULT_HOST)).strip_edges()
		target_port = int(d.get("port", DEFAULT_PORT))
		var saved_api_host := str(d.get("api_host", DEFAULT_API_HOST)).strip_edges()
		api_host = saved_api_host if not saved_api_host.is_empty() else DEFAULT_API_HOST
		api_port = int(d.get("api_port", DEFAULT_API_PORT))
		if api_port <= 0:
			api_port = DEFAULT_API_PORT
		var saved_ep := str(d.get("endpoint", DEFAULT_ENDPOINT)).strip_edges()
		if saved_ep.is_empty() or saved_ep == "/v1/events":
			saved_ep = DEFAULT_ENDPOINT
		endpoint_path = saved_ep
		auth_token = str(d.get("auth_token", DEFAULT_AUTH_TOKEN)).strip_edges()
		if auth_token.is_empty():
			auth_token = DEFAULT_AUTH_TOKEN
		auto_send_enabled = bool(d.get("auto_send", true))
		request_timeout = float(d.get("timeout", DEFAULT_TIMEOUT))

func save_config() -> bool:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if f == null:
		return false
	var d := {
		"host": target_host,
		"port": target_port,
		"endpoint": endpoint_path,
		"api_host": api_host,
		"api_port": api_port,
		"auth_token": auth_token,
		"auto_send": auto_send_enabled,
		"timeout": request_timeout
	}
	f.store_string(JSON.stringify(d, "  "))
	f.close()
	log_message("네트워크 설정 저장됨: %s:%d%s (Key: %s)" % [target_host, target_port, endpoint_path, "***" if auth_token else "없음"], "info")
	return true

func set_server_target(host: String, port: int, endpoint: String = DEFAULT_ENDPOINT, key: String = "") -> void:
	target_host = host.strip_edges()
	target_port = port
	if not endpoint.begins_with("/"):
		endpoint = "/" + endpoint
	endpoint_path = endpoint
	if not key.is_empty():
		auth_token = key.strip_edges()
	save_config()

func get_base_url() -> String:
	var h := target_host
	if not (h.begins_with("http://") or h.begins_with("https://")):
		var is_local := (
			h == "localhost"
			or h.begins_with("127.")
			or h.begins_with("192.168.")
			or h.begins_with("10.")
			or h.begins_with("172.")
		)
		h = ("http://" if is_local else "https://") + h
	if h.begins_with("https://") and (target_port == 443 or target_port == 80):
		return h
	return "%s:%d" % [h, target_port]

func get_api_base_url() -> String:
	var h := api_host.strip_edges()
	if h.is_empty():
		h = DEFAULT_API_HOST
	if not (h.begins_with("http://") or h.begins_with("https://")):
		var is_local := (
			h == "localhost"
			or h.begins_with("127.")
			or h.begins_with("192.168.")
			or h.begins_with("10.")
			or h.begins_with("172.")
		)
		h = ("http://" if is_local else "https://") + h
	if h.begins_with("https://") and (api_port == 443 or api_port == 80):
		return h
	return "%s:%d" % [h, api_port]

func get_full_url() -> String:
	return get_base_url() + endpoint_path

# ==========================================
# EVENT BUILDERS (G1 & G5 SCHEMA V2)
# ==========================================
func start_task(task_id: String, details: Dictionary = {}) -> void:
	_update_player_id()
	var resolved := resolve_minigame(task_id)
	current_task_id = resolved[0]
	current_run_id = generate_uuid_v4()
	var ev := _create_event("problem_started", details)
	_dispatch_event(ev)
	log_message("태스크 시작: %s" % current_task_id, "info")

func start_attempt(task_id: String, attempt_num: int, details: Dictionary = {}) -> void:
	var resolved := resolve_minigame(task_id)
	current_task_id = resolved[0]
	current_attempt_id = generate_uuid_v4()
	var extra := details.duplicate()
	if not extra.has("level") and attempt_num > 0:
		extra["level"] = attempt_num
	var ev := _create_event("attempt_started", extra)
	_dispatch_event(ev)
	log_message("도전 #%d 시작: %s" % [attempt_num, current_task_id], "info")

func record_operation(op_name: String, is_success: bool, failure_reason: String = "", state_before: Dictionary = {}, state_after: Dictionary = {}, context_extra: Dictionary = {}) -> void:
	var extra := context_extra.duplicate()
	extra["operation"] = op_name
	if not is_success and not failure_reason.is_empty():
		extra["failure_reason"] = failure_reason
	if not state_before.is_empty():
		extra["state_before"] = state_before
	if not state_after.is_empty():
		extra["state_after"] = state_after

	var is_hint := (op_name == "hint" or op_name == "hint_used")
	if is_hint and not extra.has("hint_id"):
		if extra.has("hints"):
			extra["hint_id"] = str(extra["hints"])
		else:
			extra["hint_id"] = "default"

	var ev_type := "hint_used" if is_hint else ("operation_succeeded" if is_success else "operation_failed")
	var ev := _create_event(ev_type, extra)
	_dispatch_event(ev)

func complete_attempt(task_id: String, is_success: bool, reason: String = "", details: Dictionary = {}) -> void:
	if not task_id.is_empty():
		current_task_id = resolve_minigame(task_id)[0]
	var ev_type := "attempt_succeeded" if is_success else "attempt_failed"
	var extra := details.duplicate()
	if not is_success and not reason.is_empty():
		extra["failure_reason"] = reason
	var ev := _create_event(ev_type, extra)
	_dispatch_event(ev)
	log_message("도전 %s: %s" % ["성공" if is_success else "실패", current_task_id], "success" if is_success else "warn")

func complete_task(task_id: String, details: Dictionary = {}) -> void:
	if not task_id.is_empty():
		current_task_id = resolve_minigame(task_id)[0]
	var ev := _create_event("problem_completed", details)
	_dispatch_event(ev)
	log_message("태스크 완료: %s" % current_task_id, "success")

func send_update_event(event_type: String, details: Dictionary = {}) -> void:
	if not is_update_event(event_type):
		return
	var ev := _create_update_event(event_type, details)
	_dispatch_event(ev)

func send_custom_event(event_type: String, data: Dictionary = {}) -> void:
	if is_update_event(event_type):
		send_update_event(event_type, data)
		return
	var mapped_type := "operation_succeeded"
	match event_type:
		"task_started", "problem_started": mapped_type = "problem_started"
		"attempt_started": mapped_type = "attempt_started"
		"attempt_succeeded": mapped_type = "attempt_succeeded"
		"task_completed", "problem_completed": mapped_type = "problem_completed"
		"attempt_failed": mapped_type = "attempt_failed"
		"operation_failed": mapped_type = "operation_failed"
		"hint", "hint_used": mapped_type = "hint_used"
		_: mapped_type = "operation_succeeded"
	var ev := _create_event(mapped_type, data)
	_dispatch_event(ev)

static func _sanitize_details(raw: Dictionary, allowed_keys: Array[String]) -> Dictionary:
	var out := {}
	for k in allowed_keys:
		if raw.has(k) and raw[k] != null:
			out[k] = raw[k]
	var encoded := JSON.stringify(out).to_utf8_buffer()
	if encoded.size() > MAX_DETAILS_BYTES:
		out.erase("state_before")
		out.erase("state_after")
		encoded = JSON.stringify(out).to_utf8_buffer()
		if encoded.size() > MAX_DETAILS_BYTES and out.has("failure_reason"):
			out["failure_reason"] = str(out["failure_reason"]).left(256)
	return out

func _create_event(event_type: String, details: Dictionary = {}) -> Dictionary:
	if session_id.is_empty():
		_init_session()
	var resolved := resolve_minigame(current_task_id)
	var clean_details := _sanitize_details(details, ALLOWED_LEARNING_DETAIL_KEYS)
	var ev := {
		"schema_version": 2,
		"event_id": generate_uuid_v4(),
		"player_id": player_id if not player_id.is_empty() else _get_or_create_install_id(),
		"session_id": session_id,
		"run_id": current_run_id if not current_run_id.is_empty() else generate_uuid_v4(),
		"attempt_id": current_attempt_id if not current_attempt_id.is_empty() else generate_uuid_v4(),
		"minigame_id": resolved[0],
		"category": resolved[1],
		"build_version": get_build_version(),
		"content_version": content_version if not content_version.is_empty() else "base",
		"event_type": event_type,
		"occurred_at": get_iso_timestamp(),
		"sequence": sequence_num,
		"details": clean_details
	}
	sequence_num += 1
	return ev

func _create_update_event(event_type: String, details: Dictionary = {}) -> Dictionary:
	if session_id.is_empty():
		_init_session()
	var clean_details := _sanitize_details(details, ALLOWED_UPDATE_DETAIL_KEYS)
	return {
		"schema_version": 2,
		"event_id": generate_uuid_v4(),
		"player_id": _get_or_create_install_id(),
		"run_id": current_run_id if not current_run_id.is_empty() else generate_uuid_v4(),
		"build_version": get_build_version(),
		"content_version": content_version if not content_version.is_empty() else "base",
		"event_type": event_type,
		"occurred_at": get_iso_timestamp(),
		"details": clean_details
	}

# ==========================================
# G2: DISK QUEUE (user://telemetry/pending/ & rejected/)
# ==========================================
func _ensure_queue_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PENDING_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REJECTED_DIR))

func _pending_file_path(ev_id: String) -> String:
	return PENDING_DIR + ev_id + ".json"

func _rejected_file_path(ev_id: String) -> String:
	return REJECTED_DIR + ev_id + ".json"

func _save_event_to_disk(event_dict: Dictionary) -> void:
	_ensure_queue_dirs()
	var ev_id := str(event_dict.get("event_id", "")).strip_edges()
	if ev_id.is_empty():
		return
	var path := _pending_file_path(ev_id)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(event_dict))
		f.close()
	_enforce_disk_queue_limit()

func _delete_pending_file(ev_id: String) -> void:
	if ev_id.is_empty():
		return
	var path := _pending_file_path(ev_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _move_pending_to_rejected(ev_id: String, fallback_dict: Dictionary = {}) -> void:
	if ev_id.is_empty():
		return
	_ensure_queue_dirs()
	var src := _pending_file_path(ev_id)
	var dst := _rejected_file_path(ev_id)
	if FileAccess.file_exists(src):
		var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(src), ProjectSettings.globalize_path(dst))
		if err != OK:
			var txt := FileAccess.get_file_as_string(src)
			var wf := FileAccess.open(dst, FileAccess.WRITE)
			if wf != null:
				wf.store_string(txt)
				wf.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(src))
	elif not fallback_dict.is_empty():
		var wf := FileAccess.open(dst, FileAccess.WRITE)
		if wf != null:
			wf.store_string(JSON.stringify(fallback_dict))
			wf.close()

func _enforce_disk_queue_limit() -> void:
	var dir := DirAccess.open(PENDING_DIR)
	if dir == null:
		return
	var files: PackedStringArray = dir.get_files()
	if files.size() <= MAX_DISK_QUEUE_FILES:
		return
	var entries: Array = []
	for fname in files:
		if fname.ends_with(".json"):
			var p := PENDING_DIR + fname
			entries.append({"name": fname.trim_suffix(".json"), "mtime": FileAccess.get_modified_time(p)})
	entries.sort_custom(func(a, b): return int(a["mtime"]) < int(b["mtime"]))
	var excess := entries.size() - MAX_DISK_QUEUE_FILES
	for i in range(maxi(0, excess)):
		_move_pending_to_rejected(str(entries[i]["name"]))

func _load_pending_from_disk() -> void:
	_ensure_queue_dirs()
	_enforce_disk_queue_limit()
	var dir := DirAccess.open(PENDING_DIR)
	if dir == null:
		return
	var files: PackedStringArray = dir.get_files()
	if files.is_empty():
		return
	var loaded_items: Array = []
	for fname in files:
		if not fname.ends_with(".json"):
			continue
		var p := PENDING_DIR + fname
		var txt := FileAccess.get_file_as_string(p)
		var parsed = JSON.parse_string(txt)
		if parsed is Dictionary and parsed.has("event_id") and parsed.has("event_type"):
			loaded_items.append(parsed)
	loaded_items.sort_custom(func(a, b):
		var ta := str(a.get("occurred_at", ""))
		var tb := str(b.get("occurred_at", ""))
		if ta != tb:
			return ta < tb
		return int(a.get("sequence", 0)) < int(b.get("sequence", 0))
	)
	var existing_ids := {}
	for item in _pending_queue:
		existing_ids[str(item.get("event_id", ""))] = true
	var prepended: Array = []
	for item in loaded_items:
		var id_str := str(item.get("event_id", ""))
		if not existing_ids.has(id_str):
			prepended.append(item)
			existing_ids[id_str] = true
	if not prepended.is_empty():
		_pending_queue = prepended + _pending_queue
		log_message("미전송 디스크 큐 %d건 복구 완료" % prepended.size(), "info")
		call_deferred("_try_flush_queue")

# ==========================================
# ASYNC TRANSMISSION & EXCEPTION SAFETY
# ==========================================
func _dispatch_event(event_dict: Dictionary) -> void:
	if not auto_send_enabled:
		return
	_save_event_to_disk(event_dict)
	var ev_type := str(event_dict.get("event_type", ""))
	if learning_events_paused and not is_update_event(ev_type):
		# G5 Required Update: keep learning events on disk queue only until updated
		_offline_backlog.append(event_dict)
		return
	_pending_queue.append(event_dict)
	while _pending_queue.size() > MAX_QUEUE_SIZE:
		var dropped: Dictionary = _pending_queue.pop_front()
		_move_pending_to_rejected(str(dropped.get("event_id", "")), dropped)
	_try_flush_queue()

func _pick_next_sendable_index() -> int:
	for i in _pending_queue.size():
		var ev: Dictionary = _pending_queue[i]
		var ev_type := str(ev.get("event_type", ""))
		if not learning_events_paused or is_update_event(ev_type):
			return i
	return -1

func _try_flush_queue() -> void:
	if _is_busy or _pending_queue.is_empty():
		return

	var next_idx := _pick_next_sendable_index()
	if next_idx < 0:
		return

	_is_busy = true
	var current_event: Dictionary = _pending_queue[next_idx]
	if next_idx > 0:
		_pending_queue.remove_at(next_idx)
		_pending_queue.push_front(current_event)

	var json_str := JSON.stringify(current_event)
	var headers := PackedStringArray([
		"Content-Type: application/json; charset=utf-8"
	])
	if not auth_token.is_empty():
		headers.append("X-API-Key: %s" % auth_token)
		headers.append("Authorization: Bearer %s" % auth_token)

	_active_request_type = str(current_event.get("event_type", "event"))
	_active_event_id = str(current_event.get("event_id", ""))
	_request_start_time = Time.get_ticks_msec()
	_set_status(NetStatus.SENDING, "전송 중: %s" % _active_request_type)

	if _http_request == null:
		_http_request = HTTPRequest.new()
		_http_request.name = "TelemetryHTTP"
		_http_request.timeout = request_timeout
		_http_request.request_completed.connect(_on_http_request_completed)
		add_child(_http_request)
	var url := get_full_url()
	var err := _http_request.request(url, headers, HTTPClient.METHOD_POST, json_str)
	if err != OK:
		_is_busy = false
		_handle_network_failure("요청 실패 (%s)" % error_string(err), 0)

func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_busy = false
	last_status_code = response_code
	last_latency_ms = Time.get_ticks_msec() - _request_start_time
	var body_str := body.get_string_from_utf8().strip_edges()

	if result == HTTPRequest.RESULT_SUCCESS and (response_code >= 200 and response_code < 300):
		total_sent_success += 1
		_retry_backoff_sec = BACKOFF_MIN_SEC
		_set_status(NetStatus.CONNECTED, "전송 성공 (%d OK, %dms)" % [response_code, last_latency_ms])
		if not _pending_queue.is_empty():
			var sent_item: Dictionary = _pending_queue.pop_front()
			_delete_pending_file(str(sent_item.get("event_id", _active_event_id)))
		else:
			_delete_pending_file(_active_event_id)
		log_message("[%s] 전송 성공 (%d OK, %dms)" % [_active_request_type, response_code, last_latency_ms], "success")
		event_transmitted.emit(_active_request_type, true, response_code, body_str.substr(0, 80))

		if not _pending_queue.is_empty() and get_tree():
			get_tree().create_timer(0.05).timeout.connect(_try_flush_queue)
	else:
		var err_reason := ""
		match result:
			HTTPRequest.RESULT_CANT_CONNECT:
				err_reason = "서버 연결 불가 (%s:%d 확인)" % [target_host, target_port]
			HTTPRequest.RESULT_TIMEOUT:
				err_reason = "응답 시간 초과 (Timeout %.1fs)" % request_timeout
			HTTPRequest.RESULT_CANT_RESOLVE:
				err_reason = "호스트 주소 해석 실패"
			HTTPRequest.RESULT_CONNECTION_ERROR:
				err_reason = "네트워크 연결 끊김"
			_:
				if response_code == 401:
					err_reason = "인증 실패 (401: X-API-Key 확인 필요)"
				elif response_code == 422:
					err_reason = "스키마 유효성 거부 (422: %s)" % body_str.substr(0, 100)
				elif response_code > 0:
					err_reason = "HTTP 오류 (%d: %s)" % [response_code, body_str.substr(0, 60)]
				else:
					err_reason = "통신 실패 (코드: %d)" % result

		_handle_network_failure(err_reason, response_code, body_str)

func _handle_network_failure(reason: String, code: int, _body_str: String = "") -> void:
	total_sent_failed += 1
	last_error_message = reason
	_last_fail_time = Time.get_ticks_msec()
	_set_status(NetStatus.OFFLINE, "오프라인/오류: %s" % reason)

	# G2 Rule: 401 & 422 are moved to user://telemetry/rejected/ and NOT retried
	if code == 401 or code == 422:
		if not _pending_queue.is_empty():
			var rejected_item: Dictionary = _pending_queue.pop_front()
			_move_pending_to_rejected(str(rejected_item.get("event_id", _active_event_id)), rejected_item)
		else:
			_move_pending_to_rejected(_active_event_id)
		log_message("[%s] 전송 거부(%d) -> rejected 이동: %s" % [_active_request_type, code, reason], "error")
		event_transmitted.emit(_active_request_type, false, code, reason)
		if not _pending_queue.is_empty() and get_tree():
			get_tree().create_timer(0.1).timeout.connect(_try_flush_queue)
		return

	# G2 Rule: Network error / 5xx / offline -> keep in pending/ with same event_id and retry with 1s..60s backoff
	if not _pending_queue.is_empty():
		var head_item: Dictionary = _pending_queue[0]
		_offline_backlog.append(head_item)
		if _offline_backlog.size() > MAX_QUEUE_SIZE:
			_offline_backlog.pop_front()

	var wait_sec := _retry_backoff_sec
	_retry_backoff_sec = minf(_retry_backoff_sec * 2.0, BACKOFF_MAX_SEC)
	log_message("[%s] 통신 실패 (%.0f초 후 재시도, 디스크 큐 보관됨): %s" % [_active_request_type, wait_sec, reason], "error")
	event_transmitted.emit(_active_request_type, false, code, reason)

	if not _retry_scheduled and get_tree():
		_retry_scheduled = true
		get_tree().create_timer(wait_sec).timeout.connect(func():
			_retry_scheduled = false
			_try_flush_queue()
		)

func _set_status(st: NetStatus, msg: String) -> void:
	current_status = st
	status_changed.emit(_status_to_string(st), msg)

func _status_to_string(st: NetStatus) -> String:
	match st:
		NetStatus.IDLE: return "IDLE"
		NetStatus.CONNECTING: return "CONNECTING"
		NetStatus.CONNECTED: return "CONNECTED"
		NetStatus.SENDING: return "SENDING"
		NetStatus.OFFLINE: return "OFFLINE"
		NetStatus.ERROR: return "ERROR"
	return "UNKNOWN"

# ==========================================
# DIAGNOSTICS & PING
# ==========================================
func test_connection() -> void:
	if _is_busy:
		log_message("현재 통신 진행 중입니다. 잠시 후 다시 시도하세요.", "warn")
		return
	log_message("서버 연결 테스트: %s" % get_full_url(), "info")
	_update_player_id()
	var test_ev := _create_event("operation_succeeded", {"operation": "ping_test", "level": 1, "moves": 0, "mistakes": 0})
	_dispatch_event(test_ev)

func send_test_dummy_event() -> void:
	log_message("ST01 배열 미니게임 v2 테스트 이벤트 전송...", "info")
	start_task("ST01", {"level": 1})
	start_attempt("ST01", 1, {"level": 1})
	record_operation("slot_move", true, "", {}, {}, {"level": 1, "moves": 1, "mistakes": 0})
	complete_attempt("ST01", true, "", {"level": 1, "moves": 1, "mistakes": 0, "stars": 3})
	complete_task("ST01", {"level": 1, "moves": 1, "mistakes": 0, "stars": 3})

# ==========================================
# LOGGING & TIMESTAMPS
# ==========================================
func log_message(text: String, level: String = "info") -> void:
	var time_str := Time.get_time_string_from_system()
	var entry := {
		"time": time_str,
		"text": text,
		"level": level
	}
	_logs.append(entry)
	if _logs.size() > MAX_LOG_SIZE:
		_logs.pop_front()
	log_appended.emit(entry)
	if level == "error":
		push_warning("[Telemetry Error] %s" % text)
	else:
		print("[Telemetry %s] %s" % [level.to_upper(), text])

func get_logs() -> Array:
	return _logs

func clear_logs() -> void:
	_logs.clear()

static func generate_uuid_v4() -> String:
	var b := PackedByteArray()
	b.resize(16)
	for i in range(16):
		b[i] = randi() % 256
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
		b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]
	]

static func get_iso_timestamp() -> String:
	var unix_sec: float = Time.get_unix_time_from_system()
	var whole_sec: int = int(floor(unix_sec))
	var ms: int = clampi(int(round((unix_sec - float(whole_sec)) * 1000.0)), 0, 999)
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(whole_sec)
	return "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"], ms
	]
