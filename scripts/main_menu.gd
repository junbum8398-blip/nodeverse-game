extends "res://scripts/minigames/mini_game_base.gd"
## 메인 메뉴: 스테이지 10종(도트 미니게임)

const STAGES := [
	["ST01", "순서가 있는 보관소", "배열", "st01_array"],
	["ST02", "끊어진 운송로", "연결 리스트", "st02_linked_list"],
	["ST03", "최근 작업 복구실", "스택", "st03_stack"],
	["ST04", "접수 순서 안내소", "큐 / 덱", "st04_queue_deque"],
	["ST05", "이름으로 찾는 물품대장", "해시", "st05_hash"],
	["ST06", "계층형 자료실", "이진 트리", "st06_binary_tree"],
	["ST07", "갈림길 창고", "이진 탐색 트리", "st07_bst"],
	["ST08", "긴급 작업 배정실", "힙", "st08_heap"],
	["ST09", "연결망 조사실", "그래프", "st09_graph"],
	["ST10", "학습 지원 센터", "통합", "st10_integrated"],
]

var thumbs := {}

func _init() -> void:
	stage_id = "ST10"

func _ready() -> void:
	font = ThemeDB.fallback_font
	bg = load("res://textures/stages/ST10/bg_pixel.png")
	for s in STAGES:
		thumbs[s[0]] = load("res://textures/stages/%s/bg_pixel.png" % s[0])
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		mouse = ev.position
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for b in _buttons:
			if b[0].has_point(ev.position):
				_go(b[1])
				return
	elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		_go_back_to_world()

func _go_back_to_world() -> void:
	var world_script := "res://scripts/nodeverse_world.gd"
	if ResourceLoader.exists(world_script):
		var W = load(world_script)
		if W.return_from_2d(get_tree()):
			return
	if ResourceLoader.exists("res://scenes/NodeverseWorld.tscn"):
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		get_tree().change_scene_to_file("res://scenes/NodeverseWorld.tscn")
	else:
		get_tree().quit()

func _go(id) -> void:
	if id == "world":
		_go_back_to_world()
	elif id == "npc":
		get_tree().change_scene_to_file("res://scenes/NPCViewer.tscn")
	elif id == "st01_array":
		get_tree().change_scene_to_file("res://scenes/stages/ST01_Array.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/minigames/%s.tscn" % id)

func _draw() -> void:
	_buttons.clear()
	draw_texture_rect(bg, Rect2(0, 0, 1281, 720), false)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.06, 0.12, 0.62))
	pbox(Rect2(40, 20, 680, 70), C_PANEL_DARK, C_INK)
	text("NODEVERSE  자료구조 도트 미니게임", Vector2(64, 68), 30, C_WHITE)
	button(Rect2(1000, 28, 240, 56), "◀ 3D 월드로 복귀", "world", true, 19, Color("2d6a4f"))
	for i in STAGES.size():
		var s: Array = STAGES[i]
		var r := Rect2(40 + (i % 5) * 244, 120 + (i / 5) * 290, 228, 270)
		var hov := hit(r, s[3])
		pbox(r, C_PANEL.lightened(0.1) if hov else C_PANEL, C_INK)
		var tr := Rect2(r.position + Vector2(12, 12), Vector2(204, 115))
		draw_texture_rect(thumbs[s[0]], tr, false)
		outline(tr, C_INK)
		pbox(Rect2(r.position.x + 12, r.position.y + 136, 76, 32), C_BLUE, C_INK, false)
		text(s[0], Vector2(r.position.x + 22, r.position.y + 159), 16, C_WHITE)
		text(s[2], Vector2(r.position.x + 98, r.position.y + 160), 17, C_BLUE_D)
		text(s[1], Vector2(r.position.x + 14, r.position.y + 200), 19, C_INK, 200)
		var st := int(cleared.get(s[0], 0))
		text("★".repeat(st) + "☆".repeat(3 - st), Vector2(r.position.x + 14, r.position.y + 246), 24, C_GOLD if st > 0 else Color(0.5, 0.45, 0.4))
		if hov:
			outline(r.grow(4), C_GOLD)
	text("카드를 클릭해 시작 · 게임 중 Esc 로 메뉴 복귀 · 메뉴에서 Esc 누르면 3D 월드로 복귀", Vector2(40, 702), 16, C_WHITE)

func _process(delta: float) -> void:
	time += delta
	queue_redraw()
