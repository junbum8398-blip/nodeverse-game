extends WalkStage
## ST05 해시 - 이름으로 찾는 물품대장
## 입고대에서 물품을 집어 h(k) = k mod 5 사물함에 넣는다. 이미 있는 키는 중복 거절함으로.
## 검색 단계: 키의 사물함을 열고 체인을 따라가며 정확한 키를 찾는다.

const M := 5
const LEVELS := [
	{"items": [[12, "포도"], [7, "배"], [3, "사과"], [10, "귤"]], "find": [7, 12], "goal": "h(k) = k mod 5 로 넣고 찾기"},
	{"items": [[21, "감"], [6, "밤"], [11, "무"], [6, "밤"], [14, "콩"], [9, "쌀"]], "find": [11, 9, 6], "goal": "충돌과 중복 키를 처리하며 넣고 찾기"},
	{"items": [[25, "책"], [40, "펜"], [33, "컵"], [18, "솔"], [25, "책"], [8, "끈"], [13, "못"]], "find": [13, 40, 18], "goal": "긴 체인이 생겨도 정확히 찾기"},
	{"items": [[7, "배"], [12, "감"], [7, "귤"]], "find": [7], "update": true, "goal": "같은 키가 또 오면 값만 바꾸기 (맵)"},
	{"items": [[7, "배"], [12, "감"], [2, "콩"], [9, "쌀"]], "find": [2, 4], "linear": true, "goal": "선형 탐사: 충돌하면 다음 빈 칸에 넣기"},
]

var buckets: Array = []
var queue: Array = []
var finds: Array = []
var phase := "insert"
var hand = null
var open_b := -1
var probe := 0
var panel_root: Node2D

func _init() -> void:
	stage_id = "ST05"
	stage_title = "이름으로 찾는 물품대장"
	npc_name = "물품대장 담당자"
	npc_portrait = preload("res://textures/npc_portraits/NPC05_portrait.png")
	level_count = LEVELS.size()
	hint_after_mistake = true
	code_keywords += ["Item"]
	intro = [
		"반가워요. 저는 물품대장을 맡고 있어요. 물건이 수천 개여도 이름표만 보면 바로 찾아야 하거든요.",
		"처음부터 하나씩 뒤지면 너무 오래 걸려요. 그래서 키를 계산 한 번으로 칸 번호로 바꾸는 함수를 써요. 이게 '해시 함수'예요.",
		"여기 함수는 h(k) = k mod 5, 즉 키를 5로 나눈 나머지예요. 12면 나머지 2, 그러니 2번 사물함! 이렇게 키로 값을 찾는 구조가 '맵'이에요.",
		"그런데 7도 나머지가 2네요? 다른 키가 같은 칸에 몰리는 걸 '충돌'이라고 해요. 같은 칸에 줄줄이 달아 두는 방법을 '체이닝'이라고 하죠.",
		"같은 키는 두 번 넣지 않아요. 키가 겹치지 않는 묶음이 '집합'이에요. 이미 있는 키가 오면 중복 거절함으로 보내 주세요.",
		"조작법! 입고대에서 E로 물품을 집고, 계산한 번호의 사물함에서 E로 넣어요. 검색 단계에서는 사물함을 열고 E를 눌러 체인을 하나씩 비교해요. 틀리면 노란 화살표가 나타나요.",
	]
	level_talk = [
		"첫 번째 장부예요. 12, 7, 3, 10을 각각 맞는 사물함에 넣어 주세요. 다 넣으면 7과 12를 찾아 볼게요.",
		"이번엔 충돌이 많아요. 21, 6, 11은 나머지가 다 1이에요! 두 번째로 오는 6은 이미 있으니 중복 거절함으로 보내 주세요.",
		"3번 사물함에 체인이 길게 달릴 거예요. 체인이 길어지면 찾는 데 오래 걸린다는 걸 느껴 보세요.",
		"이번 장부는 키에 값을 붙이는 '맵'이에요. 같은 키 7이 다시 오면 거절하지 말고, 그 키가 있는 사물함에 넣어 값만 바꿔 주세요.",
		"마지막은 '선형 탐사'예요. 사물함 한 칸에 하나만 넣을 수 있어요. 자리가 차 있으면 다음 칸으로 넘어가요. 찾을 때도 같은 길을 따라가고, 빈 칸을 만나면 없는 키예요.",
	]

func build_stage() -> void:
	panel_root = Node2D.new()
	overlay.add_child(panel_root)

func setup_level(n: int) -> void:
	var L: Dictionary = LEVELS[n]
	buckets = []
	for i in M:
		buckets.append([])
	queue = L.items.duplicate(true)
	finds = L.find.duplicate()
	phase = "insert"
	hand = null
	open_b = -1
	probe = 0
	goal_text = L.goal

func get_state() -> Dictionary:
	return {"b": buckets, "q": queue, "f": finds, "p": phase, "h": hand, "o": open_b, "r": probe}

func set_state(s: Dictionary) -> void:
	buckets = s.b
	queue = s.q
	finds = s.f
	phase = s.p
	hand = s.h
	open_b = s.o
	probe = s.r

func count() -> int:
	var n := 0
	for b in buckets:
		n += b.size()
	return n

func is_linear() -> bool:
	return LEVELS[level].get("linear", false)

func has_key(k: int) -> bool:
	for b in (range(M) if is_linear() else [k % M]):
		for it in buckets[b]:
			if it[0] == k:
				return true
	return false

## 선형 탐사로 키 k 가 들어갈 칸. 한 바퀴를 돌아도 자리가 없으면 -1.
func probe_slot(k: int) -> int:
	for step_n in M:
		var b: int = (k + step_n) % M
		if buckets[b].is_empty():
			return b
	return -1

func rebuild() -> void:
	var want := {}
	for b in M:
		for i in buckets[b].size():
			var it = buckets[b][i]
			var hidden: bool = phase == "find" and open_b != b and not is_linear()
			var col := Color("f2c14e")
			if open_b == b and i == probe:
				col = Color("6fd3ff")
			var entry := {"text": "?" if hidden else str(it[0]), "pos": mark("Tag%d" % b) + Vector2(0, 44 + i * 36), "scale": 0.5, "color": col, "z": 1}
			want["k%d" % it[0]] = entry
	if not queue.is_empty() and hand == null:
		want["q%d" % queue[0][0]] = {"text": str(queue[0][0]), "pos": mark("Inbox")}
	if hand != null:
		want["q%d" % hand[0]] = {"text": str(hand[0]), "pos": hold_pos()}
	var held_id = "q%d" % hand[0] if hand != null else null
	sync_items(want, held_id)
	for id in items:
		if want.has(id) and want[id].has("color"):
			(items[id] as StageCrate).set_tint(want[id].color)
	_draw_panel()

func _draw_panel() -> void:
	clear_children(panel_root)
	var top := mark("Panel")
	var entries := []
	for b in buckets:
		for it in b:
			entries.append("%d: %s" % [it[0], it[1]])
	var shown := entries.slice(maxi(0, entries.size() - 4))
	for i in shown.size():
		text_at(shown[i], top + Vector2(0, 28 + i * 30), 22, StageHUD.INK, 0, panel_root)
	text_at("항목 %d" % count(), top + Vector2(0, 148), 26, StageHUD.NAVY, 0, panel_root)

func _cur_text() -> String:
	if phase == "insert":
		if hand != null:
			return "%d: %s" % [hand[0], hand[1]]
		return "-" if queue.is_empty() else "%d: %s (입고대)" % [queue[0][0], queue[0][1]]
	return "키 %d 찾기" % finds[0] if not finds.is_empty() else "-"

func info_rows() -> Array:
	return [["단계", "넣기" if phase == "insert" else "찾기"], ["현재", _cur_text()], ["항목", count()], ["충돌 처리", "선형 탐사" if is_linear() else "체이닝"]]

func state_text() -> String:
	var t := ""
	for b in M:
		var keys := []
		for it in buckets[b]:
			keys.append(str(it[0]))
		t += "table[lb]%d[rb] = %s\n" % [b, " → ".join(keys) if not keys.is_empty() else "null"]
	return t.strip_edges()

func hint_allowed(t: Interactable) -> bool:
	return t.kind != "bucket" or mistakes > 0   # 어느 사물함인지 계산하는 게 이 스테이지의 핵심

func prompt(t: Interactable) -> String:
	match t.kind:
		"intake": return "물품 집기" if hand == null and not queue.is_empty() else "입고대"
		"hash":
			if hand != null:
				return "h(%d) 계산하기" % hand[0]
			return "해시 계산기"
		"dup": return "중복 키로 거절" if hand != null else "중복 거절함"
		"bucket":
			if phase == "insert":
				return "%d번 사물함에 넣기" % t.index if hand != null else "%d번 사물함" % t.index
			if open_b == t.index:
				return "다음 항목 비교"
			return "%d번 사물함 열기" % t.index
	return t.prompt

func interact(t: Interactable) -> void:
	match t.kind:
		"intake":
			if hand != null:
				wrong("이미 물품을 들고 있어요.")
			elif queue.is_empty():
				wrong("입고대가 비어 있어요.")
			else:
				snapshot()
				hand = queue.pop_front()
				code("key = %d;" % hand[0], hand[1])
		"hash":
			if hand != null:
				code("h = %d %% 5;" % hand[0], "= %d" % (hand[0] % M))
				good("h(%d) = %d mod 5 = %d" % [hand[0], hand[0], hand[0] % M])
		"dup":
			if hand == null:
				wrong("먼저 입고대에서 물품을 집어 오세요.")
			elif LEVELS[level].get("update", false):
				wrong("이번 장부는 맵이에요. 같은 키는 거절하지 말고 값을 바꿔요.")
			elif not has_key(hand[0]):
				wrong("키 %d 는 아직 없는 키예요. 사물함에 넣어 주세요." % hand[0])
			else:
				snapshot()
				code("set.add(%d);" % hand[0], "이미 있어 거절")
				good("키 %d 는 이미 있어 거절! (중복 불가)" % hand[0])
				hand = null
				moves += 1
				_after_insert()
		"bucket":
			if phase == "insert":
				_insert(t.index)
			else:
				_find(t.index)
	rebuild()

func _insert(b: int) -> void:
	if hand == null:
		wrong("먼저 입고대에서 물품을 집어 오세요.")
		return
	var k: int = hand[0]
	if has_key(k):
		if not LEVELS[level].get("update", false):
			wrong("키 %d 는 이미 등록돼 있어요. 중복 거절함으로 보내세요." % k)
			return
		if b != k % M:
			wrong("%d mod 5 = %d 이에요. 그 칸에 있는 키의 값을 바꿔요." % [k, k % M])
			return
		snapshot()
		for it in buckets[b]:
			if it[0] == k:
				code("table.put(%d);" % k, "%s → %s" % [it[1], hand[1]])
				it[1] = hand[1]
		good("키 %d 의 값을 %s(으)로 바꿨어요. 항목 수는 그대로예요." % [k, hand[1]])
		hand = null
		moves += 1
		_after_insert()
		return
	if is_linear():
		var slot := probe_slot(k)
		if b != slot:
			wrong("h(%d) = %d 부터 차례로 보면 첫 빈 칸은 %d번이에요." % [k, k % M, slot])
			return
	elif b != k % M:
		wrong("%d mod 5 = %d 이에요. %d번이 아니에요." % [k, k % M, b])
		return
	snapshot()
	buckets[b].append(hand)
	code("table[%d].add(%d);" % [b, k], hand[1] + (" (충돌)" if buckets[b].size() > 1 or b != k % M else ""))
	hand = null
	moves += 1
	_after_insert()

func _after_insert() -> void:
	if queue.is_empty() and hand == null:
		phase = "find"
		set_goal("키 %d 찾기: 사물함을 열고 체인을 비교하세요" % finds[0])
		hud.toast("등록 끝! 이제 키 %d 를 찾아 보세요." % finds[0], StageHUD.GOLD, 3.5)

func _find(b: int) -> void:
	if finds.is_empty():
		return
	if is_linear():
		_find_linear(b)
		return
	var key: int = finds[0]
	if b != key % M:
		wrong("키 %d 는 %d번 사물함에 있어요 (%d mod 5)." % [key, key % M, key])
		return
	if open_b != b:
		snapshot()
		open_b = b
		probe = 0
		code("node = table[%d];" % b, "체인의 맨 앞")
		return
	var it = buckets[b][probe]
	if it[0] != key:
		snapshot()
		code("node = node.next;", "%d ≠ %d" % [it[0], key])
		probe += 1
		moves += 1
		return
	snapshot()
	code("return node.value;", "%d: %s" % [it[0], it[1]])
	good("찾았다! %d: %s" % [it[0], it[1]])
	finds.pop_front()
	open_b = -1
	probe = 0
	moves += 1
	if finds.is_empty():
		win("등록 %d건, 검색 완료!\n실수 %d회" % [count(), mistakes])
	else:
		set_goal("키 %d 찾기: 사물함을 열고 체인을 비교하세요" % finds[0])

func _find_linear(b: int) -> void:
	var key: int = finds[0]
	var expected: int = open_b if open_b >= 0 else key % M
	if b != expected:
		wrong("선형 탐사는 %d mod 5 = %d번에서 시작해 한 칸씩 살펴요. 지금은 %d번 차례예요." % [key, key % M, expected])
		return
	snapshot()
	moves += 1
	if buckets[b].is_empty():
		code("return null;", "빈 칸이면 없는 키")
		good("%d번이 비어 있으니 키 %d 는 없어요." % [b, key])
	elif buckets[b][0][0] == key:
		code("return table[%d];" % b, "%d 찾음" % key)
		good("%d번에서 키 %d 를 찾았어요." % [b, key])
	else:
		code("i = (i + 1) % 5;", "%d ≠ %d" % [buckets[b][0][0], key])
		open_b = (b + 1) % M
		return
	finds.pop_front()
	open_b = -1
	if finds.is_empty():
		win("등록과 탐사 검색 완료!\n실수 %d회" % mistakes)
	else:
		set_goal("키 %d 찾기: %d번부터 한 칸씩 비교하세요" % [finds[0], finds[0] % M])

func summary_code() -> void:
	code("")
	code("// 키 → 칸 번호 계산 한 번으로")
	code("// 바로 찾아가요 (평균 O(1))")

func next_action() -> Array:
	if phase == "insert":
		if hand == null:
			return [spot("intake"), "물품 집기"] if not queue.is_empty() else [null, ""]
		if has_key(hand[0]):
			if LEVELS[level].get("update", false):
				return [spot("bucket", hand[0] % M), "값 바꾸기"]
			return [spot("dup"), "중복 거절"]
		var b: int = hand[0] % M
		if is_linear():
			b = probe_slot(hand[0])
		return [spot("bucket", b), "%d번 사물함에 넣기" % b]
	if finds.is_empty():
		return [null, ""]
	if is_linear():
		var slot: int = open_b if open_b >= 0 else finds[0] % M
		return [spot("bucket", slot), "%d번 비교" % slot]
	var b2: int = finds[0] % M
	return [spot("bucket", b2), "사물함 열기" if open_b != b2 else "항목 비교"]
