extends MiniGameBase
## ST07 이진 탐색 트리 - 갈림길 창고
## 로봇이 루트에서 출발. 현재 노드와 목표 값을 비교해 ◀ 왼쪽(작다) / 오른쪽(크다) ▶ / 찾았다! 를 고른다.
## 삽입 과제는 빈 자리에 도착하면 그 자리에 새 노드가 생긴다.

const LEVELS := [
	{"keys": [8, 4, 12, 2, 6, 10], "tasks": [["search", 6]]},
	{"keys": [8, 4, 12, 2, 6, 10], "tasks": [["search", 10], ["search", 11]]},
	{"keys": [8, 4, 12, 2, 6, 10], "tasks": [["insert", 9], ["insert", 14], ["search", 9]]},
	{"keys": [50, 30, 70, 20, 40, 60, 80], "tasks": [["insert", 35], ["insert", 65], ["search", 35], ["search", 45]]},
]

var tree := {}          # key -> [left, right]
var root := 0
var tasks: Array = []
var cur = null
var path: Array = []
var comps := 0
var total_comps := 0

func _init() -> void:
	stage_id = "ST07"
	stage_title = "갈림길 창고"
	level_count = LEVELS.size()

func setup_level(n: int) -> void:
	var L: Dictionary = LEVELS[n]
	tree = {}
	root = L.keys[0]
	for k in L.keys:
		_insert(k)
	tasks = L.tasks.duplicate(true)
	total_comps = 0
	_begin_task()

func _insert(k: int) -> void:
	if tree.is_empty():
		tree[k] = [null, null]
		return
	var c := root
	while true:
		var side := 0 if k < c else 1
		if tree[c][side] == null:
			tree[c][side] = k
			tree[k] = [null, null]
			return
		c = tree[c][side]

func _begin_task() -> void:
	cur = root
	path = [root]
	comps = 0
	if tasks.is_empty():
		return
	var t = tasks[0]
	goal = ("비교하며 %d을(를) 찾으세요. 없으면 빈 자리까지 내려가요." if t[0] == "search" else "비교하며 %d을(를) 넣을 빈 자리를 찾으세요.") % t[1]

func get_state() -> Dictionary:
	return {"tree": tree, "tasks": tasks, "cur": cur, "path": path, "comps": comps, "moves": moves}

func set_state(s: Dictionary) -> void:
	tree = s.tree
	tasks = s.tasks
	cur = s.cur
	path = s.path
	comps = s.comps
	moves = s.moves

func info_lines() -> Array:
	var t = tasks[0] if not tasks.is_empty() else ["-", "-"]
	return [["목표", "%s %s" % ["찾기" if t[0] == "search" else "넣기", str(t[1])]], ["비교", comps], ["남은 과제", tasks.size()]]

func controls_text() -> String:
	return "← 왼쪽(작다) · → 오른쪽(크다) · Space 찾았다! · Z 되돌리기 · R 초기화"

func on_key(ev: InputEventKey) -> bool:
	match ev.keycode:
		KEY_LEFT, KEY_A: on_button("L")
		KEY_RIGHT, KEY_D: on_button("R")
		KEY_SPACE, KEY_E: on_button("F")
		_: return false
	return true

func on_button(id) -> void:
	if tasks.is_empty() or cur == null:
		return
	var t = tasks[0]
	var k: int = t[1]
	var correct := "F" if k == cur else ("L" if k < cur else "R")
	if id != correct:
		match correct:
			"F": wrong("%d == %d 이에요. 찾았어요!" % [k, cur], id)
			"L": wrong("%d < %d 이니 왼쪽으로 가야 해요." % [k, cur], id)
			"R": wrong("%d > %d 이니 오른쪽으로 가야 해요." % [k, cur], id)
		return
	push_undo()
	moves += 1
	comps += 1
	if id == "F":
		if t[0] == "insert":
			wrong("이미 있는 키라 넣지 않아요.")
		_finish("%d 발견! (비교 %d회)" % [k, comps])
		return
	var side := 0 if id == "L" else 1
	var nxt = tree[cur][side]
	if nxt == null:
		if t[0] == "insert":
			tree[cur][side] = k
			tree[k] = [null, null]
			_finish("%d 을(를) %d 의 %s 자식으로 넣었어요. (비교 %d회)" % [k, cur, "왼쪽" if side == 0 else "오른쪽", comps])
		else:
			_finish("빈 자리에 도착 → %d 은(는) 트리에 없어요. (비교 %d회)" % [k, comps])
		return
	cur = nxt
	path.append(cur)

func _finish(msg: String) -> void:
	total_comps += comps
	tasks.pop_front()
	if tasks.is_empty():
		win(msg)
	else:
		good(msg)
		_begin_task()

func _pos(k, depth: int, x0: float, x1: float, out: Dictionary) -> void:
	if k == null:
		return
	out[k] = Vector2((x0 + x1) / 2, 140 + depth * 110)
	_pos(tree[k][0], depth + 1, x0, (x0 + x1) / 2, out)
	_pos(tree[k][1], depth + 1, (x0 + x1) / 2, x1, out)

func _fixed_pos(k, fixed: Dictionary, out: Dictionary) -> void:
	for s in 2:
		var c = tree[k][s]
		if c == null:
			continue
		out[c] = fixed[c] if fixed.has(c) else out[k] + Vector2(-90 if s == 0 else 90, 112)
		_fixed_pos(c, fixed, out)

func draw_game() -> void:
	var P := {}
	_pos(root, 0, 60.0, 1000.0, P)
	if root == 8:
		# 배경 그림 속 발판 위치에 맞춤 (8 / 4 12 / 2 6 10 빈자리)
		var fixed := {8: Vector2(712, 160), 4: Vector2(512, 276), 12: Vector2(892, 276), 2: Vector2(376, 408), 6: Vector2(628, 438), 10: Vector2(812, 408), 14: Vector2(1032, 408)}
		for k in P.keys():
			P.erase(k)
		P[root] = fixed[root]
		_fixed_pos(root, fixed, P)
	for k in tree:
		for s in 2:
			var c = tree[k][s]
			var on_path: bool = c != null and (k in path) and (c in path)
			if c != null:
				pline(P[k] + Vector2(0, 28), P[c] - Vector2(0, 28), Color("6fd3ff") if on_path else Color("c9a46a"))
			elif k == cur:
				var ep: Vector2 = P[k] + Vector2(-60 if s == 0 else 60, 84)
				pline(P[k] + Vector2(0, 28), ep - Vector2(0, 20), Color(1, 1, 1, 0.35), 4)
				outline(Rect2(ep - Vector2(26, 20), Vector2(52, 40)), Color(1, 1, 1, 0.6))
	for k in tree:
		var p: Vector2 = P[k]
		var col := Color("8b8f9a")
		if k in path:
			col = Color("3d7bd9")
		if k == cur:
			col = C_GOLD.darkened(0.15)
		pbox(Rect2(p - Vector2(40, 28), Vector2(80, 56)), col, C_INK)
		text_c(str(k), p + Vector2(0, 10), 26, C_WHITE)
	if cur != null and P.has(cur):
		robot(P[cur] + Vector2(64, 30), "")
	# 조작판
	var en := not level_done and not tasks.is_empty()
	var t = tasks[0] if not tasks.is_empty() else ["", 0]
	pbox(Rect2(260, 580, 640, 84), C_PANEL, C_INK)
	if tasks.is_empty():
		text("모든 과제 완료!", Vector2(280, 630), 20, C_INK)
	else:
		text("%s %s  vs  현재 %s" % ["찾기" if t[0] == "search" else "넣기", str(t[1]), str(cur)], Vector2(280, 630), 20, C_INK)
	button(Rect2(560, 592, 104, 60), "◀ 작다", "L", en, 18, C_RED if flashing("L") else C_BLUE)
	button(Rect2(672, 592, 104, 60), "찾았다!", "F", en, 18, C_RED if flashing("F") else C_GREEN)
	button(Rect2(784, 592, 104, 60), "크다 ▶", "R", en, 18, C_RED if flashing("R") else C_BLUE)
