class_name NetworkManagerClass
extends Node

## NODEVERSE Network & Mini-Game Telemetry Manager
## Supports FastAPI teammate endpoint (/v1/events) and v3.0 batch specification
## Handles non-blocking asynchronous transmission with complete offline exception safety.

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
const DEFAULT_HOST: String = "192.168.0.81"
const DEFAULT_PORT: int = 8000
const DEFAULT_ENDPOINT: String = "/v1/events"
const DEFAULT_AUTH_TOKEN: String = "replace-with-a-long-random-local-key"
const DEFAULT_TIMEOUT: float = 3.0
const MAX_QUEUE_SIZE: int = 150
const MAX_LOG_SIZE: int = 100

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

# Identifiers
var session_id: String = ""
var current_run_id: String = ""
var current_attempt_id: String = ""
var current_task_id: String = "ST01_ARRAY"
var sequence_num: int = 1
var player_id: String = "Guest"

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
	log_message("네트워크 매니저 초기화 완료 (대상: %s:%d%s)" % [target_host, target_port, endpoint_path], "info")

func _init_session() -> void:
	session_id = generate_uuid_v4()
	current_run_id = generate_uuid_v4()
	current_attempt_id = generate_uuid_v4()
	sequence_num = 1
	_update_player_id()

func _update_player_id() -> void:
	var auth_mgr_class = load("res://scripts/auth_manager.gd")
	if auth_mgr_class:
		var store = auth_mgr_class._get_store()
		var u = store.get("last_user", "")
		if not str(u).is_empty():
			player_id = str(u)
		else:
			player_id = "Guest"

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
		endpoint_path = str(d.get("endpoint", DEFAULT_ENDPOINT)).strip_edges()
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
		h = "http://" + h
	return "%s:%d" % [h, target_port]

func get_full_url() -> String:
	return get_base_url() + endpoint_path

# ==========================================
# EVENT BUILDERS
# ==========================================
func start_task(task_id: String, details: Dictionary = {}) -> void:
	_update_player_id()
	current_task_id = task_id
	current_run_id = generate_uuid_v4()
	sequence_num = 1
	var ev := _create_event("problem_started", details)
	_dispatch_event(ev)
	log_message("태스크 시작: %s" % task_id, "info")

func start_attempt(task_id: String, attempt_num: int, details: Dictionary = {}) -> void:
	current_attempt_id = generate_uuid_v4()
	var ev := _create_event("attempt_started", details)
	_dispatch_event(ev)
	log_message("도전 #%d 시작: %s" % [attempt_num, task_id], "info")

func record_operation(op_name: String, is_success: bool, failure_reason: String = "", state_before: Dictionary = {}, state_after: Dictionary = {}, context_extra: Dictionary = {}) -> void:
	var extra := context_extra.duplicate()
	extra["operation"] = op_name
	extra["is_success"] = is_success
	if not is_success and not failure_reason.is_empty():
		extra["failure_reason"] = failure_reason
	var ev := _create_event("operation", extra)
	_dispatch_event(ev)

func complete_attempt(task_id: String, is_success: bool, reason: String = "", details: Dictionary = {}) -> void:
	var ev_type := "attempt_succeeded" if is_success else "attempt_failed"
	var extra := details.duplicate()
	if not is_success:
		extra["failure_reason"] = reason
	var ev := _create_event(ev_type, extra)
	_dispatch_event(ev)
	log_message("도전 %s: %s" % ["성공" if is_success else "실패", task_id], "success" if is_success else "warn")

func complete_task(task_id: String, details: Dictionary = {}) -> void:
	var ev := _create_event("attempt_succeeded", details)
	_dispatch_event(ev)
	log_message("태스크 완료: %s" % task_id, "success")

func send_custom_event(event_type: String, data: Dictionary = {}) -> void:
	var mapped_type := "operation"
	match event_type:
		"task_started", "problem_started": mapped_type = "problem_started"
		"attempt_started": mapped_type = "attempt_started"
		"attempt_succeeded", "task_completed": mapped_type = "attempt_succeeded"
		"attempt_failed", "operation_failed": mapped_type = "attempt_failed"
		_: mapped_type = "operation"
	var ev := _create_event(mapped_type, data)
	_dispatch_event(ev)

func _create_event(event_type: String, details: Dictionary = {}) -> Dictionary:
	var ev := {
		"schema_version": 1,
		"event_id": generate_uuid_v4(),
		"player_id": player_id,
		"session_id": session_id,
		"run_id": current_run_id if not current_run_id.is_empty() else generate_uuid_v4(),
		"problem_id": current_task_id,
		"attempt_id": current_attempt_id if not current_attempt_id.is_empty() else generate_uuid_v4(),
		"event_type": event_type,
		"occurred_at": get_iso_timestamp(),
		"sequence": sequence_num
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
	var test_ev := _create_event("operation", {"test": true, "note": "Connection Ping Test"})
	_dispatch_event(test_ev)

func send_test_dummy_event() -> void:
	log_message("ST01 배열 미니게임 테스트 이벤트 전송...", "info")
	start_task("ST01_ARRAY", {"title": "순서가 있는 보관소"})
	start_attempt("ST01_ARRAY", 1)
	record_operation("slot_move", true, "", {}, {}, {"from": 1, "to": 2})
	complete_attempt("ST01_ARRAY", true, "", {"moves": 1, "mistakes": 0, "stars": 3})

# ==========================================
# LOGGING
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
	var dt := Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"]
	]
