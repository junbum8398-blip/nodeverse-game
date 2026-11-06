extends MiniGameBase
## ST08 힙(최소 힙) - 긴급 작업 배정실
## 삽입: 다음 빈자리(배열의 끝)를 클릭해 놓고 → 부모보다 작으면 '부모와 교환' 반복(sift-up).
## 꺼내기: 루트(최솟값)를 꺼내면 마지막 원소가 루트로 → 더 작은 자식과 교환 반복(sift-down).

const LEVELS := [
	{"heap": [2, 5, 3, 9, 7], "tasks": [["insert", 1]]},
	{"heap": [2, 5, 3, 9, 7, 8], "tasks": [["insert", 4], ["insert", 6]]},
	{"heap": [1, 3, 2, 7, 4, 5], "tasks": [["extract"]]},
	{"heap": [2, 4, 3, 8, 5, 9, 6], "tasks": [["extract"], ["insert", 1], ["extract"]]},
]

var heap: Array = []
var tasks: Array = []
var phase := ""      # place / up / take / down
var idx := -1
var outbox: Array = []

func _init() -> void:
	stage_id = "ST08"
	stage_title = "긴급 작업 배정실"
	level_count = LEVELS.size()

func setup_level(n: int) -> void:
	var L: Dictionary = LEVELS[n]
	heap = L.heap.duplicate()
	tasks = L.tasks.duplicate(true)
	outbox = []
	_begin()

func _begin() -> void:
	idx = -1
	if tasks.is_empty():
		return
	var t = tasks[0]
	if t[0] == "insert":
		phase = "place"
		goal = "다음 빈자리에 %d 놓기, 그다음 부모와 비교해 위로 올리기" % t[1]
	else:
		phase = "take"
		goal = "가장 급한 작업(최솟값) 꺼내고, 새 루트를 아래로 내리기"

func get_state() -> Dictionary:
	return {"h": heap, "t": tasks, "p": phase, "i": idx, "o": outbox, "moves": moves}

func set_state(s: Dictionary) -> void:
	heap = s.h
	tasks = s.t
	phase = s.p
	idx = s.i
	outbox = s.o
	moves = s.moves

func info_lines() -> Array:
	return [["다음 위치", heap.size()], ["최솟값", "-" if heap.is_empty() else heap[0]], ["크기", heap.size()], ["꺼낸 작업", " ".join(outbox.map(func(x): return str(x))) if not outbox.is_empty() else "-"]]

func controls_text() -> String:
	return "빈자리/버튼 클릭 · U 부모와 교환 · L 왼쪽 자식과 교환 · S 멈춤 · Z 되돌리기 · R 초기화"

func on_key(ev: InputEventKey) -> bool:
	match ev.keycode:
		KEY_U: on_button("up")
		KEY_L: on_button("left")
		KEY_S: on_button("stop")
		_: return false
	return true

func on_button(id) -> void:
	if tasks.is_empty():
		return
	var t = tasks[0]
	match phase:
		"place":
			if typeof(id) != TYPE_INT:
				return
			if id != heap.size():
				wrong("힙은 빈틈 없이 채워요. 다음 빈자리는 인덱스 %d 이에요." % heap.size(), id)
				return
			push_undo()
			heap.append(t[1])
			idx = heap.size() - 1
			moves += 1
			phase = "up"
			_auto_finish_up()
		"up":
			var p := (idx - 1) / 2
			var should: bool = idx > 0 and heap[idx] < heap[p]
			if id == "up":
				if not should:
					wrong("%d ≥ 부모 %d 이라 교환하면 안 돼요." % [heap[idx], heap[p]], "up")
					return
				push_undo()
				var tmp = heap[p]; heap[p] = heap[idx]; heap[idx] = tmp
				idx = p
				moves += 1
				_auto_finish_up()
			elif id == "stop":
				if should:
					wrong("%d < 부모 %d 이라 아직 올라가야 해요." % [heap[idx], heap[p]], "stop")
					return
				push_undo()
				_done("%d 삽입 완료" % t[1])
		"take":
			if id != "take":
				return
			push_undo()
			outbox.append(heap[0])
			var last = heap.pop_back()
			moves += 1
			if heap.is_empty():
				_done("최솟값 %d 꺼냄" % outbox.back())
				return
			heap[0] = last
			idx = 0
			phase = "down"
			say("마지막 원소 %d 가 루트로 올라왔어요. 자식과 비교하세요." % last)
			_auto_finish_down()
		"down":
			var l := idx * 2 + 1
			var r := idx * 2 + 2
			var best := idx
			if l < heap.size() and heap[l] < heap[best]: best = l
			if r < heap.size() and heap[r] < heap[best]: best = r
			var correct := "stop" if best == idx else ("left" if best == l else "right")
			if id != correct:
				match correct:
					"stop": wrong("두 자식 모두 %d 보다 작지 않아요. 멈춰야 해요." % heap[idx], id)
					_: wrong("더 작은 자식(%d)과 교환해야 해요." % heap[best], id)
				return
			push_undo()
			moves += 1
			if correct == "stop":
				_done("꺼내기 완료 (최솟값 %d)" % outbox.back())
				return
			var tmp2 = heap[best]; heap[best] = heap[idx]; heap[idx] = tmp2
			idx = best
			_auto_finish_down()

func _auto_finish_up() -> void:
	if idx == 0:
		_done("%d 이(가) 루트까지 올라갔어요" % heap[0])

func _auto_finish_down() -> void:
	if idx * 2 + 1 >= heap.size():
		_done("리프에 도착, 꺼내기 완료 (최솟값 %d)" % outbox.back())

func _done(msg: String) -> void:
	tasks.pop_front()
	idx = -1
	if tasks.is_empty():
		phase = ""
		win(msg + " · 힙 = " + str(heap))
	else:
		good(msg)
		_begin()

func npos(i: int) -> Vector2:
	var d := int(floor(log(i + 1) / log(2)))
	var first := (1 << d) - 1
	var cnt := 1 << d
	var w := 880.0
	return Vector2(80 + w * (float(i - first) + 0.5) / cnt, 140 + d * 108)

func draw_game() -> void:
	var slots := heap.size() + (1 if phase == "place" else 0)
	var nshow: int = max(slots, 7)
	for i in range(1, nshow):
		if i < heap.size() or (phase == "place" and i == heap.size()):
			pline(npos((i - 1) / 2) + Vector2(0, 30), npos(i) - Vector2(0, 30), Color("6fd3ff"))
	for i in nshow:
		var p := npos(i)
		var r := Rect2(p - Vector2(36, 32), Vector2(72, 64))
		if i < heap.size():
			var col := C_CRATE
			if i == idx:
				col = C_GOLD.darkened(0.1)
			crate(r, str(heap[i]), col, i == idx)
		else:
			var en := phase == "place" and not level_done
			var hov := hit(r, i, en)
			pbox(r, C_RED if flashing(i) else (Color(1, 1, 1, 0.35) if hov else Color(1, 1, 1, 0.12)), Color(1, 1, 1, 0.5), false)
			text_c("[%d]" % i, p + Vector2(0, 6), 14, C_WHITE)
	# 레이어 순서(배열)
	pbox(Rect2(80, 560, 600, 64), C_PANEL, C_INK)
	text("레이어 순서", Vector2(96, 598), 16, C_PANEL_DARK)
	for i in range(max(heap.size(), 8)):
		var r2 := Rect2(200 + i * 52, 568, 46, 48)
		pbox(r2, C_GOLD if i == idx else (C_WHITE if i < heap.size() else Color("d8c7a3")), C_INK, false)
		if i < heap.size():
			text_c(str(heap[i]), r2.get_center() + Vector2(0, 8), 20, C_INK)
	# 버튼
	var en2 := not level_done
	if tasks.is_empty():
		return
	var t = tasks[0]
	if phase == "place":
		label_box(Rect2(720, 560, 270, 64), "새 작업 %d → 빈자리 클릭" % t[1], C_BLUE, C_WHITE, 18)
		robot(Vector2(1000, 520), str(t[1]))
	elif phase == "up":
		button(Rect2(700, 560, 150, 64), "부모와 교환 U", "up", en2, 17, C_RED if flashing("up") else C_BLUE)
		button(Rect2(860, 560, 130, 64), "멈춤 S", "stop", en2, 17, C_RED if flashing("stop") else C_GREEN)
	elif phase == "take":
		button(Rect2(720, 560, 270, 64), "최솟값(루트) 꺼내기", "take", en2, 18, C_RED)
	elif phase == "down":
		button(Rect2(690, 560, 104, 64), "◀ 왼쪽 L", "left", en2, 16, C_RED if flashing("left") else C_BLUE)
		button(Rect2(800, 560, 104, 64), "오른쪽 ▶", "right", en2, 16, C_RED if flashing("right") else C_BLUE)
		button(Rect2(910, 560, 90, 64), "멈춤 S", "stop", en2, 16, C_RED if flashing("stop") else C_GREEN)
