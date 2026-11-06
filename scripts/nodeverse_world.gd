extends Node3D

## NODEVERSE 7-Island World (WorldTerrain Architecture)
## Seamlessly unified 7 connected islands with organic terrain, arch bridges,
## NPC dialogue system, 2D mini-game computers, auth/login screen, world tour camera,
## quizzes, and Camera Debug & Lock Panel.

const ExtraAssets = preload("res://scripts/builders/builder_extra_world_assets.gd")
const BuilderComputer = preload("res://scripts/builders/builder_computer.gd")
const StaticBatcher = preload("res://scripts/static_batcher.gd")
const PlayerRobot = preload("res://scripts/player_robot.gd")
const AuthManager = preload("res://scripts/auth_manager.gd")
const BasicsGuide = preload("res://scripts/basics_guide.gd")

const ASSET_DIR: String = "res://scenes/assets/"
const WATER_Y: float = 0.05
const TOP: float = 1.0
const SEA_FAR: Color = Color(0.10, 0.50, 0.66)
const OCEAN_SIZE: float = 1600.0

static var cached_world: Node = null
const GAME_2D_SIZE := Vector2i(1280, 720)
static var saved_player_pos: Vector3 = Vector3.ZERO
static var saved_cam_yaw: float = 45.0

# ============================================================================
# 7 ISLANDS CONFIGURATION (WorldTerrain - Organic Beveled Lego Style)
# ============================================================================
const ISLANDS := {
	"MAIN": {"center": Vector2(0.0, 5.3), "rx": 7.4, "rz": 6.3, "rects": [Rect2(-2.5, -2.6, 5.0, 4.0)], "seed": 3},
	"DS": {"center": Vector2(-15.5, -1.0), "rx": 7.0, "rz": 6.5, "rects": [], "seed": 7},
	"ALGO": {"center": Vector2(0.0, -14.0), "rx": 9.5, "rz": 5.6, "rects": [], "seed": 11},
	"SQL": {"center": Vector2(15.5, -1.0), "rx": 7.0, "rz": 6.5, "rects": [], "seed": 13},
	"INTRO": {"center": Vector2(-17.5, 17.5), "rx": 6.8, "rz": 5.8, "rects": [], "seed": 17},
	"DATA": {"center": Vector2(23.0, -17.5), "rx": 7.2, "rz": 6.0, "rects": [], "seed": 19},
	"CHALLENGE": {"center": Vector2(0.0, -32.5), "rx": 8.5, "rz": 6.5, "rects": [], "seed": 23}
}

var player: CharacterBody3D
var island_cells: Dictionary = {}
var reserved: Array = []   # [Vector2 pos, float radius]
var _scene_cache: Dictionary = {}

# Computer Terminals (2D Mini-Game)
var computer_terminals: Array[Node3D] = []
var computer_positions: Array[Vector3] = [
	Vector3(-12.4, TOP, -1.2)  # 자료구조 섬 진입로
]
const COMPUTER_INTERACT_DIST: float = 3.2
var _basics_board: Node3D
var _basics_guide: Control
var _basics_completed := false
const BOARD_INTERACT_DIST := 2.6

# NPCs (10 Characters)
var spawned_npcs: Array[Node3D] = []
var active_npc: Node3D = null

const NPC_DEFS := [
	{
		"id": "NPC00_hub_guide",
		"name": "중앙 광장 안내원",
		"pos": Vector3(-2.2, TOP, 4.0),
		"rot": -45.0,
		"dialog": "안내원: 안녕하세요! 7개의 섬으로 확장된 NODEVERSE에 오신 것을 환영합니다.\n남서쪽은 입문 섬, 서쪽은 자료구조, 북쪽은 알고리즘, 동쪽은 SQL, 북동쪽은 데이터 탐험, 최북단은 종합 도전 섬입니다."
	},
	{
		"id": "NPC01_array_keeper",
		"name": "배열 관리자",
		"pos": Vector3(-18.5, TOP, -1.5),
		"rot": 90.0,
		"dialog": "배열 관리자: 배열은 연속된 메모리 공간에 데이터를 일렬로 배치합니다.\n인덱스를 알면 O(1) 시간에 즉시 요소에 접근할 수 있죠!"
	},
	{
		"id": "NPC02_link_engineer",
		"name": "연결 엔지니어",
		"pos": Vector3(-13.5, TOP, -4.0),
		"rot": 180.0,
		"dialog": "연결 엔지니어: 연결 리스트는 노드와 포인터로 이어집니다.\n원소의 삽입과 삭제가 O(1)로 유연한 것이 가장 큰 장점입니다!"
	},
	{
		"id": "NPC03_restore_artisan",
		"name": "스택 복구 장인",
		"pos": Vector3(-15.8, TOP, 2.6),
		"rot": -90.0,
		"dialog": "스택 장인: 스택은 후입선출(LIFO)! 마지막에 쌓은 상자를 가장 먼저 꺼냅니다.\n작업 되돌리기(Ctrl+Z)와 호출 스택의 핵심 원리죠."
	},
	{
		"id": "NPC04_receptionist",
		"name": "접수원 (큐)",
		"pos": Vector3(-15.8, TOP, 4.2),
		"rot": 0.0,
		"dialog": "접수원: 큐는 선입선출(FIFO)! 먼저 오신 분부터 차례로 처리합니다.\n프린터 인쇄 대기열이나 BFS 탐색 큐로 널리 쓰입니다."
	},
	{
		"id": "NPC05_registry_clerk",
		"name": "물품대장 서기",
		"pos": Vector3(13.6, TOP, -2.5),
		"rot": 45.0,
		"dialog": "물품대장 서기: 해시 테이블(Hash Table)을 사용하면 어떤 데이터든\n평균 O(1) 시간 만에 순식간에 찾아낼 수 있습니다!"
	},
	{
		"id": "NPC06_tree_archivist",
		"name": "트리 기록관",
		"pos": Vector3(3.6, TOP, -12.5),
		"rot": -135.0,
		"dialog": "트리 기록관: 트리(Tree)는 계층적인 데이터를 표현하는 최고의 구조입니다.\n폴더 디렉토리 구조와 DOM 트리 등이 대표적이죠."
	},
	{
		"id": "NPC07_bst_warden",
		"name": "BST 파수꾼",
		"pos": Vector3(-3.8, TOP, -12.5),
		"rot": 135.0,
		"dialog": "BST 파수꾼: 이진 탐색 트리는 왼쪽엔 작은 값, 오른쪽엔 큰 값이 위치합니다.\n균형이 잘 맞으면 O(log N) 시간에 빠르게 검색할 수 있습니다."
	},
	{
		"id": "NPC08_priority_dispatcher",
		"name": "우선순위 배차원",
		"pos": Vector3(16.5, TOP, 2.8),
		"rot": -120.0,
		"dialog": "우선순위 배차원: 힙(Heap)과 우선순위 큐로 가장 급한 작업부터 즉시 배차합니다!\n최댓값이나 최솟값을 O(1)만에 바로 확인하죠."
	},
	{
		"id": "NPC09_graph_surveyor",
		"name": "그래프 측량사",
		"pos": Vector3(0.0, TOP, -11.6),
		"rot": 180.0,
		"dialog": "그래프 측량사: 정점(Vertex)과 간선(Edge)으로 연결된 복잡한 관계망!\nBFS(너비 우선)와 DFS(깊이 우선)로 최단 경로와 연결성을 분석합니다."
	}
]

# GAME & AUTH STATE
enum GameState { TITLE_LOGIN, DIFFICULTY_SELECT, PLAYING, PAUSED_MENU }
var game_state: GameState = GameState.TITLE_LOGIN
var current_user: String = ""
var current_difficulty: String = "NOVICE"
var user_save_data: Dictionary = {}
var _preview_pivots: Array[Node3D] = []
var _tour_time: float = 0.0
var _tour_paused: bool = false
var _tour_index: int = -1

# HUD & MODALS
var ui_canvas: CanvasLayer
var hud_root: Control
var zone_label: Label
var msg_label: Label
var prompt_label: Label
var help_label: Label
var fps_label: Label
var _msg_time: float = 0.0
var _zone_name: String = "MAIN"

var profile_pill: PanelContainer
var profile_lbl: Label
var diff_badge_lbl: Label
var score_badge_lbl: Label

var title_modal: Control
var auth_user_edit: LineEdit
var auth_pass_edit: LineEdit
var auth_submit_btn: Button
var auth_feedback_lbl: Label
var auth_is_register_mode: bool = false
var auth_tab_login_btn: Button
var auth_tab_register_btn: Button
var pass_toggle_btn: Button

var lobby_modal: Control
var welcome_lbl: Label
var continue_info_lbl: Label
var continue_btn: Button

var pause_modal: Control
var pause_info_lbl: Label

# CAMERA DEBUG PANEL
var cam_debug_panel: PanelContainer
var cam_debug_btn: Button
var cam_info_lbl: Label
var cam_pitch_slider: HSlider
var cam_yaw_slider: HSlider
var cam_dist_slider: HSlider
var cam_fov_slider: HSlider
var cam_height_slider: HSlider
var cam_lock_check: CheckBox
var _updating_cam_ui: bool = false

# WORLD TOUR WAYPOINTS
const TOUR_WAYPOINTS: Array[Dictionary] = [
	{
		"focus": Vector3(0.0, 1.2, 5.3),
		"yaw": 22.0, "pitch": 28.0, "dist": 22.0,
		"name": "메인 섬 · 모든 모험이 시작되는 곳",
		"sub": "WORLD TOUR / 중앙 수정 비콘과 모험가들의 마을 광장"
	},
	{
		"focus": Vector3(-17.5, 1.2, 17.5),
		"yaw": -35.0, "pitch": 26.0, "dist": 20.0,
		"name": "입문 섬 · 기초 로직과 배움의 제단",
		"sub": "WORLD TOUR / 순서도 칠판과 마법서에서 코딩의 첫걸음을 뗍니다"
	},
	{
		"focus": Vector3(-15.5, 1.2, -1.0),
		"yaw": 35.0, "pitch": 26.0, "dist": 21.0,
		"name": "자료구조 섬 · 메모리와 데이터의 질서",
		"sub": "WORLD TOUR / STACK, QUEUE, LIST, ARRAY 인터랙티브 실습"
	},
	{
		"focus": Vector3(0.0, 1.2, -14.0),
		"yaw": 15.0, "pitch": 26.0, "dist": 22.0,
		"name": "알고리즘 섬 · 생각의 계단과 미로 탐색",
		"sub": "WORLD TOUR / 정렬 계단과 5노드 그래프, 미로 정원의 최적화"
	},
	{
		"focus": Vector3(0.0, 1.5, -32.5),
		"yaw": -10.0, "pitch": 28.0, "dist": 24.0,
		"name": "종합 도전 섬 · 영예의 판테온과 정상 회랑",
		"sub": "WORLD TOUR / 모든 지식을 집대성한 최고 시스템 아키텍처"
	},
	{
		"focus": Vector3(23.0, 1.2, -17.5),
		"yaw": -45.0, "pitch": 26.0, "dist": 22.0,
		"name": "데이터 탐험 섬 · 수목 전망대와 시각화",
		"sub": "WORLD TOUR / 히스토그램과 나침반, 판타지 숲속 데이터 탐색"
	},
	{
		"focus": Vector3(15.5, 1.2, -1.0),
		"yaw": -25.0, "pitch": 26.0, "dist": 21.0,
		"name": "SQL 섬 · 데이터베이스 타워와 쿼리 수로",
		"sub": "WORLD TOUR / 방대한 아카이브와 테이블, Y형 쿼리 스트림"
	}
]

var tour_title_lbl: Label
var tour_sub_lbl: Label
var tour_pause_btn: Button

# DIFFICULTY CONFIG
const DIFFICULTY_CONFIG: Dictionary = {
	"NOVICE": {
		"title": "NOVICE",
		"sub": "초급 / 모험가",
		"tag": "초급 / 모험가",
		"badge": "초급 / 모험가",
		"color": Color(0.114, 0.357, 0.329),
		"pts": 10,
		"desc": "일상 속 비유와 시각적 탐험으로\n자료구조의 기초를 차근차근 배워요.",
		"model_scene": "res://scenes/assets/novice_island.tscn",
		"model_center": Vector3(0.24, 0.0, 0.0),
		"cam_dist": 8.4,
		"cam_pitch": 23.0,
		"cam_yaw": -34.0,
		"target_y": 0.90,
		"card_bg": Color(0.937, 0.961, 0.945),
		"border_color": Color(0.86, 0.90, 0.87)
	},
	"DEVELOPER": {
		"title": "DEVELOPER",
		"sub": "중급 / 실전 개발자",
		"tag": "중급 / 실전 개발자",
		"badge": "중급 / 실전 개발자",
		"color": Color(0.102, 0.357, 0.510),
		"pts": 15,
		"desc": "메모리 구조와 시간·공간 복잡도,\n실전 코드를 함께 분석해요.",
		"model_scene": "res://scenes/assets/developer_island.tscn",
		"model_center": Vector3(0.505, 0.0, 0.0),
		"cam_dist": 8.8,
		"cam_pitch": 24.0,
		"cam_yaw": -30.0,
		"target_y": 1.05,
		"card_bg": Color(0.929, 0.949, 0.969),
		"border_color": Color(0.84, 0.88, 0.92)
	},
	"ARCHITECT": {
		"title": "ARCHITECT",
		"sub": "고급 / 시스템 설계자",
		"tag": "고급 / 시스템 설계자",
		"badge": "고급 / 시스템 설계자",
		"color": Color(0.227, 0.278, 0.490),
		"pts": 20,
		"desc": "캐시·인덱싱·트랜잭션·분산까지,\n시스템 설계의 깊이를 탐험해요.",
		"model_scene": "res://scenes/assets/architect_island.tscn",
		"model_center": Vector3(0.28, 0.0, 0.0),
		"cam_dist": 9.2,
		"cam_pitch": 23.0,
		"cam_yaw": -28.0,
		"target_y": 1.10,
		"card_bg": Color(0.941, 0.933, 0.961),
		"border_color": Color(0.87, 0.85, 0.91)
	}
}

# INTERACTIVE PROPS & PUZZLES
var orb: MeshInstance3D
var array_tiles: Array[Node3D] = []
var array_labels: Array[Label3D] = []
var array_values: Array[int] = [7, 3, 9, 4, 1]
var array_crane: Node3D
var _crane_busy: bool = false

var list_nodes: Array[Node3D] = []
var stack_tower: Node3D
var stack_crates: Array[Node3D] = []
const STACK_CAP: int = 4
var stack_label: Label3D

const QUEUE_Z: float = 3.0
const QUEUE_START_X: float = -15.3
const QUEUE_END_X: float = -10.1
const QUEUE_CAP: int = 5
var queue_crates: Array[Node3D] = []
var queue_label: Label3D
var _queue_timer: float = 2.0

var graph_nodes: Array[Vector3] = []
var sort_columns: Array[Node3D] = []
var sort_node: Node3D
var sql_query: Node3D

# QUIZ SYSTEM
var quiz_dict: Dictionary = {}
var is_quiz_open: bool = false
var quiz_modal: Control
var quiz_zone_tag: Label
var quiz_title_lbl: Label
var quiz_question_lbl: Label
var quiz_option_btns: Array[Button] = []
var quiz_feedback_lbl: Label
var quiz_next_btn: Button
var quiz_score_lbl: Label
var current_quiz_item: Dictionary = {}
var quiz_score: int = 0
var _title_cam_angle: float = 20.0
var quiz_index: Dictionary = {}


signal world_built
var is_built: bool = false
var quality: QualityManager
var quality_btn: Button
var _loading_layer: CanvasLayer
var _loading_bar: ProgressBar
var _loading_lbl: Label

# Saved map nodes are the source of truth; procedural generation remains a fallback.
@export_storage var authored_map: bool = false
@export_storage var authored_data: Dictionary = {}
@export_storage var island_offsets: Dictionary = {}
var map_export_mode: bool = false

func _island_offset(key: String) -> Vector3:
	return island_offsets.get(key, Vector3.ZERO) if authored_map else Vector3.ZERO

func _island_center(key: String) -> Vector2:
	var offset := _island_offset(key)
	return (ISLANDS[key]["center"] as Vector2) + Vector2(offset.x, offset.z)

func _island_spawn(key: String) -> Vector3:
	var center := _island_center(key)
	return Vector3(center.x, TOP + 0.1, center.y)

func _restore_authored_map() -> void:
	for key in authored_data:
		set(key, str_to_var(authored_data[key]))
	var collections := {}
	for n in find_children("*", "", true, false):
		var bindings: Dictionary = n.get_meta("world_bindings", {})
		for key in bindings:
			var slot: int = bindings[key]
			if slot < 0:
				set(key, n)
			else:
				if not collections.has(key): collections[key] = []
				collections[key].append([slot, n])
	for key in collections:
		var entries: Array = collections[key]
		entries.sort_custom(func(a, b): return a[0] < b[0])
		var target: Array = get(key)
		target.clear()
		for entry in entries: target.append(entry[1])
	# Detect added, duplicated, moved or deleted NPCs/terminals from the saved tree.
	spawned_npcs.clear()
	computer_terminals.clear()
	computer_positions.clear()
	for n in find_children("*", "Node3D", true, false):
		if n.has_meta("npc_id"): spawned_npcs.append(n)
		if n.get_meta("world_terminal", false):
			computer_terminals.append(n)
			computer_positions.append(n.global_position)

func _ready() -> void:
	if map_export_mode:
		return
	# 그래픽 품질 관리자: 월드를 만들기 전에 최적화 단계(1~3차)를 정해야 하므로 가장 먼저 생성
	quality = QualityManager.new()
	quality.name = "QualityManager"
	add_child(quality)
	MeshKit.detail = quality.built_level
	StaticBatcher.decimate = false   # 메쉬 강제 단순화는 작은 블록(벚꽃 잎 등)이 깨져 보여서 사용 안 함
	# 최적화(체감): 월드 건설을 여러 프레임에 나눠 진행하며 로딩 화면을 표시 (멈춘 창처럼 보이지 않게)
	_show_loading()
	_build_world_async.call_deferred()

func _show_loading() -> void:
	_loading_layer = CanvasLayer.new()
	_loading_layer.layer = 110
	add_child(_loading_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.30, 0.40)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_layer.add_child(bg)
	# 로딩 배경: 7개 섬 전체 지도 일러스트 (화면을 꽉 채우고 넘치는 부분은 잘라냄)
	var art := TextureRect.new()
	art.texture = load("res://textures/loading_bg.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_layer.add_child(art)
	# 진행 표시: 화면 아래쪽 반투명 말풍선 안
	var bottom := MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -120.0
	bottom.add_theme_constant_override("margin_bottom", 36)
	_loading_layer.add_child(bottom)
	var center := CenterContainer.new()
	bottom.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _text_bubble(0.7))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(520, 0)
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	_loading_lbl = Label.new()
	_loading_lbl.text = "섬을 만드는 중..."
	_loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_lbl.add_theme_font_size_override("font_size", 18)
	v.add_child(_loading_lbl)
	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(520, 18)
	_loading_bar.show_percentage = false
	v.add_child(_loading_bar)

## 물체 위에 떠 있는 이름표(Label3D: NPC 이름, 컴퓨터 안내, 자료구조 상태 글씨 등)를 모두 숨김
func _hide_floating_labels() -> void:
	for l in find_children("*", "Label3D", true, false):
		(l as Label3D).visible = false

func _build_world_async() -> void:
	var t0 := Time.get_ticks_msec()
	var timing := []
	_loading_lbl.text = "월드 불러오는 중..."
	_loading_bar.value = 5.0
	await get_tree().process_frame
	BAKE_SCENE = "user://world_bake_L%d.scn" % quality.built_level
	BAKE_META = "user://world_bake_L%d.json" % quality.built_level
	var hash := "" if authored_map else _bake_hash()
	var baked := false
	if authored_map:
		_restore_authored_map()
		_build_player()
		_optimize()
	elif await _try_load_bake(hash):
		baked = true
		timing.append("baked_load=%dms" % (Time.get_ticks_msec() - t0))
		_build_player()
	else:
		var steps := [
			[MeshKit.ensure_textures_generated, "재질 준비"], [_build_environment, "하늘과 빛"], [_build_ocean, "바다"],
			[_build_islands, "섬 지형"], [_build_bridges, "다리"], [_build_main_island, "메인 섬"], [_build_ds_island, "자료구조 섬"],
			[_build_algo_island, "알고리즘 섬"], [_build_sql_island, "SQL 섬"], [_build_intro_island, "입문 섬"],
			[_build_data_island, "데이터 탐험 섬"], [_build_challenge_island, "종합 도전 섬"], [_build_nature, "나무와 장식"],
			[_build_orb, "수정 구슬"], [_build_computer, "컴퓨터 터미널"], [_build_npcs, "NPC"], [_build_player, "로봇"]]
		var total := steps.size() + 2
		for i in steps.size():
			_loading_lbl.text = "%s 만드는 중..." % steps[i][1]
			_loading_bar.value = 100.0 * i / total
			await get_tree().process_frame
			var ts := Time.get_ticks_usec()
			(steps[i][0] as Callable).call()
			timing.append("%s=%dms" % [(steps[i][0] as Callable).get_method(), (Time.get_ticks_usec() - ts) / 1000])
		_loading_lbl.text = "그리기 최적화 중..."
		_loading_bar.value = 100.0 * (total - 1) / total
		await get_tree().process_frame
		var tb := Time.get_ticks_usec()
		_optimize()
		timing.append("_optimize=%dms" % ((Time.get_ticks_usec() - tb) / 1000))
		_loading_lbl.text = "다음 실행을 위해 월드 저장 중..."
		await get_tree().process_frame
		var tsv := Time.get_ticks_usec()
		_save_bake(hash)
		timing.append("bake_save=%dms" % ((Time.get_ticks_usec() - tsv) / 1000))
	_configure_basics_board()
	_align_queue_crates()
	for npc in spawned_npcs:
		npc.set("look_at_target", player)
	_load_quiz_data()
	_build_hud()
	quality.apply(quality.tier, "월드 준비 완료")
	quality.tier_changed.connect(func(_t: int, why: String):
		if is_built and game_state == GameState.PLAYING:
			_show_msg("🖥 그래픽 품질: %s  (%s)" % [quality.label(), why], 3.0)
		_refresh_quality_btn())
	_refresh_quality_btn()
	_hide_floating_labels()
	for t in computer_terminals:
		var mk := t.get_node_or_null("EnterMarker") as Node3D
		if mk != null:
			_animate_marker(mk)
	if is_instance_valid(_basics_board):
		_animate_marker(_basics_board.get_node("EnterMarker"))
	_set_game_state(GameState.TITLE_LOGIN)
	_loading_layer.queue_free()
	is_built = true
	world_built.emit()
	print("NODEVERSE 7-Island World %s in %d ms" % ["loaded from bake" if baked else "built", Time.get_ticks_msec() - t0])
	if OS.is_debug_build():
		print("  build steps: ", ", ".join(timing))


# ============================================================================
# WORLD BAKE (로딩 단축): 처음 한 번 코드로 만든 월드를 user:// 에 저장해 두고, 다음 실행부터 불러옴.
# 스크립트·에셋 파일이 바뀌면 해시가 달라져 자동으로 다시 만들고 다시 저장한다.
# ============================================================================

var BAKE_SCENE := "user://world_bake.scn"
var BAKE_META := "user://world_bake.json"
const BAKE_VERSION := 1

func _bake_hash() -> String:
	var parts := PackedStringArray([str(BAKE_VERSION), "L%d" % quality.built_level])
	for dir in ["res://scripts", "res://scenes/assets", "res://scenes/npc", "res://models/props", "res://models/npc", "res://textures"]:
		_hash_dir(dir, parts)
	return "\n".join(parts).md5_text()

func _hash_dir(dir: String, out: PackedStringArray) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	var files := da.get_files()
	files.sort()
	for f in files:
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		out.append(f + ":" + FileAccess.get_md5(dir + "/" + f))
	var dirs := da.get_directories()
	dirs.sort()
	for d in dirs:
		_hash_dir(dir + "/" + d, out)

func _bake_children() -> Array[Node]:
	var out: Array[Node] = []
	for ch in get_children():
		if ch == player or ch is CanvasLayer:
			continue
		out.append(ch)
	return out

func _is_plain(v: Variant) -> bool:
	match typeof(v):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return false
		TYPE_ARRAY:
			for x in v:
				if not _is_plain(x):
					return false
		TYPE_DICTIONARY:
			for k in v:
				if not _is_plain(k) or not _is_plain(v[k]):
					return false
	return true

func _save_bake(hash: String) -> void:
	var baked := _bake_children()
	var baked_set := {}
	for n in baked:
		baked_set[n] = true
	var in_bake := func(n: Node) -> bool:
		var cur: Node = n
		while cur != null and cur != self:
			if baked_set.has(cur):
				return true
			cur = cur.get_parent()
		return false
	# 스크립트 변수: 월드 노드 참조는 경로로, 순수 데이터는 그대로 기록
	var refs := {}
	var data := {}
	for prop in get_script().get_script_property_list():
		if not (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var name: String = prop["name"]
		if name in ["player", "is_built", "game_state", "_zoom_busy", "_zoom_cam", "_zoom_terminal"] or name.begins_with("_loading"):
			continue
		var v: Variant = get(name)
		if v is Node:
			if is_instance_valid(v) and in_bake.call(v):
				refs[name] = str(get_path_to(v))
		elif typeof(v) == TYPE_ARRAY and not (v as Array).is_empty() and (v as Array).all(func(x): return x is Node):
			if (v as Array).all(func(x): return is_instance_valid(x) and in_bake.call(x)):
				refs[name] = (v as Array).map(func(x): return str(get_path_to(x)))
		elif _is_plain(v):
			data[name] = var_to_str(v)
	# 굽기용 임시 루트로 옮겨 담아 저장한 뒤 다시 제자리로
	var holder := Node3D.new()
	holder.name = "WorldBake"
	var order := []
	for n in baked:
		order.append(n.get_index())
		remove_child(n)
		holder.add_child(n)
	var stack: Array[Node] = holder.get_children()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		n.scene_file_path = ""
		n.owner = holder
		stack.append_array(n.get_children())
	var ps := PackedScene.new()
	var err := ps.pack(holder)
	if err == OK:
		err = ResourceSaver.save(ps, BAKE_SCENE, ResourceSaver.FLAG_COMPRESS)
	_clear_owner(holder)
	for n in baked:
		holder.remove_child(n)
		add_child(n)
	for i in baked.size():
		move_child(baked[i], mini(order[i], get_child_count() - 1))
	holder.free()
	if err != OK:
		push_warning("World bake save failed: " + error_string(err))
		return
	var f := FileAccess.open(BAKE_META, FileAccess.WRITE)
	f.store_string(JSON.stringify({"hash": hash, "refs": refs, "data": data}))
	f.close()

func _clear_owner(root: Node) -> void:
	var stack: Array[Node] = root.get_children()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		n.owner = null
		stack.append_array(n.get_children())

func _try_load_bake(hash: String) -> bool:
	if not FileAccess.file_exists(BAKE_META) or not FileAccess.file_exists(BAKE_SCENE):
		return false
	var meta = JSON.parse_string(FileAccess.get_file_as_string(BAKE_META))
	if typeof(meta) != TYPE_DICTIONARY or meta.get("hash", "") != hash:
		return false
	MeshKit.ensure_textures_generated()
	ResourceLoader.load_threaded_request(BAKE_SCENE)
	while ResourceLoader.load_threaded_get_status(BAKE_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var prog := []
		ResourceLoader.load_threaded_get_status(BAKE_SCENE, prog)
		if not prog.is_empty():
			_loading_bar.value = 5.0 + 85.0 * float(prog[0])
		await get_tree().process_frame
	var ps := ResourceLoader.load_threaded_get(BAKE_SCENE) as PackedScene
	if ps == null:
		return false
	_loading_lbl.text = "섬 배치 중..."
	_loading_bar.value = 92.0
	await get_tree().process_frame
	var holder := ps.instantiate()
	_clear_owner(holder)
	for n in holder.get_children():
		holder.remove_child(n)
		add_child(n)
	holder.free()
	for name in (meta["data"] as Dictionary):
		set(name, str_to_var(meta["data"][name]))
	for name in (meta["refs"] as Dictionary):
		var r: Variant = meta["refs"][name]
		if typeof(r) == TYPE_ARRAY:
			var arr: Array = get(name)
			arr.clear()
			for path in r:
				arr.append(get_node(path))
		else:
			set(name, get_node(r))
	return true

# ============================================================================
# PERFORMANCE & STATIC BATCHING
# ============================================================================

func _optimize() -> void:
	_configure_basics_board()
	var exclude: Array = [player, stack_tower, array_crane, orb, sort_node, _basics_board]
	exclude.append_array(array_tiles)
	exclude.append_array(queue_crates)
	exclude.append_array(spawned_npcs)
	exclude.append_array(computer_terminals)
	var res := StaticBatcher.batch(self, exclude)
	print("Static batching: %d mesh parts -> %d batches" % [res[0], res[1]])


# ============================================================================
# CORE HELPERS
# ============================================================================

func _spawn(asset: String, pos: Vector3, rot_y: float = 0.0, scl: float = 1.0, solid: bool = false, parent: Node = null) -> Node3D:
	var host: Node = self if parent == null else parent
	var ps: PackedScene = _scene_cache.get(asset)
	if ps == null:
		var scene_path := ASSET_DIR + asset + ".tscn"
		if ResourceLoader.exists(scene_path):
			ps = load(scene_path) as PackedScene
			if ps != null:
				_scene_cache[asset] = ps
	var n: Node3D = null
	if ps != null:
		n = ps.instantiate() as Node3D
	if n == null:
		push_warning("Missing asset: " + asset)
		n = Node3D.new()
	n.name = asset
	n.position = pos
	n.rotation_degrees = Vector3(0.0, rot_y, 0.0)
	n.scale = Vector3.ONE * scl
	host.add_child(n)
	if solid:
		_solid(n)
	return n

func _spawn_v(asset: String, pos: Vector3, rot_y: float, scl: Vector3) -> Node3D:
	var n := _spawn(asset, pos, rot_y, 1.0)
	n.scale = scl
	return n

func _local_aabb(node: Node3D) -> AABB:
	var found := false
	var box := AABB()
	var stack: Array = [[node, Transform3D.IDENTITY]]
	while stack.size() > 0:
		var item: Array = stack.pop_back()
		var cur: Node = item[0]
		var t: Transform3D = item[1]
		if cur is MeshInstance3D and (cur as MeshInstance3D).mesh != null:
			var wb: AABB = t * (cur as MeshInstance3D).mesh.get_aabb()
			box = wb if not found else box.merge(wb)
			found = true
		for ch in cur.get_children():
			if ch is Node3D:
				stack.append([ch, t * (ch as Node3D).transform])
	return box if found else AABB(Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 0.6, 0.6))

func _solid(n: Node3D, shrink: float = 0.9) -> void:
	var bb := _local_aabb(n)
	var body := StaticBody3D.new()
	body.name = "Collider"
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(bb.size.x * shrink, bb.size.y, bb.size.z * shrink)
	cs.shape = shape
	cs.position = bb.position + bb.size * 0.5
	body.add_child(cs)
	n.add_child(body)
	_reserve(Vector2(n.position.x, n.position.z), maxf(bb.size.x, bb.size.z) * n.scale.x * 0.6)

func _collider(center: Vector3, size: Vector3, rot_y: float = 0.0) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = center
	body.rotation_degrees = Vector3(0.0, rot_y, 0.0)
	add_child(body)

func _reserve(p: Vector2, r: float) -> void:
	reserved.append([p, r])

func _is_free(p: Vector2, r: float) -> bool:
	for it: Array in reserved:
		var q: Vector2 = it[0]
		if q.distance_to(p) < r + float(it[1]):
			return false
	return true

func _on_island(p: Vector2) -> bool:
	var key := Vector2i(int(floor(p.x)), int(floor(p.y)))
	for k: String in island_cells.keys():
		if (island_cells[k] as Dictionary).has(key):
			return true
	return false

func _edge_point(from: Vector2, dir: Vector2) -> Vector2:
	var p := from
	var d := dir.normalized()
	for i in range(200):
		var nx := p + d * 0.25
		if not _on_island(nx):
			return p
		p = nx
	return p

func _label3d(text: String, pos: Vector3, size: int = 40, color: Color = Color(1, 1, 1)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.005
	l.outline_size = 12
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	return l

func _path(pname: String, pts: Array, width: float = 1.4) -> void:
	WorldTerrain.paving(self, pname, pts, width, TOP)
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(a.distance_to(b) / 0.8) + 1
		for k in range(n + 1):
			_reserve(a.lerp(b, float(k) / float(n)), width * 0.5)


# ============================================================================
# ENVIRONMENT & OCEAN
# ============================================================================

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = SEA_FAR
	sky_mat.sky_horizon_color = SEA_FAR
	sky_mat.ground_horizon_color = SEA_FAR
	sky_mat.ground_bottom_color = SEA_FAR
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.65
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_hdr_threshold = 1.25
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = SEA_FAR
	env.fog_light_energy = 1.0
	env.fog_density = 0.0038
	env.fog_sky_affect = 1.0
	env.fog_aerial_perspective = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_fade_start = 0.85
	add_child(sun)
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.82, 0.98)
	fill.light_energy = 0.4
	add_child(fill)
	fill.rotation_degrees = Vector3(-35.0, 145.0, 0.0)

## 바다 스타일: 0.0 = 부드러운 파도(기본), 0.5 = 마인크래프트풍 도트 블록
const OCEAN_PIXEL_SIZE: float = 0.0

func _build_ocean() -> void:
	# 바다: 파도 셰이더 + 세분화된 평면 (그림자는 드리우지 않음 - 성능)
	var seabed := MeshInstance3D.new()
	var spm := PlaneMesh.new()
	spm.size = Vector2(OCEAN_SIZE * 1.1, OCEAN_SIZE * 1.1)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.06, 0.46, 0.55)
	smat.roughness = 0.9
	spm.material = smat
	seabed.mesh = spm
	seabed.position = Vector3(0.0, -1.2, -2.0)
	seabed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(seabed)

	var ocean := MeshInstance3D.new()
	ocean.name = "Ocean"
	var pm := PlaneMesh.new()
	pm.size = Vector2(OCEAN_SIZE, OCEAN_SIZE)
	# 파도는 셰이더가 픽셀 단위로 계산하므로 평면은 거의 나눌 필요 없음 (약 18만 → 32 삼각형)
	pm.subdivide_width = 3
	pm.subdivide_depth = 3
	var shader: Shader = load("res://shaders/ocean_water.gdshader") as Shader
	if shader != null:
		var sm := ShaderMaterial.new()
		sm.shader = shader
		sm.set_shader_parameter("pixel_size", OCEAN_PIXEL_SIZE)
		pm.material = sm
	else:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color(0.20, 0.72, 0.84)
		pm.material = fallback
	ocean.mesh = pm
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ocean.position = Vector3(0.0, WATER_Y, -2.0)
	add_child(ocean)

# ============================================================================
# 7 ISLANDS & ARCH BRIDGES (Organic WorldTerrain)
# ============================================================================

func _build_islands() -> void:
	for k: String in ISLANDS.keys():
		var def: Dictionary = ISLANDS[k]
		var cells := WorldTerrain.island_cells(def)
		island_cells[k] = cells
		WorldTerrain.build_island(self, "Island_" + k, cells, TOP, int(def["seed"]))

func _build_bridges() -> void:
	# Main <-> DS (West)
	var main_w := _edge_point(Vector2(0.0, 0.0), Vector2(-1.0, 0.0))
	var ds_e := _edge_point(Vector2(-15.5, 0.0), Vector2(1.0, 0.0))
	WorldTerrain.arch_bridge(self, "Bridge_DS", main_w + Vector2(0.4, 0.0), ds_e - Vector2(0.4, 0.0), 1.8, TOP)

	# Main <-> SQL (East)
	var main_e := _edge_point(Vector2(0.0, 0.0), Vector2(1.0, 0.0))
	var sql_w := _edge_point(Vector2(15.5, 0.0), Vector2(-1.0, 0.0))
	WorldTerrain.arch_bridge(self, "Bridge_SQL", main_e - Vector2(0.4, 0.0), sql_w + Vector2(0.4, 0.0), 1.8, TOP)

	# Main <-> ALGO (North)
	var main_n := _edge_point(Vector2(0.0, 0.0), Vector2(0.0, -1.0))
	var algo_s := _edge_point(Vector2(0.0, -14.0), Vector2(0.0, 1.0))
	WorldTerrain.arch_bridge(self, "Bridge_ALGO", main_n + Vector2(0.0, 0.4), algo_s - Vector2(0.0, 0.4), 1.8, TOP)

	# Main <-> INTRO (South-West)
	var main_sw := _edge_point(Vector2(0.0, 5.3), Vector2(-1.0, 1.0))
	var intro_ne := _edge_point(Vector2(-17.5, 17.5), Vector2(1.0, -1.0))
	WorldTerrain.arch_bridge(self, "Bridge_INTRO", main_sw, intro_ne, 1.8, TOP)

	# ALGO <-> CHALLENGE (Far North)
	var algo_n := _edge_point(Vector2(0.0, -14.0), Vector2(0.0, -1.0))
	var chal_s := _edge_point(Vector2(0.0, -32.5), Vector2(0.0, 1.0))
	WorldTerrain.arch_bridge(self, "Bridge_CHALLENGE", algo_n + Vector2(0.0, -0.4), chal_s + Vector2(0.0, 0.4), 2.2, TOP)

	# ALGO <-> DATA (North-East)
	var algo_e := _edge_point(Vector2(0.0, -14.0), Vector2(1.0, -0.3))
	var data_w := _edge_point(Vector2(23.0, -17.5), Vector2(-1.0, 0.3))
	WorldTerrain.arch_bridge(self, "Bridge_DATA_ALGO", algo_e, data_w, 1.8, TOP)

	# SQL <-> DATA
	var sql_n := _edge_point(Vector2(15.5, -1.0), Vector2(0.6, -1.0))
	var data_s := _edge_point(Vector2(23.0, -17.5), Vector2(-0.6, 1.0))
	WorldTerrain.arch_bridge(self, "Bridge_DATA_SQL", sql_n, data_s, 1.8, TOP)


# ============================================================================
# 1. MAIN ISLAND
# ============================================================================

func _build_main_island() -> void:
	_path("Path_Main_W", [Vector2(-4.5, 0.0), Vector2(-1.3, 0.0)], 1.4)
	_path("Path_Main_E", [Vector2(1.3, 0.0), Vector2(4.5, 0.0)], 1.4)
	_path("Path_Main_N", [Vector2(0.0, -2.8), Vector2(0.0, -1.2)], 1.4)
	_path("Path_Main_Beacon", [Vector2(0.0, 1.2), Vector2(0.0, 2.4)], 1.4)
	_path("Path_Main_S", [Vector2(0.0, 6.6), Vector2(0.0, 12.2)], 1.4)
	_path("Path_Main_Village", [Vector2(-2.2, 4.3), Vector2(-4.4, 4.9)], 1.0)
	_path("Path_Main_Market", [Vector2(2.2, 4.3), Vector2(4.4, 5.2)], 1.0)
	_path("Path_Main_Intro", [Vector2(-3.5, 6.5), Vector2(-6.5, 9.5)], 1.4)

	var beacon := _spawn("OBJ03_crystal_beacon", Vector3(0.0, TOP, 0.0), 0.0, 1.05, true)
	beacon.name = "CrystalBeacon"

	var plaza := _spawn("OBJ06_round_plaza", Vector3(0.0, TOP, 4.4), 0.0, 1.55)
	plaza.name = "RoundPlaza"
	_collider(Vector3(0.0, TOP + 0.25, 4.4), Vector3(4.2, 0.5, 4.2))
	_reserve(Vector2(0.0, 4.4), 2.3)

	_spawn("OBJ01_house_blue", Vector3(-5.3, TOP, 5.6), 25.0, 1.0, true)
	_spawn("OBJ02_cottage_blue", Vector3(-3.6, TOP, 2.2), 20.0, 1.0, true)
	_spawn("OBJ04_quest_board", Vector3(4.3, TOP, 2.9), -35.0, 1.0, true)
	_spawn("OBJ05_market_stall", Vector3(5.6, TOP, 6.4), -30.0, 1.0, true)
	_spawn("OBJ17_sign_main", Vector3(0.0, TOP, 8.0), 0.0, 1.0, false)
	_collider(Vector3(-0.85, TOP + 0.3, 8.0), Vector3(0.3, 0.6, 0.3))
	_collider(Vector3(0.85, TOP + 0.3, 8.0), Vector3(0.3, 0.6, 0.3))
	_reserve(Vector2(0.0, 8.0), 1.2)

	_spawn("26_fence_short", Vector3(-6.2, TOP, 7.6), 25.0)
	_spawn("27_fence_long_dark", Vector3(-3.4, TOP, 7.9), 10.0)
	_spawn("26_fence_short", Vector3(6.5, TOP, 8.4), -30.0)

	for lp: Vector3 in [Vector3(-1.1, TOP, 7.0), Vector3(1.1, TOP, 7.0), Vector3(-1.1, TOP, 10.6), Vector3(1.1, TOP, 10.6),
			Vector3(-2.6, TOP, -0.9), Vector3(2.6, TOP, -0.9)]:
		_spawn("06_lamp", lp, 0.0, 1.0, true)

	var tip := _edge_point(Vector2(0.0, 8.0), Vector2(0.0, 1.0))
	WorldTerrain.pier(self, "MainPier", Vector2(0.0, tip.y + 1.3), Vector2(2.2, 2.8), TOP - 0.05)
	_spawn("05_boat", Vector3(-2.2, WATER_Y - 0.05, tip.y + 2.0), 75.0)
	_spawn("09_crate_brown", Vector3(0.65, TOP - 0.05, tip.y + 2.1), 15.0, 0.7, true)
	_spawn("10_crate_gold_top", Vector3(0.7, TOP - 0.05, tip.y + 1.3), -10.0, 0.6, true)
	_spawn("07_torch", Vector3(-0.85, TOP - 0.05, tip.y + 2.5), 0.0, 1.0, true)


# ============================================================================
# 2. DATA STRUCTURES ISLAND
# ============================================================================

func _build_ds_island() -> void:
	_path("Path_DS_Main", [Vector2(-8.4, 0.0), Vector2(-18.2, 0.0)], 1.4)
	_path("Path_DS_List", [Vector2(-13.0, 0.0), Vector2(-13.0, -4.3)], 1.2)
	_path("Path_DS_Queue", [Vector2(-11.0, 0.0), Vector2(-11.0, 1.9)], 1.0)

	# ARRAY
	for i in range(5):
		var t := _spawn("3%d_array_tile_%d" % [i + 1, i], Vector3(-20.2, TOP, -4.0 + 1.2 * float(i)), 90.0)
		array_tiles.append(t)
		var lbl := _label3d("", Vector3(-20.0, TOP + 1.6, -4.0 + 1.2 * float(i)), 34, Color(1.0, 0.95, 0.7))
		array_labels.append(lbl)
		_collider(Vector3(-20.5, TOP + 0.5, -4.0 + 1.2 * float(i)), Vector3(0.3, 1.0, 0.9))
		_reserve(Vector2(-20.2, -4.0 + 1.2 * float(i)), 0.7)
	_refresh_array_labels(-1)
	_spawn("49_sign_array_a", Vector3(-19.0, TOP, -6.2), 20.0, 0.9, true)
	array_crane = _spawn("08_crane", Vector3(-18.4, TOP, -4.3), 30.0, 1.0, true)

	var west := _edge_point(Vector2(-17.0, 2.2), Vector2(-1.0, 0.0))
	WorldTerrain.pier(self, "HarborPier", Vector2(west.x - 1.2, 2.2), Vector2(2.6, 2.2), TOP - 0.05)
	_spawn("05_boat", Vector3(west.x - 2.0, WATER_Y - 0.05, 4.0), 20.0)
	_spawn("09_crate_brown", Vector3(west.x - 0.7, TOP - 0.05, 1.6), 10.0, 0.7, true)
	_spawn("11_crate_gold_front", Vector3(west.x - 1.5, TOP - 0.05, 1.7), -15.0, 0.7, true)
	_spawn("10_crate_gold_top", Vector3(-19.6, TOP, 3.6), 5.0, 0.8, true)

	# LIST
	var xs: Array[float] = [-15.5, -13.3, -11.1]
	for i in range(3):
		var nd := _spawn("3%d_list_node_%d0" % [7 + i, i + 1], Vector3(xs[i], TOP, -5.5), 0.0, 1.0, true)
		list_nodes.append(nd)
	_spawn_v("40_list_link_10_20", Vector3(-14.4, TOP, -5.5), 0.0, Vector3(1.9, 1.0, 1.2))
	_spawn_v("41_list_link_20_30", Vector3(-12.2, TOP, -5.5), 0.0, Vector3(1.9, 1.0, 1.2))
	_reserve(Vector2(-13.3, -5.5), 3.2)
	_spawn("51_sign_list", Vector3(-16.4, TOP, -7.0), 10.0, 0.9, true)
	_label3d("head", Vector3(-15.5, TOP + 1.2, -5.5), 32, Color(0.6, 0.95, 1.0))

	# STACK
	stack_tower = _spawn("42_stack_tower", Vector3(-17.3, TOP, 2.6), 0.0)
	_collider(Vector3(-17.3, TOP + 1.3, 2.35), Vector3(1.7, 2.6, 1.3))
	_reserve(Vector2(-17.3, 2.6), 1.4)
	for i in range(3):
		var cr: Node3D = stack_tower.get_node_or_null("StackedCrate_%d" % i) as Node3D
		if cr != null:
			stack_crates.append(cr)
	stack_label = _label3d("", Vector3(-17.3, TOP + 3.6, 2.6), 40, Color(1.0, 0.95, 0.6))
	_update_stack_label()

	# QUEUE
	var conv: Array[String] = ["43_conveyor_arrow_up", "47_conveyor_gold_plate", "44_conveyor_arrow_down_a"]
	for i in range(conv.size()):
		_spawn(conv[i], Vector3(-14.4 + 1.72 * float(i), TOP, QUEUE_Z), 90.0)
	_collider(Vector3(-12.7, TOP + 0.17, QUEUE_Z), Vector3(5.2, 0.34, 1.0))
	_reserve(Vector2(-12.7, QUEUE_Z), 1.0)
	_reserve(Vector2(-14.4, QUEUE_Z), 1.0)
	_reserve(Vector2(-11.0, QUEUE_Z), 1.0)
	var gate: Node3D = ExtraAssets.build_gantry_gate()
	gate.position = Vector3(-12.7, TOP, QUEUE_Z)
	gate.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	add_child(gate)
	_collider(Vector3(-12.7, TOP + 0.9, QUEUE_Z - 0.85), Vector3(0.35, 1.8, 0.3))
	_collider(Vector3(-12.7, TOP + 0.9, QUEUE_Z + 0.85), Vector3(0.35, 1.8, 0.3))
	_spawn("53_sign_queue", Vector3(-12.7, TOP + 2.25, QUEUE_Z), 90.0, 0.85)
	queue_label = _label3d("", Vector3(-12.7, TOP + 3.5, QUEUE_Z), 40, Color(1.0, 0.95, 0.6))
	_update_queue_label()
	for i in range(3):
		_queue_enqueue(false)
		queue_crates[queue_crates.size() - 1].position.x = QUEUE_START_X + 1.6 * float(2 - i) + 0.2

	_spawn("OBJ18_sign_ds", Vector3(-15.2, TOP, 4.6), 0.0, 1.0, true)
	for lp: Vector3 in [Vector3(-9.6, TOP, -0.9), Vector3(-13.9, TOP, -0.9), Vector3(-17.5, TOP, -0.9)]:
		_spawn("06_lamp", lp, 0.0, 1.0, true)


# ============================================================================
# 3. ALGORITHMS ISLAND
# ============================================================================

func _build_algo_island() -> void:
	_path("Path_Algo_S", [Vector2(0.0, -9.5), Vector2(0.0, -11.2)], 1.4)
	_path("Path_Algo_Hub", [Vector2(0.0, -11.2), Vector2(0.0, -14.6)], 1.6)
	_path("Path_Algo_W", [Vector2(0.0, -13.0), Vector2(-4.6, -13.0)], 1.2)
	_path("Path_Algo_E", [Vector2(0.0, -13.0), Vector2(4.6, -13.0)], 1.2)
	_path("Path_Algo_N", [Vector2(0.0, -14.6), Vector2(0.0, -18.2)], 1.4)

	# Sort Steps
	_spawn("OBJ12_sort_steps", Vector3(-4.8, TOP, -13.6), 0.0, 1.0, true)
	_spawn("OBJ20_sign_algo", Vector3(0.0, TOP, -10.0), 180.0, 1.0, false)
	_collider(Vector3(-0.85, TOP + 0.3, -10.0), Vector3(0.3, 0.6, 0.3))
	_collider(Vector3(0.85, TOP + 0.3, -10.0), Vector3(0.3, 0.6, 0.3))

	# Graph nodes (5 nodes)
	var gpos: Array[Vector3] = [
		Vector3(0.0, TOP, -14.6),
		Vector3(-2.2, TOP, -16.0),
		Vector3(2.2, TOP, -16.0),
		Vector3(-1.4, TOP, -18.0),
		Vector3(1.4, TOP, -18.0)
	]
	for p in gpos:
		_spawn("OBJ13_graph_node", p, 0.0, 0.9, true)
		graph_nodes.append(p + Vector3(0.0, 0.6, 0.0))

	# Maze garden
	_spawn("OBJ15_maze_garden", Vector3(5.2, TOP, -13.6), 0.0, 1.0, true)

	for lp: Vector3 in [Vector3(-1.3, TOP, -11.8), Vector3(1.3, TOP, -11.8), Vector3(-3.2, TOP, -13.0), Vector3(3.2, TOP, -13.0)]:
		_spawn("06_lamp", lp, 0.0, 1.0, true)


# ============================================================================
# 4. SQL ISLAND
# ============================================================================

func _build_sql_island() -> void:
	_path("Path_SQL_Main", [Vector2(8.4, 0.0), Vector2(17.5, 0.0)], 1.4)
	_path("Path_SQL_Archive", [Vector2(14.0, 0.0), Vector2(14.0, 4.0)], 1.2)
	_path("Path_SQL_Query", [Vector2(15.5, 0.0), Vector2(15.5, -4.0)], 1.2)

	_spawn("OBJ07_sql_database", Vector3(17.5, TOP, 0.0), -90.0, 1.1, true)
	_spawn("OBJ08_sql_archive", Vector3(13.6, TOP, 3.8), 20.0, 1.0, true)
	_spawn("OBJ09_sql_library", Vector3(16.8, TOP, 4.2), -30.0, 1.0, true)
	_spawn("OBJ10_sql_table", Vector3(13.5, TOP, -3.8), 10.0, 1.0, true)
	sql_query = _spawn("OBJ11_sql_query_y", Vector3(16.5, TOP, -3.8), -20.0, 1.0, true)

	_spawn("OBJ19_sign_sql", Vector3(11.2, TOP, -1.8), 90.0, 1.0, true)
	for lp: Vector3 in [Vector3(10.2, TOP, 0.9), Vector3(14.5, TOP, 0.9), Vector3(17.2, TOP, -1.8)]:
		_spawn("06_lamp", lp, 0.0, 1.0, true)


# ============================================================================
# 5. INTRO ISLAND (신규 - 기초 로직 칠판, 배움의 마법서 제단, 벚꽃 정원)
# ============================================================================

func _build_intro_island() -> void:
	var c := Vector2(-17.5, 17.5)
	_path("Path_Intro_Entry", [Vector2(-12.5, 12.5), c], 1.4)
	_path("Path_Intro_Altar", [c, c + Vector2(-2.5, 2.5)], 1.2)
	_path("Path_Intro_Board", [c, c + Vector2(2.5, 2.5)], 1.2)

	# 1. 안내 표지판 & 깃발
	# 다리 도착 지점(통로 위)에 있던 안내판을 통로 옆 잔디로 옮기고, 그 자리 주변 나무는 비움
	var sign_pos := Vector2(-12.6, 17.0)
	_spawn("OBJ41_sign_intro", Vector3(sign_pos.x, TOP, sign_pos.y), 45.0, 1.0, true)
	_reserve(sign_pos, 1.6)
	_reserve(Vector2(-13.2, 13.2), 1.6)   # 다리 착지 지점 앞 공간 확보
	_spawn("54_banner_book", Vector3(c.x - 2.8, TOP, c.y - 1.2), 30.0, 1.0, true)
	_spawn("54_banner_book", Vector3(c.x + 2.8, TOP, c.y - 1.2), -30.0, 1.0, true)

	# 2. 순서도 & 논리 칠판
	_spawn("OBJ34_logic_lesson_board", Vector3(c.x + 2.4, TOP, c.y + 2.0), -25.0, 1.0, true)

	# 3. 배움의 제단 & 벤치 & 벚꽃나무
	_spawn("OBJ33_open_book_altar", Vector3(c.x, TOP, c.y + 0.5), 0.0, 1.1, true)
	_spawn("OBJ02_cottage_blue", Vector3(c.x - 3.5, TOP, c.y + 2.2), 35.0, 0.9, true)
	_spawn("56_tree_blossom", Vector3(c.x - 1.8, TOP, c.y + 3.6), 0.0, 1.1)
	_spawn("56_tree_blossom", Vector3(c.x + 3.6, TOP, c.y + 3.2), 40.0, 1.0)
	_spawn("21_tree_short", Vector3(c.x, TOP, c.y + 4.2), 0.0, 1.0)

	for lp: Vector3 in [Vector3(c.x - 1.2, TOP, c.y - 2.0), Vector3(c.x + 1.2, TOP, c.y - 2.0)]:
		_spawn("06_lamp", lp, 0.0, 1.0, true)


# ============================================================================
# 6. DATA EXPLORATION ISLAND (신규 - 수목 전망대, 나침반 파빌리온, 히스토그램)
# ============================================================================

func _build_data_island() -> void:
	var c := Vector2(23.0, -17.5)
	_path("Path_Data_W", [c - Vector2(5.5, 0.0), c], 1.4)
	_path("Path_Data_N", [c, c + Vector2(0.0, -3.5)], 1.2)
	_path("Path_Data_S", [c, c + Vector2(0.0, 3.5)], 1.2)

	# 1. 표지판 및 탐험 나침반 (중앙)
	_spawn("OBJ42_sign_exploration", Vector3(c.x - 3.2, TOP, c.y - 2.5), 45.0, 1.0, true)
	_spawn("OBJ38_exploration_compass", Vector3(c.x, TOP, c.y), 0.0, 1.1, true)

	# 2. 데이터 트리 수목 전망대 (북동)
	_spawn("OBJ35_data_tree_observatory", Vector3(c.x + 3.5, TOP, c.y - 2.5), -35.0, 1.0, true)

	# 3. 히스토그램 & 네트워크 디스플레이 (남쪽)
	_spawn("OBJ36_histogram_display", Vector3(c.x - 2.8, TOP, c.y + 2.8), 20.0, 1.0, true)
	_spawn("OBJ37_network_display", Vector3(c.x + 2.8, TOP, c.y + 2.8), -20.0, 1.0, true)

	# 4. 이색 판타지 숲 (보라/호박/사이프러스)
	_spawn("57_tree_violet", Vector3(c.x + 4.2, TOP, c.y + 2.0), 15.0, 1.0)
	_spawn("58_tree_amber", Vector3(c.x - 3.8, TOP, c.y - 2.8), -20.0, 1.0)
	_spawn("59_cypress", Vector3(c.x + 2.0, TOP, c.y + 4.2), 0.0, 1.1)

	for lp: Vector3 in [Vector3(c.x - 2.0, TOP, c.y), Vector3(c.x + 2.0, TOP, c.y)]:
		_spawn("06_lamp", lp, 0.0, 1.0, true)


# ============================================================================
# 7. GRAND CHALLENGE ISLAND (신규 - 정상 판테온, 트로피 제단, 열주 회랑)
# ============================================================================

func _build_challenge_island() -> void:
	var c := Vector2(0.0, -32.5)
	_path("Path_Chal_Main", [c + Vector2(0.0, 6.0), c + Vector2(0.0, -2.0)], 1.6)
	_path("Path_Chal_Colonnade_L", [c + Vector2(-2.4, 4.0), c + Vector2(-2.4, -1.0)], 1.0)
	_path("Path_Chal_Colonnade_R", [c + Vector2(2.4, 4.0), c + Vector2(2.4, -1.0)], 1.0)

	# 1. 표지판 및 기둥 파빌리온 신전 (중앙)
	_spawn("OBJ43_sign_challenge", Vector3(c.x - 3.2, TOP, c.y + 4.2), 30.0, 1.0, true)
	_spawn("OBJ40_column_pavilion", Vector3(c.x, TOP, c.y - 1.5), 0.0, 1.15, true)

	# 2. 크리스탈 천체 전망대 제단
	_spawn("OBJ39_crystal_observatory", Vector3(c.x, TOP + 0.1, c.y - 1.5), 0.0, 1.0, true)

	# 4. 트로피 깃발 & 황동 난간
	_spawn("55_banner_trophy", Vector3(c.x - 1.8, TOP, c.y + 4.5), 20.0, 1.0, true)
	_spawn("55_banner_trophy", Vector3(c.x + 1.8, TOP, c.y + 4.5), -20.0, 1.0, true)
	_spawn("61_stone_brass_balustrade", Vector3(c.x, TOP, c.y + 5.5), 0.0, 1.0)

	for lp: Vector3 in [Vector3(c.x - 1.8, TOP, c.y + 2.0), Vector3(c.x + 1.8, TOP, c.y + 2.0)]:
		_spawn("06_lamp", lp, 0.0, 1.0, true)


# ============================================================================
# NATURE VEGETATION & WATER DECOR (7 Islands Organic Harmony)
# ============================================================================

func _build_nature() -> void:
	var kinds: Array[String] = ["21_tree_short", "22_tree_tall", "21_tree_short", "56_tree_blossom"]
	for k: String in island_cells.keys():
		var cells: Dictionary = island_cells[k]
		for key: Vector2i in cells.keys():
			var p := Vector2(float(key.x) + 0.5, float(key.y) + 0.5)
			var h := MeshKit._hash_float(key.x, key.y, 97)
			var rim := 0
			for d: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				if not cells.has(key + d):
					rim += 1
			var chance := 0.60 if rim > 0 else 0.12
			if h > chance:
				continue
			if not _is_free(p, 0.65):
				continue
			var kind := kinds[int(MeshKit._hash_float(key.x, key.y, 5) * 4.0) % 4]
			var s := 0.75 + MeshKit._hash_float(key.y, key.x, 9) * 0.4
			_spawn(kind, Vector3(p.x, TOP, p.y), h * 360.0, s)
			_collider(Vector3(p.x, TOP + 0.6, p.y), Vector3(0.35, 1.2, 0.35))
			_reserve(p, 0.65)

	# Water decor: lily pads, rocks, water lilies
	var deco: Array[String] = ["18_lily_pad_top", "19_lily_pad_pair", "20_lily_flower"]
	var n := 0
	for k: String in ISLANDS.keys():
		var def: Dictionary = ISLANDS[k]
		var c: Vector2 = def["center"]
		for i in range(12):
			var ang := TAU * (float(i) + MeshKit._hash_float(i, n, 3)) / 12.0
			var r := Vector2(cos(ang) * (float(def["rx"]) + 1.4), sin(ang) * (float(def["rz"]) + 1.4))
			var p := c + r
			if _on_island(p):
				continue
			if i % 3 == 0:
				_spawn("16_rocks", Vector3(p.x, -0.25, p.y), ang * 57.0, 0.6)
			else:
				_spawn(deco[i % 3], Vector3(p.x, WATER_Y, p.y), ang * 80.0, 1.0)
		n += 1


# ============================================================================
# COMPUTER TERMINAL (2D MINI-GAME) & NPC SYSTEMS
# ============================================================================

func _build_computer() -> void:
	computer_terminals.clear()
	for i in range(computer_positions.size()):
		var cpos: Vector3 = computer_positions[i]
		var term := BuilderComputer.build_computer()
		term.name = "ComputerTerminal_%d" % i
		term.position = cpos
		term.rotation_degrees.y = -45.0 if i == 1 else 0.0
		add_child(term)
		StaticBatcher.merge_children(term)   # 최적화: 책상·모니터 부품 38개 → 재질별 몇 덩어리
		term.add_child(_make_enter_marker())
		computer_terminals.append(term)
		_collider(cpos + Vector3(0.0, 0.45, 0.0), Vector3(1.5, 0.9, 0.95))

# ---------- 컴퓨터 화면 줌인 / 줌아웃 연출 ----------
const SCREEN_LOCAL := Vector3(-0.12, 1.01, 0.145)   # builder_computer.gd 의 MonScreen 중심 (터미널 로컬)
const SCREEN_GLOW := Color(0.62, 0.93, 1.0)
var _zoom_busy: bool = false
var _zoom_cam: Camera3D
var _zoom_terminal: Node3D

func _nearest_terminal() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for t in computer_terminals:
		var d := player.global_position.distance_to(t.global_position) if player != null else 0.0
		if d < best_d:
			best_d = d
			best = t
	return best

## 화면 바로 앞에서 화면을 정면으로 보는 카메라 자세
func _screen_pose(term: Node3D, dist: float) -> Transform3D:
	var center: Vector3 = term.to_global(SCREEN_LOCAL)
	var normal: Vector3 = term.global_transform.basis.z.normalized()
	var eye: Vector3 = center + normal * dist
	return Transform3D(Basis.IDENTITY, eye).looking_at(center, Vector3.UP)

func _tween_cam(cam: Camera3D, from: Transform3D, to: Transform3D, fov_from: float, fov_to: float, dur: float) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float) -> void:
		cam.global_transform = from.interpolate_with(to, k)
		cam.fov = lerpf(fov_from, fov_to, k), 0.0, 1.0, dur)
	await tw.finished

func _glow_overlay(start_alpha: float) -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 120
	var rect := ColorRect.new()
	rect.color = Color(SCREEN_GLOW, start_alpha)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	return rect

func _set_guide_label(v: bool) -> void:
	if _zoom_terminal != null:
		var g := _zoom_terminal.get_node_or_null("GuideLabel")
		if g != null:
			g.visible = v and false   # 떠 있는 글자는 숨김 유지
		var mk := _zoom_terminal.get_node_or_null("EnterMarker")
		if mk != null:
			mk.visible = v

## 컴퓨터 위 "여기로 들어가요" 표시: 아래를 가리키는 노란 화살표 (빛나는 재질, 위아래로 통통 + 천천히 회전)
func _make_enter_marker() -> Node3D:
	var root := Node3D.new()
	root.name = "EnterMarker"
	root.position = Vector3(-0.12, 1.75, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.18)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.72, 0.1)
	mat.emission_energy_multiplier = 1.6
	mat.roughness = 0.4
	var shaft := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.12, 0.26, 0.12)
	shaft.mesh = sm
	shaft.position.y = 0.2
	shaft.material_override = mat
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shaft)
	var head := MeshInstance3D.new()
	var cm := CylinderMesh.new()   # 아래로 뾰족한 4각뿔 (블록 스타일)
	cm.top_radius = 0.24
	cm.bottom_radius = 0.0
	cm.height = 0.26
	cm.radial_segments = 4
	cm.rings = 1
	head.mesh = cm
	head.material_override = mat
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(head)
	return root

func _animate_marker(root: Node3D) -> void:
	var base_y := root.position.y
	var tw := root.create_tween().set_loops()
	tw.tween_property(root, "position:y", base_y + 0.2, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(root, "position:y", base_y, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var spin := root.create_tween().set_loops()
	spin.tween_property(root, "rotation:y", TAU, 3.0).from(0.0)

func _open_computer_game() -> void:
	if _zoom_busy:
		return
	var terminal := _nearest_terminal()
	if is_instance_valid(terminal):
		var quiz_zone: String = terminal.get_meta("quiz_zone", "")
		if not quiz_zone.is_empty():
			_open_quiz_for_zone(quiz_zone)
			return
	_zoom_busy = true
	if player != null:
		saved_player_pos = player.global_position
		saved_cam_yaw = player.cam_yaw
		player.velocity = Vector3.ZERO
		player.set("can_move", false)
	if msg_label != null:
		msg_label.text = ""
	_zoom_terminal = _nearest_terminal()
	var pcam: Camera3D = player.get("cam") if player != null else null
	if _zoom_terminal != null and pcam != null:
		if hud_root != null:
			hud_root.visible = false
		_set_guide_label(false)
		_zoom_cam = Camera3D.new()
		_zoom_cam.name = "ComputerZoomCam"
		add_child(_zoom_cam)
		_zoom_cam.global_transform = pcam.global_transform
		_zoom_cam.fov = pcam.fov
		_zoom_cam.current = true
		# 1) 화면 앞으로 다가가기 → 2) 화면에 바짝 붙기 (빛 번짐)
		await _tween_cam(_zoom_cam, pcam.global_transform, _screen_pose(_zoom_terminal, 0.9), pcam.fov, 55.0, 0.9)
		var glow := _glow_overlay(0.0)
		var tw := create_tween()
		tw.tween_property(glow, "color:a", 1.0, 0.35)
		await _tween_cam(_zoom_cam, _screen_pose(_zoom_terminal, 0.9), _screen_pose(_zoom_terminal, 0.32), 55.0, 40.0, 0.35)
		_switch_to_2d()
		# 2D 메뉴 위에서 빛이 걷히며 등장
		var tw2 := glow.create_tween()
		tw2.tween_property(glow, "color:a", 0.0, 0.45)
		tw2.tween_callback(glow.get_parent().queue_free)
	else:
		_switch_to_2d()
	_zoom_busy = false

func _switch_to_2d() -> void:
	var tree := get_tree()
	var root := tree.root
	var menu: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	cached_world = self
	root.remove_child(self)
	root.add_child(menu)
	tree.current_scene = menu
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = GAME_2D_SIZE

static func return_from_2d(tree: SceneTree) -> bool:
	if cached_world == null or not is_instance_valid(cached_world):
		cached_world = null
		return false
	var world: Node = cached_world
	cached_world = null
	var root := tree.root
	# 3D 월드 UI 도 기준 해상도(1280x720) 기준으로 창 크기에 맞춰 확대·축소 (project.godot 설정과 동일)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = GAME_2D_SIZE
	var old := tree.current_scene
	if old != null and old != world:
		old.queue_free()
	root.add_child(world)
	tree.current_scene = world
	world.call("_on_returned_from_2d")
	return true

func _on_returned_from_2d() -> void:
	if player != null:
		if saved_player_pos != Vector3.ZERO:
			player.teleport_to(saved_player_pos)
		player.set("tour_mode", false)
		player.set("can_move", false)
	_set_game_state(GameState.PLAYING)
	var pcam: Camera3D = player.get("cam") if player != null else null
	if _zoom_cam != null and is_instance_valid(_zoom_cam) and _zoom_terminal != null and pcam != null:
		# 화면 속에서 빠져나오듯 줌아웃
		if hud_root != null:
			hud_root.visible = false
		_zoom_cam.current = true
		var glow := _glow_overlay(1.0)
		var tw := create_tween()
		tw.tween_property(glow, "color:a", 0.0, 0.4)
		tw.tween_callback(glow.get_parent().queue_free)
		await get_tree().process_frame
		await _tween_cam(_zoom_cam, _screen_pose(_zoom_terminal, 0.32), pcam.global_transform, 40.0, pcam.fov, 1.0)
		pcam.current = true
		_zoom_cam.queue_free()
		_zoom_cam = null
		_set_guide_label(true)
		if hud_root != null:
			hud_root.visible = true
	elif pcam != null:
		pcam.current = true
	if player != null:
		player.set("can_move", true)
	_show_msg("💻 3D 월드로 복귀했습니다", 2.5)

func _build_npcs() -> void:
	for def: Dictionary in NPC_DEFS:
		var scene_path: String = "res://scenes/npc/%s.tscn" % def["id"]
		var ps: PackedScene = _scene_cache.get(scene_path)
		if ps == null and ResourceLoader.exists(scene_path):
			ps = load(scene_path) as PackedScene
			if ps != null:
				_scene_cache[scene_path] = ps
		if ps == null:
			push_warning("NPC scene not found: " + scene_path)
			continue
		var npc := ps.instantiate() as Node3D
		npc.name = def["id"]
		npc.position = def["pos"]
		npc.rotation_degrees.y = def["rot"]
		npc.set_meta("npc_id", def["id"])
		npc.set_meta("npc_name", def["name"])
		npc.set_meta("dialog", def["dialog"])
		add_child(npc)
		spawned_npcs.append(npc)
		_reserve(Vector2((def["pos"] as Vector3).x, (def["pos"] as Vector3).z), 0.8)

func _talk_to_npc(npc: Node3D) -> void:
	var d: String = npc.get_meta("dialog", "")
	if d == "":
		return
	var pages: Array = []
	for line in d.split("\n"):
		var t := line.strip_edges()
		var colon := t.find(": ")
		if pages.is_empty() and colon > 0 and colon < 16:
			t = t.substr(colon + 2)   # "배열 관리자: ..." 처럼 앞에 붙은 이름은 이름표로 보여 주므로 뺌
		if t != "":
			pages.append(t)
	var nid: String = String(npc.get_meta("npc_id", npc.name)).left(5)
	_open_npc_dialog(String(npc.get_meta("npc_name", "NPC")), load("res://textures/npc_portraits/%s_portrait.png" % nid), pages)

# ---------- NPC 대화창 (화면 하단: 초상화 + 이름표 + 말풍선) ----------
var npc_dlg: Control
var npc_dlg_portrait: TextureRect
var npc_dlg_name: Label
var npc_dlg_text: Label
var npc_dlg_more: Label
var _dlg_pages: Array = []
var _dlg_page := 0
var _dlg_tween: Tween
var _last_interact_frame := -1

func _build_npc_dialog(canvas: CanvasLayer) -> void:
	npc_dlg = Control.new()
	npc_dlg.name = "NpcDialog"
	npc_dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
	npc_dlg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	npc_dlg.visible = false
	canvas.add_child(npc_dlg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.25)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	npc_dlg.add_child(dim)
	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 40.0
	box.offset_right = -40.0
	box.offset_top = -232.0
	box.offset_bottom = -28.0
	box.add_theme_constant_override("separation", 14)
	npc_dlg.add_child(box)
	# 초상화
	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", _style_panel_flat(Color(0.98, 0.95, 0.88), Color(0.55, 0.42, 0.25), 16, 6, 6, 3))
	pp.custom_minimum_size = Vector2(204, 204)
	npc_dlg_portrait = TextureRect.new()
	npc_dlg_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	npc_dlg_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pp.add_child(npc_dlg_portrait)
	box.add_child(pp)
	# 말풍선
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", -6)
	box.add_child(right)
	var name_row := HBoxContainer.new()
	right.add_child(name_row)
	var np := PanelContainer.new()
	np.add_theme_stylebox_override("panel", _style_panel_flat(Color(0.18, 0.37, 0.70), Color(0.10, 0.20, 0.40), 10, 14, 4, 2))
	npc_dlg_name = Label.new()
	npc_dlg_name.add_theme_font_size_override("font_size", 20)
	npc_dlg_name.add_theme_color_override("font_color", Color.WHITE)
	np.add_child(npc_dlg_name)
	name_row.add_child(np)
	np.z_index = 1
	var bubble := PanelContainer.new()
	bubble.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bubble.add_theme_stylebox_override("panel", _style_panel_flat(Color(0.99, 0.97, 0.92, 0.97), Color(0.55, 0.42, 0.25), 18, 26, 18, 3))
	right.add_child(bubble)
	var tv := VBoxContainer.new()
	bubble.add_child(tv)
	npc_dlg_text = Label.new()
	npc_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	npc_dlg_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	npc_dlg_text.add_theme_font_size_override("font_size", 23)
	npc_dlg_text.add_theme_color_override("font_color", Color(0.12, 0.11, 0.16))
	tv.add_child(npc_dlg_text)
	npc_dlg_more = Label.new()
	npc_dlg_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	npc_dlg_more.add_theme_font_size_override("font_size", 16)
	npc_dlg_more.add_theme_color_override("font_color", Color(0.18, 0.37, 0.70))
	tv.add_child(npc_dlg_more)

func npc_dialog_open() -> bool:
	return npc_dlg != null and npc_dlg.visible

func _open_npc_dialog(speaker: String, portrait: Texture2D, pages: Array) -> void:
	if pages.is_empty() or npc_dlg == null:
		return
	_dlg_pages = pages
	_dlg_page = 0
	npc_dlg_name.text = speaker
	npc_dlg_portrait.texture = portrait
	npc_dlg.visible = true
	npc_dlg.modulate.a = 0.0
	create_tween().tween_property(npc_dlg, "modulate:a", 1.0, 0.18)
	if player != null:
		player.velocity = Vector3.ZERO
		player.set("can_move", false)
	if prompt_label != null:
		prompt_label.visible = false
	_show_dlg_page()

func _show_dlg_page() -> void:
	npc_dlg_text.text = _dlg_pages[_dlg_page]
	npc_dlg_text.visible_ratio = 0.0
	var last := _dlg_page >= _dlg_pages.size() - 1
	npc_dlg_more.text = ("%d / %d   " % [_dlg_page + 1, _dlg_pages.size()]) + ("▶ E / Space 닫기" if last else "▼ E / Space 다음")
	if _dlg_tween:
		_dlg_tween.kill()
	_dlg_tween = create_tween()
	_dlg_tween.tween_property(npc_dlg_text, "visible_ratio", 1.0, maxf(0.25, npc_dlg_text.text.length() * 0.03))

func _advance_npc_dialog() -> void:
	if npc_dlg_text.visible_ratio < 1.0:
		if _dlg_tween:
			_dlg_tween.kill()
		npc_dlg_text.visible_ratio = 1.0
		return
	if _dlg_page < _dlg_pages.size() - 1:
		_dlg_page += 1
		_show_dlg_page()
	else:
		_close_npc_dialog()

func _close_npc_dialog() -> void:
	if _dlg_tween:
		_dlg_tween.kill()
	npc_dlg.visible = false
	if player != null:
		player.set("can_move", true)
	if prompt_label != null:
		prompt_label.visible = true


# ============================================================================
# PLAYER & ORB
# ============================================================================

func _build_orb() -> void:
	orb = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.16
	sph.height = 0.32
	sph.material = MeshKit.mat_emissive("world_orb", Color(0.3, 0.95, 1.0), Color(0.15, 0.85, 1.0), 4.0, 0.1)
	orb.mesh = sph
	orb.visible = false
	add_child(orb)

func _build_player() -> void:
	var spawn := Vector3(0.0, 1.08, 12.15)
	var spawn_marker := find_child("PlayerSpawn", true, false) as Marker3D
	if spawn_marker != null:
		spawn = spawn_marker.global_position
	player = PlayerRobot.new()
	player.name = "Robot"
	add_child(player)
	player.global_position = spawn
	player.set("spawn_point", spawn)
	player.set("last_safe", spawn)
	player.connect("interact_pressed", Callable(self, "_on_interact"))
	player.connect("secondary_pressed", Callable(self, "_on_secondary"))
	player.connect("fell_in_water", Callable(self, "_on_fell"))

func _safe_saved_player_position(position: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.27
	capsule.height = 1.08
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, position + Vector3(0, 0.58, 0))
	query.exclude = [player.get_rid()]
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(query).is_empty(): return false
	var ray := PhysicsRayQueryParameters3D.create(position + Vector3(0, 0.15, 0), position - Vector3(0, 1.5, 0))
	ray.exclude = [player.get_rid()]
	return not space.intersect_ray(ray).is_empty()


# ============================================================================
# HUD, CAMERA DEBUG & LOCK PANEL, AND MODALS
# ============================================================================

func _build_hud() -> void:
	ui_canvas = CanvasLayer.new()
	ui_canvas.name = "GameUI"
	add_child(ui_canvas)

	hud_root = Control.new()
	hud_root.name = "HUDRoot"
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_canvas.add_child(hud_root)

	_build_ingame_hud(ui_canvas)
	_build_camera_debug_panel(ui_canvas)
	_build_title_modal(ui_canvas)
	_build_lobby_modal(ui_canvas)
	_build_pause_modal(ui_canvas)
	_build_quiz_modal(ui_canvas)
	_build_npc_dialog(ui_canvas)
	_basics_guide = BasicsGuide.new()
	_basics_guide.name = "BasicsGuide"
	ui_canvas.add_child(_basics_guide)
	_basics_guide.closed.connect(_on_basics_closed)

func _configure_basics_board() -> void:
	if not is_instance_valid(_basics_board):
		for node in find_children("*", "Node3D", true, false):
			if node.get_meta("world_basics_board", false) or node.name == "OBJ04_quest_board":
				_basics_board = node
				break
	if is_instance_valid(_basics_board) and not _basics_board.has_node("EnterMarker"):
		var marker := _make_enter_marker()
		marker.position = Vector3(0, 2.15, 0)
		_basics_board.add_child(marker)

func _basics_open() -> bool:
	return is_instance_valid(_basics_guide) and _basics_guide.visible

func _near_basics_board() -> bool:
	return is_instance_valid(_basics_board) and player != null and player.global_position.distance_to(_basics_board.global_position) < BOARD_INTERACT_DIST

func _open_basics_board() -> void:
	if _basics_guide == null: return
	player.velocity = Vector3.ZERO
	player.can_move = false
	prompt_label.visible = false
	_basics_guide.open()

func _on_basics_closed(completed: bool) -> void:
	_basics_completed = _basics_completed or completed
	if player != null:
		player.can_move = game_state == GameState.PLAYING and not is_quiz_open
	if completed:
		_show_msg("📖 기본 안내를 마쳤습니다! 입문 섬에서 탐험을 시작해 보세요.", 4.0)

func _build_ingame_hud(canvas: CanvasLayer) -> void:
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 24.0
	vb.offset_top = 16.0
	vb.offset_right = -24.0
	vb.offset_bottom = -16.0
	hud_root.add_child(vb)

	# Top row: Zone label + Profile badge + Camera Debug button
	var top_h := HBoxContainer.new()
	top_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top_h)

	zone_label = _hud_label(26)
	top_h.add_child(zone_label)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_h.add_child(top_spacer)

	# Camera Debug toggle button (Top Right)
	cam_debug_btn = Button.new()
	cam_debug_btn.text = "📷 카메라 디버그 (F4)"
	cam_debug_btn.custom_minimum_size = Vector2(170, 36)
	_apply_btn_styles_g(cam_debug_btn, Color(0.12, 0.16, 0.24, 0.85), Color(0.20, 0.28, 0.40, 0.95), Color.WHITE, 14)
	cam_debug_btn.pressed.connect(func(): cam_debug_panel.visible = not cam_debug_panel.visible)
	top_h.add_child(cam_debug_btn)

	# Profile pill
	profile_pill = PanelContainer.new()
	profile_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_panel_g(profile_pill, Color(0.08, 0.12, 0.18, 0.85), Color(0.35, 0.45, 0.60, 0.7), 18, 8)
	top_h.add_child(profile_pill)

	var pill_h := HBoxContainer.new()
	profile_pill.add_child(pill_h)
	profile_lbl = Label.new()
	profile_lbl.text = "👤 GUEST"
	profile_lbl.modulate = Color.WHITE
	pill_h.add_child(profile_lbl)

	diff_badge_lbl = Label.new()
	diff_badge_lbl.text = " [NOVICE] "
	diff_badge_lbl.modulate = Color(0.4, 0.9, 0.7)
	pill_h.add_child(diff_badge_lbl)

	score_badge_lbl = Label.new()
	score_badge_lbl.text = "★ 0 PTS"
	score_badge_lbl.modulate = Color(1.0, 0.85, 0.3)
	pill_h.add_child(score_badge_lbl)

	msg_label = _hud_label(22)
	msg_label.modulate = Color(1.0, 0.95, 0.6)
	vb.add_child(msg_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(spacer)

	prompt_label = _hud_label(22)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prompt_label.modulate = Color(1.0, 1.0, 1.0)
	vb.add_child(prompt_label)

	fps_label = _hud_label(15)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.visible = false
	vb.add_child(fps_label)

	help_label = _hud_label(15)
	help_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	help_label.text = "WASD/방향키: 이동  |  Space: 점프  |  Shift: 달리기  |  E: 상호작용/컴퓨터(2D게임)/대화  |  1~7: 섬 빠른이동  |  F4: 카메라 디버거  |  Tab: 가이드 토글"
	vb.add_child(help_label)

func _hud_label(size: int) -> Label:
	var l := Label.new()
	l.theme_type_variation = "HeaderLarge"
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.95))
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_stylebox_override("normal", _text_bubble())
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return l

## 배경 위 글자가 묻히지 않도록 반투명 말풍선 배경
func _text_bubble(alpha: float = 0.62) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.12, alpha)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 5
	sb.content_margin_bottom = 6
	return sb

## 비어 있는 HUD 글자는 말풍선째 숨김
func _sync_hud_bubbles() -> void:
	for l in [zone_label, msg_label, prompt_label]:
		if l != null:
			(l as Label).visible = (l as Label).text.strip_edges() != ""
	if npc_dialog_open() or _basics_open():
		if prompt_label != null: prompt_label.visible = false
		if help_label != null: help_label.modulate.a = 0.0
	elif help_label != null:
		help_label.modulate.a = 1.0

func _show_msg(t: String, secs: float) -> void:
	if msg_label != null:
		msg_label.text = t
		_msg_time = secs

func _refresh_profile_pill() -> void:
	if profile_lbl == null:
		return
	profile_lbl.text = "👤 %s" % (current_user if current_user != "" else "GUEST")
	var cfg: Dictionary = DIFFICULTY_CONFIG.get(current_difficulty, DIFFICULTY_CONFIG["NOVICE"])
	diff_badge_lbl.text = " [%s] " % cfg["title"]
	diff_badge_lbl.modulate = cfg["color"].lightened(0.35)
	score_badge_lbl.text = "★ %d PTS" % quiz_score


# ============================================================================
# CAMERA DEBUG & LOCK PANEL (Real-time tuning, presets, and saving)
# ============================================================================

func _build_camera_debug_panel(canvas: CanvasLayer) -> void:
	cam_debug_panel = PanelContainer.new()
	cam_debug_panel.name = "CameraDebugPanel"
	cam_debug_panel.visible = false
	_style_panel_g(cam_debug_panel, Color(0.06, 0.09, 0.14, 0.92), Color(0.28, 0.45, 0.70, 0.85), 14, 14)
	canvas.add_child(cam_debug_panel)

	cam_debug_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cam_debug_panel.offset_left = -380.0
	cam_debug_panel.offset_top = 60.0
	cam_debug_panel.offset_right = -20.0
	cam_debug_panel.offset_bottom = 540.0
	cam_debug_panel.custom_minimum_size = Vector2(360, 480)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	cam_debug_panel.add_child(vb)

	# Header
	var h_box := HBoxContainer.new()
	vb.add_child(h_box)
	var title := Label.new()
	title.text = "📷 카메라 뷰 튜닝 & 시점 고정"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_box.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	_apply_btn_styles_g(close_btn, Color(0.3, 0.1, 0.1, 0.8), Color(0.5, 0.1, 0.1, 0.9), Color.WHITE, 12)
	close_btn.pressed.connect(func(): cam_debug_panel.visible = false)
	h_box.add_child(close_btn)

	# Info readout
	cam_info_lbl = Label.new()
	cam_info_lbl.text = "Pitch: 36.0° | Yaw: 20.0° | Dist: 14.0m"
	cam_info_lbl.add_theme_font_size_override("font_size", 13)
	cam_info_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	vb.add_child(cam_info_lbl)

	# Lock View Checkbox
	cam_lock_check = CheckBox.new()
	cam_lock_check.text = "🔒 카메라 시점 완전 고정 (마우스 회전 방지)"
	cam_lock_check.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35))
	cam_lock_check.toggled.connect(func(v: bool):
		if player != null:
			player.set("is_camera_locked", v)
			_show_msg("카메라 시점 고정: %s" % ("ON (회전 방지)" if v else "OFF (자유 회전)"), 2.0)
	)
	vb.add_child(cam_lock_check)

	# Sliders
	cam_pitch_slider = _add_slider(vb, "Pitch (상하 각도)", 10.0, 85.0, 36.0, func(v: float):
		if player != null and not _updating_cam_ui:
			player.set("cam_pitch", v)
	)

	cam_yaw_slider = _add_slider(vb, "Yaw (좌우 회전)", -180.0, 180.0, 20.0, func(v: float):
		if player != null and not _updating_cam_ui:
			player.set("cam_yaw", v)
	)

	cam_dist_slider = _add_slider(vb, "Distance (거리)", 4.0, 50.0, 14.0, func(v: float):
		if player != null and not _updating_cam_ui:
			player.set("cam_dist", v)
	)

	cam_fov_slider = _add_slider(vb, "FOV (화각)", 20.0, 75.0, 38.0, func(v: float):
		if player != null and not _updating_cam_ui:
			var cam: Camera3D = player.get("cam")
			if cam != null: cam.fov = v
	)

	cam_height_slider = _add_slider(vb, "Height Offset (높이)", 0.0, 2.5, 0.6, func(v: float):
		if player != null and not _updating_cam_ui:
			player.set("cam_height_offset", v)
	)

	# Presets
	var preset_lbl := Label.new()
	preset_lbl.text = "⚡ 원클릭 시점 프리셋:"
	preset_lbl.add_theme_font_size_override("font_size", 13)
	vb.add_child(preset_lbl)

	var p_grid := GridContainer.new()
	p_grid.columns = 2
	vb.add_child(p_grid)

	_add_preset_btn(p_grid, "쿼터뷰 45°", 35.0, 45.0, 14.0, 38.0, 0.6)
	_add_preset_btn(p_grid, "아이소메트릭", 30.0, 45.0, 18.0, 30.0, 0.6)
	_add_preset_btn(p_grid, "탑다운 75°", 72.0, 0.0, 20.0, 36.0, 0.8)
	_add_preset_btn(p_grid, "시네마틱 24°", 24.0, 25.0, 8.5, 42.0, 0.5)

	# Save & Copy Buttons
	var btn_row := HBoxContainer.new()
	vb.add_child(btn_row)

	var save_btn := Button.new()
	save_btn.text = "💾 설정 저장 (Save)"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_btn_styles_g(save_btn, Color(0.12, 0.45, 0.28), Color(0.18, 0.60, 0.38), Color.WHITE, 13)
	save_btn.pressed.connect(_on_save_camera_settings)
	btn_row.add_child(save_btn)

	var copy_btn := Button.new()
	copy_btn.text = "📋 코드 복사"
	copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_btn_styles_g(copy_btn, Color(0.20, 0.30, 0.50), Color(0.28, 0.42, 0.68), Color.WHITE, 13)
	copy_btn.pressed.connect(_on_copy_camera_code)
	btn_row.add_child(copy_btn)

func _add_slider(parent: VBoxContainer, label_text: String, min_v: float, max_v: float, def_v: float, cb: Callable) -> HSlider:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	h.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.value = def_v
	slider.step = 0.5
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(cb)
	h.add_child(slider)
	return slider

func _add_preset_btn(parent: Control, name_str: String, pitch: float, yaw: float, dist: float, fov: float, h_offset: float) -> void:
	var btn := Button.new()
	btn.text = name_str
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_btn_styles_g(btn, Color(0.14, 0.20, 0.30), Color(0.22, 0.32, 0.48), Color.WHITE, 12)
	btn.pressed.connect(func():
		if player != null:
			player.set("cam_pitch", pitch)
			player.set("cam_yaw", yaw)
			player.set("cam_dist", dist)
			player.set("cam_height_offset", h_offset)
			var c: Camera3D = player.get("cam")
			if c != null: c.fov = fov
			_sync_cam_debug_ui()
			_show_msg("카메라 프리셋 적용: %s" % name_str, 1.8)
	)
	parent.add_child(btn)

func _sync_cam_debug_ui() -> void:
	if player == null or cam_debug_panel == null or not cam_debug_panel.visible:
		return
	_updating_cam_ui = true
	var p: float = player.get("cam_pitch")
	var y: float = player.get("cam_yaw")
	var d: float = player.get("cam_dist")
	var h_off: float = player.get("cam_height_offset")
	var locked: bool = player.get("is_camera_locked")
	var cam: Camera3D = player.get("cam")
	var fov: float = cam.fov if cam != null else 38.0

	cam_info_lbl.text = "Pitch: %.1f° | Yaw: %.1f° | Dist: %.1fm | FOV: %.0f°" % [p, y, d, fov]
	cam_pitch_slider.value = p
	cam_yaw_slider.value = y
	cam_dist_slider.value = d
	cam_fov_slider.value = fov
	cam_height_slider.value = h_off
	cam_lock_check.button_pressed = locked
	_updating_cam_ui = false

func _on_save_camera_settings() -> void:
	if player == null:
		return
	var res: Dictionary = player.call("save_camera_settings")
	_show_msg("💾 카메라 설정이 영구 저장되었습니다! (Pitch:%.1f, Yaw:%.1f, Dist:%.1f)" % [res.get("pitch", 0.0), res.get("yaw", 0.0), res.get("dist", 0.0)], 3.0)

func _on_copy_camera_code() -> void:
	if player == null:
		return
	var p: float = player.get("cam_pitch")
	var y: float = player.get("cam_yaw")
	var d: float = player.get("cam_dist")
	var h: float = player.get("cam_height_offset")
	var l: bool = player.get("is_camera_locked")
	var cam: Camera3D = player.get("cam")
	var fov: float = cam.fov if cam != null else 38.0
	var snippet := "cam_pitch = %.1f\ncam_yaw = %.1f\ncam_dist = %.1f\ncam.fov = %.1f\ncam_height_offset = %.1f\nis_camera_locked = %s" % [p, y, d, fov, h, str(l).to_lower()]
	DisplayServer.clipboard_set(snippet)
	_show_msg("📋 카메라 세팅 GDScript 코드가 클립보드에 복사되었습니다!\n%s" % snippet, 4.0)


# ============================================================================
# TITLE / LOBBY / PAUSE / QUIZ MODALS (Seamless Integration)
# ============================================================================

func _style_panel_g(p: PanelContainer, bg: Color, border: Color, radius: int = 14, pad: int = 16) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	p.add_theme_stylebox_override("panel", sb)

func _apply_btn_styles_g(btn: Button, bg: Color, hover_bg: Color, text_col: Color = Color.WHITE, font_sz: int = 14) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.set_corner_radius_all(8)
	var hover := StyleBoxFlat.new()
	hover.bg_color = hover_bg
	hover.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_font_size_override("font_size", font_sz)












# ============================================================================
# QUIZ SYSTEM
# ============================================================================







# ============================================================================
# TITLE / LOBBY / PAUSE / QUIZ UI (JUNBOM 버전에서 병합)
# ============================================================================

func _style_panel(bg: Color, border: Color, radius: int = 14, pad: int = 24) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = border
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = pad
	sb.content_margin_top = pad
	sb.content_margin_right = pad
	sb.content_margin_bottom = pad
	return sb

func _apply_btn_styles(btn: Button, bg: Color, hover_bg: Color, text_col: Color, border_col: Color = Color.TRANSPARENT, radius: int = 10, border_w: int = 0) -> void:
	var sb_normal := _style_btn(bg, border_col, radius, border_w)
	var sb_hover := _style_btn(hover_bg, border_col, radius, border_w)
	var sb_pressed := _style_btn(hover_bg.darkened(0.12), border_col, radius, border_w)
	var sb_disabled := _style_btn(Color(0.85, 0.88, 0.86), Color(0.80, 0.83, 0.81), radius, border_w)
	var sb_focus := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("disabled", sb_disabled)
	btn.add_theme_stylebox_override("focus", sb_focus)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_disabled_color", Color(0.60, 0.65, 0.63))

func _style_panel_flat(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 14, pad_h: int = 24, pad_v: int = 24, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = border_w
	sb.border_width_top = border_w
	sb.border_width_right = border_w
	sb.border_width_bottom = border_w
	sb.border_color = border
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb

func _style_btn(bg: Color, border_col: Color = Color.TRANSPARENT, radius: int = 10, border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border_col
	sb.border_width_left = border_w
	sb.border_width_top = border_w
	sb.border_width_right = border_w
	sb.border_width_bottom = border_w
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	return sb

func _style_input(border_col: Color = Color(0.85, 0.82, 0.77), border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.border_color = border_col
	sb.border_width_left = border_w
	sb.border_width_top = border_w
	sb.border_width_right = border_w
	sb.border_width_bottom = border_w
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _create_interactive_3d_card(
	scene_path: String,
	center_offset: Vector3,
	view_size: Vector2i,
	bg_color: Color,
	border_color: Color,
	cam_dist: float = 5.8,
	cam_pitch: float = 22.0,
	cam_yaw: float = -32.0,
	btn_text: String = "3D 보기",
	target_y: float = 0.85
) -> Control:
	var container := PanelContainer.new()
	container.clip_contents = true
	container.custom_minimum_size = Vector2(view_size.x, view_size.y)
	container.add_theme_stylebox_override("panel", _style_panel_flat(bg_color, border_color, 14, 0, 0, 1))

	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(svc)

	var vp := SubViewport.new()
	vp.size = view_size
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(vp)

	var world_root := Node3D.new()
	vp.add_child(world_root)

	var ps: PackedScene = load(scene_path) as PackedScene
	if ps != null:
		var model: Node3D = ps.instantiate() as Node3D
		if model != null:
			model.position = -center_offset
			world_root.add_child(model)

	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, target_y, 0.0)
	world_root.add_child(pivot)
	var init_rot := Vector3(-cam_pitch, cam_yaw, 0.0)
	pivot.rotation_degrees = init_rot
	_preview_pivots.append(pivot)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.0, cam_dist)
	cam.fov = 32.0
	pivot.add_child(cam)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.light_energy = 1.35
	sun.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	world_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.65, 0.85, 1.0)
	fill.light_energy = 0.55
	fill.rotation_degrees = Vector3(30.0, 140.0, 0.0)
	world_root.add_child(fill)

	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.86, 0.92)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world_root.add_child(we)

	# Interactive mouse drag & wheel zoom
	var drag_state := {"down": false}
	svc.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
				drag_state["down"] = mb.pressed
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				if is_instance_valid(cam):
					cam.position.z = maxf(4.0, cam.position.z * 0.92)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				if is_instance_valid(cam):
					cam.position.z = minf(25.0, cam.position.z * 1.08)
		elif event is InputEventMouseMotion and drag_state["down"]:
			var mm := event as InputEventMouseMotion
			if is_instance_valid(pivot):
				pivot.rotation_degrees.y -= mm.relative.x * 0.45
				pivot.rotation_degrees.x = clampf(pivot.rotation_degrees.x - mm.relative.y * 0.3, -55.0, -10.0)
	)

	# Bottom-right button overlay
	var overlay := MarginContainer.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_constant_override("margin_right", 10)
	overlay.add_theme_constant_override("margin_bottom", 10)
	container.add_child(overlay)

	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_END
	overlay.add_child(btn_box)

	var btn_v := VBoxContainer.new()
	btn_v.alignment = BoxContainer.ALIGNMENT_END
	btn_box.add_child(btn_v)

	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(66, 26)
	btn.add_theme_font_size_override("font_size", 11)
	_apply_btn_styles(btn, Color(0.937, 0.925, 0.886), Color(0.894, 0.878, 0.831), Color(0.431, 0.392, 0.329), Color(0.847, 0.808, 0.722), 8, 1)
	btn.pressed.connect(func():
		if is_instance_valid(pivot):
			pivot.rotation_degrees = init_rot
		if is_instance_valid(cam):
			cam.position = Vector3(0.0, 0.0, cam_dist)
	)
	btn_v.add_child(btn)

	return container

func _refresh_title_inputs() -> void:
	if auth_user_edit != null:
		var last_u: String = AuthManager.get_last_user()
		if not last_u.is_empty():
			auth_user_edit.text = last_u
			if auth_pass_edit != null:
				auth_pass_edit.grab_focus()
		else:
			auth_user_edit.grab_focus()

func _refresh_lobby_ui() -> void:
	if welcome_lbl != null:
		welcome_lbl.text = "환영합니다, %s 님!" % (current_user if not current_user.is_empty() else "모험가")

	var has_save: bool = bool(user_save_data.get("has_saved_game", false))
	if continue_btn != null:
		continue_btn.disabled = not has_save
		if has_save:
			_apply_btn_styles(continue_btn,
				Color(0.102, 0.455, 0.510),
				Color(0.125, 0.545, 0.612),
				Color.WHITE, Color.TRANSPARENT, 8
			)
		else:
			_apply_btn_styles(continue_btn,
				Color(0.85, 0.88, 0.86),
				Color(0.85, 0.88, 0.86),
				Color(0.60, 0.65, 0.63),
				Color.TRANSPARENT, 8
			)
	if continue_info_lbl != null:
		if has_save:
			var d: String = str(user_save_data.get("difficulty", "NOVICE"))
			var s: int = int(user_save_data.get("score", 0))
			var z: String = str(user_save_data.get("zone", "MAIN"))
			continue_info_lbl.text = "%s  ·  %d점  ·  최근 탐험: %s" % [d, s, z]
			continue_info_lbl.add_theme_color_override("font_color", Color(0.353, 0.471, 0.447))
		else:
			continue_info_lbl.text = "(저장된 이전 여정이 없습니다. 아래에서 난이도를 선택해 새로운 모험을 시작하세요)"
			continue_info_lbl.add_theme_color_override("font_color", Color(0.55, 0.60, 0.58))

func _on_logout() -> void:
	_save_current_state()
	current_user = ""
	user_save_data = {}
	if auth_pass_edit != null:
		auth_pass_edit.text = ""
	_set_game_state(GameState.TITLE_LOGIN)

func _refresh_pause_menu_ui() -> void:
	if pause_info_lbl != null:
		pause_info_lbl.text = "플레이어: %s | 난이도: [%s] | 점수: %d점" % [
			current_user if not current_user.is_empty() else "Guest",
			current_difficulty,
			quiz_score
		]

func _save_current_state() -> void:
	if current_user.is_empty():
		return
	var pp: Vector3 = player.global_position if player != null else Vector3(0.0, 0.55, 1.6)
	user_save_data["difficulty"] = current_difficulty
	user_save_data["score"] = quiz_score
	user_save_data["player_pos"] = [pp.x, pp.y, pp.z]
	user_save_data["zone"] = _zone_name
	user_save_data["has_saved_game"] = true
	AuthManager.save_user_progress(current_user, user_save_data)

func _display_current_quiz(zone_tag: String, cur_num: int, total_num: int) -> void:
	var cfg: Dictionary = DIFFICULTY_CONFIG.get(current_difficulty, DIFFICULTY_CONFIG["NOVICE"])
	quiz_zone_tag.text = "🎯 [%s 퀴즈 - %s] (문제 %d / %d)" % [zone_tag, current_difficulty, cur_num, total_num]
	quiz_zone_tag.modulate = cfg.get("color", Color.CYAN)
	quiz_score_lbl.text = "점수: %d점" % quiz_score
	quiz_title_lbl.text = str(current_quiz_item.get("title", ""))
	quiz_question_lbl.text = str(current_quiz_item.get("question", ""))
	quiz_feedback_lbl.text = "보기를 클릭하여 정답을 맞춰보세요! (정답 시 +%d점)" % int(cfg.get("pts", 10))
	quiz_feedback_lbl.modulate = Color(0.7, 0.85, 0.95)
	quiz_next_btn.visible = false

	var opts: Array = current_quiz_item.get("options", [])
	for i in range(quiz_option_btns.size()):
		if i < opts.size():
			quiz_option_btns[i].text = "   " + str(opts[i])
			quiz_option_btns[i].visible = true
			quiz_option_btns[i].disabled = false
			quiz_option_btns[i].modulate = Color.WHITE
		else:
			quiz_option_btns[i].visible = false

func _next_quiz() -> void:
	var q_key: String = str(current_quiz_item.get("zone", "STACK")).to_upper()
	if not quiz_dict.has(q_key): q_key = "STACK"
	var target_diff: String = current_difficulty.to_lower()
	var state_key: String = q_key + "_" + target_diff
	quiz_index[state_key] = quiz_index.get(state_key, 0) + 1
	_open_quiz_for_zone(_zone_name)

func _build_title_modal(canvas: CanvasLayer) -> void:
	title_modal = Control.new()
	title_modal.name = "TitleModal"
	title_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(title_modal)

	# [1. 상단 중앙 타이틀: NODEVERSE / 연결된 배움의 세계]
	var top_header := VBoxContainer.new()
	top_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_header.offset_top = 28.0
	top_header.offset_bottom = 125.0
	top_header.add_theme_constant_override("separation", 6)
	top_header.alignment = BoxContainer.ALIGNMENT_CENTER
	top_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_modal.add_child(top_header)

	var title_lbl := Label.new()
	title_lbl.text = "NODEVERSE"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 54)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.04, 0.16, 0.22, 0.92))
	title_lbl.add_theme_constant_override("shadow_offset_y", 4)
	title_lbl.add_theme_constant_override("shadow_outline_size", 5)
	top_header.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "연결된 배움의 세계"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 19)
	sub_lbl.add_theme_color_override("font_color", Color(0.88, 0.96, 0.98))
	sub_lbl.add_theme_color_override("font_shadow_color", Color(0.04, 0.16, 0.22, 0.80))
	sub_lbl.add_theme_constant_override("shadow_offset_y", 2)
	top_header.add_child(sub_lbl)

	# [2. 우측 아이보리 로그인/회원가입 폼 카드 (사이즈 세로 축소: 높이 430px)]
	var right_card := PanelContainer.new()
	right_card.anchor_left = 1.0
	right_card.anchor_right = 1.0
	right_card.anchor_top = 0.5
	right_card.anchor_bottom = 0.5
	var card_w: float = 380.0
	var card_h: float = 430.0
	right_card.offset_right = -44.0
	right_card.offset_left = -44.0 - card_w
	right_card.offset_top = -card_h * 0.5 + 20.0
	right_card.offset_bottom = card_h * 0.5 + 20.0
	right_card.custom_minimum_size = Vector2(card_w, card_h)
	right_card.add_theme_stylebox_override("panel", _style_panel_flat(
		Color(0.985, 0.972, 0.938), # 따뜻하고 고급스러운 아이보리 #fbf8ef
		Color(0.88, 0.84, 0.77),     # 은은한 테두리
		18, 22, 18, 1
	))
	title_modal.add_child(right_card)

	var form_vb := VBoxContainer.new()
	form_vb.add_theme_constant_override("separation", 8)
	right_card.add_child(form_vb)

	var f_title := Label.new()
	f_title.text = "모험을 시작해 볼까요?"
	f_title.add_theme_font_size_override("font_size", 20)
	f_title.add_theme_color_override("font_color", Color(0.118, 0.208, 0.220)) # #1e3538
	form_vb.add_child(f_title)

	var f_sub := Label.new()
	f_sub.text = "나만의 여정을 저장하고 이어가세요."
	f_sub.add_theme_font_size_override("font_size", 12.5)
	f_sub.add_theme_color_override("font_color", Color(0.43, 0.50, 0.51)) # #6e7f82
	form_vb.add_child(f_sub)

	# 탭 바 (로그인 / 회원가입)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	form_vb.add_child(tab_row)

	auth_tab_login_btn = Button.new()
	auth_tab_login_btn.text = "로그인"
	auth_tab_login_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auth_tab_login_btn.custom_minimum_size = Vector2(0, 32)
	auth_tab_login_btn.add_theme_font_size_override("font_size", 13.0)
	auth_tab_login_btn.pressed.connect(func(): _switch_auth_tab(false))
	tab_row.add_child(auth_tab_login_btn)

	auth_tab_register_btn = Button.new()
	auth_tab_register_btn.text = "회원가입"
	auth_tab_register_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auth_tab_register_btn.custom_minimum_size = Vector2(0, 32)
	auth_tab_register_btn.add_theme_font_size_override("font_size", 13.0)
	auth_tab_register_btn.pressed.connect(func(): _switch_auth_tab(true))
	tab_row.add_child(auth_tab_register_btn)

	# 아이디 입력 필드
	var u_box := VBoxContainer.new()
	u_box.add_theme_constant_override("separation", 3)
	form_vb.add_child(u_box)

	var u_lbl := Label.new()
	u_lbl.text = "아이디"
	u_lbl.add_theme_font_size_override("font_size", 12.5)
	u_lbl.add_theme_color_override("font_color", Color(0.18, 0.24, 0.25))
	u_box.add_child(u_lbl)

	auth_user_edit = LineEdit.new()
	auth_user_edit.placeholder_text = "아이디를 입력하세요 (2글자 이상)"
	auth_user_edit.custom_minimum_size = Vector2(0, 34)
	auth_user_edit.add_theme_font_size_override("font_size", 13.5)
	auth_user_edit.add_theme_stylebox_override("normal", _style_input())
	auth_user_edit.add_theme_stylebox_override("focus", _style_input(Color(0.102, 0.455, 0.510), 2))
	auth_user_edit.add_theme_color_override("font_color", Color(0.13, 0.17, 0.18))
	auth_user_edit.add_theme_color_override("font_placeholder_color", Color(0.62, 0.65, 0.65))
	u_box.add_child(auth_user_edit)

	# 비밀번호 입력 필드
	var p_box := VBoxContainer.new()
	p_box.add_theme_constant_override("separation", 3)
	form_vb.add_child(p_box)

	var p_lbl := Label.new()
	p_lbl.text = "비밀번호"
	p_lbl.add_theme_font_size_override("font_size", 12.5)
	p_lbl.add_theme_color_override("font_color", Color(0.18, 0.24, 0.25))
	p_box.add_child(p_lbl)

	auth_pass_edit = LineEdit.new()
	auth_pass_edit.placeholder_text = "비밀번호를 입력하세요 (3글자 이상)"
	auth_pass_edit.secret = true
	auth_pass_edit.custom_minimum_size = Vector2(0, 34)
	auth_pass_edit.add_theme_font_size_override("font_size", 13.5)
	auth_pass_edit.add_theme_stylebox_override("normal", _style_input())
	auth_pass_edit.add_theme_stylebox_override("focus", _style_input(Color(0.102, 0.455, 0.510), 2))
	auth_pass_edit.add_theme_color_override("font_color", Color(0.13, 0.17, 0.18))
	auth_pass_edit.add_theme_color_override("font_placeholder_color", Color(0.62, 0.65, 0.65))
	auth_pass_edit.text_submitted.connect(func(_t): _on_auth_submit())
	p_box.add_child(auth_pass_edit)

	# 비밀번호 보기 스위치
	var show_pass_row := HBoxContainer.new()
	form_vb.add_child(show_pass_row)

	var sp_lbl := Label.new()
	sp_lbl.text = "비밀번호 보기"
	sp_lbl.add_theme_font_size_override("font_size", 12.0)
	sp_lbl.add_theme_color_override("font_color", Color(0.33, 0.40, 0.41))
	show_pass_row.add_child(sp_lbl)

	var sp_spacer := Control.new()
	sp_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	show_pass_row.add_child(sp_spacer)

	pass_toggle_btn = Button.new()
	pass_toggle_btn.custom_minimum_size = Vector2(40, 20)
	pass_toggle_btn.toggle_mode = true
	pass_toggle_btn.focus_mode = Control.FOCUS_NONE
	var knob := Panel.new()
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.custom_minimum_size = Vector2(12, 12)
	var knob_sb := StyleBoxFlat.new()
	knob_sb.bg_color = Color.WHITE
	knob_sb.corner_radius_top_left = 6
	knob_sb.corner_radius_top_right = 6
	knob_sb.corner_radius_bottom_left = 6
	knob_sb.corner_radius_bottom_right = 6
	knob.add_theme_stylebox_override("panel", knob_sb)
	knob.position = Vector2(4, 4)
	pass_toggle_btn.add_child(knob)

	var update_switch := func(is_on: bool):
		var track_col := Color(0.102, 0.455, 0.510) if is_on else Color(0.824, 0.796, 0.729)
		var track_sb := StyleBoxFlat.new()
		track_sb.bg_color = track_col
		track_sb.corner_radius_top_left = 10
		track_sb.corner_radius_top_right = 10
		track_sb.corner_radius_bottom_left = 10
		track_sb.corner_radius_bottom_right = 10
		pass_toggle_btn.add_theme_stylebox_override("normal", track_sb)
		pass_toggle_btn.add_theme_stylebox_override("hover", track_sb)
		pass_toggle_btn.add_theme_stylebox_override("pressed", track_sb)
		knob.position = Vector2(24, 4) if is_on else Vector2(4, 4)

	update_switch.call(false)
	pass_toggle_btn.toggled.connect(func(toggled_on: bool):
		auth_pass_edit.secret = not toggled_on
		update_switch.call(toggled_on)
	)
	show_pass_row.add_child(pass_toggle_btn)

	# 안내/피드백 라벨
	auth_feedback_lbl = Label.new()
	auth_feedback_lbl.text = "등록된 계정으로 로그인하세요."
	auth_feedback_lbl.add_theme_font_size_override("font_size", 11.5)
	auth_feedback_lbl.add_theme_color_override("font_color", Color(0.48, 0.52, 0.52))
	form_vb.add_child(auth_feedback_lbl)

	# 메인 제출 버튼 (로그인하고 탐험하기 →)
	auth_submit_btn = Button.new()
	auth_submit_btn.text = "로그인하고 탐험하기  →"
	auth_submit_btn.custom_minimum_size = Vector2(0, 38)
	auth_submit_btn.add_theme_font_size_override("font_size", 14.0)
	_apply_btn_styles(auth_submit_btn,
		Color(0.102, 0.455, 0.510), # #1a7482
		Color(0.125, 0.545, 0.612), # #208b9c
		Color.WHITE, Color.TRANSPARENT, 10
	)
	auth_submit_btn.pressed.connect(func(): _on_auth_submit())
	form_vb.add_child(auth_submit_btn)

	# 보조 버튼 (게스트로 바로 시작)
	var guest_btn := Button.new()
	guest_btn.text = "게스트로 바로 시작"
	guest_btn.custom_minimum_size = Vector2(0, 34)
	guest_btn.add_theme_font_size_override("font_size", 13.0)
	_apply_btn_styles(guest_btn,
		Color(0.929, 0.906, 0.843), # #ede7d7
		Color(0.894, 0.867, 0.796),
		Color(0.133, 0.267, 0.278),
		Color(0.827, 0.784, 0.706), 10, 1
	)
	guest_btn.pressed.connect(func(): _on_guest_login())
	form_vb.add_child(guest_btn)

	# [3. 좌측 하단 월드 투어 정보 오버레이 (일시정지 버튼 없이 순수 정보만 깔끔하게 표시)]
	var tour_hud := VBoxContainer.new()
	tour_hud.anchor_left = 0.0
	tour_hud.anchor_right = 0.0
	tour_hud.anchor_top = 1.0
	tour_hud.anchor_bottom = 1.0
	tour_hud.offset_left = 44.0
	tour_hud.offset_bottom = -28.0
	tour_hud.offset_top = -112.0
	tour_hud.offset_right = 520.0
	tour_hud.add_theme_constant_override("separation", 4)
	title_modal.add_child(tour_hud)

	tour_title_lbl = Label.new()
	tour_title_lbl.text = "메인 섬 · 모든 모험이 시작되는 곳"
	tour_title_lbl.add_theme_font_size_override("font_size", 18)
	tour_title_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	tour_title_lbl.add_theme_color_override("font_shadow_color", Color(0.04, 0.16, 0.22, 0.85))
	tour_title_lbl.add_theme_constant_override("shadow_offset_y", 2)
	tour_title_lbl.add_theme_stylebox_override("normal", _text_bubble(0.55))
	tour_title_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tour_hud.add_child(tour_title_lbl)

	tour_sub_lbl = Label.new()
	tour_sub_lbl.text = "WORLD TOUR / 섬을 둘러보며 모험을 준비하세요"
	tour_sub_lbl.add_theme_font_size_override("font_size", 13.0)
	tour_sub_lbl.add_theme_color_override("font_color", Color(0.82, 0.94, 0.96))
	tour_sub_lbl.add_theme_color_override("font_shadow_color", Color(0.04, 0.16, 0.22, 0.70))
	tour_sub_lbl.add_theme_constant_override("shadow_offset_y", 1)
	tour_sub_lbl.add_theme_stylebox_override("normal", _text_bubble(0.5))
	tour_sub_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tour_hud.add_child(tour_sub_lbl)

	_switch_auth_tab(false)

func _switch_auth_tab(register_mode: bool) -> void:
	auth_is_register_mode = register_mode
	if auth_is_register_mode:
		_apply_btn_styles(auth_tab_login_btn, Color(0.929, 0.902, 0.839), Color(0.902, 0.871, 0.804), Color(0.494, 0.463, 0.404), Color(0.871, 0.835, 0.761), 10, 1)
		_apply_btn_styles(auth_tab_register_btn, Color(0.980, 0.969, 0.937), Color(0.980, 0.969, 0.937), Color(0.118, 0.231, 0.243), Color(0.784, 0.749, 0.671), 10, 2)
		auth_submit_btn.text = "회원가입하고 탐험하기  →"
		auth_feedback_lbl.text = "새로운 아이디와 비밀번호를 입력해 가입하세요."
		auth_feedback_lbl.add_theme_color_override("font_color", Color(0.48, 0.52, 0.52))
	else:
		_apply_btn_styles(auth_tab_login_btn, Color(0.980, 0.969, 0.937), Color(0.980, 0.969, 0.937), Color(0.118, 0.231, 0.243), Color(0.784, 0.749, 0.671), 10, 2)
		_apply_btn_styles(auth_tab_register_btn, Color(0.929, 0.902, 0.839), Color(0.902, 0.871, 0.804), Color(0.494, 0.463, 0.404), Color(0.871, 0.835, 0.761), 10, 1)
		auth_submit_btn.text = "로그인하고 탐험하기  →"
		auth_feedback_lbl.text = "등록된 계정으로 로그인하세요."
		auth_feedback_lbl.add_theme_color_override("font_color", Color(0.48, 0.52, 0.52))

func _on_auth_submit() -> void:
	var u := auth_user_edit.text.strip_edges()
	var p := auth_pass_edit.text.strip_edges()
	if auth_is_register_mode:
		var res: Dictionary = AuthManager.register(u, p)
		if res.get("success", false):
			auth_feedback_lbl.text = "🎉 " + str(res.get("message", ""))
			auth_feedback_lbl.add_theme_color_override("font_color", Color(0.15, 0.65, 0.35))
			_on_login_success(u, {"difficulty": "NOVICE", "score": 0, "has_saved_game": false})
		else:
			auth_feedback_lbl.text = "❌ " + str(res.get("message", ""))
			auth_feedback_lbl.add_theme_color_override("font_color", Color(0.85, 0.25, 0.25))
	else:
		var res: Dictionary = AuthManager.login(u, p)
		if res.get("success", false):
			auth_feedback_lbl.text = "🎉 " + str(res.get("message", ""))
			auth_feedback_lbl.add_theme_color_override("font_color", Color(0.15, 0.65, 0.35))
			_on_login_success(u, res.get("save_data", {}))
		else:
			auth_feedback_lbl.text = "❌ " + str(res.get("message", ""))
			auth_feedback_lbl.add_theme_color_override("font_color", Color(0.85, 0.25, 0.25))

func _on_guest_login() -> void:
	var res: Dictionary = AuthManager.guest_login()
	_on_login_success(res.get("username", "Guest"), res.get("save_data", {}))

func _on_login_success(username: String, save_data: Dictionary) -> void:
	current_user = username
	user_save_data = save_data
	current_difficulty = str(save_data.get("difficulty", "NOVICE"))
	quiz_score = int(save_data.get("score", 0))
	_set_game_state(GameState.DIFFICULTY_SELECT)

func _build_lobby_modal(canvas: CanvasLayer) -> void:
	lobby_modal = Control.new()
	lobby_modal.name = "LobbyModal"
	lobby_modal.visible = false
	lobby_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(lobby_modal)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.08, 0.12, 0.45)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lobby_modal.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lobby_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1040, 640)
	panel.add_theme_stylebox_override("panel", _style_panel_flat(
		Color(0.985, 0.973, 0.941, 0.98), # #fbf8f0
		Color(0.86, 0.82, 0.75),            # #dcd2bf
		24, 28, 28, 2
	))
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	# 1. 상단 헤더 행 (좌: 브레드크럼 + 환영 타이틀 / 우: 로그아웃 버튼)
	var top_row := HBoxContainer.new()
	vb.add_child(top_row)

	var title_v := VBoxContainer.new()
	title_v.add_theme_constant_override("separation", 3)
	top_row.add_child(title_v)

	var breadcrumb := Label.new()
	breadcrumb.text = "NODEVERSE / 여정 선택"
	breadcrumb.add_theme_font_size_override("font_size", 12.5)
	breadcrumb.add_theme_color_override("font_color", Color(0.098, 0.482, 0.533)) # #197b88
	title_v.add_child(breadcrumb)

	welcome_lbl = Label.new()
	welcome_lbl.text = "환영합니다, 모험가 님!"
	welcome_lbl.add_theme_font_size_override("font_size", 24)
	welcome_lbl.add_theme_color_override("font_color", Color(0.106, 0.188, 0.204)) # #1b3034
	title_v.add_child(welcome_lbl)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_spacer)

	var logout_btn := Button.new()
	logout_btn.text = "로그아웃"
	logout_btn.custom_minimum_size = Vector2(96, 36)
	logout_btn.add_theme_font_size_override("font_size", 13.5)
	_apply_btn_styles(logout_btn,
		Color(0.929, 0.906, 0.843), # #ede7d7
		Color(0.894, 0.867, 0.796),
		Color(0.227, 0.259, 0.267),
		Color(0.816, 0.776, 0.698), 10, 1.5
	)
	logout_btn.pressed.connect(func(): _on_logout())
	top_row.add_child(logout_btn)

	# 2. [이전 여정 이어하기] 민트-크림 배너
	var continue_panel := PanelContainer.new()
	continue_panel.add_theme_stylebox_override("panel", _style_panel_flat(
		Color(0.91, 0.945, 0.925), # #e8f1ec
		Color(0.78, 0.86, 0.81),     # #c7dcce
		12, 18, 12, 1
	))
	vb.add_child(continue_panel)

	var cont_row := HBoxContainer.new()
	cont_row.add_theme_constant_override("separation", 16)
	continue_panel.add_child(cont_row)

	var cont_v := VBoxContainer.new()
	cont_v.add_theme_constant_override("separation", 2)
	cont_row.add_child(cont_v)

	var cont_t := Label.new()
	cont_t.text = "이전 여정 이어하기"
	cont_t.add_theme_font_size_override("font_size", 14.5)
	cont_t.add_theme_color_override("font_color", Color(0.110, 0.243, 0.227)) # #1c3e3a
	cont_v.add_child(cont_t)

	continue_info_lbl = Label.new()
	continue_info_lbl.text = "ARCHITECT · 40점 · 최근 탐험: MAIN"
	continue_info_lbl.add_theme_font_size_override("font_size", 12.5)
	continue_info_lbl.add_theme_color_override("font_color", Color(0.353, 0.471, 0.447)) # #5a7872
	cont_v.add_child(continue_info_lbl)

	var cont_spacer := Control.new()
	cont_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cont_row.add_child(cont_spacer)

	continue_btn = Button.new()
	continue_btn.text = "이어서 탐험  →"
	continue_btn.custom_minimum_size = Vector2(120, 38)
	continue_btn.add_theme_font_size_override("font_size", 13.5)
	_apply_btn_styles(continue_btn,
		Color(0.102, 0.455, 0.510),
		Color(0.125, 0.545, 0.612),
		Color.WHITE, Color.TRANSPARENT, 8
	)
	continue_btn.pressed.connect(func(): _on_continue_game())
	cont_row.add_child(continue_btn)

	# 3. 섹션 타이틀
	var sec_title := Label.new()
	sec_title.text = "나에게 맞는 탐험 난이도를 선택하세요"
	sec_title.add_theme_font_size_override("font_size", 18)
	sec_title.add_theme_color_override("font_color", Color(0.106, 0.188, 0.204))
	vb.add_child(sec_title)

	# 4. 3개 난이도 카드 행 (NOVICE, DEVELOPER, ARCHITECT)
	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 16)
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(cards_row)

	for diff_key: String in ["NOVICE", "DEVELOPER", "ARCHITECT"]:
		var cfg: Dictionary = DIFFICULTY_CONFIG[diff_key]
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _style_panel_flat(
			Color.WHITE,
			Color(0.871, 0.835, 0.761), # #ded5c2
			16, 16, 16, 1
		))
		cards_row.add_child(card)

		var cvb := VBoxContainer.new()
		cvb.add_theme_constant_override("separation", 10)
		card.add_child(cvb)

		# 태그 (초급 / 모험가 등)
		var tag_lbl := Label.new()
		tag_lbl.text = str(cfg.get("tag", ""))
		tag_lbl.add_theme_font_size_override("font_size", 12)
		tag_lbl.add_theme_color_override("font_color", Color(0.424, 0.510, 0.486))
		cvb.add_child(tag_lbl)

		# 난이도 명칭 (NOVICE, DEVELOPER, ARCHITECT)
		var title_lbl := Label.new()
		title_lbl.text = str(cfg["title"])
		title_lbl.add_theme_font_size_override("font_size", 22)
		title_lbl.add_theme_color_override("font_color", cfg["color"])
		cvb.add_child(title_lbl)

		# 3D 뷰포트 프리뷰 (novice_island, developer_island, architect_island)
		var preview_card := _create_interactive_3d_card(
			str(cfg["model_scene"]),
			cfg["model_center"],
			Vector2i(270, 185),
			cfg["card_bg"],
			cfg["border_color"],
			float(cfg.get("cam_dist", 5.8)),
			float(cfg.get("cam_pitch", 22.0)),
			float(cfg.get("cam_yaw", -32.0)),
			"3D 보기",
			float(cfg.get("target_y", 0.85))
		)
		preview_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cvb.add_child(preview_card)

		# 설명 문구
		var desc_lbl := Label.new()
		desc_lbl.text = str(cfg["desc"])
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", Color(0.345, 0.384, 0.392)) # #586264
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cvb.add_child(desc_lbl)

		# 점수 보상 안내
		var pts_lbl := Label.new()
		pts_lbl.text = "문제당 +%d점" % int(cfg["pts"])
		pts_lbl.add_theme_font_size_override("font_size", 13.5)
		pts_lbl.add_theme_color_override("font_color", cfg["color"])
		cvb.add_child(pts_lbl)

		# 시작 버튼
		var start_btn := Button.new()
		start_btn.text = "이 난이도로 시작  →"
		start_btn.custom_minimum_size = Vector2(0, 40)
		start_btn.add_theme_font_size_override("font_size", 14)
		_apply_btn_styles(start_btn,
			Color(0.102, 0.455, 0.510),
			Color(0.125, 0.545, 0.612),
			Color.WHITE, Color.TRANSPARENT, 10
		)
		var k := diff_key
		start_btn.pressed.connect(func(): _on_select_difficulty(k))
		cvb.add_child(start_btn)

	# 5. 푸터 문구
	var footer_lbl := Label.new()
	footer_lbl.text = "작은 도전부터 시작해도 좋아요. 탐험은 나만의 속도로!"
	footer_lbl.add_theme_font_size_override("font_size", 12.5)
	footer_lbl.add_theme_color_override("font_color", Color(0.478, 0.522, 0.502)) # #7a8580
	vb.add_child(footer_lbl)

func _on_select_difficulty(diff_key: String) -> void:
	current_difficulty = diff_key
	user_save_data["difficulty"] = current_difficulty
	_save_current_state()
	_set_game_state(GameState.PLAYING)
	_show_msg("⚔️ [%s] 난이도로 게임을 시작합니다!" % current_difficulty, 3.0)

func _on_continue_game() -> void:
	current_difficulty = str(user_save_data.get("difficulty", "NOVICE"))
	quiz_score = int(user_save_data.get("score", 0))
	var ppos: Variant = user_save_data.get("player_pos", null)
	if ppos is Array and ppos.size() >= 3:
		var saved_position := Vector3(float(ppos[0]), float(ppos[1]), float(ppos[2]))
		player.teleport_to(saved_position if _safe_saved_player_position(saved_position) else player.spawn_point)
	_set_game_state(GameState.PLAYING)
	_show_msg("🚀 이전 저장 상태에서 여정을 이어갑니다! (난이도: %s, 점수: %d점)" % [current_difficulty, quiz_score], 3.0)

func _build_pause_modal(canvas: CanvasLayer) -> void:
	pause_modal = Control.new()
	pause_modal.name = "PauseModal"
	pause_modal.visible = false
	pause_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(pause_modal)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.11, 0.76)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_modal.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 420)
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.06, 0.09, 0.16, 0.96), Color(0.24, 0.88, 1.0, 0.9), 16, 28))
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "⚙️ NODEVERSE SYSTEM MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color(0.25, 0.95, 1.0)
	vb.add_child(title)

	pause_info_lbl = Label.new()
	pause_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_info_lbl.add_theme_font_size_override("font_size", 15)
	pause_info_lbl.text = "플레이어: Guest | 난이도: NOVICE | 점수: 0점"
	pause_info_lbl.modulate = Color(1.0, 0.90, 0.40)
	vb.add_child(pause_info_lbl)

	var btn_v := VBoxContainer.new()
	btn_v.add_theme_constant_override("separation", 10)
	vb.add_child(btn_v)

	var resume_btn := Button.new()
	resume_btn.text = "▶ 게임 계속하기 (Resume)"
	resume_btn.custom_minimum_size = Vector2(0, 44)
	resume_btn.pressed.connect(func(): _set_game_state(GameState.PLAYING))
	btn_v.add_child(resume_btn)

	var chg_diff_btn := Button.new()
	chg_diff_btn.text = "🔄 난이도 변경 / 로비로 가기"
	chg_diff_btn.custom_minimum_size = Vector2(0, 44)
	chg_diff_btn.pressed.connect(func(): _set_game_state(GameState.DIFFICULTY_SELECT))
	btn_v.add_child(chg_diff_btn)

	var save_btn := Button.new()
	save_btn.text = "💾 현재 상태 저장 (Save Progress)"
	save_btn.custom_minimum_size = Vector2(0, 44)
	save_btn.pressed.connect(func():
		_save_current_state()
		_show_msg("💾 현재 위치와 점수가 성공적으로 저장되었습니다!", 2.5)
		_set_game_state(GameState.PLAYING))
	btn_v.add_child(save_btn)

	# 그래픽 품질: 누를 때마다 자동 → 높음 → 중간 → 낮음 → 자동
	quality_btn = Button.new()
	quality_btn.custom_minimum_size = Vector2(0, 44)
	quality_btn.pressed.connect(func():
		if quality == null:
			return
		if quality.auto_mode:
			quality.set_manual(QualityManager.Tier.HIGH)
		elif quality.tier == QualityManager.Tier.HIGH:
			quality.set_manual(QualityManager.Tier.MEDIUM)
		elif quality.tier == QualityManager.Tier.MEDIUM:
			quality.set_manual(QualityManager.Tier.LOW)
		else:
			quality.set_auto()
		_refresh_quality_btn())
	btn_v.add_child(quality_btn)
	_refresh_quality_btn()

	var logout_btn := Button.new()
	logout_btn.text = "🚪 타이틀로 나가기 / 로그아웃"
	logout_btn.custom_minimum_size = Vector2(0, 44)
	logout_btn.pressed.connect(func(): _on_logout())
	btn_v.add_child(logout_btn)

func _refresh_quality_btn() -> void:
	if quality_btn != null:
		quality_btn.text = "🖥 그래픽 품질: %s  (누르면 변경)" % (quality.label() if quality != null else "자동")

func _set_game_state(new_state: GameState) -> void:
	game_state = new_state
	match game_state:
		GameState.TITLE_LOGIN:
			if hud_root: hud_root.visible = false
			if title_modal: title_modal.visible = true
			if lobby_modal: lobby_modal.visible = false
			if pause_modal: pause_modal.visible = false
			if quiz_modal: quiz_modal.visible = false
			is_quiz_open = false
			if player != null:
				player.can_move = false
				player.overview_mode = true
				player.tour_mode = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_refresh_title_inputs()
		GameState.DIFFICULTY_SELECT:
			if hud_root: hud_root.visible = false
			if title_modal: title_modal.visible = false
			if lobby_modal: lobby_modal.visible = true
			if pause_modal: pause_modal.visible = false
			if quiz_modal: quiz_modal.visible = false
			is_quiz_open = false
			if player != null:
				player.can_move = false
				player.overview_mode = true
				player.tour_mode = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_refresh_lobby_ui()
		GameState.PLAYING:
			if hud_root: hud_root.visible = true
			if title_modal: title_modal.visible = false
			if lobby_modal: lobby_modal.visible = false
			if pause_modal: pause_modal.visible = false
			if quiz_modal: quiz_modal.visible = is_quiz_open
			if player != null:
				player.can_move = not is_quiz_open
				player.overview_mode = false
				player.tour_mode = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_refresh_profile_pill()
		GameState.PAUSED_MENU:
			if hud_root: hud_root.visible = true
			if title_modal: title_modal.visible = false
			if lobby_modal: lobby_modal.visible = false
			if pause_modal: pause_modal.visible = true
			if quiz_modal: quiz_modal.visible = false
			is_quiz_open = false
			if player != null:
				player.can_move = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_refresh_pause_menu_ui()

func _load_quiz_data() -> void:
	quiz_dict = {
		"INTRO": [], "STACK": [], "QUEUE": [], "ARRAY": [], "LIST": [], "SQL": [], "ALGO": [], "DATA": [], "CHALLENGE": []
	}
	quiz_index = {}

	# quizzes.json 파일 읽기
	var file_path := "res://data/quizzes.json"
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f != null:
		var txt := f.get_as_text()
		var json := JSON.new()
		if json.parse(txt) == OK:
			var parsed: Variant = json.data
			if parsed is Dictionary and parsed.has("quizzes"):
				for q in parsed["quizzes"]:
					var z: String = str(q.get("zone", "")).to_upper()
					if quiz_dict.has(z):
						quiz_dict[z].append(q)
		f.close()

func _build_quiz_modal(canvas: CanvasLayer) -> void:
	quiz_modal = Control.new()
	quiz_modal.name = "QuizModal"
	quiz_modal.visible = false
	quiz_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(quiz_modal)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.10, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quiz_modal.add_child(bg)

	var center_c := CenterContainer.new()
	center_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quiz_modal.add_child(center_c)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 520)
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.08, 0.11, 0.16, 0.96), Color(0.24, 0.88, 1.0, 0.9), 14, 32))
	center_c.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	# 상단 헤더: 구역 & 난이도 배지 + 점수
	var top_row := HBoxContainer.new()
	box.add_child(top_row)

	quiz_zone_tag = Label.new()
	quiz_zone_tag.text = "🎯 [자료구조 퀴즈 CHALLENGE]"
	quiz_zone_tag.add_theme_font_size_override("font_size", 22)
	quiz_zone_tag.modulate = Color(0.25, 0.95, 1.0)
	top_row.add_child(quiz_zone_tag)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(sp)

	quiz_score_lbl = Label.new()
	quiz_score_lbl.text = "점수: 0점"
	quiz_score_lbl.add_theme_font_size_override("font_size", 18)
	quiz_score_lbl.modulate = Color(1.0, 0.90, 0.40)
	top_row.add_child(quiz_score_lbl)

	# 제목 & 본문 질문
	quiz_title_lbl = Label.new()
	quiz_title_lbl.add_theme_font_size_override("font_size", 19)
	quiz_title_lbl.modulate = Color(0.92, 0.95, 1.0)
	box.add_child(quiz_title_lbl)

	quiz_question_lbl = Label.new()
	quiz_question_lbl.add_theme_font_size_override("font_size", 17)
	quiz_question_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quiz_question_lbl.custom_minimum_size = Vector2(690, 56)
	box.add_child(quiz_question_lbl)

	# 보기 버튼
	var opt_box := VBoxContainer.new()
	opt_box.add_theme_constant_override("separation", 8)
	box.add_child(opt_box)

	quiz_option_btns.clear()
	for i in range(3):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 16)
		var btn_idx := i
		btn.pressed.connect(func(): _on_quiz_option_selected(btn_idx))
		opt_box.add_child(btn)
		quiz_option_btns.append(btn)

	# 정답/오답 해설 안내문
	quiz_feedback_lbl = Label.new()
	quiz_feedback_lbl.add_theme_font_size_override("font_size", 15)
	quiz_feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quiz_feedback_lbl.custom_minimum_size = Vector2(690, 48)
	box.add_child(quiz_feedback_lbl)

	# 하단 버튼바: [다음 문제] [닫기 (ESC)]
	var btm_row := HBoxContainer.new()
	box.add_child(btm_row)

	var btm_sp := Control.new()
	btm_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btm_row.add_child(btm_sp)

	quiz_next_btn = Button.new()
	quiz_next_btn.text = "  다음 문제 ▶  "
	quiz_next_btn.custom_minimum_size = Vector2(130, 38)
	quiz_next_btn.pressed.connect(func(): _next_quiz())
	btm_row.add_child(quiz_next_btn)

	var close_btn := Button.new()
	close_btn.text = "  닫기 (ESC)  "
	close_btn.custom_minimum_size = Vector2(110, 38)
	close_btn.pressed.connect(func(): _close_quiz())
	btm_row.add_child(close_btn)

func _open_quiz_for_zone(zone_key: String) -> void:
	var q_key := "STACK"
	var pp: Vector3 = player.global_position
	if zone_key == "INTRO":
		q_key = "INTRO"
	elif zone_key == "DATA":
		q_key = "DATA"
	elif zone_key == "CHALLENGE":
		q_key = "CHALLENGE"
	elif zone_key == "DS":
		if pp.x < -14.0: q_key = "ARRAY"
		elif pp.z < -3.5: q_key = "LIST"
		elif pp.x < -11.0: q_key = "STACK"
		else: q_key = "QUEUE"
	elif zone_key == "SQL":
		q_key = "SQL"
	elif zone_key == "ALGO":
		q_key = "ALGO"
	else:
		var keys := ["INTRO", "STACK", "QUEUE", "ARRAY", "LIST", "SQL", "ALGO", "DATA", "CHALLENGE"]
		q_key = keys[randi() % keys.size()]

	var all_list: Array = quiz_dict.get(q_key, [])
	if all_list.is_empty():
		_show_msg("이 구역의 퀴즈 데이터가 없습니다.", 2.0)
		return

	# 현재 선택된 난이도로 퀴즈 필터링
	var target_diff: String = current_difficulty.to_lower()
	var filtered: Array = []
	for q in all_list:
		if str(q.get("difficulty", "")).to_lower() == target_diff:
			filtered.append(q)
	if filtered.is_empty():
		filtered = all_list # 대체 폴백

	var state_key: String = q_key + "_" + target_diff
	var idx: int = quiz_index.get(state_key, 0) % filtered.size()
	current_quiz_item = filtered[idx]
	_display_current_quiz(q_key, idx + 1, filtered.size())

	is_quiz_open = true
	quiz_modal.visible = true
	if player != null and player.has_method("set"):
		player.set("can_move", false)

func _close_quiz() -> void:
	is_quiz_open = false
	quiz_modal.visible = false
	if player != null and player.has_method("set"):
		player.set("can_move", true)

func _on_quiz_option_selected(opt_idx: int) -> void:
	var correct: int = int(current_quiz_item.get("correctIndex", 0))
	var exp: String = str(current_quiz_item.get("explanation", ""))
	var cfg: Dictionary = DIFFICULTY_CONFIG.get(current_difficulty, DIFFICULTY_CONFIG["NOVICE"])
	var pts: int = int(cfg.get("pts", 10))

	for btn: Button in quiz_option_btns:
		btn.disabled = true

	if opt_idx == correct:
		quiz_score += pts
		_save_current_state()
		_refresh_profile_pill()
		quiz_score_lbl.text = "점수: %d점" % quiz_score
		quiz_option_btns[opt_idx].modulate = Color(0.3, 1.0, 0.4)
		quiz_feedback_lbl.text = "🎉 정답입니다! (+%d점 획득)\n💡 해설: %s" % [pts, exp]
		quiz_feedback_lbl.modulate = Color(0.35, 1.0, 0.5)
	else:
		quiz_option_btns[opt_idx].modulate = Color(1.0, 0.35, 0.35)
		if correct >= 0 and correct < quiz_option_btns.size():
			quiz_option_btns[correct].modulate = Color(0.3, 1.0, 0.4)
		quiz_feedback_lbl.text = "❌ 아쉽게 틀렸습니다!\n💡 해설: %s" % exp
		quiz_feedback_lbl.modulate = Color(1.0, 0.65, 0.4)

	quiz_next_btn.visible = true


# ============================================================================
# FRAME LOOP, PROCESS & INPUT
# ============================================================================

func _zone_of(p: Vector3) -> String:
	if authored_map:
		var cell := Vector2i(floori(p.x), floori(p.z))
		for key in island_cells:
			if (island_cells[key] as Dictionary).has(cell): return key
		var nearest := "MAIN"
		var distance := INF
		for key in ISLANDS:
			var center := _island_center(key)
			var radius := Vector2(ISLANDS[key]["rx"], ISLANDS[key]["rz"])
			var score := ((Vector2(p.x, p.z) - center) / radius).length_squared()
			if score < distance:
				distance = score
				nearest = key
		return nearest
	if p.z > 11.0 and p.x < -8.0:
		return "INTRO"
	elif p.z < -24.0:
		return "CHALLENGE"
	elif p.x > 14.0 and p.z < -9.0:
		return "DATA"
	elif p.z < -8.0:
		return "ALGO"
	elif p.x < -7.0:
		return "DS"
	elif p.x > 7.0:
		return "SQL"
	return "MAIN"

func _process(delta: float) -> void:
	if not is_built:
		return
	_sync_hud_bubbles()
	if quality != null:
		quality.active = game_state == GameState.PLAYING
	# F3: FPS + 로봇 위치 (맵 수정할 때 좌표 확인용)
	if fps_label != null and fps_label.visible and player != null:
		var pp3 := player.global_position
		fps_label.text = "FPS %d  |  그래픽 %s · %s  |  위치 Vector3(%.1f, TOP, %.1f)  |  구역 %s" % [Engine.get_frames_per_second(), quality.label() if quality else "-", quality.level_label() if quality else "", pp3.x, pp3.z, _zone_name]
	if player == null:
		return

	# 월드 투어 시네마틱 카메라 (타이틀/로비 상태)
	if game_state == GameState.TITLE_LOGIN or game_state == GameState.DIFFICULTY_SELECT:
		if not _tour_paused:
			_tour_time += delta
		const SEG_DUR := 7.5
		var total_dur := float(TOUR_WAYPOINTS.size()) * SEG_DUR
		var t := fmod(_tour_time, total_dur)
		var s_idx := int(t / SEG_DUR)
		var n_idx := (s_idx + 1) % TOUR_WAYPOINTS.size()
		var lt := (t - float(s_idx) * SEG_DUR) / SEG_DUR
		var smooth_t := lt * lt * (3.0 - 2.0 * lt)

		var wa: Dictionary = TOUR_WAYPOINTS[s_idx]
		var wb: Dictionary = TOUR_WAYPOINTS[n_idx]
		var tour_islands := ["MAIN", "INTRO", "DS", "ALGO", "CHALLENGE", "DATA", "SQL"]
		var focus_a: Vector3 = wa["focus"] + _island_offset(tour_islands[s_idx])
		var focus_b: Vector3 = wb["focus"] + _island_offset(tour_islands[n_idx])
		var target_focus: Vector3 = focus_a.lerp(focus_b, smooth_t)
		var target_dist: float = lerpf(wa["dist"], wb["dist"], smooth_t)
		var target_pitch: float = lerpf(wa["pitch"], wb["pitch"], smooth_t)
		var target_yaw: float = rad_to_deg(lerp_angle(deg_to_rad(wa["yaw"]), deg_to_rad(wb["yaw"]), smooth_t))

		player.set("tour_mode", true)
		player.set("cam_focus", target_focus)
		player.set("cam_dist", target_dist)
		player.set("cam_pitch", target_pitch)
		player.set("cam_yaw", target_yaw)
		return

	# 카메라 디버그 패널이 열려있으면 실시간 수치 동기화
	if cam_debug_panel != null and cam_debug_panel.visible:
		_sync_cam_debug_ui()

	var pp: Vector3 = player.global_position
	var z := _zone_of(pp)
	if z != _zone_name:
		_zone_name = z

	match z:
		"MAIN":
			zone_label.text = "🏰 메인 섬 (Main Hub) — 중앙 수정 비콘 & 마을 광장"
			prompt_label.text = "[E] 비콘 상호작용  |  [T] 퀴즈  |  [F4] 카메라 디버그 & 시점 고정  |  [1~7] 빠른 이동"
		"INTRO":
			zone_label.text = "📖 입문 섬 (Intro Basics) — 순서도 논리 칠판 & 마법서 제단"
			prompt_label.text = "[E] 로직 보드 탐색  |  [T] 기초 프로그래밍 퀴즈  |  [F4] 카메라 디버그"
		"DS":
			zone_label.text = "📦 자료구조 섬 (Data Structures) — ARRAY · LIST · STACK · QUEUE"
			prompt_label.text = "[E] 자료구조 조작  |  [Q] Pop/Dequeue  |  [T] 퀴즈  |  [F4] 카메라 디버그"
		"SQL":
			zone_label.text = "🏛️ SQL 섬 (Database & Query) — DB 타워 · 아카이브 · Y형 수로"
			prompt_label.text = "[E] SELECT/JOIN 쿼리 실행  |  [T] SQL 퀴즈  |  [F4] 카메라 디버그"
		"ALGO":
			zone_label.text = "⚡ 알고리즘 섬 (Algorithms) — 정렬 계단 · 5노드 그래프 · 미로 정원"
			prompt_label.text = "[E] 정렬/BFS/미로 실행  |  [T] 알고리즘 퀴즈  |  [F4] 카메라 디버그"
		"DATA":
			zone_label.text = "🔭 데이터 탐험 섬 (Data Exploration) — 수목 전망대 & 탐험 나침반 & 히스토그램"
			prompt_label.text = "[E] 히스토그램/전망대 관측  |  [T] 데이터 분석 퀴즈  |  [F4] 카메라 디버그"
		"CHALLENGE":
			zone_label.text = "👑 종합 도전 섬 (Grand Challenge) — 정상 천체 판테온 & 영예의 회랑"
			prompt_label.text = "[E] 마스터 판테온 트로피 도전  |  [T] 종합 퀴즈  |  [F4] 카메라 디버그"

	# NPC & 컴퓨터 터미널 감지
	var near_npc: Node3D = null
	var min_npc_dist := 2.6
	for npc: Node3D in spawned_npcs:
		if is_instance_valid(npc):
			var d := pp.distance_to(npc.global_position)
			if d < min_npc_dist:
				min_npc_dist = d
				near_npc = npc
	active_npc = near_npc

	var near_comp := false
	for cp: Vector3 in computer_positions:
		if pp.distance_to(cp) < COMPUTER_INTERACT_DIST:
			near_comp = true
			break

	if _near_basics_board():
		prompt_label.text = "📖 [E] 게시판 읽기  ➜  기본 조작·학습 안내" + (" · 확인 완료" if _basics_completed else "")
		prompt_label.modulate = Color(1.0, 0.95, 0.35)
	elif near_comp:
		var terminal := _nearest_terminal()
		var topic: String = terminal.get_meta("learning_title", "자료구조 2D 미니게임")
		prompt_label.text = "💻 [E] 컴퓨터 접속  ➜  " + topic
		prompt_label.modulate = Color(1.0, 0.95, 0.35)
	elif active_npc != null:
		prompt_label.text = "💬 [E] 대화하기: %s" % active_npc.get_meta("npc_name", "NPC")
		prompt_label.modulate = Color(0.4, 0.95, 1.0)
	else:
		prompt_label.modulate = Color(1.0, 1.0, 1.0)

	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time <= 0.0:
			msg_label.text = ""

	# Queue crates movement
	var lane := _queue_lane()
	var lane_axis := (lane[1] - lane[0]).normalized()
	var lane_length := lane[0].distance_to(lane[1])
	for cr in queue_crates:
		if is_instance_valid(cr):
			cr.global_position += lane_axis * delta * 0.65
			var progress := (cr.global_position - lane[0]).dot(lane_axis)
			if progress > lane_length: progress = 0.0
			var aligned := lane[0] + lane_axis * clampf(progress, 0.0, lane_length)
			aligned.y = _queue_support_height(aligned)
			cr.global_position = aligned

func _unhandled_input(event: InputEvent) -> void:
	if _basics_open():
		if Engine.get_process_frames() != _last_interact_frame:
			_basics_guide.handle_key(event)
		get_viewport().set_input_as_handled()
		return
	if npc_dialog_open():
		if event is InputEventKey and event.pressed and not event.echo:
			match (event as InputEventKey).keycode:
				KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
					if Engine.get_process_frames() != _last_interact_frame:
						_last_interact_frame = Engine.get_process_frames()
						_advance_npc_dialog()
				KEY_ESCAPE:
					_close_npc_dialog()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_advance_npc_dialog()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var ek: InputEventKey = event as InputEventKey
		if ek.pressed and not ek.echo:
			if ek.keycode == KEY_ESCAPE:
				if is_quiz_open:
					_close_quiz()
				elif game_state == GameState.PLAYING:
					_set_game_state(GameState.PAUSED_MENU)
				elif game_state == GameState.PAUSED_MENU:
					_set_game_state(GameState.PLAYING)
			elif ek.keycode == KEY_F4:
				if cam_debug_panel != null:
					cam_debug_panel.visible = not cam_debug_panel.visible
					_sync_cam_debug_ui()
			elif game_state == GameState.PLAYING:
				if ek.keycode == KEY_TAB:
					help_label.visible = not help_label.visible
				elif ek.keycode == KEY_F3:
					fps_label.visible = not fps_label.visible
				elif ek.keycode == KEY_E:
					_on_interact()
				elif ek.keycode == KEY_Q:
					_on_secondary()
				elif ek.keycode == KEY_T:
					if is_quiz_open: _close_quiz()
					else: _open_quiz_for_zone(_zone_name)
				elif ek.keycode == KEY_1:
					player.teleport_to(player.spawn_point)
					_show_msg("⚓ 메인 섬 부두로 이동했습니다", 2.0)
				elif ek.keycode == KEY_2:
					player.teleport_to(Vector3(-15.5, TOP + 0.1, 0.0))
					_show_msg("📦 자료구조 섬으로 이동했습니다", 2.0)
				elif ek.keycode == KEY_3:
					player.teleport_to(_island_spawn("SQL"))
					_show_msg("🏛️ SQL 섬으로 이동했습니다", 2.0)
				elif ek.keycode == KEY_4:
					player.teleport_to(Vector3(0.0, TOP + 0.1, -14.0))
					_show_msg("⚡ 알고리즘 섬으로 이동했습니다", 2.0)
				elif ek.keycode == KEY_5:
					player.teleport_to(_island_spawn("INTRO"))
					_show_msg("📖 입문 섬으로 이동했습니다", 2.0)
				elif ek.keycode == KEY_6:
					player.teleport_to(Vector3(23.0, TOP + 0.1, -17.5))
					_show_msg("🔭 데이터 탐험 섬으로 이동했습니다", 2.0)
				elif ek.keycode == KEY_7:
					player.teleport_to(Vector3(0.0, TOP + 0.1, -32.5))
					_show_msg("👑 종합 도전 섬으로 이동했습니다", 2.0)


# ============================================================================
# INTERACTION DISPATCHER
# ============================================================================

func _on_interact() -> void:
	if player == null or _basics_open() or is_quiz_open or game_state != GameState.PLAYING:
		return
	# E 키가 로봇 신호와 월드 입력 양쪽에서 들어오므로 같은 프레임 중복 실행 방지
	if Engine.get_process_frames() == _last_interact_frame:
		return
	_last_interact_frame = Engine.get_process_frames()
	if npc_dialog_open():
		_advance_npc_dialog()
		return
	var pp: Vector3 = player.global_position
	if _near_basics_board():
		_open_basics_board()
		return

	# 1. 컴퓨터 터미널 (2D 미니게임)
	for cp: Vector3 in computer_positions:
		if pp.distance_to(cp) < COMPUTER_INTERACT_DIST:
			_open_computer_game()
			return

	# 2. NPC 대화
	if active_npc != null:
		_talk_to_npc(active_npc)
		return

	# 3. 구역별 기믹
	match _zone_name:
		"MAIN":
			_show_msg("✨ 크리스탈 비콘 활성화! 7개의 섬이 찬란하게 연결되어 빛납니다.", 3.0)
		"INTRO":
			_show_msg("📘 [기초 로직 마법서] 변수, 조건문, 반복문의 동작 원리를 학습했습니다! (+10 EXP)", 3.0)
		"DATA":
			_show_msg("📊 [데이터 탐험대] 히스토그램과 나침반 네트워크를 분석했습니다! (+15 EXP)", 3.0)
		"CHALLENGE":
			_show_msg("🏆 [판테온 신전] 최고 난이도 아키텍처 마스터 트로피에 도달했습니다! (+30 EXP)", 3.0)
		"DS":
			if pp.x < -18.0:
				_array_swap()
			elif pp.z < -3.0:
				_list_pulse()
			elif pp.x < -14.0:
				_stack_push()
			else:
				_queue_enqueue(true)
		"SQL":
			_sql_run_query()
		"ALGO":
			_algo_sort_step()

func _on_secondary() -> void:
	if _basics_open(): return
	match _zone_name:
		"DS":
			_stack_pop()
			_queue_dequeue(true)
		"ALGO":
			_algo_sort_shuffle()

func _refresh_array_labels(active: int) -> void:
	for i in range(array_labels.size()):
		var slot: int = array_labels[i].get_meta("array_index", i)
		array_labels[i].text = "arr[%d] = %d" % [slot, array_values[slot]]
		array_labels[i].modulate = Color(1.0, 0.9, 0.3) if i == active else Color(1.0, 1.0, 1.0, 0.85)

func _array_swap() -> void:
	var tmp: int = array_values[0]
	array_values[0] = array_values[1]
	array_values[1] = tmp
	_refresh_array_labels(0)
	_show_msg("배열 첫 두 요소 Swap 완료! arr[0]=%d, arr[1]=%d" % [array_values[0], array_values[1]], 2.0)

func _list_pulse() -> void:
	_show_msg("연결 리스트 노드 탐색 (Node 10 ➜ Node 20 ➜ Node 30) O(N) 순회", 2.5)

func _stack_slot_y(i: int) -> float:
	return 0.29 + float(i) * 0.505

func _update_stack_label() -> void:
	if stack_label != null:
		stack_label.text = "STACK  size = %d / %d" % [stack_crates.size(), STACK_CAP]

func _stack_push() -> void:
	if not is_instance_valid(stack_tower):
		return
	if stack_crates.size() >= STACK_CAP:
		_show_msg("Stack Overflow! (Q: Pop)", 2.0)
		return
	var idx: int = stack_crates.size()
	var cr: Node3D = _spawn("09_crate_brown", Vector3(0.0, _stack_slot_y(idx), 0.18), 0.0, 0.76, false, stack_tower)
	stack_crates.append(cr)
	_show_msg("PUSH ➜ 스택 맨 위에 추가 (LIFO, size %d)" % stack_crates.size(), 2.0)
	_update_stack_label()

func _stack_pop() -> void:
	if stack_crates.is_empty():
		_show_msg("Stack Underflow! (E: Push)", 2.0)
		return
	var cr: Node3D = stack_crates.pop_back()
	cr.queue_free()
	_show_msg("POP ➜ 스택 맨 위 상자 꺼냄 (LIFO, size %d)" % stack_crates.size(), 2.0)
	_update_stack_label()

func _update_queue_label() -> void:
	if queue_label != null:
		queue_label.text = "QUEUE  size = %d / %d" % [queue_crates.size(), QUEUE_CAP]

func _queue_enqueue(announce: bool = true) -> void:
	if queue_crates.size() >= QUEUE_CAP:
		if announce: _show_msg("Queue Full!", 2.0)
		return
	var cr: Node3D = _spawn("10_crate_gold_top", _queue_lane()[0], 0.0, 0.7)
	queue_crates.append(cr)
	if announce: _show_msg("ENQUEUE ➜ 큐 뒤쪽에 추가 (FIFO, size %d)" % queue_crates.size(), 2.0)
	_update_queue_label()

func _queue_lane() -> PackedVector3Array:
	var first := find_child("43_conveyor_arrow_up", true, false) as Node3D
	var last := find_child("44_conveyor_arrow_down_a", true, false) as Node3D
	if first != null and last != null:
		var direction := (last.global_position - first.global_position).normalized()
		# Keep the entire 0.7-scale crate inside the end rollers, not just its pivot.
		var start := first.global_position - direction * maxf(0.05, 0.86 * first.global_basis.z.length() - 0.27)
		var finish := last.global_position + direction * maxf(0.05, 0.86 * last.global_basis.z.length() - 0.27)
		start.y = _queue_support_height(start)
		finish.y = _queue_support_height(finish)
		return PackedVector3Array([start, finish])
	return PackedVector3Array([Vector3(QUEUE_START_X, TOP + 0.24, QUEUE_Z), Vector3(QUEUE_END_X, TOP + 0.24, QUEUE_Z)])

func _queue_support_height(point: Vector3) -> float:
	var support := -INF
	for name in ["43_conveyor_arrow_up", "47_conveyor_gold_plate", "44_conveyor_arrow_down_a"]:
		var belt := find_child(name, true, false) as Node3D
		if belt == null: continue
		var local := belt.to_local(point)
		var footprint := 0.231 / maxf(belt.global_basis.z.length(), 0.01)
		if absf(local.z) > 0.86 + footprint: continue
		var top := 0.233  # slat top: 0.215 + 0.036 / 2
		var pad_z := -0.38 if name == "43_conveyor_arrow_up" else 0.38
		if absf(local.z - pad_z) < 0.36 + footprint:
			top = 0.294 if name == "47_conveyor_gold_plate" else 0.312
		support = maxf(support, belt.to_global(Vector3(0, top, local.z)).y)
	return support + 0.006 if is_finite(support) else TOP + 0.24

func _align_queue_crates() -> void:
	var lane := _queue_lane()
	var axis := (lane[1] - lane[0]).normalized()
	var length := lane[0].distance_to(lane[1])
	for crate in queue_crates:
		if not is_instance_valid(crate): continue
		var progress := clampf((crate.global_position - lane[0]).dot(axis), 0.0, length)
		var point := lane[0] + axis * progress
		point.y = _queue_support_height(point)
		crate.global_position = point

func _queue_dequeue(manual: bool) -> void:
	if queue_crates.is_empty():
		if manual: _show_msg("Queue Empty!", 2.0)
		return
	var cr: Node3D = queue_crates.pop_front()
	cr.queue_free()
	if manual: _show_msg("DEQUEUE ➜ 큐 맨 앞 상자 처리 (FIFO, size %d)" % queue_crates.size(), 2.0)
	_update_queue_label()

func _sql_run_query() -> void:
	_show_msg("SELECT * FROM nodes WHERE status = 'CONNECTED'; ➜ 8개 레코드 반환 완료!", 3.0)

func _algo_sort_step() -> void:
	_show_msg("버블 정렬 1단계 진행: 인접 요소 비교 및 교환", 2.0)

func _algo_sort_shuffle() -> void:
	_show_msg("정렬 막대 배열 랜덤 셔플 완료!", 2.0)

func _on_fell(pos: Vector3) -> void:
	_show_msg("물에 빠졌습니다! 안전한 지점으로 복귀합니다.", 2.0)
