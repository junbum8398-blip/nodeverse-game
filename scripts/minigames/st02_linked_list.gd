extends MiniGameBase
## ST02 연결 리스트 - 끊어진 운송로
## 노드(또는 HEAD)를 클릭해 고른 뒤, 가리킬 노드(또는 '끝')를 클릭하면 next 가 바뀐다.
## 아무도 가리키지 않게 된 노드는 물에 빠져 사라진다(참조 유실) -> 순서가 중요!

const LEVELS := [
	{"nodes": {"A": 10, "B": 20, "C": 30}, "next": {"A": "C", "B": null, "C": null}, "head": "A", "held": ["B"],
	 "target": ["A", "B", "C"], "goal": "A와 C 사이에 B(20) 끼우기 - 20의 next를 먼저 연결!", "opt": 2},
	{"nodes": {"A": 10, "B": 20, "C": 30, "D": 40}, "next": {"A": "B", "B": "C", "C": "D", "D": null}, "head": "A", "held": [],
	 "target": ["A", "B", "D"], "goal": "C(30)를 리스트에서 빼기", "opt": 1},
	{"nodes": {"X": 5, "A": 10, "B": 20}, "next": {"X": null, "A": "B", "B": null}, "head": "A", "held": ["X"],
	 "target": ["X", "A", "B"], "goal": "맨 앞에 X(5) 넣기 - HEAD도 바꿔야 해요", "opt": 2},
	{"nodes": {"A": 10, "B": 20, "C": 30, "D": 40, "E": 50}, "next": {"A": "C", "B": null, "C": "E", "D": null, "E": null},
	 "head": "A", "held": ["B", "D"], "target": ["A", "B", "C", "D", "E"], "goal": "B(20)와 D(40)를 제자리에 끼워 A→B→C→D→E 만들기", "opt": 4},
]

var nodes := {}
var nxt := {}
var head := ""
var held: Array = []
var lost: Array = []
var sel = null
var target: Array = []
var opt := 0
var pos := {}

func _init() -> void:
	stage_id = "ST02"
	stage_title = "끊어진 운송로"
	level_count = LEVELS.size()

func setup_level(n: int) -> void:
	var L: Dictionary = LEVELS[n]
	nodes = L.nodes.duplicate()
	nxt = L.next.duplicate()
	head = L.head
	held = L.held.duplicate()
	lost = []
	sel = null
	target = L.target
	goal = L.goal
	opt = L.opt
	pos = {}
	var keys := nodes.keys()
	keys.sort()
	var chain := chain_list()
	var i := 0
	for k in chain:
		pos[k] = Vector2(170 + i * 170, 250)
		i += 1
	var j := 0
	for k in keys:
		if not pos.has(k):
			pos[k] = Vector2(300 + j * 250, 470)
			j += 1

func get_state() -> Dictionary:
	return {"nxt": nxt, "head": head, "held": held, "lost": lost, "moves": moves}

func set_state(s: Dictionary) -> void:
	nxt = s.nxt
	head = s.head
	held = s.held
	lost = s.lost
	moves = s.moves
	sel = null

func chain_list() -> Array:
	var out := []
	var cur = head
	var guard := 0
	while cur != null and cur != "" and guard < 20:
		out.append(cur)
		cur = nxt[cur]
		guard += 1
	return out

func info_lines() -> Array:
	var keys := nodes.keys()
	keys.sort()
	var lines := [["HEAD", head]]
	for k in keys:
		if k in lost:
			continue
		lines.append(["%s.next" % k, "끝" if nxt[k] == null else nxt[k]])
	lines.append(["변경", "%d (최소 %d)" % [moves, opt]])
	return lines

func controls_text() -> String:
	return "① 바꿀 노드/HEAD 클릭 → ② 가리킬 노드/끝 클릭 · Z 되돌리기 · R 초기화"

func on_button(id) -> void:
	if sel == null:
		if id == "null":
			return
		sel = id
		say("%s 선택: 이제 %s 가 가리킬 대상을 고르세요." % [id, "HEAD" if id == "HEAD" else id + ".next"])
		return
	if id == sel and id != "HEAD":
		if sel == id:
			wrong("자기 자신을 가리키면 순환이 생겨요.", id)
			sel = null
			return
	push_undo()
	var target_v = null if id == "null" else id
	if sel == "HEAD":
		if target_v == null:
			wrong("HEAD가 비면 리스트 전체를 잃어요.")
			_undo.pop_back()
			sel = null
			return
		head = target_v
	else:
		nxt[sel] = target_v
	moves += 1
	sel = null
	_resolve()

func _resolve() -> void:
	# 참조 집합: HEAD 에서 도달 가능 + 로봇이 들고 있는 노드에서 도달 가능
	var reach := {}
	var starts := [head] + held
	for s in starts:
		var cur = s
		var g := 0
		while cur != null and not reach.has(cur) and g < 20:
			reach[cur] = true
			cur = nxt[cur]
			g += 1
	# HEAD 에서 도달 가능해진 노드는 더 이상 들고 있을 필요 없음
	var main := chain_list()
	for h in held.duplicate():
		if h in main:
			held.erase(h)
	for k in nodes.keys():
		if not reach.has(k) and not (k in lost):
			if k in target:
				lost.append(k)
				wrong("%s(%d)를 가리키는 링크가 사라져 노드를 잃었어요! Z로 되돌리세요." % [k, nodes[k]], k)
				return
			lost.append(k)
			good("%s(%d) 제거 완료" % [k, nodes[k]], k)
	if main == target and held.is_empty():
		win("완성: %s  (변경 %d회)" % [" → ".join(main), moves])

func draw_game() -> void:
	# HEAD
	var hr := Rect2(40, 226, 80, 48)
	var hc := C_GOLD if sel == "HEAD" else C_BLUE
	button(hr, "HEAD", "HEAD", not level_done, 18, hc)
	if pos.has(head):
		arrow(Vector2(122, 250), pos[head] - Vector2(40, 0), C_GOLD)
	# 링크
	for k in nodes.keys():
		if k in lost or nxt[k] == null:
			continue
		var a: Vector2 = pos[k]
		var b: Vector2 = pos[nxt[k]]
		var d := (b - a).normalized()
		arrow(a + d * 42, b - d * 44, Color("6fd3ff"))
	# 끝(null)
	var nr := Rect2(1000, 470, 0, 0)
	nr = Rect2(880, 560, 120, 52)
	button(nr, "끝 (null)", "null", sel != null and not level_done, 18, Color("7a4f2a"))
	for k in nodes.keys():
		if k in lost or nxt[k] != null:
			continue
		var a2: Vector2 = pos[k]
		draw_rect(Rect2(a2.x - 12, a2.y + 40, 24, 8), Color("ffffff", 0.6))
	# 노드
	for k in nodes.keys():
		var p: Vector2 = pos[k]
		if k in lost:
			var sink := clampf(time, 0, 1)
			pcircle(p + Vector2(0, 12), 36, Color("3a6f8f", 0.5), Color(0, 0, 0, 0.3))
			continue
		var col := Color("3d7bd9")
		if k in held:
			col = Color("9b59d0")
		if sel == k:
			col = C_GOLD
		if flashing(k):
			col = C_RED
		var r := Rect2(p - Vector2(44, 44), Vector2(88, 88))
		var hov := hit(r, k, not level_done)
		pbox(r, col.lightened(0.15) if hov else col, C_INK)
		text_c(k, p + Vector2(0, -6), 26, C_WHITE)
		label_box(Rect2(p.x - 30, p.y + 6, 60, 30), str(nodes[k]), C_WHITE, C_INK, 18)
		if k in held:
			text_c("로봇이 들고 있음", p + Vector2(0, 70), 15, Color("e6c8ff"))
	# 목표 순서
	text("완성 모습:  HEAD → " + " → ".join(target) + " → 끝", Vector2(40, 640), 18, C_WHITE)
	robot(Vector2(140, 560), "")
