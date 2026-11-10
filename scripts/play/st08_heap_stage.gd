extends WalkStage
## ST08 최소 힙 - 긴급 작업 배정실
## 삽입: 입고에서 상자를 집어 다음 빈자리에 놓고 → 레버로 부모와 교환 반복, 멈출 곳에서는 받침대에서 E.
## 꺼내기: 루트 상자를 들어 완료 접수대로 → 마지막 상자가 루트로 → 더 작은 자식 쪽 레버로 교환 반복.

const LEVELS := [
	{"heap": [1, 3, 2, 7, 4, 5], "tasks": [["slot", 1], ["slot", 4], ["parent", 4], ["parent", 2]]},
	{"heap": [2, 5, 3, 9, 7], "tasks": [["insert", 1]]},
	{"heap": [2, 4, 8, 9, 5], "tasks": [["insert", 3]]},
	{"heap": [1, 3, 2, 7, 4, 5], "tasks": [["extract"]]},
	{"heap": [2, 4, 3, 8, 5, 6], "tasks": [["extract"], ["insert", 1], ["extract"]]},
	{"heap": [4], "tasks": [["extract"], ["insert", 2], ["insert", 2]]},
]

var heap: Array = []
var tasks: Array = []
var phase := ""        # pick / place / up / take / carry / down
var idx := -1
var hand = null
var outbox: Array = []
var arr_labels: Array = []

func _init() -> void:
	stage_id = "ST08"
	stage_title = "긴급 작업 배정실"
	npc_name = "긴급 배정 담당자"
	npc_portrait = preload("res://textures/npc_portraits/NPC08_portrait.png")
	level_count = LEVELS.size()
	code_keywords += ["swap", "int"]
	intro = [
		"시간 없어, 빨리 설명할게! 난 긴급 작업 배정 담당자야. 숫자가 작을수록 급한 일이고, 가장 급한 일은 언제나 맨 위에 있어야 해.",
		"받침대들이 위에서 아래로 갈라져 있지? 부모는 항상 자식보다 작거나 같아야 해. 이 규칙을 지키는 트리가 '최소 힙'이야.",
		"덕분에 맨 위(루트)만 보면 최솟값을 바로 알 수 있어. 형제끼리는 순서가 없어도 괜찮아.",
		"아래 '레이어 순서'를 봐. 힙은 트리지만 실제로는 배열에 층별로 차곡차곡 넣어. 인덱스 i의 부모는 (i-1)/2, 자식은 2i+1, 2i+2야.",
		"넣을 때는 맨 끝 빈자리에 놓고 부모보다 작으면 교환해서 올려. 꺼낼 때는 루트를 빼고 마지막 상자를 루트로 올린 뒤 더 작은 자식과 교환해서 내려.",
		"조작법! 입고에서 E로 상자를 집어 빈 받침대에 놓아. 받침대 사이 레버에서 E를 누르면 부모와 자식이 교환돼. 더 옮길 필요가 없으면 그 받침대에서 E로 멈춰. 막히면 노란 화살표를 따라가!",
	]
	level_talk = [
		"먼저 받침대와 배열 번호를 맞춰 보자! 아래 레이어 순서의 번호가 트리의 어느 받침대인지 찾아가서 E를 눌러 줘. 부모는 (i-1)/2야.",
		"작업 1번이 들어왔어! 맨 끝 빈자리에 놓고 부모와 비교해서 맨 위까지 올려 줘.",
		"이번 작업은 3이야. 8보다 작으니 교환하지만, 부모 2보다는 크니까 거기서 멈춰야 해. 받침대에서 E로 멈추는 걸 잊지 마.",
		"이제 꺼내기! 루트 상자를 들어 완료 접수대로 보내고, 올라온 상자를 더 작은 자식 쪽 레버로 내려 줘.",
		"연속 작업이야. 꺼내고, 1을 넣고, 다시 꺼내기. 정신 바짝 차려!",
		"마지막! 작업이 하나뿐일 때 꺼내면 힙이 비어. 그다음 같은 우선순위 2를 두 번 넣어 봐. 부모와 같으면 교환하지 않고 멈추는 거야.",
	]

func build_stage() -> void:
	for i in 6:
		arr_labels.append(text_at("", mark("Arr%d" % i) + Vector2(0, -2), 32, StageHUD.INK, 0))

func setup_level(n: int) -> void:
	var L: Dictionary = LEVELS[n]
	heap = L.heap.duplicate()
	tasks = L.tasks.duplicate(true)
	outbox = []
	hand = null
	_begin()

func _begin() -> void:
	idx = -1
	if tasks.is_empty():
		phase = ""
		return
	var t = tasks[0]
	if t[0] == "insert":
		phase = "pick"
		goal_text = "새 작업 %d 넣고 부모와 비교해 올리기" % t[1]
	elif t[0] == "slot":
		phase = "slot"
		goal_text = "배열 인덱스 %d 번 값이 놓인 받침대 찾기" % t[1]
	elif t[0] == "parent":
		phase = "slot"
		goal_text = "인덱스 %d 의 부모 받침대 찾기 ((i-1)/2)" % t[1]
	else:
		phase = "take"
		goal_text = "가장 급한 작업(최솟값) 꺼내고 새 루트 내리기"
	if is_node_ready() and hud.goal_label and level >= 0:
		hud.set_goal(goal_text)

func get_state() -> Dictionary:
	return {"h": heap, "t": tasks, "p": phase, "i": idx, "a": hand, "o": outbox}

func set_state(s: Dictionary) -> void:
	heap = s.h
	tasks = s.t
	phase = s.p
	idx = s.i
	hand = s.a
	outbox = s.o

func rebuild() -> void:
	var want := {}
	for i in heap.size():
		want["c%d" % i] = {"text": str(heap[i]), "pos": mark("Crate%d" % i)}
	var pending = tasks[0][1] if phase == "pick" else null
	if pending != null:
		want["new"] = {"text": str(pending), "pos": mark("Inbox"), "scale": 0.9}
	var held_id = null
	if hand != null:
		held_id = "hand"
		want["hand"] = {"text": str(hand), "pos": hold_pos()}
	sync_items(want, held_id)
	for i in 6:
		arr_labels[i].text = str(heap[i]) if i < heap.size() else ""
		arr_labels[i].add_theme_color_override("font_color", StageHUD.RED if i == idx else StageHUD.INK)

func _pop_two(a: int, b: int) -> void:
	for i in [a, b]:
		var c: StageCrate = items.get("c%d" % i)
		if c:
			c.pop()

func info_rows() -> Array:
	var ph := {"slot": "받침대 찾기", "pick": "새 상자 집기", "place": "빈자리에 놓기", "up": "위로 올리기", "take": "루트 꺼내기", "carry": "완료 접수대로", "down": "아래로 내리기", "": "-"}
	return [["단계", ph[phase]], ["최솟값", "-" if heap.is_empty() else heap[0]], ["크기", heap.size()], ["꺼낸 작업", " ".join(outbox.map(func(x): return str(x))) if not outbox.is_empty() else "-"]]

func state_text() -> String:
	var cells := []
	for v in heap:
		cells.append(num(v))
	var t := "heap = [lb]%s[rb]" % ", ".join(cells)
	if idx >= 0:
		t += "\ni = %s" % num(idx)
		if idx > 0:
			t += ", parent = %s" % num((idx - 1) / 2)
	if hand != null:
		t += "\ntemp = %s" % num(hand)
	return t

func prompt(t: Interactable) -> String:
	match t.kind:
		"intake": return "새 상자 집기" if phase == "pick" else "입고"
		"outbox": return "작업 완료 접수" if phase == "carry" else "완료 접수대"
		"lever":
			return "%d번 ↔ 부모 교환" % t.index
		"pad":
			if phase == "place":
				return "여기에 놓기" if t.index == heap.size() else "%d번 받침대" % t.index
			if phase == "take" and t.index == 0:
				return "최솟값 꺼내기"
			if (phase == "up" or phase == "down") and t.index == idx:
				return "여기서 멈추기"
			return "%d번 받침대" % t.index
	return t.prompt

func _slot_target() -> int:
	var task = tasks[0]
	return int(task[1]) if task[0] == "slot" else (int(task[1]) - 1) / 2

func interact(t: Interactable) -> void:
	match phase:
		"slot":
			var want := _slot_target()
			if t.kind != "pad" or t.index != want:
				wrong("찾는 받침대는 배열 %d번 자리예요. 층별로 왼쪽부터 세어 보세요." % want)
				return
			snapshot()
			moves += 1
			code("x = heap[%d];" % want, "값 %d" % heap[want])
			_done("%d번 받침대의 값은 %d" % [want, heap[want]])
		"pick":
			if t.kind != "intake":
				wrong("먼저 입고에서 새 상자를 집어 오세요.")
				return
			snapshot()
			hand = tasks[0][1]
			code("key = %d;" % hand, "새 작업")
			phase = "place"
		"place":
			if t.kind != "pad":
				wrong("다음 빈 받침대(%d번)에 놓으세요." % heap.size())
				return
			if t.index != heap.size():
				wrong("힙은 빈틈 없이 채워요. 다음 빈자리는 %d번이에요." % heap.size())
				return
			snapshot()
			heap.append(hand)
			idx = heap.size() - 1
			code("heap[%d] = %d;" % [idx, hand], "맨 끝에 추가")
			hand = null
			moves += 1
			phase = "up"
			_auto_finish_up()
		"up":
			_up(t)
		"take":
			if t.kind != "pad" or t.index != 0:
				wrong("가장 급한 작업은 맨 위 받침대에 있어요.")
				return
			snapshot()
			hand = heap[0]
			code("min = heap[0];", "최솟값 %d" % hand)
			var last = heap.pop_back()
			if heap.is_empty():
				phase = "carry"
			else:
				heap[0] = last
				idx = 0
				code("heap[0] = heap[%d];" % heap.size(), "마지막을 루트로")
				phase = "carry"
			moves += 1
		"carry":
			if t.kind != "outbox":
				wrong("먼저 들고 있는 작업을 완료 접수대로 가져가세요.")
				return
			snapshot()
			outbox.append(hand)
			hand = null
			code("return min;")
			if heap.is_empty():
				_done("꺼내기 완료")
			else:
				idx = 0
				phase = "down"
				_auto_finish_down()
		"down":
			_down(t)
	rebuild()

func _up(t: Interactable) -> void:
	var p := (idx - 1) / 2
	var should: bool = idx > 0 and heap[idx] < heap[p]
	if t.kind == "pad" and t.index == idx:
		if should:
			wrong("%d < 부모 %d 이라 아직 올라가야 해요." % [heap[idx], heap[p]])
			return
		snapshot()
		code("break;", "%d ≥ 부모 %d" % [heap[idx], heap[p]])
		_done("%d 삽입 완료" % heap[idx])
		return
	if t.kind != "lever":
		wrong("레버에서 교환하거나, %d번 받침대에서 멈추세요." % idx)
		return
	if t.index != idx:
		wrong("지금 상자는 %d번에 있어요. 그 위쪽 레버를 쓰세요." % idx)
		return
	if not should:
		wrong("%d ≥ 부모 %d 이라 교환하면 안 돼요." % [heap[idx], heap[p]])
		return
	snapshot()
	_swap(idx, p)
	idx = p
	_auto_finish_up()

func _down(t: Interactable) -> void:
	var l := idx * 2 + 1
	var r := idx * 2 + 2
	var best := idx
	if l < heap.size() and heap[l] < heap[best]:
		best = l
	if r < heap.size() and heap[r] < heap[best]:
		best = r
	if t.kind == "pad" and t.index == idx:
		if best != idx:
			wrong("자식 %d 이(가) 더 작아요. 더 내려가야 해요." % heap[best])
			return
		snapshot()
		code("break;", "자식보다 작거나 같음")
		_done("꺼내기 완료 (최솟값 %d)" % outbox.back())
		return
	if t.kind != "lever":
		wrong("더 작은 자식 쪽 레버를 쓰세요.")
		return
	if best == idx:
		wrong("두 자식 모두 %d 보다 작지 않아요. %d번 받침대에서 멈추세요." % [heap[idx], idx])
		return
	if t.index != best:
		wrong("더 작은 자식(%d)과 교환해야 해요." % heap[best])
		return
	snapshot()
	_swap(idx, best)
	idx = best
	_auto_finish_down()

func _swap(a: int, b: int) -> void:
	var tmp = heap[a]
	heap[a] = heap[b]
	heap[b] = tmp
	moves += 1
	code("swap(%d, %d);" % [a, b], "%d ↔ %d" % [heap[a], heap[b]])
	rebuild()
	_pop_two(a, b)

func _auto_finish_up() -> void:
	if idx == 0:
		_done("%d 이(가) 맨 위까지 올라갔어요" % heap[0])

func _auto_finish_down() -> void:
	if idx * 2 + 1 >= heap.size():
		_done("맨 아래 도착, 꺼내기 완료 (최솟값 %d)" % outbox.back())

func _done(msg: String) -> void:
	tasks.pop_front()
	idx = -1
	if tasks.is_empty():
		phase = ""
		win("%s\n힙 = %s · 실수 %d회" % [msg, str(heap), mistakes])
	else:
		good(msg)
		_begin()

func summary_code() -> void:
	code("")
	code("// 삽입·삭제 모두 높이만큼: O(log n)")

func next_action() -> Array:
	match phase:
		"slot": return [spot("pad", _slot_target()), "이 받침대"]
		"pick": return [spot("intake"), "새 상자 집기"]
		"place": return [spot("pad", heap.size()), "빈자리에 놓기"]
		"take": return [spot("pad", 0), "최솟값 꺼내기"]
		"carry": return [spot("outbox"), "완료 접수대로"]
		"up":
			if idx > 0 and heap[idx] < heap[(idx - 1) / 2]:
				return [spot("lever", idx), "부모와 교환"]
			return [spot("pad", idx), "여기서 멈추기"]
		"down":
			var l := idx * 2 + 1
			var r := idx * 2 + 2
			var best := idx
			if l < heap.size() and heap[l] < heap[best]:
				best = l
			if r < heap.size() and heap[r] < heap[best]:
				best = r
			if best != idx:
				return [spot("lever", best), "더 작은 자식과 교환"]
			return [spot("pad", idx), "여기서 멈추기"]
	return [null, ""]
