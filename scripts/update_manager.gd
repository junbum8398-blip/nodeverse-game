class_name UpdateManagerClass
extends Node

## NODEVERSE Game Update & Resource Pack Manager (G5 Compliant)
## - Checks GET /api/game/manifest?channel=windows-stable on startup (max 5s timeout)
## - Gracefully falls back to last verified pack (or base) when server is offline or unimplemented
## - Supports required update (min_build), optional update (latest_build), and SHA-256 verified .pck hot-patching
## - Emits all 9 update telemetry events (update_checked, update_prompted, update_accepted, update_dismissed,
##   pack_download_started, pack_download_succeeded, pack_download_failed, pack_mounted, build_changed)

signal update_required(download_page: String)
signal update_available(download_page: String, notes: String)
signal update_check_completed(status: String)

const MANIFEST_ENDPOINT: String = "/api/game/manifest?channel=windows-stable"
const PACK_DIR: String = "user://packs/"
const INSTALLED_JSON: String = "user://packs/installed.json"
const LAST_BUILD_FILE: String = "user://last_build"
const DEFAULT_TIMEOUT_SEC: float = 5.0

var manifest_url_override: String = ""
var is_checking: bool = false
var last_check_result: String = "idle"
var current_content_version: String = "base"

var _ui_layer: CanvasLayer = null
var _modal_root: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PACK_DIR))
	update_required.connect(_show_required_update_dialog)
	update_available.connect(_show_optional_update_dialog)
	call_deferred("_startup_flow")

func _startup_flow() -> void:
	_check_build_changed()
	# In headless CLI test runs, mount local packs immediately without waiting on network timeout
	if DisplayServer.get_name() == "headless":
		_mount_installed()
		return
	var nm := _get_net_mgr()
	if nm and not bool(nm.get("auto_send_enabled")):
		_mount_installed()
		return
	await run()

func _get_net_mgr() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.get_node_or_null("NetworkManager")
	return null

func _emit_update_event(event_type: String, details: Dictionary = {}) -> void:
	var nm := _get_net_mgr()
	if nm and nm.has_method("send_update_event"):
		nm.call("send_update_event", event_type, details)

func _get_build_version() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", "0.3.0")).strip_edges()
	return v if not v.is_empty() else "0.3.0"

func get_manifest_url() -> String:
	if not manifest_url_override.strip_edges().is_empty():
		return manifest_url_override.strip_edges()
	var env_url := OS.get_environment("NODEVERSE_MANIFEST_URL").strip_edges()
	if not env_url.is_empty():
		return env_url
	var nm := _get_net_mgr()
	if nm and nm.has_method("get_base_url"):
		return str(nm.call("get_base_url")) + MANIFEST_ENDPOINT
	return "http://192.168.0.81:8000" + MANIFEST_ENDPOINT

# ==========================================
# BUILD VERSION CHANGE DETECTION
# ==========================================
func _check_build_changed() -> void:
	var current_build := _get_build_version()
	var prev_build := ""
	if FileAccess.file_exists(LAST_BUILD_FILE):
		prev_build = FileAccess.get_file_as_string(LAST_BUILD_FILE).strip_edges()
	if not prev_build.is_empty() and prev_build != current_build:
		_emit_update_event("build_changed", {
			"from_version": prev_build,
			"target_version": current_build
		})
	var wf := FileAccess.open(LAST_BUILD_FILE, FileAccess.WRITE)
	if wf != null:
		wf.store_string(current_build)
		wf.close()

# ==========================================
# CORE UPDATE CHECK & RESOURCE PACK FLOW (G5)
# ==========================================
func run() -> void:
	if is_checking:
		return
	is_checking = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PACK_DIR))

	var url := get_manifest_url()
	var m = await _fetch_json(url, DEFAULT_TIMEOUT_SEC)
	if m == null or not (m is Dictionary):
		# Offline or server endpoint not implemented yet: mount last verified pack and continue cleanly
		last_check_result = "offline"
		_emit_update_event("update_checked", {"result": "offline"})
		_mount_installed()
		is_checking = false
		update_check_completed.emit("offline")
		return

	var build := _get_build_version()
	var min_build := str(m.get("min_build", "0.0.0")).strip_edges()
	var latest_build := str(m.get("latest_build", build)).strip_edges()
	var download_page := str(m.get("download_page", "")).strip_edges()
	var notes := str(m.get("notes", "")).strip_edges()

	if not min_build.is_empty() and _cmp(build, min_build) < 0:
		last_check_result = "required"
		_emit_update_event("update_checked", {
			"result": "required",
			"target_version": latest_build if not latest_build.is_empty() else min_build
		})
		update_required.emit(download_page)
		is_checking = false
		update_check_completed.emit("required")
		return

	if not latest_build.is_empty() and _cmp(build, latest_build) < 0:
		last_check_result = "optional"
		_emit_update_event("update_checked", {
			"result": "optional",
			"target_version": latest_build
		})
		update_available.emit(download_page, notes)
	else:
		last_check_result = "up_to_date"
		_emit_update_event("update_checked", {
			"result": "up_to_date",
			"target_version": build
		})

	var content_dict: Dictionary = m.get("content", {}) if m.get("content") is Dictionary else {}
	var content_ver := str(content_dict.get("version", "")).strip_edges()
	var packs: Array = content_dict.get("packs", []) if content_dict.get("packs") is Array else []
	for p in packs:
		if p is Dictionary:
			var pack_min_build := str(p.get("min_build", "0.0.0")).strip_edges()
			if _cmp(build, pack_min_build) >= 0:
				await _ensure_pack(p, content_ver)

	_mount_installed()
	is_checking = false
	update_check_completed.emit(last_check_result)

static func _cmp(a: String, b: String) -> int:
	var pa := a.strip_edges().trim_prefix("v").split(".")
	var pb := b.strip_edges().trim_prefix("v").split(".")
	var n := maxi(pa.size(), pb.size())
	for i in range(n):
		var va := int(pa[i]) if i < pa.size() and pa[i].is_valid_int() else 0
		var vb := int(pb[i]) if i < pb.size() and pb[i].is_valid_int() else 0
		if va < vb:
			return -1
		if va > vb:
			return 1
	return 0

func _fetch_json(url: String, timeout_sec: float = DEFAULT_TIMEOUT_SEC):
	if url.is_empty():
		return null
	var req := HTTPRequest.new()
	req.timeout = timeout_sec
	add_child(req)
	var err := req.request(url)
	if err != OK:
		req.queue_free()
		return null
	var r: Array = await req.request_completed
	req.queue_free()
	var result: int = int(r[0])
	var code: int = int(r[1])
	var body: PackedByteArray = r[3]
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return null
	var txt := body.get_string_from_utf8().strip_edges()
	var parsed = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else null

func _ensure_pack(p: Dictionary, content_ver: String = "") -> void:
	var file_name := str(p.get("file", "")).strip_edges()
	var pack_url := str(p.get("url", "")).strip_edges()
	var expected_sha := str(p.get("sha256", "")).strip_edges().to_lower()
	var target_ver := content_ver if not content_ver.is_empty() else file_name.trim_suffix(".pck")
	if file_name.is_empty() or expected_sha.is_empty():
		return

	var path: String = PACK_DIR + file_name
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path).to_lower() == expected_sha:
		_mark_installed(p, target_ver)
		return

	if pack_url.is_empty():
		return

	_emit_update_event("pack_download_started", {"target_version": target_ver})
	var t0 := Time.get_ticks_msec()
	var part_path := path + ".part"
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	req.download_file = part_path
	var err := req.request(pack_url)
	if err != OK:
		req.queue_free()
		_emit_update_event("pack_download_failed", {
			"target_version": target_ver,
			"failure_reason": "network",
			"bytes": 0,
			"duration_ms": Time.get_ticks_msec() - t0
		})
		return

	var r: Array = await req.request_completed
	var dl_bytes := req.get_downloaded_bytes()
	var duration_ms := Time.get_ticks_msec() - t0
	req.queue_free()

	var result: int = int(r[0])
	var code: int = int(r[1])
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		if FileAccess.file_exists(part_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(part_path))
		var reason := "http_error" if code > 0 else "network"
		_emit_update_event("pack_download_failed", {
			"target_version": target_ver,
			"failure_reason": reason,
			"bytes": dl_bytes,
			"duration_ms": duration_ms
		})
		return

	if not FileAccess.file_exists(part_path):
		_emit_update_event("pack_download_failed", {
			"target_version": target_ver,
			"failure_reason": "disk",
			"bytes": dl_bytes,
			"duration_ms": duration_ms
		})
		return

	var actual_sha := FileAccess.get_sha256(part_path).to_lower()
	if actual_sha == expected_sha:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		var ren_err := DirAccess.rename_absolute(ProjectSettings.globalize_path(part_path), ProjectSettings.globalize_path(path))
		if ren_err == OK:
			_mark_installed(p, target_ver)
			_emit_update_event("pack_download_succeeded", {
				"target_version": target_ver,
				"bytes": dl_bytes,
				"duration_ms": duration_ms
			})
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(part_path))
			_emit_update_event("pack_download_failed", {
				"target_version": target_ver,
				"failure_reason": "disk",
				"bytes": dl_bytes,
				"duration_ms": duration_ms
			})
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(part_path))
		_emit_update_event("pack_download_failed", {
			"target_version": target_ver,
			"failure_reason": "hash_mismatch",
			"bytes": dl_bytes,
			"duration_ms": duration_ms
		})

func _mark_installed(p: Dictionary, target_ver: String = "") -> void:
	var file_name := str(p.get("file", "")).strip_edges()
	var ver := target_ver if not target_ver.is_empty() else file_name.trim_suffix(".pck")
	var state := _read_installed_dict()
	var history: Array = state.get("files", [])
	if not history.has(file_name):
		history.append(file_name)
	# Keep active pack + at most 1 previous pack for rollback; delete older packs
	while history.size() > 2:
		var old_file := str(history.pop_front())
		var old_path := PACK_DIR + old_file
		if FileAccess.file_exists(old_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))
	var new_state := {
		"version": ver,
		"active_file": file_name,
		"sha256": str(p.get("sha256", "")).to_lower(),
		"files": history
	}
	var wf := FileAccess.open(INSTALLED_JSON, FileAccess.WRITE)
	if wf != null:
		wf.store_string(JSON.stringify(new_state, "  "))
		wf.close()

func _read_installed_dict() -> Dictionary:
	if not FileAccess.file_exists(INSTALLED_JSON):
		return {"version": "base", "active_file": "", "files": []}
	var txt := FileAccess.get_file_as_string(INSTALLED_JSON)
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed
	if parsed is Array:
		var last_f := str(parsed.back()) if not parsed.is_empty() else ""
		return {"version": last_f.trim_suffix(".pck") if not last_f.is_empty() else "base", "active_file": last_f, "files": parsed}
	return {"version": "base", "active_file": "", "files": []}

func _read_installed() -> Array:
	var d := _read_installed_dict()
	var active := str(d.get("active_file", "")).strip_edges()
	if not active.is_empty():
		return [active]
	var files = d.get("files", [])
	return files if files is Array else []

func _mount_installed() -> void:
	var d := _read_installed_dict()
	var mounted_any := false
	for f in _read_installed():
		var f_str := str(f).strip_edges()
		if f_str.is_empty():
			continue
		var pack_path := PACK_DIR + f_str
		if FileAccess.file_exists(pack_path):
			var ok := ProjectSettings.load_resource_pack(pack_path)
			if ok:
				mounted_any = true
	if mounted_any:
		var ver := str(d.get("version", "base")).strip_edges()
		if ver.is_empty():
			ver = "base"
		current_content_version = ver
		var nm := _get_net_mgr()
		if nm and nm.has_method("set_content_version"):
			nm.call("set_content_version", ver)
		_emit_update_event("pack_mounted", {"target_version": ver})
	else:
		current_content_version = "base"
		var nm := _get_net_mgr()
		if nm and nm.has_method("set_content_version"):
			nm.call("set_content_version", "base")

# ==========================================
# UPDATE PROMPT UI (REQUIRED & OPTIONAL)
# ==========================================
func _ensure_ui_layer() -> void:
	if _ui_layer != null and is_instance_valid(_ui_layer):
		return
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 128
	_ui_layer.name = "UpdatePromptLayer"
	add_child(_ui_layer)

func _clear_modal() -> void:
	if _modal_root != null and is_instance_valid(_modal_root):
		_modal_root.queue_free()
		_modal_root = null

func _on_required_accepted(download_page: String) -> void:
	_emit_update_event("update_accepted", {"kind": "required"})
	if not download_page.is_empty():
		OS.shell_open(download_page)

func _on_required_dismissed() -> void:
	var nm := _get_net_mgr()
	if nm:
		nm.set("learning_events_paused", true)
	_emit_update_event("update_dismissed", {"kind": "required"})
	_clear_modal()
	_mount_installed()

func _on_optional_accepted(download_page: String) -> void:
	_emit_update_event("update_accepted", {"kind": "optional"})
	if not download_page.is_empty():
		OS.shell_open(download_page)
	_clear_modal()

func _on_optional_dismissed() -> void:
	_emit_update_event("update_dismissed", {"kind": "optional"})
	_clear_modal()

func _show_required_update_dialog(download_page: String) -> void:
	_emit_update_event("update_prompted", {"kind": "required"})
	if DisplayServer.get_name() == "headless":
		return
	_ensure_ui_layer()
	_clear_modal()

	_modal_root = _build_dialog_card(
		"새 버전이 필요합니다",
		"현재 실행 중인 클라이언트 버전이 최소 요구 버전보다 낮습니다.\n원활한 학습 기록 연동과 최신 스테이지 이용을 위해 새 버전을 받아주세요.",
		"다운로드 페이지 열기",
		"오프라인으로 계속",
		func(): _on_required_accepted(download_page),
		func(): _on_required_dismissed()
	)
	_ui_layer.add_child(_modal_root)

func _show_optional_update_dialog(download_page: String, notes: String) -> void:
	_emit_update_event("update_prompted", {"kind": "optional"})
	if DisplayServer.get_name() == "headless":
		return
	_ensure_ui_layer()
	_clear_modal()

	var desc := "새로운 버전이 준비되었습니다."
	if not notes.is_empty():
		desc += "\n• 변경 사항: " + notes
	_modal_root = _build_dialog_card(
		"업데이트 안내 (선택)",
		desc,
		"다운로드 페이지 열기",
		"그대로 플레이",
		func(): _on_optional_accepted(download_page),
		func(): _on_optional_dismissed()
	)
	_ui_layer.add_child(_modal_root)

func _build_dialog_card(title_text: String, body_text: String, primary_label: String, secondary_label: String, on_primary: Callable, on_secondary: Callable) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.08, 0.11, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 250)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.985, 0.972, 0.938)
	sb.border_color = Color(0.102, 0.455, 0.510)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var tl := Label.new()
	tl.text = title_text
	tl.add_theme_font_size_override("font_size", 22)
	tl.add_theme_color_override("font_color", Color(0.10, 0.22, 0.25))
	vb.add_child(tl)

	var bl := Label.new()
	bl.text = body_text
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.custom_minimum_size = Vector2(460, 72)
	bl.add_theme_font_size_override("font_size", 15)
	bl.add_theme_color_override("font_color", Color(0.24, 0.32, 0.34))
	vb.add_child(bl)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)

	var sec_btn := Button.new()
	sec_btn.text = secondary_label
	sec_btn.custom_minimum_size = Vector2(150, 40)
	sec_btn.pressed.connect(on_secondary)
	hb.add_child(sec_btn)

	var pri_btn := Button.new()
	pri_btn.text = primary_label
	pri_btn.custom_minimum_size = Vector2(180, 40)
	pri_btn.pressed.connect(on_primary)
	hb.add_child(pri_btn)

	return root
