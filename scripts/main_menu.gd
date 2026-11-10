extends "res://scripts/minigames/mini_game_base.gd"
## 분야별 미니게임 메뉴. 3D 월드의 컴퓨터에서 해당 분야 탭으로 들어온다.

const Catalog = preload("res://scripts/learning_catalog.gd")
const STAGES = Catalog.GAMES
const PAGE_SIZE := 6
var thumbs := {}
var page := 0

func _ready() -> void:
	load_progress()
	font = load("res://fonts/NotoSansKR_Medium.tres")
	bg = load("res://textures/stages/ST10/bg_pixel.png")
	if not Catalog.CATEGORIES.has(Catalog.selected_category):
		Catalog.selected_category = "DS"

func _thumb(game: Array) -> Texture2D:
	if not thumbs.has(game[0]):
		var folder: String = game[6]
		var small := "res://textures/stages/%s/bg_pixel.png" % folder
		thumbs[game[0]] = load(small if ResourceLoader.exists(small) else "res://textures/stages/%s/bg_game.png" % folder)
	return thumbs[game[0]]

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		mouse = ev.position
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for b in _buttons:
			if b[0].has_point(ev.position) and b[2]:
				_go(b[1])
				return
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_ESCAPE: _go_back_to_world()
			KEY_LEFT: page = maxi(page - 1, 0)
			KEY_RIGHT: page = mini(page + 1, _pages() - 1)

func _pages() -> int:
	return ceili(Catalog.games_for(Catalog.selected_category).size() / float(PAGE_SIZE))

func _go_back_to_world() -> void:
	var world = load("res://scripts/nodeverse_world.gd")
	if world.return_from_2d(get_tree()):
		return
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_tree().change_scene_to_file("res://scenes/NodeverseWorld.tscn")

func _go(id) -> void:
	var key := str(id)
	if key == "world":
		_go_back_to_world()
	elif key == "previous":
		page -= 1
	elif key == "next":
		page += 1
	else:
		get_tree().change_scene_to_file("res://scenes/stages/%s.tscn" % key)

func _draw() -> void:
	_buttons.clear()
	if bg:
		draw_texture_rect(bg, Rect2(0, 0, 1280, 720), false)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.03, 0.06, 0.12, 0.88))
	var category_name: String = Catalog.CATEGORIES[Catalog.selected_category]
	text("%s 섬 컴퓨터" % category_name, Vector2(34, 58), 34, C_WHITE)
	button(Rect2(1010, 18, 236, 44), "3D 월드로 복귀", "world", true, 19, Color("2d6a4f"))
	text("이 섬의 실습만 볼 수 있어요. 다른 분야는 해당 섬의 컴퓨터에서 열려요.", Vector2(36, 110), 20, C_WHITE)
	var games := Catalog.games_for(Catalog.selected_category)
	var pages := _pages()
	page = clampi(page, 0, pages - 1)
	for i in mini(PAGE_SIZE, games.size() - page * PAGE_SIZE):
		_draw_card(games[page * PAGE_SIZE + i], i)
	button(Rect2(34, 634, 136, 40), "이전", "previous", page > 0)
	text_c("%s · %d개 실습 · %d / %d" % [Catalog.CATEGORIES[Catalog.selected_category], games.size(), page + 1, pages], Vector2(640, 664), 20, C_WHITE)
	button(Rect2(1110, 634, 136, 40), "다음", "next", page + 1 < pages)
	text("카드 클릭: 시작  |  실습에서 Esc: 이 메뉴", Vector2(36, 705), 16, C_WHITE)

func _draw_card(game: Array, i: int) -> void:
	var r := Rect2(34 + (i % 3) * 408, 182 + (i / 3) * 216, 392, 202)
	var hovered := hit(r, game[4])
	pbox(r, C_PANEL.lightened(0.1) if hovered else C_PANEL, C_INK)
	draw_texture_rect(_thumb(game), Rect2(r.position + Vector2(12, 12), Vector2(126, 84)), false)
	text(str(game[7]), r.position + Vector2(152, 34), 19, C_BLUE_D)
	text(game[2], r.position + Vector2(152, 65), 20, C_BLUE_D, 226)
	text(game[1], r.position + Vector2(14, 127), 22, C_INK, 362)
	text(game[5], r.position + Vector2(14, 158), 17, C_PANEL_DARK, 362)
	var star_count := clampi(int(cleared.get(game[0], 0)), 0, 3)
	text("★".repeat(star_count) + "☆".repeat(3 - star_count), r.position + Vector2(14, 188), 21, C_BLUE_D)
	if hovered:
		outline(r.grow(2), C_GOLD)

func _process(delta: float) -> void:
	time += delta
	queue_redraw()
