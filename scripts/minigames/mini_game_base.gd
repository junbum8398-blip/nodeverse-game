class_name MiniGameBase
extends Node2D
## 2D 도트 미니게임 공통 틀.
## - 배경: textures/stages/<id>/bg_pixel.png (427x240) 를 x3 Nearest 확대
## - 도트풍 패널/버튼/상자/노드 그리기 도우미 (4px 그리드)
## - 공통 HUD: 제목, 목표, 정보 패널, 조작 안내, 메시지, 레벨 클리어 화면
## - 공통 입력: 클릭 버튼, R 레벨 초기화, Z 되돌리기, N/Enter 다음 레벨, Esc 메뉴

const PX := 4
const C_INK := Color("1d1b2a")
const C_PANEL := Color("f3e3c3")
const C_PANEL_DARK := Color("6b4a2b")
const C_BLUE := Color("2f5fb3")
const C_BLUE_D := Color("1d3a73")
const C_GOLD := Color("f2c14e")
const C_GREEN := Color("4caf50")
const C_RED := Color("e05252")
const C_WHITE := Color("fffaf0")
const C_CRATE := Color("c8843f")
const C_CRATE_D := Color("8a5426")

static var cleared := {}   # stage_id -> 최고 별 수

var stage_id := "ST00"
var stage_title := ""
var goal := ""
var level := 0
var level_count := 1
var moves := 0
var mistakes := 0
var level_done := false
var all_done := false
var font: Font
var bg: Texture2D
var mouse := Vector2.ZERO
var _buttons: Array = []       # [Rect2, id, enabled]
var _undo: Array = []
var _msg := ""
var _msg_color := C_WHITE
var _msg_t := 0.0
var _flash := {}               # key -> 남은 시간
var time := 0.0
var overlay_alpha := 0.38      # 배경 어둡게 (배경이 게임판이면 낮게)
var tut_open := false          # 시작 안내 카드 표시 중
var _tut_seen := false
const BG_SCALE := 1281.0 / 1672.0   # 원본 컨셉아트 좌표 -> 화면 좌표

# ---------- 하위 클래스가 구현 ----------
func tutorial() -> Array: return []          # [[제목, 설명], ...] 3단계 안내
func hint_rect() -> Rect2: return Rect2()    # 다음에 누를 곳 (반짝임)
func hint_text() -> String: return ""
func setup_level(_n: int) -> void: pass
func draw_game() -> void: pass
func on_button(_id) -> void: pass
func on_key(_ev: InputEventKey) -> bool: return false
func info_lines() -> Array: return []
func get_state() -> Dictionary: return {}
func set_state(_s: Dictionary) -> void: pass
func controls_text() -> String: return "클릭 선택 · Z 되돌리기 · R 초기화 · Esc 메뉴"

# ---------- 수명 주기 ----------
func _ready() -> void:
	font = ThemeDB.fallback_font
	var p := "res://textures/stages/%s/bg_pixel.png" % stage_id
	if ResourceLoader.exists(p):
		bg = load(p)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	start_level(0)

func start_level(n: int) -> void:
	level = n
	moves = 0
	mistakes = 0
	level_done = false
	_undo.clear()
	_flash.clear()
	setup_level(n)
	if n == 0 and not tutorial().is_empty() and not _tut_seen:
		tut_open = true
		_tut_seen = true
	say("레벨 %d / %d 시작!" % [n + 1, level_count], C_GOLD)
	
	# Telemetry: Task and Attempt Start
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		if n == 0:
			nm.call("start_task", stage_id, {"title": stage_title, "goal": goal, "total_levels": level_count})
		nm.call("start_attempt", stage_id, n + 1, {"goal": goal})

func _process(delta: float) -> void:
	time += delta
	_msg_t = max(0.0, _msg_t - delta)
	for k in _flash.keys():
		_flash[k] -= delta
		if _flash[k] <= 0:
			_flash.erase(k)
	queue_redraw()

# ---------- 진행 ----------
func push_undo() -> void:
	_undo.append(get_state().duplicate(true))
	if _undo.size() > 200:
		_undo.pop_front()

func undo() -> void:
	if level_done or _undo.is_empty():
		return
	set_state(_undo.pop_back())
	moves = max(0, moves - 1)
	say("되돌렸습니다.", C_WHITE)
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.call("record_operation", "undo", true, "", {}, {}, {"moves": moves})

func say(t: String, c := C_WHITE, dur := 2.6) -> void:
	_msg = t
	_msg_color = c
	_msg_t = dur

func wrong(t: String, key = null) -> void:
	mistakes += 1
	say("✗ " + t, C_RED, 3.2)
	if key != null:
		_flash[key] = 0.6
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.call("record_operation", "wrong_move", false, t, {}, {}, {"mistakes": mistakes, "moves": moves, "stage": stage_id})

func good(t: String, key = null) -> void:
	say("✓ " + t, C_GREEN)
	if key != null:
		_flash[key] = 0.5
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.call("record_operation", "good_move", true, "", {}, {}, {"mistakes": mistakes, "moves": moves, "stage": stage_id})

func flashing(key) -> bool:
	return _flash.has(key)

func stars() -> int:
	return 3 if mistakes == 0 else (2 if mistakes <= 2 else 1)

func win(t: String) -> void:
	level_done = true
	say("★ " + t, C_GOLD, 6.0)
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.call("complete_attempt", stage_id, true, "", {"level": level + 1, "moves": moves, "mistakes": mistakes, "stars": stars(), "time": time})
	if level >= level_count - 1:
		all_done = true
		cleared[stage_id] = max(int(cleared.get(stage_id, 0)), stars())
		if nm:
			nm.call("complete_task", stage_id, {"stage_id": stage_id, "moves": moves, "mistakes": mistakes, "stars": stars(), "time": time})

func next_level() -> void:
	if level < level_count - 1:
		start_level(level + 1)
	else:
		get_tree().change_scene_to_file("res://scenes/Main.tscn")

# ---------- 입력 ----------
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		mouse = ev.position
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		mouse = ev.position
		if tut_open:
			tut_open = false
			return
		for b in _buttons:
			if b[0].has_point(ev.position) and b[2]:
				if level_done and not (str(b[1]).begins_with("__")):
					return
				_click(b[1])
				return
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if tut_open:
			if ev.keycode == KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/Main.tscn")
			tut_open = false
			return
		match ev.keycode:
			KEY_H, KEY_F1:
				if not tutorial().is_empty():
					tut_open = true
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/Main.tscn")
			KEY_R:
				start_level(level)
			KEY_Z:
				undo()
			KEY_N, KEY_ENTER, KEY_KP_ENTER:
				if level_done:
					next_level()
			_:
				if not level_done:
					on_key(ev)

func _click(id) -> void:
	match str(id):
		"__next": next_level()
		"__retry": start_level(level)
		"__menu": get_tree().change_scene_to_file("res://scenes/Main.tscn")
		"__undo": undo()
		"__reset": start_level(level)
		_: on_button(id)

# ---------- 그리기 ----------
func _draw() -> void:
	_buttons.clear()
	if bg:
		draw_texture_rect(bg, Rect2(0, 0, 1281, 720), false)
	else:
		draw_rect(Rect2(0, 0, 1280, 720), Color("3a8fb7"))
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.07, 0.12, overlay_alpha))
	draw_game()
	if not level_done and not tut_open:
		_draw_hint()
	_draw_hud()
	if level_done:
		_draw_clear()
	if tut_open:
		_draw_tutorial()

func _draw_hint() -> void:
	var r := hint_rect()
	if r.size == Vector2.ZERO:
		return
	var pulse := 0.5 + 0.5 * sin(time * 6.0)
	var c := Color(C_GOLD, 0.55 + 0.45 * pulse)
	outline(r.grow(PX * 2 + pulse * PX), c, PX * 2)
	var tip := Vector2(r.get_center().x, r.position.y - 10 - pulse * 6)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-14, -20), tip + Vector2(14, -20)]), c)
	var ht := hint_text()
	if ht != "":
		var w := text_w(ht, 17) + 20
		var p := Vector2(clamp(r.get_center().x - w / 2, 8, 1272 - w), r.position.y - 92)
		pbox(Rect2(p, Vector2(w, 34)), C_GOLD, C_INK, false)
		text(ht, p + Vector2(10, 24), 17, C_INK)

func _draw_tutorial() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.55))
	var steps := tutorial()
	var h := 150 + steps.size() * 104
	var r := Rect2(240, 360 - h / 2, 800, h)
	pbox(r, C_PANEL, C_INK)
	pbox(Rect2(r.position.x, r.position.y, r.size.x, 64), C_BLUE, C_INK)
	text_c("%s %s · 플레이 방법" % [stage_id, stage_title], Vector2(640, r.position.y + 42), 26, C_WHITE)
	var y := r.position.y + 88
	for i in steps.size():
		pcircle(Vector2(r.position.x + 52, y + 30), 22, C_GOLD)
		text_c(str(i + 1), Vector2(r.position.x + 52, y + 39), 24, C_INK)
		text(steps[i][0], Vector2(r.position.x + 92, y + 22), 22, C_BLUE_D)
		text(steps[i][1], Vector2(r.position.x + 92, y + 56), 18, C_INK, r.size.x - 120)
		if steps[i].size() > 2:
			text(steps[i][2], Vector2(r.position.x + 92, y + 82), 18, C_INK, r.size.x - 120)
		y += 104
	text_c("아무 키나 누르거나 클릭하면 시작 · 게임 중 H 로 다시 보기", Vector2(640, r.end.y - 22), 17, C_PANEL_DARK)

func _draw_hud() -> void:
	# 제목
	var tw := text_w(stage_title, 24) + text_w(stage_id, 20) + 70
	pbox(Rect2(16, 12, tw, 52), C_PANEL_DARK, C_INK)
	pbox(Rect2(24, 20, text_w(stage_id, 20) + 24, 36), C_BLUE, C_INK)
	text(stage_id, Vector2(36, 46), 20, C_WHITE)
	text(stage_title, Vector2(text_w(stage_id, 20) + 62, 48), 24, C_WHITE)
	# 목표
	var gx := tw + 32
	var gw: float = min(text_w("목표: " + goal, 20) + 40, 1000 - gx)
	pbox(Rect2(gx, 12, gw, 52), C_PANEL, C_INK)
	text("목표:", Vector2(gx + 16, 46), 20, C_RED)
	text(goal, Vector2(gx + 16 + text_w("목표: ", 20), 46), 20, C_INK, gw - 32 - text_w("목표: ", 20))
	# 정보 패널
	var lines := info_lines()
	var ph := 64 + lines.size() * 38
	pbox(Rect2(1032, 12, 232, ph), C_BLUE_D, C_INK)
	text("레벨 %d/%d   %s" % [level + 1, level_count, "★".repeat(stars())], Vector2(1048, 44), 18, C_GOLD)
	var y := 64.0
	for l in lines:
		pbox(Rect2(1044, y, 208, 32), C_PANEL, C_INK, false)
		text(str(l[0]), Vector2(1054, y + 23), 16, C_INK)
		var v := str(l[1])
		text(v, Vector2(1242 - text_w(v, 17), y + 23), 17, C_BLUE_D)
		y += 38
	# 조작 안내 + 버튼
	var ct := controls_text()
	pbox(Rect2(16, 676, text_w(ct, 15) + 28, 32), Color(0.1, 0.1, 0.14, 0.85), C_INK, false)
	text(ct, Vector2(30, 698), 15, C_WHITE)
	button(Rect2(1040, 672, 104, 36), "되돌리기 Z", "__undo", not _undo.is_empty(), 15)
	button(Rect2(1152, 672, 112, 36), "초기화 R", "__reset", true, 15)
	# 메시지
	if _msg_t > 0.0 and _msg != "":
		var mw := text_w(_msg, 22) + 48
		var a: float = clamp(_msg_t * 2.0, 0.0, 1.0)
		var r := Rect2(640 - mw / 2, 68, mw, 44)
		pbox(r, Color(0.08, 0.08, 0.12, 0.9 * a), C_INK)
		text(_msg, Vector2(r.position.x + 24, r.position.y + 31), 22, Color(_msg_color, a))

func _draw_clear() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.35))
	var r := Rect2(390, 200, 500, 280)
	pbox(r, C_PANEL, C_INK)
	pbox(Rect2(r.position.x, r.position.y, r.size.x, 64), C_BLUE, C_INK)
	var t := "스테이지 클리어!" if all_done and level >= level_count - 1 else "레벨 %d 클리어!" % (level + 1)
	text_c(t, Vector2(640, 244), 28, C_WHITE)
	text_c("★".repeat(stars()) + "☆".repeat(3 - stars()), Vector2(640, 320), 44, C_GOLD)
	text_c("행동 %d회 · 실수 %d회" % [moves, mistakes], Vector2(640, 366), 20, C_INK)
	if level < level_count - 1:
		button(Rect2(420, 400, 210, 52), "다음 레벨 (Enter)", "__next", true, 18)
	else:
		button(Rect2(420, 400, 210, 52), "메뉴로 (Enter)", "__next", true, 18)
	button(Rect2(650, 400, 210, 52), "다시 하기 (R)", "__retry", true, 18)

# ---------- 도트 그리기 도우미 ----------
func snap(v: float) -> float:
	return floor(v / PX) * PX

func pbox(r: Rect2, fill: Color, border := C_INK, bevel := true) -> void:
	r = Rect2(snap(r.position.x), snap(r.position.y), snap(r.size.x), snap(r.size.y))
	draw_rect(r, border)
	var inner := r.grow(-PX)
	draw_rect(inner, fill)
	if bevel and inner.size.x > PX * 2 and inner.size.y > PX * 2:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, PX)), fill.lightened(0.25))
		draw_rect(Rect2(inner.position, Vector2(PX, inner.size.y)), fill.lightened(0.18))
		draw_rect(Rect2(inner.position.x, inner.end.y - PX, inner.size.x, PX), fill.darkened(0.3))
		draw_rect(Rect2(inner.end.x - PX, inner.position.y, PX, inner.size.y), fill.darkened(0.22))

func button(r: Rect2, label: String, id, enabled := true, size := 18, col := C_BLUE) -> bool:
	var hover := enabled and r.has_point(mouse)
	var fill := col if enabled else Color(0.45, 0.45, 0.5)
	if hover:
		fill = fill.lightened(0.18)
	var off := Vector2(0, 0)
	pbox(Rect2(r.position + Vector2(0, PX), r.size), C_INK, C_INK, false)
	pbox(Rect2(r.position + off, r.size), fill, C_INK)
	text_c(label, r.position + off + Vector2(r.size.x / 2, r.size.y / 2 + size * 0.36), size, C_WHITE if enabled else Color(0.85, 0.85, 0.85))
	_buttons.append([r, id, enabled])
	return hover

func hit(r: Rect2, id, enabled := true) -> bool:
	_buttons.append([r, id, enabled])
	return enabled and r.has_point(mouse)

func crate(r: Rect2, label: String, col := C_CRATE, highlight := false) -> void:
	pbox(r, col, C_INK)
	var i := r.grow(-PX * 3)
	draw_rect(Rect2(i.position.x, i.position.y + i.size.y / 2 - PX / 2, i.size.x, PX), col.darkened(0.25))
	var lw := text_w(label, 22) + 16
	pbox(Rect2(r.get_center().x - lw / 2, r.get_center().y - 18, lw, 36), C_WHITE, C_INK, false)
	text_c(label, r.get_center() + Vector2(0, 8), 22, C_INK)
	if highlight:
		outline(r.grow(PX * 2), C_GOLD)

func outline(r: Rect2, c: Color, w := PX) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, w)), c)
	draw_rect(Rect2(r.position.x, r.end.y - w, r.size.x, w), c)
	draw_rect(Rect2(r.position, Vector2(w, r.size.y)), c)
	draw_rect(Rect2(r.end.x - w, r.position.y, w, r.size.y), c)

func pcircle(c: Vector2, radius: float, fill: Color, border := C_INK) -> void:
	# 도트 원: 4px 행 단위로 채움
	var rr := snap(radius)
	var y := -rr
	while y < rr:
		var hw := snap(sqrt(max(0.0, rr * rr - (y + PX / 2) * (y + PX / 2))))
		draw_rect(Rect2(snap(c.x) - hw - PX, snap(c.y) + y, hw * 2 + PX * 2, PX), border)
		y += PX
	y = -rr + PX
	while y < rr - PX:
		var hw2 := snap(sqrt(max(0.0, (rr - PX) * (rr - PX) - (y + PX / 2) * (y + PX / 2))))
		var col := fill.lightened(0.2) if y < -rr / 2 else (fill.darkened(0.15) if y > rr / 2 else fill)
		draw_rect(Rect2(snap(c.x) - hw2, snap(c.y) + y, hw2 * 2, PX), col)
		y += PX

func node_bubble(c: Vector2, label: String, fill: Color, radius := 30.0, sub := "") -> void:
	pcircle(c, radius, fill)
	text_c(label, c + Vector2(0, 9), 24, C_WHITE)
	if sub != "":
		text_c(sub, c + Vector2(0, radius + 22), 15, C_WHITE)

func pline(a: Vector2, b: Vector2, c: Color, w := PX * 2) -> void:
	draw_line(a, b, C_INK, w + PX * 2)
	draw_line(a, b, c, w)

func arrow(a: Vector2, b: Vector2, c: Color, head := 14.0) -> void:
	pline(a, b, c)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var pts := PackedVector2Array([b, b - d * head + n * head * 0.6, b - d * head - n * head * 0.6])
	draw_colored_polygon(pts, c)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), C_INK, 2)

func robot(p: Vector2, carrying := "") -> void:
	# 16x16 도트 로봇 (x3)
	var s := 3.0
	var bob := 3.0 if fmod(time, 0.8) < 0.4 else 0.0
	var o := p + Vector2(-8 * s, -18 * s - bob)
	var rows := [
		"....11111111....",
		"...1222222221...",
		"..122222222221..",
		"..123333333321..",
		"..134433334431..",
		"..134433334431..",
		"..123333333321..",
		"...1222222221...",
		"....11111111....",
		"...1222222221...",
		"..122225522221..",
		"..122225522221..",
		"..122222222221..",
		"...1222222221...",
		"....11....11....",
		"....11....11....",
	]
	var pal := {"1": C_INK, "2": Color("eef2f7"), "3": Color("2a3140"), "4": Color("49f27a"), "5": Color("49f27a")}
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if pal.has(ch):
				draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(s, s)), pal[ch])
	if carrying != "":
		crate(Rect2(p.x - 26, o.y - 52, 52, 48), carrying)

func text(t: String, pos: Vector2, size: int, c: Color, max_w := -1.0) -> void:
	draw_string_outline(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, max_w, size, 4, Color(C_INK, c.a * 0.55) if c.v > 0.5 else Color(0, 0, 0, 0))
	draw_string(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, max_w, size, c)

func text_c(t: String, pos: Vector2, size: int, c: Color) -> void:
	text(t, Vector2(pos.x - text_w(t, size) / 2, pos.y), size, c)

func text_w(t: String, size: int) -> float:
	return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func label_box(r: Rect2, t: String, fill := C_PANEL, tc := C_INK, size := 18) -> void:
	pbox(r, fill, C_INK, false)
	text_c(t, r.position + Vector2(r.size.x / 2, r.size.y / 2 + size * 0.36), size, tc)
