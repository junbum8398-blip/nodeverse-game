extends "res://scripts/minigames/learning_lab.gd"
## 자료구조 실습: 트리 구조(DS09) · 그래프 구조(DS10). 연결 관계만 평가하고 순회·탐색은 평가하지 않는다.

const TREE_LEVELS := [
	{"nodes": ["A", "B", "C"], "target": {"A": ["B", "C"]}, "start": {}},
	{"nodes": ["A", "B", "C", "D", "E"], "target": {"A": ["B", "C"], "B": ["D", null], "C": [null, "E"]}, "start": {}},
	{"nodes": ["A", "B", "C", "D", "E"], "target": {"A": ["B", "C"], "B": ["D", "E"]}, "start": {"A": ["B", null], "B": [null, "C"], "C": ["D", null]}},
]
const TREE_POS := {"A": Vector2(560, 170), "B": Vector2(370, 300), "C": Vector2(750, 300), "D": Vector2(270, 450), "E": Vector2(850, 450)}

const GRAPH_LEVELS := [
	{"directed": false, "weighted": false, "v": ["A", "B", "C", "D"], "edges": [["A", "B", 1], ["A", "C", 1], ["B", "D", 1], ["C", "D", 1]], "start": []},
	{"directed": true, "weighted": false, "v": ["A", "B", "C", "D"], "edges": [["A", "B", 1], ["B", "C", 1], ["C", "A", 1], ["D", "A", 1]], "start": []},
	{"directed": true, "weighted": true, "v": ["A", "B", "C", "D", "E"], "edges": [["A", "B", 3], ["B", "C", 2], ["C", "A", 4], ["D", "A", 1]], "start": [["A", "B", 5], ["C", "B", 2]]},
]

func lab_table() -> Dictionary:
	return {
		"tree": {"id": "DS09", "title": "가지 잇는 나무", "levels": 3, "art": "ST06", "npc": "NPC06", "npc_name": "자료실 사서",
			"intro": ["어서 오렴. 책이 층층이 갈라지는 자료실을 지으려면 먼저 '트리'를 이어 봐야 한단다.",
				"맨 위 하나가 루트, 아래로 이어진 쪽이 자식, 더 내려갈 곳이 없으면 리프야. 부모는 언제나 하나뿐이지.",
				"조작은 간단해. 부모 노드와 자식 노드를 차례로 E를 누르고 숫자 키 1은 왼쪽, 2는 오른쪽, 3은 연결 해제란다. 고리가 생기거나 부모가 둘이면 거부된단다."],
			"talk": ["A를 루트로 두고 왼쪽에 B, 오른쪽에 C를 이어 보렴.", "한 단계 더 깊은 나무야. 표의 왼쪽과 오른쪽을 잘 보렴. 한쪽만 있는 부모도 있단다.", "잘못 이어진 가지가 있구나. 부모와 자식을 고른 뒤 3번 키로 연결을 풀고, 표대로 다시 이어 보렴."],
			"hints": ["트리는 고리가 없고 모든 노드의 부모가 하나인 구조예요.", "표에서 부모 하나씩 읽어 왼쪽 슬롯, 오른쪽 슬롯 순서로 맞춰 보세요.", "예: A.left = B, A.right = C, B.left = D 이면 루트는 A, 리프는 C와 D예요."]},
		"graph": {"id": "DS10", "title": "연결망 건설소", "levels": 3, "art": "ST09", "npc": "NPC09", "npc_name": "연결망 측량사",
			"intro": ["왔어? 이번엔 조사가 아니라 건설이야. 마을 사이에 노선을 놓아서 '그래프'를 직접 만들어 보자.",
				"집은 정점, 길은 간선이야. 양쪽으로 다닐 수 있으면 무방향, 한쪽으로만 가면 방향 간선, 길에 비용이 붙으면 가중치가 있다고 해.",
				"트리와 달리 그래프는 고리가 생겨도 괜찮아. 어디에도 안 이어진 집이 있어도 요청대로라면 정답이야.",
				"출발 정점과 도착 정점을 차례로 E를 누르고 숫자 키 1로 간선을 놓아. 2는 삭제, 3과 4는 비용 조절이야. 다 놓으면 검사 지점에서 E를 눌러 확인해."],
			"talk": ["양쪽으로 다니는 길 4개를 놓아 줘. 무방향이라 A-B와 B-A는 같은 길이야.", "이번엔 한쪽으로만 가는 편도 노선이야. C에서 A로 돌아오면 고리가 생기지만 유효해.", "비용이 잘못된 노선과 방향이 뒤집힌 노선이 있어. 고쳐서 복원해 줘. E는 연결하지 않아도 돼."],
			"hints": ["정점은 장소, 간선은 연결이에요. 방문 순서는 평가하지 않아요.", "표의 각 줄을 출발 → 도착 순서로 E를 눌러 만들고, 방향과 비용까지 같은지 보세요.", "예: A→B(3), B→C(2)이면 A에서 C로 갈 수 있지만 C에서 A로는 못 가요."]},
	}

func problems_for(n: int) -> Array:
	return [TREE_LEVELS[n] if activity == "tree" else GRAPH_LEVELS[n]]

func setup_problem(p: Dictionary) -> void:
	if activity == "tree":
		state = {"edges": p.start.duplicate(true), "parent": "", "child": ""}
		goal = "표와 같은 부모·자식 연결 만들기"
	else:
		state = {"edges": {}, "from": "", "to": "", "cost": 1}
		for e in p.start:
			state.edges[edge_key(e[0], e[1])] = e[2]
		goal = ("양방향" if not p.directed else "편도") + " 노선표대로 연결망 만들기"

func handle(key: String) -> void:
	if activity == "tree":
		tree_action(key)
	else:
		graph_action(key)

func lab_rows() -> Array:
	if activity == "tree":
		return [["간선 수", tree_rows(state.edges).size()], ["행동", moves], ["실수", mistakes]]
	return [["간선 수", state.edges.size()], ["행동", moves], ["실수", mistakes]]

# ---------- 트리 ----------
func tree_action(key: String) -> void:
	var p: Dictionary = problems()[0]
	if p.nodes.has(key):
		if state.parent == "" or state.child != "":
			state.parent = key
			state.child = ""
		else:
			state.child = key
		return
	if key == "check":
		moves += 1
		var expected = tree_rows(p.target)
		var actual = tree_rows(state.edges)
		if actual == expected:
			var leaves = p.nodes.filter(func(n): return not state.edges.has(n))
			win("올바른 트리예요. 루트 A · 리프 %s" % ", ".join(leaves))
		elif actual.size() < expected.size():
			wrong("아직 %d개의 연결이 더 필요해요." % (expected.size() - actual.size()))
		else:
			wrong("왼쪽·오른쪽 슬롯이나 부모가 표와 다른 연결이 있어요.")
		return
	if key not in ["left", "right", "unlink"]:
		return
	if state.parent == "" or state.child == "":
		wrong("부모와 자식을 먼저 E를 눌러서 고르세요.")
		return
	if key == "unlink":
		tree_unlink(state.parent, state.child)
	else:
		tree_link(state.parent, state.child, 0 if key == "left" else 1)

func tree_unlink(parent: String, child: String) -> void:
	var slots: Array = state.edges.get(parent, [null, null])
	var side = slots.find(child)
	if side < 0:
		wrong("%s와 %s는 연결되어 있지 않아요." % [parent, child])
		return
	step()
	code("%s.%s = null;" % [parent, "left" if side == 0 else "right"], "연결 해제")
	state.edges[parent][side] = null
	if state.edges[parent] == [null, null]:
		state.edges.erase(parent)
	state.parent = ""
	state.child = ""

func tree_link(parent: String, child: String, side: int) -> void:
	if parent == child or child == "A":
		wrong("자기 자신이나 루트를 자식으로 연결할 수 없어요.")
		return
	if state.edges.get(parent, [null, null])[side] != null:
		wrong("그 슬롯은 이미 차 있어요. 먼저 연결을 해제하세요.")
		return
	for p in state.edges:
		if child in state.edges[p]:
			wrong("%s에게는 이미 부모 %s가 있어요. 부모는 하나뿐이에요." % [child, p])
			return
	var cursor = [child]
	while not cursor.is_empty():
		var node = cursor.pop_back()
		if node == parent:
			wrong("순환하는 연결은 트리가 아니에요.")
			return
		for next in state.edges.get(node, []):
			if next != null:
				cursor.append(next)
	step()
	if not state.edges.has(parent):
		state.edges[parent] = [null, null]
	state.edges[parent][side] = child
	code("%s.%s = %s;" % [parent, "left" if side == 0 else "right", child])
	state.parent = ""
	state.child = ""

func tree_rows(edges: Dictionary) -> Array:
	var rows = []
	for parent in edges:
		for side in 2:
			if edges[parent][side] != null:
				rows.append("%s%d%s" % [parent, side, edges[parent][side]])
	rows.sort()
	return rows

func state_code() -> String:
	if activity == "tree":
		var out = ""
		for parent in state.edges:
			out += "%s: left=%s, right=%s\n" % [parent, slot_name(state.edges[parent][0]), slot_name(state.edges[parent][1])]
		return out.strip_edges() if out != "" else "// 연결 없음"
	var names = state.edges.keys()
	names.sort()
	return "edges = " + ", ".join(names.map(func(k): return "%s(%d)" % [k, state.edges[k]]))

func slot_name(v) -> String:
	return "없음" if v == null else str(v)

# ---------- 그래프 ----------
func edge_key(a: String, b: String) -> String:
	var p: Dictionary = problems()[0]
	if p.directed:
		return a + ">" + b
	return (a + "-" + b) if a < b else (b + "-" + a)

func graph_action(key: String) -> void:
	var p: Dictionary = problems()[0]
	if p.v.has(key):
		if state.from == "" or state.to != "":
			state.from = key
			state.to = ""
		else:
			state.to = key
		return
	match key:
		"cost+": state.cost = mini(state.cost + 1, 9)
		"cost-": state.cost = maxi(state.cost - 1, 1)
		"add": graph_add()
		"del": graph_delete()
		"check": graph_check()

func graph_add() -> void:
	if state.from == "" or state.to == "":
		wrong("출발과 도착 정점을 먼저 E를 누르세요.")
		return
	if state.from == state.to:
		wrong("자기 자신으로 가는 간선은 이번 범위에서 만들지 않아요.")
		return
	var p: Dictionary = problems()[0]
	var k = edge_key(state.from, state.to)
	var cost: int = state.cost if p.weighted else 1
	if state.edges.has(k):
		if state.edges[k] == cost:
			wrong("같은 간선이 이미 있어요. 평행 간선은 만들지 않아요.")
			return
		step()
		state.edges[k] = cost
		code('edge("%s").cost = %d;' % [k, cost], "비용 수정")
	else:
		step()
		state.edges[k] = cost
		code('addEdge("%s", %d);' % [k, cost] if p.weighted else 'addEdge("%s");' % k)
	state.from = ""
	state.to = ""

func graph_delete() -> void:
	if state.from == "" or state.to == "":
		wrong("지울 간선의 두 정점을 먼저 E를 누르세요.")
		return
	var k = edge_key(state.from, state.to)
	if not state.edges.has(k):
		wrong("%s 간선은 없어요. 방향을 확인하세요." % k)
		return
	step()
	state.edges.erase(k)
	code('removeEdge("%s");' % k)
	state.from = ""
	state.to = ""

func graph_check() -> void:
	moves += 1
	var p: Dictionary = problems()[0]
	var want = {}
	for e in p.edges:
		want[edge_key(e[0], e[1])] = e[2]
	for k in want:
		if not state.edges.has(k):
			if p.directed and state.edges.has(k[2] + ">" + k[0]):
				wrong("%s 간선의 방향이 반대예요." % k)
			else:
				wrong("요청한 %s 간선이 아직 없어요." % k)
			return
		if state.edges[k] != want[k]:
			wrong("%s 간선의 비용이 요청과 달라요." % k)
			return
	for k in state.edges:
		if not want.has(k):
			wrong("요청에 없는 %s 간선이 있어요." % k)
			return
	win("요청한 연결망을 만들었어요. 고리와 단절은 요청대로라면 오답이 아니에요.")

func reachable(from: String) -> Array:
	var p: Dictionary = problems()[0]
	var seen = {from: true}
	var stack = [from]
	while not stack.is_empty():
		var u: String = stack.pop_back()
		for k in state.edges:
			var a: String = k[0]
			var b: String = k[2]
			if a == u and not seen.has(b):
				seen[b] = true
				stack.append(b)
			elif not p.directed and b == u and not seen.has(a):
				seen[a] = true
				stack.append(a)
	seen.erase(from)
	var out = seen.keys()
	out.sort()
	return out

func vertex_pos(i: int, n: int) -> Vector2:
	var a = -PI / 2 + TAU * i / n
	return Vector2(480, 320) + Vector2(cos(a) * 170, sin(a) * 170)

# ---------- 시안 위 배치 ----------
const NODE_NAMES := ["A", "B", "C", "D", "E"]

func action_keys() -> Dictionary:
	if activity == "tree":
		return {KEY_1: "left", KEY_2: "right", KEY_3: "unlink"}
	return {KEY_1: "add", KEY_2: "del", KEY_3: "cost-", KEY_4: "cost+"}

func stations() -> Array:
	var p: Dictionary = problems()[0]
	var out = []
	var names: Array = p.nodes if activity == "tree" else p.v
	for n in NODE_NAMES:
		out.append([n, "%s 선택" % n, ""] if names.has(n) else null)
	out.append(["check", "연결 검사" if activity == "tree" else "노선 검사", "검사"])
	return out

func node_pos(n: String) -> Vector2:
	return spot("st", NODE_NAMES.find(n)).position + Vector2(0, -62)

func node_tag(n: String, picked: bool) -> void:
	if picked:
		plate(node_pos(n), n, 26, GOLD, INK, 44)

func draw_board() -> void:
	if activity == "tree":
		draw_tree_board()
	else:
		draw_graph_board()

func draw_tree_board() -> void:
	var p: Dictionary = problems()[0]
	var rows = []
	for parent in p.target:
		rows.append([parent, slot_name(p.target[parent][0]), slot_name(p.target[parent][1])])
	table_at(Vector2(960, 230), ["부모", "왼쪽", "오른쪽"], rows, 300, 34, 20)
	for parent in state.edges:
		for side in 2:
			var child = state.edges[parent][side]
			if child != null:
				var a = node_pos(parent)
				var b = node_pos(child)
				ink_line(a, b, Color("5fd6ff"))
				plate((a + b) / 2, "왼" if side == 0 else "오", 18, CREAM, RED)
	for n in p.nodes:
		node_tag(n, n == state.parent or n == state.child)
	if state.parent != "" and state.child != "":
		plate(Vector2(640, 660), "%s → %s   1: 왼쪽   2: 오른쪽   3: 해제" % [state.parent, state.child], 24, GOLD)
	elif state.parent != "":
		plate(Vector2(640, 660), "부모 %s 선택됨. 자식 노드에서 E" % state.parent, 22)

func draw_graph_board() -> void:
	var p: Dictionary = problems()[0]
	var rows = []
	for e in p.edges:
		rows.append([("%s → %s" if p.directed else "%s — %s") % [e[0], e[1]], e[2] if p.weighted else "-"])
	table_at(Vector2(960, 110), ["노선 요청", "비용"], rows, 300, 32, 20)
	var adj = []
	for v in p.v:
		var out = []
		for k in state.edges:
			if k[0] == v:
				out.append(k[2])
			elif not p.directed and k[2] == v:
				out.append(k[0])
		out.sort()
		adj.append([v, " ".join(out) if not out.is_empty() else "-"])
	table_at(Vector2(960, 290), ["정점", "연결"], adj, 300, 32, 20)
	for k in state.edges:
		var a = node_pos(k[0])
		var b = node_pos(k[2])
		var d = (b - a).normalized()
		if p.directed:
			var side = Vector2(-d.y, d.x) * 10
			ink_arrow(a + d * 34 + side, b - d * 36 + side, Color("5fd6ff"))
		else:
			ink_line(a + d * 30, b - d * 30, Color("5fd6ff"))
		if p.weighted:
			plate((a + b) / 2, str(state.edges[k]), 20)
	for v in p.v:
		node_tag(v, v == state.from or v == state.to)
	var origin: String = state.from if state.from != "" else p.v[0]
	var reach_list: Array = reachable(origin)
	plate(Vector2(1110, 520), "%s에서 도달: %s" % [origin, " ".join(reach_list) if not reach_list.is_empty() else "없음"], 20)
	if state.from != "" and state.to != "":
		var tip = "%s → %s   1: 추가   2: 삭제" % [state.from, state.to]
		if p.weighted:
			tip += "   3·4: 비용 %d" % state.cost
		plate(Vector2(500, 660), tip, 22, GOLD)
	elif state.from != "":
		plate(Vector2(500, 660), "출발 %s 선택됨. 도착 정점에서 E" % state.from, 22)
