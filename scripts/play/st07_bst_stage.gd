extends WalkStage
## ST07 이진 탐색 트리 - 갈림길 창고
## 발판(인덱스 0~6 완전 이진 트리 자리)을 따라 내려가며 목표 값과 비교한다.
## 지금 칸에서 E: 찾았다 / 더 내려갈 곳 없음. 자식 칸에서 E: 그쪽으로 이동. 빈 발판에서 E: 새 값 넣기.

const LEVELS := [
	{"keys": [8, 4, 12, 2, 6, 10, null], "tasks": [["search", 6]]},
	{"keys": [8, 4, 12, 2, 6, 10, null], "tasks": [["search", 10], ["search", 11]]},
	{"keys": [8, 4, 12, 2, 6, 10, null], "tasks": [["insert", 14], ["search", 14], ["search", 3]]},
	{"keys": [50, 30, 70, 20, 40, 60, null], "tasks": [["insert", 80], ["search", 40], ["search", 45]]},
]

var keys: Array = []
var tasks: Array = []
var cur := 0
var path: Array = []
var comps := 0
var labels: Array = []
var ring: Line2D

func _init() -> void:
	stage_id = "ST07"
	stage_title = "갈림길 창고"
	npc_name = "갈림길 감독관"
	npc_portrait = preload("res://textures/npc_portraits/NPC07_portrait.png")
	level_count = LEVELS.size()
	hint_after_mistake = true
	code_keywords += ["node"]
	intro = [
		"좋아, 왔군! 난 이 갈림길 창고의 감독관이다. 여기선 길마다 규칙이 있어. 규칙만 알면 절대 헤매지 않지.",
		"발판의 숫자를 잘 봐. 어느 발판이든 왼쪽 아래는 그 값보다 작고, 오른쪽 아래는 그 값보다 커. 이게 '이진 탐색 트리'의 규칙이다.",
		"찾고 싶은 값을 지금 값과 비교해. 작으면 왼쪽, 크면 오른쪽. 갈림길을 지날 때마다 후보가 절반씩 줄어드니 아주 빠르지.",
		"내려갈 곳이 없으면? 찾는 값은 트리에 없는 거다. 그리고 새 값을 넣을 자리도 바로 거기야.",
		"조작법! 다음 칸 발판에서 E를 누르면 그쪽으로 내려간다. 지금 칸에서 E를 누르면 '찾았다' 또는 '여기까지'를 선언해. 빈 발판에서 E를 누르면 새 값이 들어가지. 틀리면 노란 화살표가 나온다.",
	]
	level_talk = [
		"첫 임무다. 6을 찾아라. 8보다 작으니 왼쪽, 4보다 크니 오른쪽. 도착하면 6 발판에서 E로 '찾았다'를 선언해.",
		"이번엔 10을 찾고, 11도 찾아라. 11은 트리에 없을 수도 있겠지? 더 내려갈 곳이 없으면 그 칸에서 '없음'을 선언해.",
		"14를 넣어라! 12의 오른쪽 빈 발판이 그 자리다. 넣은 다음 찾아 보고, 3도 찾아라.",
		"마지막이다. 값이 바뀌었으니 규칙대로 80을 넣고, 40과 45를 찾아라.",
	]

func build_stage() -> void:
	for i in 7:
		labels.append(text_at("", mark("Plate%d" % i) + Vector2(0, -2), 40, StageHUD.INK, 0))
	ring = Line2D.new()
	ring.width = 7.0
	ring.default_color = StageHUD.GOLD
	ring.closed = true
	overlay.add_child(ring)
	var e := PackedVector2Array()
	for a in 24:
		e.append(Vector2(cos(a / 24.0 * TAU) * 58, sin(a / 24.0 * TAU) * 30))
	ring.points = e

func setup_level(n: int) -> void:
	var L: Dictionary = LEVELS[n]
	keys = L.keys.duplicate()
	tasks = L.tasks.duplicate(true)
	_begin()

func _begin() -> void:
	cur = 0
	path = [0]
	comps = 0
	if not tasks.is_empty():
		var t = tasks[0]
		var s := ("%d 찾기: 작으면 왼쪽, 크면 오른쪽" if t[0] == "search" else "%d 넣기: 빈 자리까지 내려가기") % t[1]
		goal_text = s
		if is_node_ready() and hud.goal_label:
			hud.set_goal(s)

func get_state() -> Dictionary:
	return {"k": keys, "t": tasks, "c": cur, "p": path, "n": comps}

func set_state(s: Dictionary) -> void:
	keys = s.k
	tasks = s.t
	cur = s.c
	path = s.p
	comps = s.n
	if not tasks.is_empty():
		var t = tasks[0]
		hud.set_goal(("%d 찾기: 작으면 왼쪽, 크면 오른쪽" if t[0] == "search" else "%d 넣기: 빈 자리까지 내려가기") % t[1])

func rebuild() -> void:
	clear_children(links)
	for i in 7:
		labels[i].text = "" if keys[i] == null else str(keys[i])
		labels[i].add_theme_color_override("font_color", StageHUD.BLUE if i in path else StageHUD.INK)
	for i in range(1, path.size()):
		link(mark("Plate%d" % path[i - 1]) + Vector2(0, 34), mark("Plate%d" % path[i]) + Vector2(0, -36), C_LINK, 0.0)
	ring.position = mark("Plate%d" % cur) + Vector2(0, 4)

func _target():
	return tasks[0] if not tasks.is_empty() else null

func _dir_child() -> int:
	var t = _target()
	return cur * 2 + 1 if t[1] < keys[cur] else cur * 2 + 2

func _has_child(i: int) -> bool:
	return i < 7 and keys[i] != null

func info_rows() -> Array:
	var t = _target()
	return [["목표", "-" if t == null else "%s %d" % ["찾기" if t[0] == "search" else "넣기", t[1]]], ["현재 값", str(keys[cur])], ["비교", comps], ["남은 임무", tasks.size()]]

func state_text() -> String:
	var t = _target()
	if t == null:
		return "// 임무 완료"
	var op := "<" if t[1] < keys[cur] else (">" if t[1] > keys[cur] else "==")
	return "key = %s\nnode.key = %s\nkey %s node.key" % [num(t[1]), num(keys[cur]), op]

func prompt(t: Interactable) -> String:
	var task = _target()
	if task == null:
		return "발판"
	if t.index == cur:
		if task[1] == keys[cur]:
			return "찾았다!"
		return "여기까지 (없음)" if not _has_child(_dir_child()) else "지금 칸"
	if t.index >= 7 or keys[t.index] == null:
		return "%d 넣기" % task[1] if task[0] == "insert" else "빈 자리"
	return "%d 칸으로 이동" % keys[t.index]

func interact(t: Interactable) -> void:
	var task = _target()
	if task == null:
		return
	var k: int = task[1]
	var c: int = keys[cur]
	if t.index == cur:
		_at_current(task, k, c)
	else:
		_at_other(task, k, c, t.index)
	rebuild()

func _at_current(task, k: int, c: int) -> void:
	if k == c:
		snapshot()
		code("return node;", "%d == %d" % [k, c])
		_finish("%d 발견! (비교 %d회)" % [k, comps + 1])
		return
	var ch := _dir_child()
	if _has_child(ch):
		wrong("%d %s %d 이니 %s로 더 내려갈 수 있어요." % [k, "<" if k < c else ">", c, "왼쪽" if k < c else "오른쪽"])
		return
	if task[0] == "insert":
		wrong("빈 발판으로 가서 넣어 주세요.")
		return
	snapshot()
	code("return null;", "%s 자식 없음" % ("왼쪽" if k < c else "오른쪽"))
	_finish("%d 은(는) 트리에 없어요. (비교 %d회)" % [k, comps + 1])

func _at_other(task, k: int, c: int, i: int) -> void:
	if k == c:
		wrong("%d == %d 이에요. 지금 칸에서 E를 누르세요." % [k, c])
		return
	var want := _dir_child()
	if i != want:
		wrong("%d %s %d 이니 %s 자식 쪽으로 가야 해요." % [k, "<" if k < c else ">", c, "왼쪽" if k < c else "오른쪽"])
		return
	if keys[i] == null:
		if task[0] != "insert":
			wrong("여기는 비어 있어요. 지금 칸에서 '없음'을 선언하세요.")
			return
		snapshot()
		keys[i] = k
		moves += 1
		code("node.%s = new Node(%d);" % ["left" if i % 2 == 1 else "right", k])
		_finish("%d 을(를) %d 의 %s 자식으로 넣었어요." % [k, c, "왼쪽" if i % 2 == 1 else "오른쪽"])
		return
	snapshot()
	comps += 1
	moves += 1
	code("node = node.%s;" % ("left" if i % 2 == 1 else "right"), "%d %s %d" % [k, "<" if k < c else ">", c])
	cur = i
	path.append(i)

func _finish(msg: String) -> void:
	tasks.pop_front()
	if tasks.is_empty():
		win(msg + "\n실수 %d회" % mistakes)
	else:
		good(msg)
		_begin()

func summary_code() -> void:
	code("")
	code("// 비교할 때마다 절반씩 줄어요")
	code("// 평균 O(log n)")

func next_action() -> Array:
	var t = _target()
	if t == null:
		return [null, ""]
	if t[1] == keys[cur]:
		return [spot("pad", cur), "찾았다!"]
	var ch := _dir_child()
	if _has_child(ch):
		return [spot("pad", ch), "%d 칸으로 이동" % keys[ch]]
	if t[0] == "insert" and ch < 7:
		return [spot("pad", ch), "%d 넣기" % t[1]]
	return [spot("pad", cur), "없음 선언"]
