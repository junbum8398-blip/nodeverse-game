extends WalkStage
## ST04 큐/덱 - 접수 순서 안내소
## 손님 토큰을 도착 대기에서 데려와 FRONT/REAR 게이트로 줄에 세우고, 줄에서 빼서 창구로 보낸다.
## 큐: 뒤로만 넣고 앞에서만 뺀다. 덱: 양쪽 끝 모두 가능.

const CAP := 4
const LEVELS := [
	{"mode": "queue", "line": ["A", "B", "C"], "arrive": ["D"], "target": ["A", "B"], "goal": "A를 창구로 보내고, 이어서 B도 보내기"},
	{"mode": "queue", "line": ["A"], "arrive": ["B", "C", "D"], "target": ["A", "B", "C", "D"], "goal": "도착한 순서대로 모두 처리하기 (FIFO)"},
	{"mode": "deque", "line": ["A", "B", "C"], "arrive": ["V"], "target": ["V", "A", "B", "C"], "goal": "긴급 손님 V를 가장 먼저 처리하기"},
	{"mode": "deque", "line": ["A", "B", "C", "D"], "arrive": [], "target": ["D", "A", "B", "C"], "goal": "맨 뒤의 D 먼저, 그다음 A, B, C 처리하기"},
	{"mode": "deque", "line": ["A"], "arrive": ["X", "Y"], "target": ["Y", "A", "X"], "goal": "처리 순서를 Y → A → X 로 만들기"},
]
const COLORS := {"A": "e05252", "B": "e8a33d", "C": "4caf50", "D": "3d7bd9", "V": "c04fd8", "X": "2bb3a8", "Y": "d8577e"}

var mode := "queue"
var line: Array = []
var arrive: Array = []
var served: Array = []
var target: Array = []
var hand = null
var hand_from := ""     # "arrive" 또는 "line"
var mode_label: Label

func _init() -> void:
	stage_id = "ST04"
	stage_title = "접수 순서 안내소"
	npc_name = "접수 담당자"
	npc_portrait = preload("res://textures/npc_portraits/NPC04_portrait.png")
	level_count = LEVELS.size()
	code_keywords += ["String"]
	intro = [
		"안녕하세요! 저는 이 안내소의 접수 담당자예요. 손님들이 다투지 않게 차례를 지키는 게 제 일이랍니다.",
		"컨베이어 위에 손님들이 한 줄로 서 있죠? 먼저 온 손님이 먼저 창구로 가요. 이런 구조가 '큐'예요. 선입선출, FIFO라고 불러요.",
		"왼쪽 끝이 앞(FRONT), 오른쪽 끝이 뒤(REAR)예요. 큐에서는 새 손님을 뒤에만 세울 수 있고(enqueue), 앞에서만 빼낼 수 있어요(dequeue).",
		"프린터 대기열이나 은행 번호표가 다 큐랍니다. 공평하게 순서대로 처리해야 할 때 딱이에요.",
		"그런데 응급 손님은 어떡하죠? 그럴 땐 양쪽 끝에서 모두 넣고 뺄 수 있는 '덱(Deque)' 모드를 켜요. 표지판을 잘 보세요!",
		"조작법! WASD로 걷고, 도착 대기에서 E로 손님을 데려와 REAR 게이트에서 E로 줄에 세워요. FRONT 게이트에서 E로 앞 손님을 데려와 창구에서 E를 누르면 처리 끝! 막히면 노란 화살표를 따라가세요.",
	]
	level_talk = [
		"첫 번째 일이에요. 맨 앞의 A를 창구로 보내고, 그다음 B도 보내 주세요. 앞에서만 뺄 수 있다는 걸 기억하세요!",
		"손님 A만 줄에 있고 B, C, D가 곧 도착해요. 뒤로 세우고 앞에서 빼면서 온 순서대로 처리해 주세요.",
		"덱 모드예요! 긴급 손님 V를 줄의 맨 앞에 세워 가장 먼저 보내 주세요. FRONT 게이트로 데려가면 앞에 설 수 있어요.",
		"이번엔 맨 뒤의 D가 제일 급해요. 덱은 뒤에서도 뺄 수 있답니다. REAR 게이트에서 D를 데려온 뒤, 나머지는 앞에서부터 보내 주세요.",
		"마지막! X가 먼저, Y가 나중에 도착하는데 처리는 Y → A → X 순서예요. 어느 쪽 끝에 세워야 할지 생각해 보세요.",
	]

func build_stage() -> void:
	mode_label = text_at("", mark("Mode"), 28, Color.WHITE, 5)

func setup_level(n: int) -> void:
	var L: Dictionary = LEVELS[n]
	mode = L.mode
	line = L.line.duplicate()
	arrive = L.arrive.duplicate()
	served = []
	target = L.target
	hand = null
	hand_from = ""
	goal_text = L.goal
	mode_label.text = "← 큐 모드 (대기열)" if mode == "queue" else "⇄ 덱 모드 (양쪽 끝)"

func get_state() -> Dictionary:
	return {"l": line, "a": arrive, "s": served, "h": hand, "f": hand_from}

func set_state(s: Dictionary) -> void:
	line = s.l
	arrive = s.a
	served = s.s
	hand = s.h
	hand_from = s.f

func _tok(who: String, p: Vector2, sc := 1.0) -> Dictionary:
	return {"text": who, "pos": p, "scale": sc, "color": Color(COLORS.get(who, "888888"))}

func rebuild() -> void:
	var want := {}
	for i in line.size():
		want[line[i]] = _tok(line[i], mark("Line%d" % i))
	for i in arrive.size():
		want[arrive[i]] = _tok(arrive[i], mark("Arrive%d" % mini(i, 2)), 0.9)
	for i in served.size():
		want[served[i]] = _tok(served[i], mark("Served%d" % mini(i, 3)), 0.6)
	if hand != null:
		want[hand] = _tok(hand, hold_pos(), 0.9)
	sync_items(want, hand)

func info_rows() -> Array:
	return [["모드", "큐" if mode == "queue" else "덱"], ["앞 (Front)", "-" if line.is_empty() else line[0]], ["뒤 (Rear)", "-" if line.is_empty() else line.back()], ["처리", " ".join(served) if not served.is_empty() else "-"]]

func state_text() -> String:
	var cells := []
	for v in line:
		cells.append(v)
	var t := "queue = [lb]%s[rb]\nsize = %s" % [", ".join(cells), num(line.size())]
	if hand != null:
		t += "\ntemp = %s" % hand
	return t

func prompt(t: Interactable) -> String:
	match t.kind:
		"counter": return "창구로 보내기" if hand != null else "창구"
		"arrive": return "도착 손님 데려오기" if hand == null and not arrive.is_empty() else "도착 대기"
		"front":
			if hand == null:
				return "앞에서 빼기" if not line.is_empty() else "FRONT (비어 있음)"
			return "앞에 세우기"
		"rear":
			if hand != null:
				return "뒤에 세우기"
			return "뒤에서 빼기" if mode == "deque" and not line.is_empty() else "REAR"
	return t.prompt

func interact(t: Interactable) -> void:
	match t.kind:
		"arrive":
			if hand != null:
				wrong("이미 손님을 모시고 있어요.")
			elif arrive.is_empty():
				wrong("기다리는 도착 손님이 없어요.")
			else:
				snapshot()
				hand = arrive.pop_front()
				hand_from = "arrive"
				code('temp = "%s";' % hand, "새 손님")
		"front":
			if hand != null:
				_enqueue(true)
			else:
				_dequeue(true)
		"rear":
			if hand != null:
				_enqueue(false)
			else:
				_dequeue(false)
		"counter":
			if hand == null:
				wrong("먼저 줄에서 손님을 데려오세요.")
			elif hand_from != "line":
				wrong("새 손님은 먼저 줄에 세워야 해요.")
			else:
				snapshot()
				served.append(hand)
				code('serve("%s");' % hand, "%d번째 처리" % served.size())
				hand = null
				hand_from = ""
				moves += 1
				if served == target:
					win("처리 순서 %s 완성!\n실수 %d회" % [" → ".join(served), mistakes])
	rebuild()

func _enqueue(front: bool) -> void:
	if front and mode == "queue":
		wrong("큐는 앞에 세울 수 없어요. REAR 게이트로 가세요.")
		return
	if line.size() >= CAP:
		wrong("줄이 가득 찼어요.")
		return
	snapshot()
	if front:
		line.push_front(hand)
		code_replace('deque.addFirst("%s");' % hand, "앞에 추가")
	else:
		line.append(hand)
		code_replace('%s.addLast("%s");' % ["queue" if mode == "queue" else "deque", hand], "뒤에 추가")
	hand = null
	hand_from = ""
	moves += 1

func _dequeue(front: bool) -> void:
	if not front and mode == "queue":
		wrong("큐는 뒤에서 뺄 수 없어요. FRONT 게이트로 가세요.")
		return
	if line.is_empty():
		wrong("대기열이 비었어요.")
		return
	var who = line[0] if front else line.back()
	var expect = target[served.size()]
	if who != expect:
		wrong("지금 창구에 갈 손님은 %s 예요. (%s 아님)" % [str(expect), who])
		return
	snapshot()
	if front:
		line.pop_front()
		code('temp = %s;' % ("queue.pollFirst()" if mode == "queue" else "deque.pollFirst()"), "%s 빼기" % who)
	else:
		line.pop_back()
		code("temp = deque.pollLast();", "%s 빼기" % who)
	hand = who
	hand_from = "line"

func summary_code() -> void:
	code("")
	code("// 큐: 먼저 온 것부터 (FIFO)" if mode == "queue" else "// 덱: 양쪽 끝 모두 넣고 빼기")

func next_action() -> Array:
	if hand != null:
		if hand_from == "line":
			return [spot("counter"), "창구로 보내기"]
		if mode == "deque" and not line.is_empty() and target.find(hand) < target.find(line[0]):
			return [spot("front"), "앞에 세우기"]
		return [spot("rear"), "뒤에 세우기"]
	if served.size() >= target.size():
		return [null, ""]
	var expect = target[served.size()]
	if not line.is_empty() and line[0] == expect:
		return [spot("front"), "%s 앞에서 빼기" % expect]
	if mode == "deque" and not line.is_empty() and line.back() == expect:
		return [spot("rear"), "%s 뒤에서 빼기" % expect]
	if not arrive.is_empty():
		return [spot("arrive"), "도착 손님 데려오기"]
	return [null, ""]
