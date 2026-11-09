extends WalkStage
## ST09 그래프 - 연결망 조사실
## 출발 건물에서 BFS(큐) / DFS(재귀)로, 이웃은 알파벳 순으로 조사하는 순서대로 건물을 찾아가 E 를 누른다.

const KEYS := ["A", "B", "C", "D", "E"]
const EDGES := [["A", "B"], ["A", "C"], ["B", "D"], ["C", "D"], ["D", "E"]]
const LEVELS := [
	{"start": "A", "algo": "BFS"}, {"start": "A", "algo": "DFS"}, {"start": "D", "algo": "BFS"}, {"start": "C", "algo": "DFS"},
]

var algo := "BFS"
var start := "A"
var adj := {}
var answer: Array = []
var snapshots: Array = []
var visited: Array = []
var stamps: Node2D

func _init() -> void:
	stage_id = "ST09"
	stage_title = "연결망 조사실"
	npc_name = "연결망 측량사"
	npc_portrait = preload("res://textures/npc_portraits/NPC09_portrait.png")
	level_count = LEVELS.size()
	hint_after_mistake = true
	code_keywords += ["queue", "visit", "seen"]
	intro = [
		"왔어? 난 연결망 측량사야! 이 마을은 집들이 길로 얽혀 있어서, 빠짐없이 돌아보려면 요령이 필요해.",
		"집 하나하나를 '정점', 집을 잇는 길을 '간선'이라고 해. 정점과 간선으로 이루어진 구조가 '그래프'야. 지하철 노선도나 친구 관계가 다 그래프지.",
		"트리와 달리 그래프는 길이 돌아서 만날 수 있어. 그래서 이미 간 집을 표시해 둬야 빙글빙글 돌지 않아.",
		"BFS는 가까운 집부터 넓게 퍼져 나가. 아래쪽 대기줄처럼 큐를 쓰고, 앞에서 꺼낸 집의 이웃을 뒤에 세워. 최단 경로를 찾을 때 좋아.",
		"DFS는 한 길을 끝까지 파고들다가 막히면 돌아와. 지금 온 길을 스택처럼 기억하지. 둘 다 이웃이 여럿이면 알파벳 빠른 쪽부터 봐!",
		"조작법! WASD로 걸어서, 조사할 집 앞에서 E를 눌러. 대기줄의 변화를 잘 봐. 순서를 틀리면 노란 화살표가 나타나.",
	]
	level_talk = [
		"A에서 BFS 조사를 시작하자. A의 이웃 B, C가 먼저, 그다음이 그들의 이웃이야.",
		"이번엔 A에서 DFS야. B로 들어가서 갈 수 있는 데까지 쭉 가 봐. 막히면 돌아와서 안 가 본 쪽으로!",
		"출발점을 D로 바꿔 볼게. D에서 BFS면 이웃 B, C, E가 먼저겠지?",
		"마지막! C에서 DFS 조사. 이웃은 알파벳 순이니까 A부터 들어가 봐.",
	]

func build_stage() -> void:
	stamps = Node2D.new()
	overlay.add_child(stamps)
	adj = {}
	for k in KEYS:
		adj[k] = []
	for e in EDGES:
		adj[e[0]].append(e[1])
		adj[e[1]].append(e[0])
	for k in adj:
		adj[k].sort()

func setup_level(n: int) -> void:
	var L: Dictionary = LEVELS[n]
	algo = L.algo
	start = L.start
	goal_text = "%s로 %s부터, 이웃은 알파벳 순으로 조사" % [algo, start]
	answer = []
	snapshots = [[start]]
	if algo == "BFS":
		var q := [start]
		var seen := {start: true}
		while not q.is_empty():
			var c = q.pop_front()
			answer.append(c)
			for nb in adj[c]:
				if not seen.has(nb):
					seen[nb] = true
					q.append(nb)
			snapshots.append(q.duplicate())
	else:
		_dfs(start, {}, [])
		snapshots.remove_at(0)
		snapshots.insert(0, [])
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
	return {"v": visited}

func set_state(s: Dictionary) -> void:
	visited = s.v

func _ds() -> Array:
	return snapshots[visited.size()] if visited.size() < snapshots.size() else []

func rebuild() -> void:
	clear_children(stamps)
	var lit := {}
	for i in visited.size():
		var r: Interactable = spot("house", KEYS.find(visited[i]))
		text_at(str(i + 1), r.position + Vector2(0, -60), 30, StageHUD.GOLD, 7, stamps)
		lit[visited[i]] = true
	clear_children(links)
	for e in EDGES:
		if lit.has(e[0]) and lit.has(e[1]):
			link(spot("house", KEYS.find(e[0])).position, spot("house", KEYS.find(e[1])).position, C_LINK, 0.0)
	var want := {}
	var ds := _ds()
	for i in mini(ds.size(), 4):
		want["q" + ds[i]] = {"text": ds[i], "pos": mark("Q%d" % i), "scale": 0.72, "color": Color("3d7bd9")}
	sync_items(want)

func info_rows() -> Array:
	return [["탐색", algo], ["방문", "{" + ", ".join(visited) + "}"], ["큐" if algo == "BFS" else "지나온 길", "[" + ", ".join(_ds()) + "]"]]

func state_text() -> String:
	return "%s = [lb]%s[rb]\nvisited = {%s}" % ["queue" if algo == "BFS" else "stack", ", ".join(_ds()), ", ".join(visited)]

func prompt(t: Interactable) -> String:
	var k: String = KEYS[t.index]
	return "%s 이미 조사함" % k if k in visited else "%s 조사하기" % k

func interact(t: Interactable) -> void:
	var k: String = KEYS[t.index]
	if k in visited:
		wrong("%s 는 이미 조사했어요." % k)
		return
	var expect: String = answer[visited.size()]
	if k != expect:
		if algo == "BFS":
			wrong("BFS는 큐 앞에서 꺼내요. 지금은 %s 차례가 아니에요." % k)
		else:
			wrong("DFS는 안 가 본 이웃 중 알파벳이 빠른 쪽으로 끝까지 들어가요.")
		return
	snapshot()
	visited.append(k)
	moves += 1
	if algo == "BFS":
		code("cur = queue.poll();", k)
		var added := []
		for nb in adj[k]:
			if not (nb in visited) and not (nb in _ds()) and nb != k:
				added.append(nb)
		for nb in added:
			code("queue.add(%s);" % nb)
	else:
		code("visit(%s);" % k, "%d번째" % visited.size())
	rebuild()
	if visited.size() == answer.size():
		win("%s 순서: %s\n실수 %d회" % [algo, " → ".join(visited), mistakes])

func summary_code() -> void:
	code("")
	if algo == "BFS":
		code("// 큐에 넣을 때 방문 표시해야")
		code("// 같은 집이 두 번 안 들어가요")
	else:
		code("// visit(n) 안에서 안 가 본")
		code("// 이웃을 차례로 visit() 해요")

func next_action() -> Array:
	if visited.size() >= answer.size():
		return [null, ""]
	var k: String = answer[visited.size()]
	return [spot("house", KEYS.find(k)), "%s 조사하기" % k]
