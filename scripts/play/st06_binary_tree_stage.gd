extends WalkStage
## ST06 이진 트리 - 계층형 자료실
## 정해진 순회 방식의 순서대로 방을 찾아가 E 로 방문 도장을 찍는다.

const KEYS := ["A", "B", "C", "D", "E"]
const TREE := {"A": ["B", "C"], "B": ["D", "E"], "C": [null, null], "D": [null, null], "E": [null, null]}
const LEVELS := ["pre", "in", "post", "level"]
const ANSWER := {"pre": ["A", "B", "D", "E", "C"], "in": ["D", "B", "E", "A", "C"], "post": ["D", "E", "B", "C", "A"], "level": ["A", "B", "C", "D", "E"]}
const NAMES := {"pre": "전위", "in": "중위", "post": "후위", "level": "레벨"}
const DESC := {"pre": "루트 → 왼쪽 → 오른쪽", "in": "왼쪽 → 루트 → 오른쪽", "post": "왼쪽 → 오른쪽 → 루트", "level": "위층부터 왼쪽 → 오른쪽"}
const WHY := {"pre": "전위는 방에 들어가자마자 기록하고 왼쪽으로 내려가요.", "in": "중위는 왼쪽 아래를 다 본 뒤에 기록해요.", "post": "후위는 두 자식을 모두 본 뒤에 기록해요.", "level": "레벨 순서는 같은 층을 왼쪽부터 다 본 뒤 내려가요."}

var order := "pre"
var answer: Array = []
var visited: Array = []
var chips := {}
var stamps: Node2D

func _init() -> void:
	stage_id = "ST06"
	stage_title = "계층형 자료실"
	npc_name = "자료실 사서"
	npc_portrait = preload("res://textures/npc_portraits/NPC06_portrait.png")
	level_count = LEVELS.size()
	hint_after_mistake = true
	code_keywords += ["visit", "Queue"]
	intro = [
		"어서 오렴. 나는 이 자료실을 오래 지켜 온 사서란다. 책을 분야별로 층층이 나눠 두면 찾기가 아주 쉽지.",
		"맨 위의 A 방에서 B, C 방으로 갈라지고, B에서 다시 D, E로 갈라져 있지? 위아래로 갈라지는 구조를 '트리'라고 한단다.",
		"맨 위 방을 '루트', 아래로 이어진 방을 '자식', 더 내려갈 곳이 없는 방을 '리프'라고 불러. 자식이 많아야 둘인 트리가 '이진 트리'야.",
		"트리의 방을 빠짐없이 도는 일을 '순회'라고 해. 언제 기록하느냐에 따라 이름이 달라진단다.",
		"전위는 루트를 먼저, 중위는 왼쪽을 다 보고 루트를, 후위는 자식을 다 보고 루트를 기록해. 레벨 순서는 위층부터 차례로 돌지.",
		"조작법! WASD로 계단을 오르내리고, 방 앞 E 표시에서 E를 누르면 방문 도장이 찍혀. 순서를 틀리면 노란 화살표가 알려 줄 거야.",
	]
	level_talk = [
		"전위 순회로 돌아 보렴. 방에 들어서면 바로 기록하고, 왼쪽 자식부터 내려가는 거야. 답은 A부터 시작이겠지?",
		"이번엔 중위 순회야. 왼쪽 끝까지 내려간 다음 기록하면서 올라와. 첫 도장은 어느 방일까?",
		"후위 순회란다. 자식을 모두 본 다음에야 부모를 기록해. 그래서 루트 A는 가장 마지막이지.",
		"마지막은 레벨 순서야. 위층부터 왼쪽에서 오른쪽으로. 줄을 세워 돌 듯이 큐를 쓰는 방법이란다.",
	]

func build_stage() -> void:
	stamps = Node2D.new()
	overlay.add_child(stamps)
	var c := mark("Order")
	panel_at(Rect2(c.x - 100, c.y - 44, 200, 88), Color("e9d7b0"), StageHUD.INK, 3)
	var pos := {"pre": Vector2(-52, -21), "in": Vector2(48, -21), "post": Vector2(-52, 21), "level": Vector2(48, 21)}
	for k in pos:
		var r := Rect2(c + pos[k] - Vector2(46, 17), Vector2(92, 34))
		chips[k] = panel_at(r, Color("f6e7c8"))
		text_at(NAMES[k], c + pos[k], 22, StageHUD.INK, 0)

func setup_level(n: int) -> void:
	order = LEVELS[n]
	answer = ANSWER[order]
	visited = []
	goal_text = "%s 순회 (%s) 순서대로 방문" % [NAMES[order], DESC[order]]
	for k in chips:
		var sb: StyleBoxFlat = (chips[k] as Panel).get_theme_stylebox("panel")
		sb.bg_color = StageHUD.GOLD if k == order else Color("f6e7c8")

func get_state() -> Dictionary:
	return {"v": visited}

func set_state(s: Dictionary) -> void:
	visited = s.v

func rebuild() -> void:
	clear_children(stamps)
	var want := {}
	for i in visited.size():
		var r: Interactable = spot("room", KEYS.find(visited[i]))
		text_at(str(i + 1), r.position + Vector2(0, -56), 30, StageHUD.GOLD, 7, stamps)
		want["log%d" % i] = {"text": visited[i], "pos": mark("Log%d" % i) + Vector2(0, 18), "scale": 0.6, "color": Color("3f9d48")}
	sync_items(want)

func info_rows() -> Array:
	return [["순회", NAMES[order]], ["방문", "%d / %d" % [visited.size(), answer.size()]], ["실수", mistakes]]

func state_text() -> String:
	return "visited = [lb]%s[rb]" % ", ".join(visited)

func prompt(t: Interactable) -> String:
	var k: String = KEYS[t.index]
	return "%s 방 이미 방문" % k if k in visited else "%s 방 방문" % k

func interact(t: Interactable) -> void:
	var k: String = KEYS[t.index]
	if k in visited:
		wrong("%s 는 이미 방문했어요." % k)
		return
	var expect: String = answer[visited.size()]
	if k != expect:
		wrong("%s 차례가 아니에요. %s" % [k, WHY[order]])
		return
	snapshot()
	visited.append(k)
	moves += 1
	code("visit(%s);" % k, "%d번째" % visited.size())
	rebuild()
	if visited.size() == answer.size():
		win("%s 순회: %s\n실수 %d회" % [NAMES[order], " ".join(visited), mistakes])

func summary_code() -> void:
	code("")
	code("// ── 재귀로 쓰면 ──" if order != "level" else "// ── 큐로 쓰면 ──")
	match order:
		"pre":
			code("visit(n);")
			code("go(n.left);")
			code("go(n.right);")
		"in":
			code("go(n.left);")
			code("visit(n);")
			code("go(n.right);")
		"post":
			code("go(n.left);")
			code("go(n.right);")
			code("visit(n);")
		"level":
			code("q.add(root);")
			code("while (!q.isEmpty()) {")
			code("  n = q.poll(); visit(n);")
			code("  q.add(n.left); q.add(n.right);")
			code("}")

func next_action() -> Array:
	if visited.size() >= answer.size():
		return [null, ""]
	var k: String = answer[visited.size()]
	return [spot("room", KEYS.find(k)), "%s 방 방문" % k]
