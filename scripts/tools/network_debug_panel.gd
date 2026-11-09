class_name NetworkDebugPanel
extends CanvasLayer

## In-Game Realtime Telemetry & Mini-Game Data Transmission Debug Panel
## Allows live inspection, configuration (IP/Port/Endpoint/Key), ping testing, and offline status monitoring.
## Can be toggled via F6 key or corner HUD button.

@onready var panel_root: PanelContainer = $Panel
@onready var host_input: LineEdit = $Panel/VBox/ConfigSection/Grid/HostEdit
@onready var port_input: LineEdit = $Panel/VBox/ConfigSection/Grid/PortEdit
@onready var endpoint_input: LineEdit = $Panel/VBox/ConfigSection/Grid/EndpointEdit
@onready var key_input: LineEdit = $Panel/VBox/ConfigSection/Grid/KeyEdit
@onready var save_btn: Button = $Panel/VBox/ConfigSection/BtnRow/SaveBtn
@onready var ping_btn: Button = $Panel/VBox/ConfigSection/BtnRow/PingBtn
@onready var test_btn: Button = $Panel/VBox/ConfigSection/BtnRow/TestSendBtn
@onready var clear_btn: Button = $Panel/VBox/ConfigSection/BtnRow/ClearLogBtn
@onready var status_badge: Label = $Panel/VBox/StatusBar/StatusBadge
@onready var status_desc: Label = $Panel/VBox/StatusBar/StatusDesc
@onready var stats_label: Label = $Panel/VBox/StatusBar/StatsLabel
@onready var log_box: RichTextLabel = $Panel/VBox/LogSection/Scroll/LogBox
@onready var toggle_pill_btn: Button = $TogglePillBtn

var _net_mgr: Node = null

func _ready() -> void:
	layer = 125
	# Find NetworkManager singleton
	if Engine.has_singleton("NetworkManager"):
		_net_mgr = Engine.get_singleton("NetworkManager")
	elif get_node_or_null("/root/NetworkManager"):
		_net_mgr = get_node("/root/NetworkManager")
	else:
		_net_mgr = get_parent()
	
	_setup_ui()
	_connect_signals()
	_refresh_from_config()
	
	# Hide corner button and panel completely by default so ordinary players never see debug UI
	toggle_pill_btn.visible = false
	panel_root.visible = false

func _setup_ui() -> void:
	# Corner pill button
	toggle_pill_btn.pressed.connect(toggle_panel)
	
	# Action buttons
	save_btn.pressed.connect(_on_save_pressed)
	ping_btn.pressed.connect(_on_ping_pressed)
	test_btn.pressed.connect(_on_test_send_pressed)
	clear_btn.pressed.connect(_on_clear_log_pressed)
	
	var close_btn = $Panel/VBox/Header/CloseBtn
	if close_btn:
		close_btn.pressed.connect(func(): panel_root.visible = false)

func _connect_signals() -> void:
	if _net_mgr:
		if _net_mgr.has_signal("status_changed"):
			_net_mgr.connect("status_changed", _on_status_changed)
		if _net_mgr.has_signal("log_appended"):
			_net_mgr.connect("log_appended", _on_log_appended)
		if _net_mgr.has_signal("event_transmitted"):
			_net_mgr.connect("event_transmitted", _on_event_transmitted)

func toggle_panel() -> void:
	panel_root.visible = not panel_root.visible
	if panel_root.visible:
		_refresh_from_config()
		_update_stats()

func _refresh_from_config() -> void:
	if not _net_mgr:
		return
	host_input.text = str(_net_mgr.get("target_host"))
	port_input.text = str(_net_mgr.get("target_port"))
	endpoint_input.text = str(_net_mgr.get("endpoint_path"))
	key_input.text = str(_net_mgr.get("auth_token"))
	_update_status_display(str(_net_mgr.call("_status_to_string", _net_mgr.get("current_status"))), "대기 중")
	_rebuild_log_view()

func _on_save_pressed() -> void:
	if not _net_mgr:
		return
	var h: String = host_input.text.strip_edges()
	var p: int = int(port_input.text.strip_edges())
	var ep: String = endpoint_input.text.strip_edges()
	var k: String = key_input.text.strip_edges()
	if h.is_empty():
		h = "192.168.0.81"
	if p <= 0:
		p = 8000
	if ep.is_empty():
		ep = "/v1/events"
	
	_net_mgr.call("set_server_target", h, p, ep, k)
	_update_status_display("IDLE", "설정이 저장되었습니다.")

func _on_ping_pressed() -> void:
	if not _net_mgr:
		return
	_net_mgr.call("test_connection")

func _on_test_send_pressed() -> void:
	if not _net_mgr:
		return
	_net_mgr.call("send_test_dummy_event")

func _on_clear_log_pressed() -> void:
	if not _net_mgr:
		return
	_net_mgr.call("clear_logs")
	log_box.clear()

func _on_status_changed(st: String, msg: String) -> void:
	_update_status_display(st, msg)
	_update_stats()

func _on_event_transmitted(_ev_type: String, _is_success: bool, _code: int, _info: String) -> void:
	_update_stats()

func _update_status_display(st: String, msg: String) -> void:
	match st:
		"CONNECTED":
			status_badge.text = "● 연결 정상"
			status_badge.modulate = Color("4caf50") # Green
		"SENDING":
			status_badge.text = "● 전송 중..."
			status_badge.modulate = Color("f2c14e") # Yellow
		"OFFLINE":
			status_badge.text = "● 오프라인/오류"
			status_badge.modulate = Color("e05252") # Red
		"ERROR":
			status_badge.text = "● 통신 오류"
			status_badge.modulate = Color("e05252") # Red
		_:
			status_badge.text = "● 대기 중"
			status_badge.modulate = Color("9e9e9e") # Gray
	
	status_desc.text = msg

func _update_stats() -> void:
	if not _net_mgr:
		return
	var succ: int = int(_net_mgr.get("total_sent_success"))
	var fail: int = int(_net_mgr.get("total_sent_failed"))
	var queue_size: int = 0
	var q = _net_mgr.get("_pending_queue")
	if q is Array:
		queue_size = q.size()
	var lat: int = int(_net_mgr.get("last_latency_ms"))
	
	stats_label.text = "성공: %d | 실패: %d | 대기: %d | 응답속도: %dms" % [succ, fail, queue_size, lat]

func _on_log_appended(log_data: Dictionary) -> void:
	var color_tag := "white"
	match str(log_data.get("level", "info")):
		"success": color_tag = "#66bb6a"
		"warn": color_tag = "#ffa726"
		"error": color_tag = "#ef5350"
		"info": color_tag = "#4fc3f7"
	
	var line := "[color=#9e9e9e][%s][/color] [color=%s]%s[/color]\n" % [
		str(log_data.get("time", "")),
		color_tag,
		str(log_data.get("text", "")).replace("[", "\\[").replace("]", "\\]")
	]
	log_box.append_text(line)

func _rebuild_log_view() -> void:
	log_box.clear()
	if not _net_mgr:
		return
	var logs: Array = _net_mgr.call("get_logs")
	for entry in logs:
		_on_log_appended(entry)
