extends MiniGameBase
## ST05 해시 - 이름으로 찾는 물품대장
## 등록 단계: 들어온 물품의 키 k 에 대해 h(k) = k mod 5 버킷을 클릭 (이미 있는 키면 '중복' 버튼 - 집합 규칙).
## 검색 단계: 키를 찾으려면 해당 버킷을 열고, 같은 버킷(충돌) 안에서도 정확한 키의 물품을 골라야 한다.

const M := 5
const LEVELS := [
	{"items": [[12, "포도"], [7, "배"], [3, "사과"], [10, "귤"]], "find": [7, 12], "goal": "h(k) = k mod 5 로 등록하고, 같은 버킷에서도 키를 구분해 찾기"},
	{"items": [[21, "감"], [6, "밤"], [11, "무"], [6, "밤"], [14, "콩"], [9, "쌀"]], "find": [11, 9, 6], "goal": "충돌(체이닝)과 중복 키(집합)를 처리하며 등록 후 검색"},
	{"items": [[25, "책"], [40, "펜"], [33, "컵"], [18, "솔"], [25, "책"], [8, "끈"], [13, "못"]], "find": [13, 40, 18], "goal": "긴 체인이 생겨도 정확히 찾아내기"},
]

var buckets: Array = []
var queue: Array = []
var finds: Array = []
var phase := "insert"
var open_bucket := -1
var probes := 0

func _init() -> void:
	stage_id = "ST05"
	stage_title = "이름으로 찾는 물품대장"
	level_count = LEVELS.size()

func setup_level(n: int) -> void:
	var L: Dictionary = LEVELS[n]
	buckets = []
	for i in M:
		buckets.append([])
	queue = L.items.duplicate(true)
	finds = L.find.duplicate()
	phase = "insert"
	open_bucket = -1
	probes = 0
	goal = L.goal

func get_state() -> Dictionary:
	return {"b": buckets, "q": queue, "f": finds, "p": phase, "o": open_bucket, "moves": moves}

func set_state(s: Dictionary) -> void:
	buckets = s.b
	queue = s.q
	finds = s.f
	phase = s.p
	open_bucket = s.o
	moves = s.moves

func count() -> int:
	var n := 0
	for b in buckets:
		n += b.size()
	return n

func has_key(k: int) -> bool:
	for it in buckets[k % M]:
		if it[0] == k:
			return true
	return false

func info_lines() -> Array:
	var cur := "-"
	if phase == "insert" and not queue.is_empty():
		cur = "%d: %s" % [queue[0][0], queue[0][1]]
	elif phase == "find" and not finds.is_empty():
		cur = "키 %d 찾기" % finds[0]
	return [["단계", "등록" if phase == "insert" else "검색"], ["현재", cur], ["항목", count()], ["해시", "k mod 5"]]

func controls_text() -> String:
	return "0~4 키 또는 클릭으로 버킷 선택 · 검색 단계에선 버킷 속 물품 클릭 · Z 되돌리기 · R 초기화"

func on_key(ev: InputEventKey) -> bool:
	if ev.keycode >= KEY_0 and ev.keycode <= KEY_4:
		on_button(ev.keycode - KEY_0)
		return true
	if ev.keycode == KEY_X:
		on_button("dup")
		return true
	return false

func on_button(id) -> void:
	if phase == "insert":
		if queue.is_empty():
			return
		var k: int = queue[0][0]
		if str(id) == "dup":
			if has_key(k):
				push_undo()
				queue.pop_front()
				moves += 1
				good("키 %d 는 이미 있어 등록 거절 (집합: 중복 불가)" % k)
				_after_insert()
			else:
				wrong("키 %d 는 아직 없는 키예요." % k, "dup")
			return
		if typeof(id) != TYPE_INT:
			return
		if has_key(k):
			wrong("키 %d 는 이미 등록되어 있어요 → '중복' 버튼!" % k, id)
			return
		if id != k % M:
			wrong("%d mod 5 = %d 이에요. 버킷 %d 이 아니에요." % [k, k % M, id], id)
			return
		push_undo()
		buckets[id].append(queue.pop_front())
		moves += 1
		good("%d → 버킷 %d" % [k, id], id)
		_after_insert()
	else:
		if finds.is_empty():
			return
		var key: int = finds[0]
		if typeof(id) == TYPE_INT:
			if id != key % M:
				wrong("키 %d 는 버킷 %d 에 있어요 (%d mod 5)." % [key, key % M, key], id)
				return
			open_bucket = id
			probes = 0
			say("버킷 %d 을 열었어요. 키 %d 인 물품을 고르세요." % [id, key])
		elif str(id).begins_with("item_"):
			var parts := str(id).split("_")
			var b := int(parts[1])
			var i := int(parts[2])
			var it = buckets[b][i]
			probes += 1
			if it[0] != key:
				wrong("이 물품의 키는 %d 예요. 키를 비교해 구분하세요." % it[0], "item_%d_%d" % [b, i])
				return
			push_undo()
			moves += 1
			finds.pop_front()
			open_bucket = -1
			good("찾았다! %d: %s" % [it[0], it[1]])
			if finds.is_empty():
				win("등록 %d건, 검색 완료!" % count())

func _after_insert() -> void:
	if queue.is_empty():
		phase = "find"
		say("등록 끝! 이제 검색 단계예요. 키 %d 를 찾으세요." % finds[0], C_GOLD, 4.0)

func draw_game() -> void:
	# 버킷 (사물함)
	for b in M:
		var x := 120 + b * 172
		var r := Rect2(x, 120, 148, 380)
		var col := C_BLUE
		if open_bucket == b:
			col = C_GOLD.darkened(0.2)
		if flashing(b):
			col = C_RED
		var hov := hit(Rect2(x, 120, 148, 72), b, not level_done)
		pbox(Rect2(x, 120, 148, 72), col.lightened(0.2) if hov else col, C_INK)
		text_c(str(b), Vector2(x + 74, 168), 32, C_WHITE)
		pbox(Rect2(x, 196, 148, 304), Color("2f3a52"), C_INK)
		for i in buckets[b].size():
			var it = buckets[b][i]
			var ir := Rect2(x + 10, 208 + i * 72, 128, 64)
			var hidden := phase == "find" and open_bucket != b
			var key := "item_%d_%d" % [b, i]
			if hidden:
				pbox(ir, Color("55607a"), C_INK, false)
				text_c("?", ir.get_center() + Vector2(0, 9), 24, C_WHITE)
			else:
				var h2 := hit(ir, key, phase == "find" and not level_done)
				var fill := C_RED if flashing(key) else (Color("fff2c8") if h2 else C_PANEL)
				pbox(ir, fill, C_INK, false)
				text_c(str(it[0]), ir.position + Vector2(64, 28), 22, C_BLUE_D)
				text_c(it[1], ir.position + Vector2(64, 54), 17, C_INK)
			if i < buckets[b].size() - 1:
				text_c("↓", Vector2(x + 74, 278 + i * 72), 14, C_GOLD)
	# 해시 함수 표지판
	pbox(Rect2(120, 520, 330, 76), C_PANEL, C_INK)
	text("h(k) = k mod 5", Vector2(150, 568), 28, C_INK)
	# 현재 물품 / 검색 요청
	pbox(Rect2(470, 520, 300, 76), Color("5b6475"), C_INK)
	if phase == "insert" and not queue.is_empty():
		var k: int = queue[0][0]
		text("입고:", Vector2(490, 566), 18, C_WHITE)
		crate(Rect2(556, 528, 120, 60), "%d %s" % [k, queue[0][1]])
		text("남음 %d" % (queue.size() - 1), Vector2(690, 566), 16, C_WHITE)
	elif phase == "find" and not finds.is_empty():
		text("검색 요청:  키 %d" % finds[0], Vector2(490, 566), 22, C_GOLD)
	button(Rect2(790, 520, 210, 76), "중복 (거절) X", "dup", phase == "insert" and not level_done, 18, C_RED if flashing("dup") else Color("7a4f2a"))
	robot(Vector2(60, 600), "")
