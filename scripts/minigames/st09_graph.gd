extends MiniGameBase
## ST09 그래프 - 연결망 조사실
## BFS(큐) / DFS(스택·재귀)로 A 에서 출발해 '이웃은 알파벳 순'으로 조사하는 순서대로 건물을 클릭한다.

const G1 := {"nodes": {"A": Vector2(200, 470), "B": Vector2(260, 190), "C": Vector2(520, 470), "D": Vector2(620, 190), "E": Vector2(860, 330)},
	"edges": [["A", "B"], ["A", "C"], ["B", "D"], ["C", "E"], ["D", "E"], ["C", "D"]]}
const G2 := {"nodes": {"A": Vector2(160, 330), "B": Vector2(330, 170), "C": Vector2(330, 490), "D": Vector2(530, 170), "E": Vector2(530, 490), "F": Vector2(730, 330), "G": Vector2(920, 330)},
	"edges": [["A", "B"], ["A", "C"], ["B", "D"], ["B", "E"], ["C", "E"], ["D", "F"], ["E", "F"], ["F", "G"], ["C", "D"]]}
const LEVELS := [
	{"g": G1, "algo": "BFS"}, {"g": G1, "algo": "DFS"}, {"g": G2, "algo": "BFS"}, {"g": G2, "algo": "DFS"},
]

var g: Dictionary
var algo := "BFS"
var adj := {}
var answer: Array = []
var snapshots: Array = []   # 각 방문 시점의 큐/스택 표시용
var visited: Array = []

func _init() -> void:
	stage_id = "ST09"
	stage_title = "연결망 조사실"
	level_count = LEVELS.size()

func setup_level(n: int) -> void:
	var L: Dictionary = LEVELS[n]
	g = L.g
	algo = L.algo
	goal = "%s로 A부터, 이웃을 알파벳 순으로 조사하세요." % algo
	adj = {}
	for k in g.nodes:
		adj[k] = []
	for e in g.edges:
		adj[e[0]].append(e[1])
		adj[e[1]].append(e[0])
	for k in adj:
		adj[k].sort()
	answer = []
	snapshots = [["A"]]
	if algo == "BFS":
		var q := ["A"]
		var seen := {"A": true}
		while not q.is_empty():
			var c = q.pop_front()
			answer.append(c)
			for nb in adj[c]:
				if not seen.has(nb):
					seen[nb] = true
					q.append(nb)
			snapshots.append(q.duplicate())
	else:
		var seen2 := {}
		var st := []
		_dfs("A", seen2, st)
	visited = []

func _dfs(n: String, seen: Dictionary, st: Array) -> void:
	seen[n] = true
	st.append(n)
	answer.append(n)
	snapshots.append(st.duplicate())
	for nb in adj[n]:
		if not seen.has(nb):
			_dfs(nb, seen, st)
	st.pop_back()

func get_state() -> Dictionary:
	return {"v": visited, "moves": moves}

func set_state(s: Dictionary) -> void:
	visited = s.v
	moves = s.moves

func info_lines() -> Array:
	var ds: Array = snapshots[visited.size()] if visited.size() < snapshots.size() else []
	return [["탐색", algo], ["방문", "{" + ",".join(visited) + "}"], ["큐" if algo == "BFS" else "경로 스택", "[" + ",".join(ds) + "]"]]

func controls_text() -> String:
	return "건물을 조사 순서대로 클릭 · Z 되돌리기 · R 초기화 · Esc 메뉴"

func on_button(id) -> void:
	if id in visited:
		wrong("%s 는 이미 방문했어요." % id, id)
		return
	var expect = answer[visited.size()]
	if id != expect:
		if algo == "BFS":
			wrong("BFS는 큐 앞에서 꺼내요. 지금은 %s 차례가 아니에요." % id, id)
		else:
			wrong("DFS는 방문 안 한 이웃 중 알파벳이 빠른 쪽으로 끝까지 들어가요.", id)
		return
	push_undo()
	visited.append(id)
	moves += 1
	if visited.size() == answer.size():
		win("%s 순서: %s" % [algo, " → ".join(visited)])

func draw_game() -> void:
	for e in g.edges:
		var a: Vector2 = g.nodes[e[0]]
		var b: Vector2 = g.nodes[e[1]]
		var lit: bool = (e[0] in visited) and (e[1] in visited)
		pline(a, b, Color("6fd3ff") if lit else Color("d8c7a3"), 10)
	for k in g.nodes:
		var p: Vector2 = g.nodes[k]
		var r := Rect2(p - Vector2(44, 36), Vector2(88, 76))
		var hov := hit(r, k, not level_done)
		var col := Color("3d6bc4")
		if k in visited:
			col = C_GREEN
		if hov:
			col = col.lightened(0.2)
		if flashing(k):
			col = C_RED
		draw_colored_polygon(PackedVector2Array([p + Vector2(-52, -26), p + Vector2(0, -60), p + Vector2(52, -26)]), C_BLUE_D)
		pbox(r, col, C_INK)
		text_c(k, p + Vector2(0, 14), 32, C_WHITE)
		var idx := visited.find(k)
		if idx >= 0:
			label_box(Rect2(p.x + 28, p.y - 58, 34, 30), str(idx + 1), C_GOLD, C_INK, 16)
	# 큐/스택 시각화
	var ds: Array = snapshots[visited.size()] if visited.size() < snapshots.size() else []
	pbox(Rect2(160, 580, 600, 72), C_PANEL_DARK, C_INK)
	text_c("FRONT" if algo == "BFS" else "바닥", Vector2(210, 624), 16, C_WHITE)
	for i in ds.size():
		label_box(Rect2(260 + i * 60, 590, 52, 52), ds[i], C_PANEL, C_INK, 24)
	text_c("REAR" if algo == "BFS" else "top", Vector2(720, 624), 16, C_WHITE)
	if not visited.is_empty():
		robot(g.nodes[visited.back()] + Vector2(0, 80), "")
