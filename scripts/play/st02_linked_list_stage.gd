extends WalkStage
## ST02 연결 리스트 - 끊어진 운송로
## 노드 받침대에서 E 로 next 연결선을 집고, 가리킬 노드(또는 '끝')에서 E 로 잇는다.
## 아무도 가리키지 않게 된 노드는 참조를 잃어 사라진다 -> 연결 순서가 중요!

const KEYS := ["A", "B", "C"]
const VALUE := {"A": 10, "B": 20, "C": 30}
const LEVELS := [
	{"next": {"A": "B", "B": "C", "C": null}, "head": "A", "held": [], "target": ["A", "B", "C"], "goal": "HEAD에서 next를 따라 차례로 읽기", "opt": 3, "read": true,
	 "plan": [], "sum": ["for (cur = head; cur != null; cur = cur.next)", "    read(cur.value);"]},
	{"next": {"A": "C", "B": null, "C": null}, "head": "A", "held": ["B"], "target": ["A", "B", "C"], "goal": "A와 C 사이에 B(20) 끼우기", "opt": 2,
	 "plan": [["B", "C"], ["A", "B"]], "sum": ["Node b = new Node(20);", "b.next = a.next;", "a.next = b;"]},
	{"next": {"A": "B", "B": "C", "C": null}, "head": "A", "held": [], "target": ["A", "C"], "goal": "B(20)를 리스트에서 빼기", "opt": 1,
	 "plan": [["A", "C"]], "sum": ["a.next = a.next.next;", "// b 는 아무도 안 가리켜 사라져요"]},
	{"next": {"A": "C", "B": null, "C": null}, "head": "A", "held": ["B"], "target": ["B", "A", "C"], "goal": "맨 앞에 B(20) 넣기 (HEAD도 옮기기)", "opt": 2,
	 "plan": [["B", "A"], ["HEAD", "B"]], "sum": ["Node b = new Node(20);", "b.next = head;", "head = b;"]},
	{"next": {"A": "B", "B": "C", "C": null}, "head": "A", "held": [], "target": ["B", "C"], "goal": "첫 노드 A(10) 지우기 (HEAD 옮기기)", "opt": 1,
	 "plan": [["HEAD", "B"]], "sum": ["head = head.next;", "// a 는 아무도 안 가리켜 사라져요"]},
	{"next": {"A": "B", "B": "C", "C": null}, "head": "A", "held": [], "target": ["A", "C", "B"], "goal": "순서를 A → C → B 로 바꾸기", "opt": 3,
	 "plan": [["C", "B"], ["A", "C"], ["B", null]], "sum": ["c.next = b;", "a.next = c;", "b.next = null;"]},
	{"next": {"A": "B", "B": "C", "C": null}, "head": "A", "held": [], "target": ["A"], "goal": "A 하나만 남기기 (A.next를 끝으로)", "opt": 1,
	 "plan": [["A", null]], "sum": ["a.next = null;", "// 노드가 하나여도 끝은 null 이에요"]},
]

var nxt := {}
var head := "A"
var held: Array = []
var lost: Array = []
var removed: Array = []
var cable = null            # 들고 있는 연결선의 출발 ("A", "B", "C", "HEAD") 또는 null
var read_i := 0             # 읽기 레벨: 지금까지 읽은 노드 수
var L: Dictionary
var head_label: Label
var cable_line: Line2D
var stickers: Node2D

func _init() -> void:
	stage_id = "ST02"
	stage_title = "끊어진 운송로"
	npc_name = "운송로 정비사"
	npc_portrait = preload("res://textures/npc_portraits/NPC02_portrait.png")
	level_count = LEVELS.size()
	code_keywords += ["Node"]
	intro = [
		"안녕, 꼬마 로봇! 난 이 섬들을 잇는 운송로 정비사야. 다리가 끊기면 물건이 길을 잃거든. 일 시작 전에 이곳 규칙부터 알려 줄게.",
		"저기 A, B, C 받침대 보이지? 값을 담은 칸 하나를 '노드'라고 해. 배열처럼 나란히 붙어 있지 않고, 섬처럼 여기저기 떨어져 있어도 괜찮아.",
		"대신 노드마다 다음 노드를 가리키는 연결선이 있어. 이걸 'next'라고 불러. next를 따라가면 순서대로 돌 수 있지. 이게 '연결 리스트'야.",
		"첫 노드는 왼쪽 위 HEAD 팻말이 가리키고, 마지막 노드의 next는 '끝(null)' 단말기에 연결돼 있어.",
		"장점은 끼우고 빼는 게 쉽다는 거야. 배열처럼 뒤를 다 밀 필요 없이 연결선 몇 개만 바꾸면 돼. 대신 3번째 노드를 보려면 HEAD부터 따라가야 해.",
		"제일 중요한 규칙! 아무도 가리키지 않는 노드는 영영 잃어버려. 그래서 새 노드의 next를 먼저 잇고, 그다음에 앞 노드의 연결을 바꿔야 해.",
		"조작법! WASD로 걷고, 받침대 앞에서 E를 누르면 그 노드의 next 연결선을 집어. 가리킬 받침대나 '끝' 단말기에 가서 E로 이으면 돼. 막히면 노란 화살표를 따라가!",
	]
	level_talk = [
		"먼저 읽는 법부터! HEAD가 가리키는 A에서 시작해서 next를 따라 A, B, C 받침대 순서로 E를 눌러 값을 읽어 줘.",
		"첫 번째 일이야. A와 C 사이에 B를 끼워 줘. B.next를 C로 먼저 잇고, 그다음 A.next를 B로 바꾸는 거야. 순서를 바꾸면 C를 잃어버려!",
		"이번엔 삭제야. B를 빼려면 A.next가 B를 건너뛰고 C를 가리키게만 하면 돼. 아무도 안 가리키는 B는 저절로 사라지지.",
		"맨 앞에 B를 넣어 볼래? B.next를 A로 잇고, HEAD 팻말에서 연결선을 집어 B로 옮겨. HEAD를 안 옮기면 B는 리스트에 못 들어와.",
		"이번엔 첫 노드 A를 지워 볼래? HEAD 팻말에서 연결선을 집어 B로 옮기면 돼. 아무도 안 가리키는 A는 저절로 사라져.",
		"A → B → C를 A → C → B로 바꿔 줘. 꼭 C.next부터 B로 이어 둬야 해. 잠깐 고리가 생겨도 괜찮아. 마지막엔 B.next를 '끝'에 이어서 고리를 풀어 줘.",
		"마지막! A 하나만 남겨 줘. A.next를 '끝'에 이으면 B와 C는 함께 떨어져 나가. 노드가 하나뿐이어도 끝은 null이야.",
	]

func build_stage() -> void:
	head_label = text_at("A", mark("AnchorHead") + Vector2(-12, 2), 34, StageHUD.INK, 0)
	cable_line = Line2D.new()
	cable_line.width = 7.0
	cable_line.default_color = StageHUD.GOLD
	cable_line.z_index = 2
	field.add_child(cable_line)
	field.move_child(cable_line, world.get_index())
	stickers = Node2D.new()
	overlay.add_child(stickers)

func setup_level(n: int) -> void:
	L = LEVELS[n]
	nxt = L.next.duplicate()
	head = L.head
	held = L.held.duplicate()
	lost = []
	removed = []
	cable = null
	read_i = 0
	goal_text = L.goal

func get_state() -> Dictionary:
	return {"n": nxt, "h": head, "e": held, "l": lost, "r": removed, "c": cable, "i": read_i}

func set_state(s: Dictionary) -> void:
	nxt = s.n
	head = s.h
	held = s.e
	lost = s.l
	removed = s.r
	cable = s.c
	read_i = s.i

func chain() -> Array:
	var out := []
	var cur = head
	var seen := {}
	while cur != null and not seen.has(cur):
		out.append(cur)
		seen[cur] = true
		cur = nxt[cur]
	return out

func _is_cycle() -> bool:
	var ch := chain()
	return not ch.is_empty() and nxt[ch.back()] != null

func _anchor(k: String) -> Vector2:
	return mark("Anchor" + k)

func rebuild() -> void:
	clear_children(links)
	clear_children(stickers)
	head_label.text = head
	link(_anchor("Head") + Vector2(40, 10), _anchor(head) + Vector2(-20, -26), C_HEAD, 24.0)
	for k in KEYS:
		if k in lost or k in removed:
			continue
		if nxt[k] == null:
			if k in chain():
				link(_anchor(k) + Vector2(30, 10), _anchor("End") + Vector2(-20, 20), Color(1, 1, 1, 0.75), 20.0)
		else:
			link(_anchor(k) + Vector2(0, 10), _anchor(nxt[k]) + Vector2(0, 14), C_LINK, 34.0)
		if k in held:
			text_at("로봇 임시 참조", _anchor(k) + Vector2(0, -44), 19, Color("e6c8ff"), 5, stickers)
	for i in read_i:
		text_at("%d번째 읽음" % (i + 1), _anchor(L.target[i]) + Vector2(0, -44), 20, StageHUD.GOLD, 5, stickers)
	for k in lost:
		text_at("참조 유실!", _anchor(k) + Vector2(0, -44), 22, StageHUD.RED, 6, stickers)
	for k in removed:
		text_at("제거됨", _anchor(k) + Vector2(0, -44), 22, Color("9fd8a8"), 6, stickers)

func _process(_d: float) -> void:
	if cable == null:
		cable_line.clear_points()
		return
	var from: Vector2 = _anchor(cable if cable != "HEAD" else "Head")
	cable_line.points = PackedVector2Array([from, world.to_local(player.carry_point.global_position)])

func info_rows() -> Array:
	var ch := chain()
	return [["HEAD", head], ["리스트", " → ".join(ch) + (" ↺" if _is_cycle() else "")], ["변경", "%d (최소 %d)" % [moves, L.opt]], ["연결선", "-" if cable == null else ("HEAD" if cable == "HEAD" else cable + ".next")]]

func state_text() -> String:
	var s := "head = %s" % head
	for k in KEYS:
		if k in removed:
			continue
		s += "\n%s.next = %s" % [k, "null" if nxt[k] == null else nxt[k]]
		if k in held:
			s += "  [color=#7fbf7f]// 임시 참조[/color]"
	return s

func prompt(t: Interactable) -> String:
	if L.has("read"):
		return "%s 값 읽기" % KEYS[t.index] if t.kind == "node" else t.prompt
	match t.kind:
		"head":
			return "HEAD 연결선 집기" if cable == null else "HEAD 팻말"
		"null":
			return "끝(null)에 잇기" if cable != null else "끝 단말기"
		"node":
			var k: String = KEYS[t.index]
			if cable == null:
				return "%s.next 연결선 집기" % k
			if cable == k:
				return "연결선 내려놓기"
			return "%s 로 잇기" % k
	return t.prompt

func _read(t: Interactable) -> void:
	if t.kind != "node":
		wrong("이번엔 노드 받침대에서 값을 읽어요.")
		return
	var k: String = KEYS[t.index]
	if k != L.target[read_i]:
		wrong("HEAD부터 next를 따라가야 해요. 지금 읽을 노드는 %s예요." % L.target[read_i])
		return
	snapshot()
	moves += 1
	code("value = cur.value;" if read_i == 0 else "cur = cur.next;", "%s = %d" % [k, VALUE[k]])
	read_i += 1
	rebuild()
	if read_i == L.target.size():
		code("cur = cur.next;", "null 이면 끝")
		win("읽은 순서: %s → null\n실수 %d회" % [" → ".join(L.target), mistakes])

func interact(t: Interactable) -> void:
	if L.has("read"):
		_read(t)
		return
	match t.kind:
		"head":
			if cable == null:
				snapshot()
				cable = "HEAD"
				code("// head 를 옮길 준비")
			else:
				wrong("연결선은 노드나 '끝'에 이어야 해요.")
		"null":
			if cable == null:
				wrong("먼저 노드에서 연결선을 집어 오세요.")
			elif cable == "HEAD":
				wrong("HEAD가 비면 리스트 전체를 잃어요.")
			else:
				_connect(null)
		"node":
			var k: String = KEYS[t.index]
			if k in lost or k in removed:
				wrong("%s 는 이미 리스트에서 사라졌어요." % k)
			elif cable == null:
				snapshot()
				cable = k
				code("// %s.next 를 바꿀 준비" % k)
			elif cable == k:
				code_lines.pop_back()
				_undo.pop_back()
				cable = null
			else:
				_connect(k)
	rebuild()

func _connect(to) -> void:
	var from: String = cable
	cable = null
	if from == "HEAD":
		head = to
		code_replace("head = %s;" % to, "첫 노드 변경")
	else:
		nxt[from] = to
		code_replace("%s.next = %s;" % [from, "null" if to == null else to], "")
	moves += 1
	_resolve()

func _resolve() -> void:
	var reach := {}
	for s in [head] + held:
		var cur = s
		while cur != null and not reach.has(cur):
			reach[cur] = true
			cur = nxt[cur]
	var main := chain()
	for h in held.duplicate():
		if h in main:
			held.erase(h)
	for k in KEYS:
		if reach.has(k) or k in lost or k in removed:
			continue
		if k in L.target:
			lost.append(k)
			wrong("%s(%d)를 가리키는 연결이 사라져 노드를 잃었어요! Z로 되돌리세요." % [k, VALUE[k]])
			return
		removed.append(k)
		good("%s(%d) 제거 완료" % [k, VALUE[k]])
	if main == L.target and held.is_empty() and not _is_cycle():
		if moves > L.opt:
			mistakes = maxi(mistakes, 1)
		win("완성: %s → null\n변경 %d회 (최소 %d회) · 실수 %d회" % [" → ".join(main), moves, L.opt, mistakes])

func summary_code() -> void:
	code("")
	code("// ── 정리하면 ──")
	for c in L.sum:
		code(c)

func next_action() -> Array:
	if L.has("read"):
		if read_i >= L.target.size():
			return [null, ""]
		return [spot("node", KEYS.find(L.target[read_i])), "%s 값 읽기" % L.target[read_i]]
	if not lost.is_empty():
		return [null, ""]
	for p in L.plan:
		var cur = head if p[0] == "HEAD" else nxt[p[0]]
		if cur == p[1]:
			continue
		var label_from: String = "HEAD" if p[0] == "HEAD" else p[0] + ".next"
		if cable == null:
			return [spot("head") if p[0] == "HEAD" else spot("node", KEYS.find(p[0])), "%s 연결선 집기" % label_from]
		if cable != p[0]:
			return [spot("head") if cable == "HEAD" else spot("node", KEYS.find(cable)), "연결선 내려놓기"]
		if p[1] == null:
			return [spot("null"), "끝(null)에 잇기"]
		return [spot("node", KEYS.find(p[1])), "%s 로 잇기" % p[1]]
	return [null, ""]
