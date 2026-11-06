extends MiniGameBase
## ST04 큐/덱 - 접수 순서 안내소
## 대기열(FRONT ← … ← REAR)에 손님을 넣고 빼서 '창구 처리 순서'를 목표대로 맞춘다.
## 큐 모드: 뒤에 넣기 / 앞에서 빼기만 가능.  덱 모드: 양쪽 끝 모두 넣기/빼기 가능.

const LEVELS := [
	{"mode": "queue", "line": ["A", "B", "C"], "arrive": ["D"], "target": ["A", "B"], "goal": "A를 창구에 전달하고, 이어서 B도 전달하기"},
	{"mode": "queue", "line": ["A"], "arrive": ["B", "C", "D"], "target": ["A", "B", "C", "D"], "goal": "도착한 순서대로 모두 처리하기 (FIFO)"},
	{"mode": "deque", "line": ["A", "B", "C"], "arrive": ["V"], "target": ["V", "A", "B", "C"], "goal": "긴급 손님 V를 가장 먼저 처리하기"},
	{"mode": "deque", "line": ["A", "B", "C", "D"], "arrive": [], "target": ["D", "A", "B", "C"], "goal": "마지막에 선 D를 먼저, 그다음 A, B, C 처리하기"},
	{"mode": "deque", "line": ["A"], "arrive": ["X", "Y"], "target": ["Y", "A", "X"], "goal": "처리 순서를 Y → A → X 로 만들기 (X가 먼저 도착)"},
]
const COLORS := {"A": "e05252", "B": "e8a33d", "C": "4caf50", "D": "3d7bd9", "V": "c04fd8", "X": "2bb3a8", "Y": "d8577e"}

var mode := "queue"
var line: Array = []
var arrive: Array = []
var served: Array = []
var target: Array = []

func _init() -> void:
	stage_id = "ST04"
	stage_title = "접수 순서 안내소"
	level_count = LEVELS.size()

func setup_level(n: int) -> void:
	var L: Dictionary = LEVELS[n]
	mode = L.mode
	line = L.line.duplicate()
	arrive = L.arrive.duplicate()
	served = []
	target = L.target
	goal = L.goal

func get_state() -> Dictionary:
	return {"line": line, "arrive": arrive, "served": served, "moves": moves}

func set_state(s: Dictionary) -> void:
	line = s.line
	arrive = s.arrive
	served = s.served
	moves = s.moves

func info_lines() -> Array:
	return [["모드", "큐" if mode == "queue" else "덱"], ["앞 (Front)", "-" if line.is_empty() else line[0]],
		["뒤 (Rear)", "-" if line.is_empty() else line.back()], ["처리", " ".join(served) if not served.is_empty() else "-"]]

func controls_text() -> String:
	return "Q 앞에서 빼기 · W 뒤에 넣기" + (" · A 앞에 넣기 · S 뒤에서 빼기" if mode == "deque" else "") + " · Z 되돌리기 · R 초기화"

func on_key(ev: InputEventKey) -> bool:
	match ev.keycode:
		KEY_Q: on_button("pop_front")
		KEY_W: on_button("push_back")
		KEY_A: on_button("push_front")
		KEY_S: on_button("pop_back")
		_: return false
	return true

func on_button(id) -> void:
	var deque_only: bool = id == "push_front" or id == "pop_back"
	if deque_only and mode == "queue":
		wrong("큐 모드에서는 앞에 넣거나 뒤에서 뺄 수 없어요.", id)
		return
	if (id == "push_back" or id == "push_front") and arrive.is_empty():
		wrong("기다리는 도착 손님이 없어요.", id)
		return
	if (id == "pop_front" or id == "pop_back") and line.is_empty():
		wrong("대기열이 비었어요.", id)
		return
	push_undo()
	moves += 1
	match id:
		"push_back": line.append(arrive.pop_front())
		"push_front": line.push_front(arrive.pop_front())
		"pop_front", "pop_back":
			var p = line.pop_front() if id == "pop_front" else line.pop_back()
			var expect = target[served.size()] if served.size() < target.size() else null
			if p != expect:
				_undo.pop_back()
				if id == "pop_front":
					line.push_front(p)
				else:
					line.append(p)
				moves -= 1
				wrong("지금 창구에 갈 손님은 %s 예요. (%s 아님)" % [str(expect), p], id)
				return
			served.append(p)
			good("%s 처리 완료" % p)
			if served == target:
				win("처리 순서 %s 완성!" % " → ".join(served))

func chip(c: Vector2, who: String, s := 64.0) -> void:
	var r := Rect2(c - Vector2(s / 2, s / 2), Vector2(s, s))
	pbox(r, Color(COLORS.get(who, "888888")), C_INK)
	text_c(who, c + Vector2(0, 11), 30, C_WHITE)

func draw_game() -> void:
	# 창구
	pbox(Rect2(40, 120, 200, 180), C_PANEL_DARK, C_INK)
	label_box(Rect2(80, 132, 120, 40), "창구", C_BLUE, C_WHITE, 22)
	for i in served.size():
		chip(Vector2(80 + (i % 3) * 56, 212 + (i / 3) * 56), served[i], 48)
	# 대기열 컨베이어
	var y := 380.0
	pbox(Rect2(250, y - 54, 640, 108), Color("5b6475"), C_INK)
	label_box(Rect2(120, y - 30, 110, 60), "", C_BLUE, C_WHITE, 18)
	text_c("FRONT", Vector2(175, y + 7), 18, C_WHITE)
	label_box(Rect2(910, y - 30, 100, 60), "", C_BLUE, C_WHITE, 18)
	text_c("REAR", Vector2(960, y + 7), 18, C_WHITE)
	for i in line.size():
		chip(Vector2(300 + i * 76, y), line[i])
		if i > 0:
			text_c("←", Vector2(300 + i * 76 - 38, y + 8), 20, C_WHITE)
	arrow(Vector2(170, y - 40), Vector2(170, 300), C_GOLD)
	# 도착 대기
	pbox(Rect2(890, 470, 120, 150), Color("3a4255"), C_INK)
	text_c("도착", Vector2(950, 500), 18, C_WHITE)
	if not arrive.is_empty():
		chip(Vector2(950, 545), arrive[0], 56)
	if arrive.size() > 1:
		text_c("+%d" % (arrive.size() - 1), Vector2(950, 606), 16, C_WHITE)
	# 조작 버튼
	var en := not level_done
	button(Rect2(250, 470, 200, 56), "앞에서 빼기 Q", "pop_front", en, 18, C_RED if flashing("pop_front") else C_BLUE)
	button(Rect2(470, 470, 200, 56), "뒤에 넣기 W", "push_back", en, 18, C_RED if flashing("push_back") else C_BLUE)
	var dq := mode == "deque"
	button(Rect2(250, 540, 200, 56), "앞에 넣기 A", "push_front", en and dq, 18, C_RED if flashing("push_front") else Color("7b4fc4"))
	button(Rect2(470, 540, 200, 56), "뒤에서 빼기 S", "pop_back", en and dq, 18, C_RED if flashing("pop_back") else Color("7b4fc4"))
	# 목표 순서
	pbox(Rect2(690, 120, 320, 120), C_PANEL, C_INK)
	text("창구 처리 목표", Vector2(710, 152), 18, C_PANEL_DARK)
	for i in target.size():
		var c := Vector2(730 + i * 64, 196)
		chip(c, target[i], 48)
		if i < served.size():
			text_c("✓", c + Vector2(18, -18), 20, C_GREEN)
	robot(Vector2(170, 620), "")
