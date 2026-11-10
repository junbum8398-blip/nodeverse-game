extends "res://scripts/play/walk_stage.gd"
## 시안 위를 걸어 다니는 실습 공통 틀. 분야별 스크립트(structure_labs, algo_labs, sql_labs, data_labs)가 이어받는다.
## ST01~ST10 과 같은 구조: NPC 설명 → WASD 로 로봇 이동 → 시안 속 장치 앞에서 E → 오른쪽 코드 패널.
## 씬은 tools/write_lab_scenes.py 가 만들고, 장치 위치는 씬의 St0, St1 ... 지점이다.

const CREAM := Color("fbf1d6")
const PANEL_BG := Color(0.97, 0.93, 0.83, 0.97)
const NULL_FILL := Color("e6e0d0")
const INK := Color("1d1b2a")
const NAVY := Color("1d3a73")
const BLUE := Color("2f5fb3")
const GOLD := Color("f2c14e")
const RED := Color("d64545")
const TEAL := Color("3a7f6d")
const WOOD := Color("6b4a2b")

@export var activity := ""

var goal: String:
	set(v):
		goal_text = v
	get:
		return goal_text
var level_done: bool:
	get:
		return done

var state := {}
var info := {}
var problem := 0
var hint_step := 0
var hints_used := 0
var clear_note := ""
var input_field := ""
var popup := ""
var font: Font
var board: Node2D
var _cv: CanvasItem
var _st: Array = []
var _pop_canvas: Node2D

# ---------- 하위 클래스가 구현 ----------
func lab_table() -> Dictionary: return {}
func problems_for(_n: int) -> Array: return [{}]
func setup_problem(_p) -> void: pass
func handle(_key: String) -> void: pass
func draw_board() -> void: pass
func draw_popup(_kind: String) -> void: pass
func state_code() -> String: return ""
func lab_rows() -> Array: return []
## 장치 목록: St 번호 순서로 [동작 키, 말풍선 문구, 바닥 표지] 또는 null(이번 문제에서 안 씀)
func stations() -> Array: return []
## 다음에 해야 할 동작 키 (실수 뒤 노란 화살표). 조립형 게임은 "" 로 둔다.
func next_key() -> String: return ""
func action_keys() -> Dictionary: return {}
func input_locked() -> bool: return false

# ---------- 준비 ----------
func _ready() -> void:
	info = lab_table()[activity]
	stage_id = info.id
	stage_title = info.title
	level_count = info.levels
	npc_name = info.npc_name
	npc_portrait = load("res://textures/npc_portraits/%s_portrait.png" % info.npc)
	intro = info.intro
	level_talk = info.talk
	hint_after_mistake = true
	code_keywords += ["SELECT", "FROM", "WHERE", "ORDER", "BY", "LIMIT", "JOIN", "ON", "GROUP", "HAVING", "IN", "AND", "OR", "LEFT", "INNER"]
	font = load("res://fonts/NotoSansKR_Medium.tres")
	super._ready()
	hud.set_controls("WASD 이동 · E 조작 · F 힌트 · Z 되돌리기 · R 초기화 · H 도움말 · Esc 메뉴")

func build_stage() -> void:
	hud.toast_y = 664.0       # 알림이 시안 위의 표를 가리지 않게 화면 아래쪽에 띄운다
	hud.toast_center_x = 484.0
	board = Node2D.new()
	overlay.add_child(board)
	board.draw.connect(_draw_board_layer)
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	_pop_canvas = Node2D.new()
	layer.add_child(_pop_canvas)
	_pop_canvas.draw.connect(_draw_popup_layer)

func setup_level(_n: int) -> void:
	problem = 0
	hint_step = 0
	clear_note = ""
	popup = ""
	_begin_problem()

func problems() -> Array:
	return problems_for(level)

func _begin_problem() -> void:
	state = {}
	input_field = ""
	setup_problem(problems()[problem])

## 현재 문제를 끝내고 다음 문제로 넘어간다. 마지막 문제면 레벨 완료.
func finish_problem(note_text: String) -> void:
	clear_note = note_text
	if problem < problems().size() - 1:
		problem += 1
		code("")
		_undo.clear()
		_begin_problem()
		hud.set_goal(goal_text)
		good(note_text)
	else:
		win(note_text)

func win(t: String) -> void:
	super.win("%s\n행동 %d회 · 실수 %d회 · 힌트 %d회" % [clear_note if clear_note != "" else t, moves, mistakes, hints_used])

func say(t: String, c := Color.WHITE, dur := 2.6) -> void:
	hud.toast(t, c, dur)

func get_state() -> Dictionary:
	return {"state": state.duplicate(true), "field": input_field}

func set_state(s: Dictionary) -> void:
	state = s.state.duplicate(true)
	input_field = s.field

func undo() -> void:
	undo_last()

func step() -> void:
	snapshot()
	moves += 1

func use_hint() -> void:
	if done:
		return
	var h: Array = info.hints
	hud.toast(h[hint_step], StageHUD.GOLD, 7.0)
	hint_step = mini(hint_step + 1, h.size() - 1)
	hints_used += 1
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.call("record_operation", "hint", true, "", {}, {}, {"hints": hints_used, "stage": stage_id})

# ---------- 장치와 입력 ----------
func rebuild() -> void:
	_st = stations()
	var i := 0
	while spot("st", i) != null:
		spot("st", i).enabled = i < _st.size() and _st[i] != null
		i += 1
	board.queue_redraw()
	_pop_canvas.queue_redraw()
	player.active = popup == "" and not done and not hud.dialogue_open() and not input_locked()

func interact(t: Interactable) -> void:
	if t.kind == "st" and t.index < _st.size() and _st[t.index] != null:
		on_button(_st[t.index][0])

func prompt(t: Interactable) -> String:
	if t.kind == "st" and t.index < _st.size() and _st[t.index] != null:
		return _st[t.index][1]
	return t.prompt

func next_action() -> Array:
	var k := next_key()
	if k != "":
		for i in _st.size():
			if _st[i] != null and _st[i][0] == k:
				return [spot("st", i), _st[i][1]]
	return [null, ""]

func state_text() -> String:
	return state_code().replace("[", "[lb]")

func info_rows() -> Array:
	return lab_rows()

func on_button(id) -> void:
	var key := str(id)
	if key.begins_with("view:"):
		popup = key.trim_prefix("view:")
	elif key.begins_with("field:"):
		input_field = key.trim_prefix("field:")
		hud.toast("숫자 키로 입력하세요. 지우기는 Backspace", StageHUD.GOLD)
	elif key.begins_with("key:"):
		_key_input(key.trim_prefix("key:"))
	else:
		handle(key)
	rebuild()
	refresh()

func _key_input(k: String) -> void:
	if input_field == "" or not state.has("fields"):
		return
	var cur: String = state.fields.get(input_field, "")
	match k:
		"back": cur = cur.left(maxi(cur.length() - 1, 0))
		"-": cur = cur.trim_prefix("-") if cur.begins_with("-") else "-" + cur
		".":
			if not cur.contains("."):
				cur += "."
		_:
			if cur.length() < 8:
				cur += k
	state.fields[input_field] = cur

func field_number(key: String) -> float:
	var t: String = state.fields.get(key, "")
	return float(t) if t.is_valid_float() else NAN

func _unhandled_input(ev: InputEvent) -> void:
	if popup != "":
		if (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventMouseButton and ev.pressed):
			popup = ""
			rebuild()
			get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and not hud.dialogue_open() and not done:
		if ev.keycode == KEY_F:
			use_hint()
			return
		var actions := action_keys()
		if actions.has(ev.keycode):
			on_button(actions[ev.keycode])
			return
		if input_field != "":
			var digit: int = ev.keycode - KEY_0
			if digit >= 0 and digit <= 9:
				on_button("key:%d" % digit)
				return
			match ev.keycode:
				KEY_BACKSPACE:
					on_button("key:back")
					return
				KEY_PERIOD:
					on_button("key:.")
					return
				KEY_MINUS:
					on_button("key:-")
					return
	super._unhandled_input(ev)

# ---------- 시안 위 그리기 ----------
func _draw_board_layer() -> void:
	_cv = board
	draw_board()
	for i in _st.size():
		if _st[i] != null and _st[i].size() > 2 and _st[i][2] != "" and spot("st", i) != null:
			var focused: bool = player.focus == spot("st", i)
			plate(spot("st", i).position + Vector2(0, -10), _st[i][2], 18, GOLD if focused else CREAM)

func _draw_popup_layer() -> void:
	if popup == "":
		return
	_cv = _pop_canvas
	_cv.draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.5))
	var r := Rect2(120, 90, 1040, 540)
	_cv.draw_rect(r, INK)
	_cv.draw_rect(r.grow(-4), PANEL_BG)
	draw_popup(popup)
	text(Vector2(640, 612), "아무 키나 누르면 닫혀요", 18, WOOD, true)

func text(p: Vector2, t: String, size := 20, c := INK, center := false) -> void:
	var x := p.x
	if center:
		x -= font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2
	_cv.draw_string(font, Vector2(x, p.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

func wrapped(p: Vector2, t: String, width: float, size := 18, c := INK) -> void:
	_cv.draw_multiline_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, c)

func text_width(t: String, size: int) -> float:
	return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func fit_size(t: String, width: float, size: int) -> int:
	var s := size
	while s > 10 and text_width(t, s) > width - 8:
		s -= 1
	return s

## 시안 위에 얹는 작은 명패. c 는 명패 중앙.
func plate(c: Vector2, t: String, size := 20, fill := CREAM, tc := INK, min_w := 0.0) -> void:
	var w := maxf(text_width(t, size) + 18, min_w)
	var h := size * 1.55
	var r := Rect2(c - Vector2(w, h) / 2, Vector2(w, h))
	_cv.draw_rect(r, INK)
	_cv.draw_rect(r.grow(-2), fill)
	text(Vector2(c.x, c.y + size * 0.36), t, size, tc, true)

func box_cell(r: Rect2, t: String, fill := CREAM, tc := INK, size := 18) -> void:
	_cv.draw_rect(r, INK)
	_cv.draw_rect(r.grow(-1.5), fill)
	var s := fit_size(t, r.size.x, size)
	text(Vector2(r.get_center().x, r.get_center().y + s * 0.36), t, s, tc, true)

func display(v) -> String:
	if v == null:
		return "NULL"
	if v is float:
		return str(int(v)) if is_equal_approx(v, round(v)) else str(snappedf(v, 0.01))
	return str(v)

func table_at(origin: Vector2, headers: Array, rows: Array, width: float, row_h := 28.0, size := 18, dim := []) -> void:
	if headers.is_empty():
		return
	var w: float = width / headers.size()
	for c in headers.size():
		box_cell(Rect2(origin + Vector2(c * w, 0), Vector2(w, row_h)), str(headers[c]), BLUE, Color.WHITE, size)
	for r in rows.size():
		for c in rows[r].size():
			var v = rows[r][c]
			var dimmed: bool = dim.has(r)
			box_cell(Rect2(origin + Vector2(c * w, (r + 1) * row_h), Vector2(w, row_h)), display(v), Color("b9b4a6") if dimmed else (NULL_FILL if v == null else CREAM), Color(0.35, 0.33, 0.3) if dimmed else INK, size)

## 시안의 벽에 거는 나무 게시판 표. 조작 중에도 항상 보인다.
func wall_table(origin: Vector2, title: String, headers: Array, rows: Array, width: float, row_h := 26.0, size := 18, dim := []) -> void:
	var height: float = (rows.size() + 1) * row_h
	var frame := Rect2(origin - Vector2(10, 30), Vector2(width + 20, height + 40))
	_cv.draw_rect(frame.grow(2), INK)
	_cv.draw_rect(frame, WOOD)
	text(origin + Vector2(2, -8), title, 20, Color("fff0c8"))
	table_at(origin, headers, rows, width, row_h, size, dim)

func cover(r: Rect2, fill := Color("b89a7c")) -> void:
	_cv.draw_rect(r, fill)

func ink_line(a: Vector2, b: Vector2, c := BLUE, w := 6.0) -> void:
	_cv.draw_line(a, b, INK, w + 4.0)
	_cv.draw_line(a, b, c, w)

func ink_arrow(a: Vector2, b: Vector2, c := BLUE) -> void:
	ink_line(a, b, c)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	_cv.draw_colored_polygon(PackedVector2Array([b, b - d * 18 + n * 11, b - d * 18 - n * 11]), c)

func ring(c: Vector2, r: float, col := GOLD) -> void:
	_cv.draw_arc(c, r, 0, TAU, 32, INK, 7.0)
	_cv.draw_arc(c, r, 0, TAU, 32, col, 4.0)
