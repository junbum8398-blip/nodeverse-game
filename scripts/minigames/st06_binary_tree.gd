extends MiniGameBase
## ST06 이진 트리 - 계층형 자료실
## 선택된 순회 방식(전위/중위/후위/레벨 순서)으로 방을 방문하는 순서대로 노드를 클릭한다.

# 트리: 노드 -> [왼쪽, 오른쪽]
const T1 := {"A": ["B", "C"], "B": ["D", "E"], "C": [null, null], "D": [null, null], "E": [null, null]}
const T2 := {"A": ["B", "C"], "B": ["D", null], "C": ["E", "F"], "D": [null, null], "E": [null, "G"], "F": [null, null], "G": [null, null]}
const LEVELS := [
	{"tree": T1, "order": "pre"}, {"tree": T1, "order": "in"}, {"tree": T1, "order": "post"},
	{"tree": T2, "order": "in"}, {"tree": T2, "order": "post"}, {"tree": T2, "order": "level"},
]
const NAMES := {"pre": "전위 (루트→왼→오른)", "in": "중위 (왼→루트→오른)", "post": "후위 (왼→오른→루트)", "level": "레벨 순서 (위→아래, 왼→오른)"}

var tree: Dictionary
var order := ""
var answer: Array = []
var visited: Array = []
var pos := {}

func _init() -> void:
	stage_id = "ST06"
	stage_title = "계층형 자료실"
	level_count = LEVELS.size()

func setup_level(n: int) -> void:
	var L: Dictionary = LEVELS[n]
	tree = L.tree
	order = L.order
	goal = NAMES[order] + " 순회로 방문 순서대로 방을 클릭하세요."
	answer = []
	visited = []
	match order:
		"pre": _pre("A")
		"in": _in("A")
		"post": _post("A")
		"level":
			var q := ["A"]
			while not q.is_empty():
				var c = q.pop_front()
				answer.append(c)
				for ch in tree[c]:
					if ch != null:
						q.append(ch)
	pos = {}
	_layout("A", 0, 160.0, 1000.0)

func _layout(n, depth: int, x0: float, x1: float) -> void:
	if n == null:
		return
	pos[n] = Vector2((x0 + x1) / 2, 150 + depth * 128)
	_layout(tree[n][0], depth + 1, x0, (x0 + x1) / 2)
	_layout(tree[n][1], depth + 1, (x0 + x1) / 2, x1)

func _pre(n) -> void:
	if n == null: return
	answer.append(n); _pre(tree[n][0]); _pre(tree[n][1])

func _in(n) -> void:
	if n == null: return
	_in(tree[n][0]); answer.append(n); _in(tree[n][1])

func _post(n) -> void:
	if n == null: return
	_post(tree[n][0]); _post(tree[n][1]); answer.append(n)

func get_state() -> Dictionary:
	return {"v": visited, "moves": moves}

func set_state(s: Dictionary) -> void:
	visited = s.v
	moves = s.moves

func info_lines() -> Array:
	return [["순회", NAMES[order].split(" ")[0]], ["방문", "%d / %d" % [visited.size(), answer.size()]], ["실수", mistakes]]

func controls_text() -> String:
	return "방(노드)을 방문 순서대로 클릭 · Z 되돌리기 · R 초기화 · Esc 메뉴"

func on_button(id) -> void:
	if id in visited:
		wrong("%s 는 이미 방문했어요." % id, id)
		return
	var expect = answer[visited.size()]
	if id != expect:
		var hint := ""
		match order:
			"pre": hint = "전위는 루트를 먼저 기록하고 왼쪽 서브트리로 내려가요."
			"in": hint = "중위는 왼쪽 서브트리를 다 본 뒤 루트를 기록해요."
			"post": hint = "후위는 두 자식을 모두 본 뒤에 루트를 기록해요."
			"level": hint = "레벨 순서는 같은 깊이를 왼쪽부터 다 본 뒤 내려가요."
		wrong("%s 차례가 아니에요. %s" % [id, hint], id)
		return
	push_undo()
	visited.append(id)
	moves += 1
	if visited.size() == answer.size():
		win("%s: %s" % [NAMES[order].split(" ")[0], " ".join(visited)])

func draw_game() -> void:
	for n in tree:
		for ch in tree[n]:
			if ch != null:
				pline(pos[n] + Vector2(0, 34), pos[ch] - Vector2(0, 34), Color("c9a46a"))
	for n in tree:
		var p: Vector2 = pos[n]
		var r := Rect2(p - Vector2(46, 40), Vector2(92, 80))
		var hov := hit(r, n, not level_done)
		var col := Color("3d6bc4")
		if n in visited:
			col = C_GREEN
		if hov:
			col = col.lightened(0.2)
		if flashing(n):
			col = C_RED
		# 지붕 + 방
		draw_colored_polygon(PackedVector2Array([p + Vector2(-54, -28), p + Vector2(0, -60), p + Vector2(54, -28)]), C_BLUE_D)
		pbox(r, col, C_INK)
		text_c(n, p + Vector2(0, 12), 32, C_WHITE)
		var idx := visited.find(n)
		if idx >= 0:
			label_box(Rect2(p.x + 30, p.y - 56, 34, 30), str(idx + 1), C_GOLD, C_INK, 16)
		text_c("depth%d" % int((p.y - 150) / 128), p + Vector2(0, 58), 14, C_WHITE)
	# 방문 기록
	pbox(Rect2(160, 590, 840, 70), C_PANEL, C_INK)
	text("방문 순서(기록)", Vector2(180, 632), 18, C_PANEL_DARK)
	for i in answer.size():
		var r2 := Rect2(340 + i * 60, 600, 50, 50)
		pbox(r2, Color("d8c7a3") if i >= visited.size() else C_GREEN, C_INK, false)
		if i < visited.size():
			text_c(visited[i], r2.get_center() + Vector2(0, 9), 24, C_WHITE)
	if not visited.is_empty():
		robot(pos[visited.back()] + Vector2(70, 40), "")
	else:
		robot(Vector2(110, 230), "")
