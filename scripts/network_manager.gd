class_name NetworkManagerClass
extends Node

## NODEVERSE Network & Mini-Game Telemetry Manager (Schema v2)
## Implements Common Event Schema v2 (/v2/events) for all 24 mini-games
## Handles non-blocking asynchronous transmission with complete offline exception safety.

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
const DEFAULT_HOST: String = "192.168.0.81"
const DEFAULT_PORT: int = 8000
const DEFAULT_ENDPOINT: String = "/v2/events"
const DEFAULT_AUTH_TOKEN: String = "replace-with-a-long-random-local-key"
const DEFAULT_TIMEOUT: float = 3.0
const MAX_QUEUE_SIZE: int = 150
const MAX_LOG_SIZE: int = 100
const MAX_DETAILS_BYTES: int = 2048

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

# Configuration
var target_host: String = DEFAULT_HOST
var target_port: int = DEFAULT_PORT
var endpoint_path: String = DEFAULT_ENDPOINT
var auth_token: String = DEFAULT_AUTH_TOKEN
var auto_send_enabled: bool = true
var request_timeout: float = DEFAULT_TIMEOUT

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
var _is_busy: bool = false
var _active_request_type: String = ""
var _request_start_time: int = 0
var _logs: Array = []
var _debug_panel_scene: PackedScene = null
var _debug_panel_instance: CanvasLayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_config()
	_init_session()

	_http_request = HTTPRequest.new()
	_http_request.name = "TelemetryHTTP"
	_http_request.timeout = request_timeout
	_http_request.request_completed.connect(_on_http_request_completed)
	add_child(_http_request)

	_init_debug_overlay()
	log_message("네트워크 매니저 초기화 완료 (v2 대상: %s:%d%s)" % [target_host, target_port, endpoint_path], "info")

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
			if users.has(u) and users[u] is Dictionary and users[u].has("user_id"):
				player_id = str(users[u]["user_id"])
				return
			player_id = u
			return
	player_id = _get_or_create_install_id()

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

func _init_debug_overlay() -> void:
	var panel_path = "res://scenes/tools/NetworkDebugPanel.tscn"
	if ResourceLoader.exists(panel_path):
		_debug_panel_scene = load(panel_path)
		if _debug_panel_scene:
			_debug_panel_instance = _debug_panel_scene.instantiate() as CanvasLayer
			add_child(_debug_panel_instance)

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

func get_full_url() -> String:
	return get_base_url() + endpoint_path

# ==========================================
# EVENT BUILDERS (SCHEMA V2)
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

func send_custom_event(event_type: String, data: Dictionary = {}) -> void:
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

# ==========================================
# ASYNC TRANSMISSION & EXCEPTION SAFETY
# ==========================================
func _dispatch_event(event_dict: Dictionary) -> void:
	if not auto_send_enabled:
		return
	_pending_queue.append(event_dict)
	if _pending_queue.size() > MAX_QUEUE_SIZE:
		_pending_queue.pop_front()
	_try_flush_queue()

func _try_flush_queue() -> void:
	if _is_busy or _pending_queue.is_empty():
		return

	_is_busy = true
	var current_event: Dictionary = _pending_queue[0]
	var json_str := JSON.stringify(current_event)

	var headers := PackedStringArray([
		"Content-Type: application/json; charset=utf-8"
	])
	if not auth_token.is_empty():
		headers.append("X-API-Key: %s" % auth_token)
		headers.append("Authorization: Bearer %s" % auth_token)

	_active_request_type = str(current_event.get("event_type", "event"))
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
		_set_status(NetStatus.CONNECTED, "전송 성공 (%d OK, %dms)" % [response_code, last_latency_ms])
		if not _pending_queue.is_empty():
			_pending_queue.pop_front()
		log_message("[%s] 전송 성공 (%d OK, %dms)" % [_active_request_type, response_code, last_latency_ms], "success")
		event_transmitted.emit(_active_request_type, true, response_code, body_str.substr(0, 80))

		if not _pending_queue.is_empty():
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
					err_reason = "인증 실패 (401: X-API-Key 또는 INGEST_KEY 확인 필요)"
				elif response_code == 422:
					err_reason = "데이터 형식 불일치 (422: 유효성 오류: %s)" % body_str.substr(0, 100)
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

	if not _pending_queue.is_empty():
		var failed_item = _pending_queue.pop_front()
		if code != 401 and code != 422:
			_offline_backlog.append(failed_item)
			if _offline_backlog.size() > MAX_QUEUE_SIZE:
				_offline_backlog.pop_front()

	log_message("[%s] 통신 실패: %s (게임은 정상 계속됩니다)" % [_active_request_type, reason], "error")
	event_transmitted.emit(_active_request_type, false, code, reason)

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
