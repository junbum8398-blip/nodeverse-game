extends MiniGameBase
## ST01 배열 - 순서가 있는 보관소
## 배경 그림 속 보관함 0~4번 칸이 그대로 배열이다. 상자는 바로 옆 빈칸으로만 한 칸씩 옮길 수 있다.
## 삽입: 뒤쪽 상자부터 오른쪽으로 밀어 자리를 만든 뒤 입고 트레이의 새 상자를 넣는다.
## 삭제: 지울 상자를 반환함에 넣고, 뒤쪽 상자들을 왼쪽으로 당겨 빈틈을 없앤다.

const CAP := 5
const S := BG_SCALE
const SLOT_X := [477.0, 642.0, 807.0, 972.0, 1137.0]   # 원본 그림 속 칸 중심
const LEVELS := [
	{"arr": [10, 30, 40], "tray": 20, "target": [10, 20, 30, 40], "goal": "인덱스 1에 20 넣기", "opt": 3},
	{"arr": [10, 20, 30, 40], "tray": null, "target": [20, 30, 40], "goal": "인덱스 0의 10 지우기 (빈칸 없이 당기기)", "opt": 4},
	{"arr": [15, 25, 35, 45], "tray": 5, "target": [5, 15, 25, 35, 45], "goal": "인덱스 0에 5 넣기", "opt": 5},
	{"arr": [7, 14, 99, 21, 28], "tray": null, "target": [7, 14, 21, 28], "goal": "인덱스 2의 99 지우기 (빈칸 없이 당기기)", "opt": 3},
]

var slots: Array = []
var tray = null
var hand = null           # {"v": 값, "from": 칸 번호 또는 "tray"}
var cursor := 0
var target: Array = []
var opt := 0

func _init() -> void:
	stage_id = "ST01"
	stage_title = "순서가 있는 보관소"
	level_count = LEVELS.size()
	overlay_alpha = 0.08

func tutorial() -> Array:
	return [
		["보관함 0~4번 칸이 배열이에요", "칸 번호가 인덱스예요. 배열은 중간에 빈칸이 있으면 안 돼요."],
		["상자는 바로 옆 칸으로만 한 칸씩", "상자를 클릭해 집고, 옆 빈칸을 클릭해 내려놓아요. (키보드: ←/→ 이동, E 집기·놓기)"],
		["넣을 땐 뒤에서부터 밀고, 지울 땐 당겨요", "새 상자는 입고 트레이에, 지울 상자는 반환함에 있어요.", "막히면 반짝이는 곳을 따라 해 보세요. Z 되돌리기, R 처음부터."],
	]

func setup_level(n: int) -> void:
	var L: Dictionary = LEVELS[n]
	slots = []
	for i in CAP:
		slots.append(L.arr[i] if i < L.arr.size() else null)
	tray = L.tray
	hand = null
	cursor = 0
	target = L.target
	goal = L.goal
	opt = L.opt

func get_state() -> Dictionary:
	return {"slots": slots, "tray": tray, "hand": hand, "cursor": cursor, "moves": moves}

func set_state(s: Dictionary) -> void:
	slots = s.slots
	tray = s.tray
	hand = s.hand
	cursor = s.cursor
	moves = s.moves

func length() -> int:
	var n := 0
	for v in slots:
		if v != null:
			n += 1
	return n

func info_lines() -> Array:
	return [["길이", length()], ["용량", CAP], ["이동", "%d (최소 %d)" % [moves, opt]]]

func controls_text() -> String:
	return "상자 클릭=집기 · 빈칸 클릭=놓기 · 트레이/반환함 클릭 · H 도움말 · Z 되돌리기 · R 초기화"

# ---------- 위치 (원본 그림 좌표 -> 화면) ----------
func slot_center(i: int) -> Vector2:
	return Vector2(SLOT_X[i], 412) * S

func slot_rect(i: int) -> Rect2:
	return Rect2(Vector2(SLOT_X[i] - 72, 330) * S, Vector2(144, 176) * S)

func crate_rect(c: Vector2) -> Rect2:
	return Rect2(c - Vector2(42, 42), Vector2(84, 84))

func tray_rect() -> Rect2:
	return Rect2(Vector2(560, 570) * S, Vector2(210, 130) * S)

func bin_rect() -> Rect2:
	return Rect2(944, 488, 112, 92)

# ---------- 입력 ----------
func on_key(ev: InputEventKey) -> bool:
	match ev.keycode:
		KEY_LEFT, KEY_A: cursor = max(0, cursor - 1)
		KEY_RIGHT, KEY_D: cursor = min(CAP - 1, cursor + 1)
		KEY_E, KEY_SPACE: on_button(cursor)
		KEY_T: on_button("tray")
		KEY_X: on_button("bin")
		_: return false
	return true

func on_button(id) -> void:
	if typeof(id) == TYPE_INT:
		cursor = id
		_slot_action(id)
	elif id == "tray":
		if hand == null and tray != null:
			push_undo()
			hand = {"v": tray, "from": "tray"}
			tray = null
			say("새 상자 %d 을(를) 들었어요. 넣을 칸을 클릭하세요." % hand.v)
		elif hand != null and typeof(hand.from) != TYPE_INT:
			push_undo()
			tray = hand.v
			hand = null
		elif hand != null:
			wrong("입고 트레이에는 새 상자만 돌려놓을 수 있어요.")
		else:
			wrong("트레이가 비어 있어요.")
	elif id == "bin":
		if hand == null:
			wrong("먼저 지울 상자를 클릭해 집으세요.")
			return
		if typeof(hand.from) != TYPE_INT:
			wrong("새 상자는 버리지 말고 배열에 넣어야 해요.")
			return
		if hand.v in target:
			wrong("%d 은(는) 남겨야 하는 상자예요." % hand.v)
			return
		push_undo()
		good("%d 삭제! 이제 뒤쪽 상자들을 왼쪽으로 당겨 빈칸을 메우세요." % hand.v)
		hand = null
		moves += 1
		_check()

func _slot_action(i: int) -> void:
	if hand == null:
		if slots[i] == null:
			wrong("빈칸이에요. 상자가 있는 칸을 클릭해 집으세요.", i)
			return
		push_undo()
		hand = {"v": slots[i], "from": i}
		slots[i] = null
		return
	if slots[i] != null:
		wrong("이미 상자가 있는 칸이에요.", i)
		return
	if typeof(hand.from) == TYPE_INT and abs(int(hand.from) - i) > 1:
		wrong("상자는 바로 옆 칸으로만 한 칸씩 옮길 수 있어요.", i)
		return
	push_undo()
	slots[i] = hand.v
	if typeof(hand.from) != TYPE_INT or hand.from != i:
		moves += 1
	hand = null
	_check()

func _check() -> void:
	if hand != null:
		return
	var arr := []
	var gap := false
	for v in slots:
		if v == null:
			gap = true
		elif gap:
			return
		else:
			arr.append(v)
	if arr == target:
		if moves > opt:
			mistakes = max(mistakes, 1)
		win("배열 완성! %s  (이동 %d회, 최소 %d회)" % [str(arr), moves, opt])

# ---------- 다음 행동 안내 ----------
func _next_action() -> Array:
	# [대상("slot"/"tray"/"bin"), 칸 번호, 설명]
	if hand != null:
		if typeof(hand.from) != TYPE_INT:
			var t := target.find(hand.v)
			return ["slot", t, "인덱스 %d 에 놓기" % t]
		if not (hand.v in target):
			return ["bin", -1, "반환함에 넣어 삭제"]
		var ti := target.find(hand.v)
		var j: int = hand.from
		if ti == j:
			return ["slot", j, "제자리에 다시 놓기"]
		var to := j + (1 if ti > j else -1)
		return ["slot", to, "옆 칸으로 한 칸 옮기기"]
	for j in CAP:
		if slots[j] != null and not (slots[j] in target):
			return ["slot", j, "지울 상자 집기"]
	for j in range(CAP - 1, -1, -1):
		if slots[j] != null and target.find(slots[j]) > j and j + 1 < CAP and slots[j + 1] == null:
			return ["slot", j, "맨 뒤부터 오른쪽으로 밀기"]
	for j in CAP:
		if slots[j] != null and j > 0 and target.find(slots[j]) < j and slots[j - 1] == null:
			return ["slot", j, "왼쪽으로 당기기"]
	if tray != null:
		return ["tray", -1, "새 상자 집기"]
	return ["", -1, ""]

func hint_rect() -> Rect2:
	var a := _next_action()
	match a[0]:
		"slot": return slot_rect(a[1])
		"tray": return tray_rect()
		"bin": return bin_rect()
	return Rect2()

func hint_text() -> String:
	return _next_action()[2]

# ---------- 그리기 ----------
func draw_game() -> void:
	for i in CAP:
		var r := slot_rect(i)
		var hov := hit(r, i, not level_done)
		if flashing(i):
			draw_rect(r, Color(C_RED, 0.45))
		elif hov:
			draw_rect(r, Color(1, 1, 1, 0.12))
		if i == cursor:
			outline(r, Color(C_WHITE, 0.7))
		if slots[i] != null:
			crate(crate_rect(slot_center(i)), str(slots[i]))
	# 입고 트레이
	var tr := tray_rect()
	hit(tr, "tray", not level_done)
	if tray != null:
		crate(crate_rect(Vector2(665, 628) * S), str(tray))
	# 반환함
	var br := bin_rect()
	hit(br, "bin", not level_done)
	pbox(br, C_CRATE_D, C_INK)
	draw_rect(Rect2(br.position + Vector2(12, 12), Vector2(br.size.x - 24, 20)), Color("2b1a0e"))
	label_box(Rect2(br.position.x + 8, br.end.y - 40, br.size.x - 16, 30), "반환함", C_WHITE, C_INK, 15)
	# 완성 모습
	var px := 600.0
	pbox(Rect2(px, 604, 120 + target.size() * 60, 56), Color(0.1, 0.1, 0.14, 0.85), C_INK)
	text("완성 모습", Vector2(px + 16, 640), 17, C_GOLD)
	for i in target.size():
		label_box(Rect2(px + 108 + i * 60, 612, 54, 40), str(target[i]), C_PANEL, C_INK, 18)
	# 로봇 (선택한 칸 아래, 들고 있는 상자 표시)
	robot(Vector2(slot_center(cursor).x, 474), "" if hand == null else str(hand.v))
