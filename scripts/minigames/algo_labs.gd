extends "res://scripts/minigames/learning_lab.gd"
## 알고리즘 실습: 탐색(ALG02) · 기본 정렬(ALG01) · 분할 정복 정렬(ALG03) · 최단 경로(ALG04).
## 최종 결과만 보지 않고 각 단계가 그 알고리즘의 규칙에 맞는지 검사한다.

const INF := 1000000

const SEARCH_LEVELS := [
	[{"mode": "linear", "values": [7, 3, 9, 1, 5], "target": 1}, {"mode": "linear", "values": [4, 8, 6], "target": 5}],
	[{"mode": "binary", "values": [2, 5, 8, 12, 16, 23, 38], "target": 16}, {"mode": "binary", "values": [5], "target": 5}],
	[{"mode": "binary", "values": [2, 5, 8, 12, 16, 23, 38], "target": 15}, {"mode": "binary", "values": [1, 3, 3, 3, 7], "target": 3},
	 {"mode": "choose", "values": [9, 2, 7, 4], "target": 7}, {"mode": "binary", "values": [], "target": 4}],
]
const SORT_LEVELS := [
	[{"algo": "bubble", "values": [5, 2, 4, 1]}, {"algo": "bubble", "values": [1, 2, 3]}],
	[{"algo": "selection", "values": [7, 3, 3, 6, 1]}],
	[{"algo": "insertion", "values": [9, -2, 5, 0, 3, 1]}],
]
const SORT_NAMES := {"bubble": "버블 정렬", "selection": "선택 정렬", "insertion": "삽입 정렬"}
const DIVIDE_LEVELS := [
	[{"mode": "split", "values": [4, 1, 3, 2]}, {"mode": "split", "values": [5, 2, 9, 1, 7]}],
	[{"mode": "merge", "values": [4, 1, 3, 2]}, {"mode": "merge", "values": [2, 5, 2, 3]}],
	[{"mode": "quick", "values": [6, 2, 8, 2, 4]}, {"mode": "quick", "values": [5, 5, 5]}],
]
const P4 := {"A": Vector2(322, 345), "B": Vector2(488, 232), "C": Vector2(485, 452), "D": Vector2(895, 345)}
const P5 := {"A": Vector2(322, 345), "B": Vector2(488, 232), "C": Vector2(485, 452), "D": Vector2(895, 345), "E": Vector2(740, 232)}
const PATH_LEVELS := [
	[{"pos": P4, "edges": [["A", "B", 4], ["A", "C", 1], ["C", "B", 2], ["B", "D", 1], ["C", "D", 5]], "start": "A", "goal": "D"}],
	[{"pos": P5, "edges": [["A", "B", 7], ["A", "C", 2], ["C", "D", 1], ["D", "B", 3], ["B", "E", 1], ["D", "E", 6]], "start": "A", "goal": "E"}],
	[{"pos": P4, "edges": [["A", "B", 1], ["A", "C", 1], ["B", "D", 2], ["C", "D", 2]], "start": "A", "goal": "D"},
	 {"pos": P4, "edges": [["A", "B", 2], ["B", "C", 3]], "start": "A", "goal": "D"},
	 {"pos": P4, "edges": [["A", "B", 2], ["B", "D", 3]], "start": "A", "goal": "A"},
	 {"pos": P4, "edges": [["A", "B", 2], ["B", "C", -3], ["C", "D", 1]], "start": "A", "goal": "D", "negative": true}],
]

func lab_table() -> Dictionary:
	return {
		"search": {"id": "ALG02", "title": "물건 찾기 비교실", "levels": 3, "art": "ALG02", "npc": "NPC07", "npc_name": "서고 감독관",
			"intro": ["좋아, 왔군. 물건을 찾는 방법은 하나가 아니야. 왼쪽부터 하나씩 보는 선형 탐색과 절반씩 줄이는 이진 탐색을 비교해 보자.",
				"이진 탐색은 값이 정렬되어 있어야만 쓸 수 있어. 가운데 칸 mid = (low + high) / 2 를 보고, 작으면 오른쪽, 크면 왼쪽만 남긴다.",
				"다음에 검사할 칸을 직접 E를 눌러. 구간이 비면 없는 값이다."],
			"talk": ["선형 탐색이다. 왼쪽부터 차례로 칸을 E를 눌러. 끝까지 없으면 없는 값이야.", "이제 정렬된 줄에서 이진 탐색이다. low와 high를 보고 가운데 칸을 골라.", "없는 값, 중복 값, 정렬되지 않은 줄, 빈 줄까지 나온다. 어떤 방법을 쓸 수 있는지부터 따져 봐."],
			"hints": ["선형 탐색은 앞에서부터, 이진 탐색은 정렬된 구간의 가운데부터 봐요.", "mid = floor((low + high) / 2). 값이 작으면 low = mid + 1, 크면 high = mid - 1이에요.", "[2,5,8,12,16,23,38]에서 16은 인덱스 3 → 5 → 4 순서로 검사해요."]},
		"sort": {"id": "ALG01", "title": "순서 맞춤 작업대", "levels": 3, "art": "ALG01", "npc": "NPC01", "npc_name": "작업대 관리인",
			"intro": ["어서 와! 이 작업대에선 카드를 오름차순으로 맞춘단다. 다만 방법마다 비교하는 대상이 달라.",
				"버블은 이웃끼리 비교해서 큰 값을 뒤로 보내고, 선택은 남은 구간의 최솟값을 앞으로, 삽입은 카드를 하나 들고 앞쪽 알맞은 자리에 끼워.",
				"완성된 모양만 보지 않아. 각 단계가 그 방법대로인지 확인할 거야."],
			"talk": ["버블 정렬이야. 노란 두 카드를 비교해서 왼쪽이 더 크면 교환, 아니면 유지를 눌러. 이미 정렬된 줄은 한 번만 훑어도 끝나.", "선택 정렬이야. 남은 구간에서 최솟값 카드를 E를 누르면 맨 앞 칸과 한 번 교환돼.", "삽입 정렬이야. 카드를 들고, 앞쪽 값이 더 크면 밀고, 아니면 빈자리에 놓아."],
			"hints": ["방법마다 비교 대상과 확정되는 구간이 달라요.", "버블은 인접 두 칸, 선택은 남은 구간의 최솟값, 삽입은 key와 앞쪽 값을 비교해요.", "[3,1,2]의 첫 패스: 버블 [1,2,3], 선택 [1,3,2], 삽입 첫 삽입 [1,3,2]."]},
		"divide": {"id": "ALG03", "title": "나누고 합치는 공방", "levels": 3, "art": "ALG03", "npc": "NPC03", "npc_name": "공방 장인",
			"intro": ["어이쿠, 왔구나! 큰 일은 잘게 나누면 쉬워진단다. 이걸 분할 정복이라고 해.",
				"병합 정렬은 한 원소가 될 때까지 나눈 뒤, 정렬된 두 묶음의 앞 값을 비교하며 합쳐. 값이 같으면 왼쪽을 먼저 내려서 순서를 지킨단다.",
				"퀵 정렬은 기준값을 골라 작은 값, 같은 값, 큰 값으로 나누고 각 묶음을 다시 정렬해. 여기선 마지막 값을 기준으로 삼자꾸나."],
			"talk": ["병합 정렬의 나누기야. 두 개 이상인 묶음을 E를 눌러서 한 원소가 될 때까지 나누렴.", "이제 합치기란다. 왼쪽 묶음과 오른쪽 묶음의 맨 앞 값 중 더 작은 쪽을 E를 눌러. 같으면 왼쪽이야.", "퀵 정렬이야. 금색 기준값과 비교해서 지금 원소가 작은지, 같은지, 큰지 고르렴."],
			"hints": ["병합은 나눈 뒤 합치고, 퀵은 기준값으로 나눈 뒤 각각 정렬해요.", "병합은 앞 값 비교, 퀵은 현재 원소와 pivot의 크기 비교가 판단 기준이에요.", "[1,4]와 [2,3]을 합치면 1, 2, 3, 4 순서로 내려요. [4,1,3,2]의 첫 pivot은 2예요."]},
		"shortest": {"id": "ALG04", "title": "최소 비용 배달소", "levels": 3, "art": "ALG04", "npc": "NPC02", "npc_name": "배달 경로 담당자",
			"intro": ["안녕! 여기는 배달비를 가장 적게 쓰는 길을 찾는 곳이야. 다익스트라 알고리즘을 그대로 따라가 보자.",
				"시작 정점의 거리는 0, 나머지는 무한대로 둬. 아직 확정하지 않은 정점 중 거리가 가장 짧은 곳을 확정해. 동률이면 알파벳 순이야.",
				"확정한 곳에서 이웃으로 가는 비용을 계산해서 더 싸면 갱신해. 도착지를 확정하면 경로를 앞에서부터 E를 눌러서 복원하면 끝이야."],
			"talk": ["작은 지도부터 해 보자. 거리표를 보고 미확정 최소 정점을 E를 눌러.", "바로 가는 길보다 돌아가는 길이 더 쌀 수도 있어. 갱신할지 유지할지 계산해 봐.", "최단 경로가 둘인 경우, 갈 수 없는 목적지, 출발지와 같은 목적지, 음수 간선까지 나와. 음수가 있으면 다익스트라를 쓸 수 없어."],
			"hints": ["다익스트라는 최소 거리를 확정하고 이웃을 갱신하는 과정을 반복해요.", "새 거리 = dist[현재] + 간선 비용이 dist[이웃]보다 작을 때만 갱신해요.", "A→C=1, C→B=2, B→D=1이면 A→C→B→D, 비용 4예요."]},
	}

func problems_for(n: int) -> Array:
	match activity:
		"search": return SEARCH_LEVELS[n]
		"sort": return SORT_LEVELS[n]
		"divide": return DIVIDE_LEVELS[n]
	return PATH_LEVELS[n]

func setup_problem(p: Dictionary) -> void:
	match activity:
		"search":
			state = {"mode": p.mode, "low": 0, "high": p.values.size() - 1, "i": 0, "cmp": 0}
			goal = "%d 찾기 (%s)" % [p.target, {"linear": "선형 탐색", "binary": "이진 탐색", "choose": "방법 선택"}[p.mode]]
		"sort":
			var cards = []
			for i in p.values.size():
				cards.append([p.values[i], i])
			state = {"a": cards, "i": 0, "j": 0, "swapped": false, "phase": "lift", "key": null, "hole": -1, "cmp": 0, "write": 0, "done": false}
			if p.algo == "insertion":
				state.i = 1
			goal = SORT_NAMES[p.algo] + "로 오름차순 만들기"
		"divide":
			setup_divide(p)
		"shortest":
			setup_path(p)

func handle(key: String) -> void:
	match activity:
		"search": search_action(key)
		"sort": sort_action(key)
		"divide": divide_action(key)
		"shortest": path_action(key)

func lab_rows() -> Array:
	match activity:
		"search": return [["방법", {"linear": "선형", "binary": "이진", "choose": "선택 전"}[state.mode]], ["비교", state.cmp], ["실수", mistakes]]
		"sort": return [["비교", state.cmp], ["쓰기", state.write], ["실수", mistakes]]
		"divide": return [["단계", {"split": "나누기", "merge": "합치기", "quick": "퀵 분할"}[problems()[problem].mode]], ["행동", moves], ["실수", mistakes]]
	return [["단계", {"select": "정점 확정", "relax": "간선 완화", "path": "경로 복원", "negative": "조건 확인"}[state.phase]], ["확정", state.settled.size()], ["실수", mistakes]]

func state_code() -> String:
	var p: Dictionary = problems()[problem]
	match activity:
		"search":
			return "low=%d high=%d target=%d" % [state.low, state.high, p.target] if state.mode == "binary" else "i=%d target=%d" % [state.i, p.target]
		"sort":
			return "arr = " + str(state.a.map(func(c): return c[0]))
		"divide":
			return divide_state_text()
	var d = []
	for v in p.pos:
		d.append("%s=%s" % [v, "∞" if state.dist[v] >= INF else str(state.dist[v])])
	return "dist: " + " ".join(d)

# ---------- 탐색 ----------
func search_action(key: String) -> void:
	var p: Dictionary = problems()[problem]
	if key == "none":
		search_declare_none(p)
		return
	if key == "pick:linear":
		step()
		state.mode = "linear"
		code("// 정렬되지 않았으니 선형 탐색")
		return
	if key == "pick:binary":
		wrong("이 줄은 정렬되어 있지 않아 이진 탐색을 쓸 수 없어요.")
		return
	if state.mode == "choose" or not key.is_valid_int():
		return
	var i = int(key)
	if state.mode == "linear":
		search_linear(p, i)
	else:
		search_binary(p, i)

func search_declare_none(p: Dictionary) -> void:
	if p.values.is_empty() or state.low > state.high or (state.mode == "linear" and state.i >= p.values.size()):
		moves += 1
		code("return -1;", "없는 값")
		end_search(p, false)
	else:
		wrong("아직 검사할 칸이 남아 있어요.")

func search_linear(p: Dictionary, i: int) -> void:
	if i != state.i:
		wrong("선형 탐색은 왼쪽부터 차례로 봐요. 지금은 인덱스 %d 차례예요." % state.i)
		return
	step()
	state.cmp += 1
	code("if (arr[%d] == %d)" % [i, p.target], "%d" % p.values[i])
	if p.values[i] == p.target:
		end_search(p, true, i)
		return
	state.i += 1
	if state.i >= p.values.size():
		code("return -1;", "끝까지 없음")
		end_search(p, false)

func search_binary(p: Dictionary, i: int) -> void:
	var mid = int((state.low + state.high) / 2.0)
	if i != mid:
		wrong("현재 구간의 가운데 인덱스를 계산해 보세요.")
		return
	step()
	state.cmp += 1
	var value: int = p.values[mid]
	if value == p.target:
		code("mid = %d;" % mid, "%d == %d" % [value, p.target])
		end_search(p, true, mid)
		return
	if value < p.target:
		state.low = mid + 1
		code("low = mid + 1;", "%d < %d" % [value, p.target])
	else:
		state.high = mid - 1
		code("high = mid - 1;", "%d > %d" % [value, p.target])
	if state.low > state.high:
		code("return -1;", "low > high")
		end_search(p, false)

func end_search(p: Dictionary, found: bool, index := -1) -> void:
	var linear_cost = p.values.size()
	if found:
		linear_cost = p.values.find(p.target) + 1
	var result: String = ("인덱스 %d에서 %d를 찾았어요." % [index, p.target]) if found else ("%d는 없는 값이에요." % p.target)
	finish_problem("%s 비교 %d회 (선형이면 %d회)" % [result, state.cmp, linear_cost])

# ---------- 기본 정렬 ----------
func sort_action(key: String) -> void:
	var p: Dictionary = problems()[problem]
	match p.algo:
		"bubble": bubble_action(key, p)
		"selection": selection_action(key)
		"insertion": insertion_action(key)

func bubble_limit() -> int:
	return state.a.size() - 1 - state.i

func bubble_action(key: String, _p: Dictionary) -> void:
	if key.is_valid_int():
		var i = int(key)
		if i != state.j and i != state.j + 1:
			wrong("바로 옆 두 칸(노란 카드)만 비교할 수 있어요.")
			return
		key = "swap"
	if key != "swap" and key != "keep":
		return
	var a: Array = state.a
	var j: int = state.j
	var left: int = a[j][0]
	var right: int = a[j + 1][0]
	if key == "swap" and left <= right:
		wrong("%d ≤ %d 이라 교환하지 않아요." % [left, right])
		return
	if key == "keep" and left > right:
		wrong("%d > %d 이라 교환해야 해요." % [left, right])
		return
	step()
	state.cmp += 1
	if key == "swap":
		var t = a[j]
		a[j] = a[j + 1]
		a[j + 1] = t
		state.swapped = true
		state.write += 2
		code("swap(arr[%d], arr[%d]);" % [j, j + 1], "%d > %d" % [left, right])
	else:
		code("// %d ≤ %d 유지" % [left, right])
	state.j += 1
	if state.j >= bubble_limit():
		end_bubble_pass()

func end_bubble_pass() -> void:
	var swapped: bool = state.swapped
	state.i += 1
	state.j = 0
	state.swapped = false
	if not swapped or state.i >= state.a.size() - 1:
		state.done = true
		code("// 교환이 없으면 정렬 끝" if not swapped else "// 모든 패스 완료")
		finish_problem("버블 정렬 완료: 비교 %d회 · 쓰기 %d회" % [state.cmp, state.write])

func selection_action(key: String) -> void:
	if not key.is_valid_int():
		return
	var a: Array = state.a
	var k = int(key)
	var i: int = state.i
	if k < i:
		wrong("앞쪽은 이미 확정된 구간이에요.")
		return
	var low: int = a[i][0]
	for x in range(i, a.size()):
		low = mini(low, a[x][0])
	if a[k][0] != low:
		wrong("남은 구간의 최솟값은 %d예요." % low)
		return
	step()
	state.cmp += a.size() - i - 1
	if k != i:
		var t = a[i]
		a[i] = a[k]
		a[k] = t
		state.write += 2
		code("swap(arr[%d], arr[%d]);" % [i, k], "최솟값 %d" % low)
	else:
		code("// arr[%d]는 이미 최솟값" % i)
	state.i += 1
	if state.i >= a.size() - 1:
		finish_problem("선택 정렬 완료: 비교 %d회 · 쓰기 %d회" % [state.cmp, state.write])

func insertion_action(key: String) -> void:
	var a: Array = state.a
	if state.phase == "lift":
		if key != str(state.i):
			wrong("지금 들 카드는 인덱스 %d예요." % state.i)
			return
		step()
		state.key = a[state.i]
		state.hole = state.i
		state.phase = "place"
		code("key = arr[%d];" % state.i, "%d 보관" % state.key[0])
		return
	var j: int = state.hole - 1
	if key == "shift":
		if j < 0 or a[j][0] <= state.key[0]:
			wrong("앞쪽 값이 key보다 크지 않아서 밀 수 없어요.")
			return
		step()
		state.cmp += 1
		state.write += 1
		a[state.hole] = a[j]
		state.hole = j
		code("arr[%d] = arr[%d];" % [j + 1, j], "큰 값 밀기")
	elif key == "place":
		if j >= 0 and a[j][0] > state.key[0]:
			wrong("앞쪽 %d가 key보다 커요. 더 밀어야 해요." % a[j][0])
			return
		step()
		if j >= 0:
			state.cmp += 1
		state.write += 1
		a[state.hole] = state.key
		code("arr[%d] = key;" % state.hole)
		state.key = null
		state.hole = -1
		state.phase = "lift"
		state.i += 1
		if state.i >= a.size():
			finish_problem("삽입 정렬 완료: 비교 %d회 · 쓰기 %d회" % [state.cmp, state.write])

# ---------- 분할 정복 ----------
func tag_values(values: Array) -> Array:
	var out = []
	for i in values.size():
		out.append([values[i], i])
	return out

func setup_divide(p: Dictionary) -> void:
	var items = tag_values(p.values)
	match p.mode:
		"split":
			state = {"runs": [items]}
			goal = "모든 묶음을 한 원소까지 나누기"
		"merge":
			var plan = []
			merge_plan(items, plan)
			state = {"plan": plan, "m": 0, "l": 0, "r": 0, "out": []}
			goal = "정렬된 두 묶음을 앞 값 비교로 합치기"
		"quick":
			state = {"segs": [{"items": items, "sorted": items.size() <= 1}], "k": 0, "lt": [], "eq": [], "gt": []}
			goal = "마지막 값을 기준으로 작은·같은·큰 묶음 나누기"

func merge_plan(items: Array, plan: Array) -> Array:
	if items.size() <= 1:
		return items
	var mid: int = items.size() / 2
	var left = merge_plan(items.slice(0, mid), plan)
	var right = merge_plan(items.slice(mid), plan)
	plan.append({"left": left, "right": right})
	var merged = []
	var l = 0
	var r = 0
	while l < left.size() or r < right.size():
		if r >= right.size() or (l < left.size() and left[l][0] <= right[r][0]):
			merged.append(left[l])
			l += 1
		else:
			merged.append(right[r])
			r += 1
	return merged

func divide_action(key: String) -> void:
	match problems()[problem].mode:
		"split": split_action(key)
		"merge": merge_action(key)
		"quick": quick_action(key)

func split_action(key: String) -> void:
	if not key.begins_with("run:"):
		return
	var i = int(key.trim_prefix("run:"))
	var run: Array = state.runs[i]
	if run.size() <= 1:
		wrong("이미 한 원소라 더 나눌 수 없어요.")
		return
	step()
	var mid: int = run.size() / 2
	state.runs[i] = run.slice(0, mid)
	state.runs.insert(i + 1, run.slice(mid))
	code("mid = %d / 2;" % run.size(), "%s | %s" % [run_text(run.slice(0, mid)), run_text(run.slice(mid))])
	for r in state.runs:
		if r.size() > 1:
			return
	finish_problem("한 원소까지 나눴어요. 이제 정렬된 묶음끼리 합칠 수 있어요.")

func merge_action(key: String) -> void:
	if key != "left" and key != "right":
		return
	var m: Dictionary = state.plan[state.m]
	var left: Array = m.left
	var right: Array = m.right
	var l: int = state.l
	var r: int = state.r
	var has_left = l < left.size()
	var has_right = r < right.size()
	var take_left = not has_right or (has_left and left[l][0] <= right[r][0])
	if key == "left" and not has_left:
		wrong("왼쪽 묶음은 이미 비었어요.")
		return
	if key == "right" and not has_right:
		wrong("오른쪽 묶음은 이미 비었어요.")
		return
	if (key == "left") != take_left:
		if has_left and has_right and left[l][0] == right[r][0]:
			wrong("값이 같으면 왼쪽을 먼저 내려야 순서가 유지돼요.")
		else:
			wrong("앞 값 중 더 작은 쪽을 먼저 내려요.")
		return
	step()
	if key == "left":
		state.out.append(left[l])
		state.l += 1
	else:
		state.out.append(right[r])
		state.r += 1
	code("out.add(%d);" % state.out.back()[0])
	if state.l >= left.size() and state.r >= right.size():
		state.m += 1
		state.l = 0
		state.r = 0
		var done_run: Array = state.out
		state.out = []
		code("// 묶음 완성 " + run_text(done_run))
		if state.m >= state.plan.size():
			finish_problem("병합 완료: %s" % run_text(done_run))

func current_segment() -> int:
	for i in state.segs.size():
		if not state.segs[i].sorted:
			return i
	return -1

func quick_action(key: String) -> void:
	if key not in ["lt", "eq", "gt"]:
		return
	var s = current_segment()
	var seg: Dictionary = state.segs[s]
	var items: Array = seg.items
	var pivot: Array = items.back()
	var cur: Array = items[state.k]
	var right = "eq" if cur[0] == pivot[0] else ("lt" if cur[0] < pivot[0] else "gt")
	if key != right:
		wrong("%d은(는) 기준값 %d보다 %s." % [cur[0], pivot[0], {"lt": "작아요", "eq": "같아요", "gt": "커요"}[right]])
		return
	step()
	state[key].append(cur)
	code("// %d → %s" % [cur[0], {"lt": "작은 쪽", "eq": "같은 쪽", "gt": "큰 쪽"}[key]])
	state.k += 1
	if state.k >= items.size() - 1:
		quick_finish_segment(s, pivot)

func quick_finish_segment(s: int, pivot: Array) -> void:
	state.eq.append(pivot)
	var parts = []
	for group in ["lt", "eq", "gt"]:
		if not state[group].is_empty():
			parts.append({"items": state[group].duplicate(), "sorted": group == "eq" or state[group].size() <= 1})
	state.segs.remove_at(s)
	for i in parts.size():
		state.segs.insert(s + i, parts[i])
	state.k = 0
	state.lt = []
	state.eq = []
	state.gt = []
	code("// pivot %d 위치 확정" % pivot[0])
	if current_segment() < 0:
		var flat = []
		for seg in state.segs:
			flat += seg.items
		finish_problem("퀵 정렬 완료: %s" % run_text(flat))

func run_text(run: Array) -> String:
	return "[" + ", ".join(run.map(func(c): return str(c[0]))) + "]"

func divide_state_text() -> String:
	var p: Dictionary = problems()[problem]
	match p.mode:
		"split": return " ".join(state.runs.map(func(r): return run_text(r)))
		"merge":
			return "out = " + run_text(state.out)
	return "segments = " + " ".join(state.segs.map(func(s): return run_text(s.items)))

# ---------- 최단 경로 ----------
func setup_path(p: Dictionary) -> void:
	var dist = {}
	var prev = {}
	for v in p.pos:
		dist[v] = INF
		prev[v] = ""
	dist[p.start] = 0
	state = {"dist": dist, "prev": prev, "settled": [], "phase": "negative" if p.get("negative", false) else "select", "cur": "", "queue": [], "path": [p.start]}
	goal = "%s에서 %s까지 최소 비용 찾기" % [p.start, p.goal]

func neighbors(p: Dictionary, u: String) -> Array:
	var out = []
	for e in p.edges:
		if e[0] == u and not state.settled.has(e[1]):
			out.append([e[1], e[2]])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out

func path_action(key: String) -> void:
	var p: Dictionary = problems()[problem]
	match state.phase:
		"negative":
			if key == "unusable":
				moves += 1
				code("// 음수 간선: 다익스트라 사용 불가")
				finish_problem("음수 간선이 있으면 확정한 거리가 뒤집힐 수 있어요.")
			elif p.pos.has(key):
				wrong("지도에 음수 비용이 있어요. 먼저 사용할 수 있는지 판단하세요.")
		"select":
			path_select(key, p)
		"relax":
			path_relax(key, p)
		"path":
			path_trace(key, p)

func path_select(key: String, p: Dictionary) -> void:
	var low = INF
	var best = ""
	var names: Array = p.pos.keys()
	names.sort()
	for v in names:
		if not state.settled.has(v) and state.dist[v] < low:
			low = state.dist[v]
			best = v
	if key == "unreachable":
		if best == "":
			moves += 1
			code("return INF;", "도달 불가")
			finish_problem("%s는 %s에서 갈 수 없어요." % [p.goal, p.start])
		else:
			wrong("아직 확정할 수 있는 정점이 남아 있어요.")
		return
	if not p.pos.has(key):
		return
	if key != best:
		if best == "":
			wrong("남은 정점의 거리가 모두 무한대예요. 도달 불가를 선언하세요.")
		elif state.dist[key] == low:
			wrong("거리가 같으면 알파벳이 빠른 %s를 먼저 확정해요." % best)
		else:
			wrong("미확정 정점 중 거리가 가장 짧은 곳은 %s예요." % best)
		return
	step()
	state.settled.append(key)
	state.cur = key
	code("settle(%s);" % key, "dist=%d" % low)
	if key == p.goal:
		state.phase = "path"
		if p.start == p.goal:
			finish_problem("출발지가 곧 목적지라 비용은 0이에요.")
		return
	state.queue = neighbors(p, key)
	state.phase = "relax" if not state.queue.is_empty() else "select"

func path_relax(key: String, p: Dictionary) -> void:
	if key != "update" and key != "keep":
		return
	var n: Array = state.queue[0]
	var v: String = n[0]
	var cand: int = state.dist[state.cur] + n[1]
	var better: bool = cand < state.dist[v]
	if (key == "update") != better:
		if better:
			wrong("%d < %s 이라 갱신해야 해요." % [cand, dist_text(state.dist[v])])
		else:
			wrong("%d ≥ %s 이라 갱신하지 않아요." % [cand, dist_text(state.dist[v])])
		return
	step()
	if better:
		state.dist[v] = cand
		state.prev[v] = state.cur
		code("dist[%s] = %d;" % [v, cand], "prev=%s" % state.cur)
	else:
		code("// dist[%s] 유지" % v)
	state.queue.pop_front()
	if state.queue.is_empty():
		state.phase = "select"
		state.cur = ""
	if p.is_empty():
		return

func dist_text(d: int) -> String:
	return "∞" if d >= INF else str(d)

## v 에서 목적지까지 최단 거리를 유지하며 갈 수 있는지 확인한다.
func on_tight_route(p: Dictionary, v: String) -> bool:
	if v == p.goal:
		return true
	for e in p.edges:
		if e[0] == v and state.settled.has(e[1]) and state.dist[v] + e[2] == state.dist[e[1]] and on_tight_route(p, e[1]):
			return true
	return false

func path_trace(key: String, p: Dictionary) -> void:
	if not p.pos.has(key):
		return
	var from: String = state.path.back()
	var weight = -1
	for e in p.edges:
		if e[0] == from and e[1] == key:
			weight = e[2]
	if weight < 0:
		wrong("%s에서 %s로 바로 가는 길이 없어요." % [from, key])
		return
	if not state.settled.has(key) or state.dist[from] + weight != state.dist[key] or not on_tight_route(p, key):
		wrong("이 길을 쓰면 최소 비용이 되지 않아요.")
		return
	step()
	state.path.append(key)
	code("path.add(%s);" % key)
	if key == p.goal:
		finish_problem("최단 경로 %s, 비용 %d" % [" → ".join(state.path), state.dist[p.goal]])

# ---------- 시안 위 배치 ----------
const CRATE_X := [318.0, 444.0, 570.0, 698.0, 825.0, 953.0]
const CHEST_X := [262.0, 410.0, 525.0, 640.0, 755.0, 870.0, 1018.0]
const PATH_NAMES := ["A", "B", "C", "D", "E"]
const TRAY_MID := [Vector2(280, 362), Vector2(480, 362), Vector2(720, 362), Vector2(868, 365), Vector2(1030, 362)]

func chest_offset() -> int:
	return (7 - problems()[problem].values.size()) / 2

func stations() -> Array:
	match activity:
		"search": return search_stations()
		"sort": return sort_stations()
		"divide": return divide_stations()
	return path_stations()

func search_stations() -> Array:
	var p: Dictionary = problems()[problem]
	var out = []
	var off = chest_offset()
	for i in 7:
		var v = i - off
		if v >= 0 and v < p.values.size():
			out.append([str(v), "%d번 칸 검사" % v, ""])
		else:
			out.append(null)
	out.append(["none", "없는 값 선언", "없음 선언"])
	out.append(["pick:linear", "선형 탐색 고르기", "선형"] if state.mode == "choose" else null)
	out.append(["pick:binary", "이진 탐색 고르기", "이진"] if state.mode == "choose" else null)
	return out

func sort_stations() -> Array:
	var p: Dictionary = problems()[problem]
	var out = []
	var n: int = state.a.size()
	for i in 6:
		out.append([str(i), "%d번 상자" % i, ""] if i < n else null)
	match p.algo:
		"bubble":
			out.append(["swap", "두 상자 교환", "교환"])
			out.append(["keep", "그대로 유지", "유지"])
		"insertion":
			out.append(["shift", "앞쪽 값 밀기", "밀기"] if state.phase == "place" else null)
			out.append(["place", "빈자리에 놓기", "놓기"] if state.phase == "place" else null)
		_:
			out.append(null)
			out.append(null)
	return out

func divide_stations() -> Array:
	var p: Dictionary = problems()[problem]
	var out = [null, null, null, null, null]
	match p.mode:
		"split":
			for i in mini(state.runs.size(), 5):
				out[i] = ["run:%d" % i, "%s 나누기" % run_text(state.runs[i]), ""]
		"merge":
			out[0] = ["left", "왼쪽 앞 값 내리기", "왼쪽"]
			out[1] = ["right", "오른쪽 앞 값 내리기", "오른쪽"]
		"quick":
			out[2] = ["lt", "기준보다 작다", "< 작다"]
			out[3] = ["eq", "기준과 같다", "= 같다"]
			out[4] = ["gt", "기준보다 크다", "> 크다"]
	return out

func path_stations() -> Array:
	var p: Dictionary = problems()[problem]
	var out = []
	for n in PATH_NAMES:
		out.append([n, "%s 지점" % n, ""] if p.pos.has(n) else null)
	match state.phase:
		"relax":
			out.append(["update", "거리 갱신", "갱신"])
			out.append(["keep", "유지", "유지"])
			out.append(null)
		"select":
			out.append(null)
			out.append(null)
			out.append(["unreachable", "도달 불가 선언", "도달 불가"])
		"negative":
			out.append(null)
			out.append(null)
			out.append(["unusable", "사용 불가 선언", "사용 불가"])
		_:
			out.append(null)
			out.append(null)
			out.append(null)
	return out

func next_key() -> String:
	var p: Dictionary = problems()[problem]
	match activity:
		"search":
			if state.mode == "choose":
				return "pick:linear"
			if p.values.is_empty():
				return "none"
			if state.mode == "linear":
				return str(state.i)
			return str(int((state.low + state.high) / 2.0))
		"sort":
			return next_sort_key(p)
		"divide":
			return next_divide_key(p)
		"shortest":
			return next_path_key(p)
	return ""

func next_sort_key(p: Dictionary) -> String:
	var a: Array = state.a
	match p.algo:
		"bubble":
			if state.j + 1 < a.size():
				return "swap" if a[state.j][0] > a[state.j + 1][0] else "keep"
		"selection":
			var best: int = state.i
			for x in range(state.i, a.size()):
				if a[x][0] < a[best][0]:
					best = x
			return str(best)
		"insertion":
			if state.phase == "lift":
				return str(state.i)
			var j: int = state.hole - 1
			return "shift" if j >= 0 and a[j][0] > state.key[0] else "place"
	return ""

func next_divide_key(p: Dictionary) -> String:
	match p.mode:
		"split":
			for i in state.runs.size():
				if state.runs[i].size() > 1:
					return "run:%d" % i
		"merge":
			if state.m >= state.plan.size():
				return ""
			var m: Dictionary = state.plan[state.m]
			var has_left: bool = state.l < m.left.size()
			var has_right: bool = state.r < m.right.size()
			return "left" if not has_right or (has_left and m.left[state.l][0] <= m.right[state.r][0]) else "right"
		"quick":
			var s: int = current_segment()
			if s < 0:
				return ""
			var items: Array = state.segs[s].items
			var cur = items[state.k][0]
			var piv = items.back()[0]
			return "eq" if cur == piv else ("lt" if cur < piv else "gt")
	return ""

func next_path_key(p: Dictionary) -> String:
	match state.phase:
		"negative":
			return "unusable"
		"select":
			var low: int = INF
			var best = ""
			var names: Array = p.pos.keys()
			names.sort()
			for v in names:
				if not state.settled.has(v) and state.dist[v] < low:
					low = state.dist[v]
					best = v
			return best if best != "" else "unreachable"
		"relax":
			if not state.queue.is_empty():
				var n: Array = state.queue[0]
				return "update" if state.dist[state.cur] + n[1] < state.dist[n[0]] else "keep"
		"path":
			var from: String = state.path.back()
			for e in p.edges:
				if e[0] == from and state.settled.has(e[1]) and state.dist[from] + e[2] == state.dist[e[1]] and on_tight_route(p, e[1]):
					return e[1]
	return ""

func draw_board() -> void:
	match activity:
		"search": draw_search_board()
		"sort": draw_sort_board()
		"divide": draw_divide_board()
		"shortest": draw_path_board()

func draw_search_board() -> void:
	var p: Dictionary = problems()[problem]
	plate(Vector2(640, 455), "찾는 값 %d" % p.target, 24, GOLD)
	var off = chest_offset()
	for i in 7:
		cover(Rect2(CHEST_X[i] - 42, 276, 84, 44), Color("c9b08e"))
	for i in p.values.size():
		var active: bool = state.mode == "choose" or (state.mode == "linear" and i >= state.i) or (state.mode == "binary" and i >= state.low and i <= state.high)
		var x: float = CHEST_X[i + off]
		plate(Vector2(x, 298), str(p.values[i]), 26, CREAM if active else Color("9a958a"), INK, 72)
		text(Vector2(x, 262), "[%d]" % i, 18, Color.WHITE, true)
	if state.mode == "binary" and not p.values.is_empty() and state.low <= state.high:
		plate(Vector2(CHEST_X[state.low + off], 346), "low", 18, Color("9fd3ff"))
		plate(Vector2(CHEST_X[state.high + off], 372), "high", 18, GOLD)
		plate(Vector2(CHEST_X[int((state.low + state.high) / 2.0) + off], 240), "mid?", 18, Color("ffd7a8"))
	if p.values.is_empty():
		plate(Vector2(640, 298), "빈 배열", 28)

func card_pos(i: int) -> Vector2:
	return Vector2(CRATE_X[i], 408)

func draw_sort_board() -> void:
	var p: Dictionary = problems()[problem]
	var a: Array = state.a
	var want = {}
	for i in a.size():
		if i != state.hole:
			want["c%d" % a[i][1]] = {"text": str(a[i][0]), "pos": card_pos(i), "scale": 1.25}
	var held = null
	if state.key != null:
		held = "c%d" % state.key[1]
		want[held] = {"text": str(state.key[0]), "pos": hold_pos(), "scale": 1.25}
	sync_items(want, held)
	for i in range(a.size(), 6):
		plate(Vector2(CRATE_X[i], 356), "-", 26, Color("c9b08e"))
	plate(Vector2(640, 268), SORT_NAMES[p.algo], 24, GOLD)
	if p.algo == "bubble" and state.j + 1 < a.size():
		ring(card_pos(state.j) + Vector2(0, -44), 58)
		ring(card_pos(state.j + 1) + Vector2(0, -44), 58)
		for i in range(bubble_limit() + 1, a.size()):
			plate(card_pos(i) + Vector2(0, 24), "확정", 16, Color("bfe3b4"))
	elif p.algo == "selection":
		for i in state.i:
			plate(card_pos(i) + Vector2(0, 24), "확정", 16, Color("bfe3b4"))
	elif p.algo == "insertion":
		if state.phase == "lift" and state.i < a.size():
			ring(card_pos(state.i) + Vector2(0, -44), 58)
		elif state.hole >= 0:
			plate(Vector2(CRATE_X[state.hole], 356), "빈칸", 20, Color("ffd7a8"))

func draw_tray(c: Vector2, run: Array, fill := BLUE, half := Vector2(80, 24), cell_w := 38.0) -> void:
	cover(Rect2(c - half, half * 2))
	var x = c.x - run.size() * cell_w / 2 + cell_w / 2
	for item in run:
		plate(Vector2(x, c.y), str(item[0]), 20, fill, Color.WHITE, cell_w - 4)
		x += cell_w

func draw_divide_board() -> void:
	var p: Dictionary = problems()[problem]
	match p.mode:
		"split":
			for i in mini(state.runs.size(), 5):
				draw_tray(TRAY_MID[i], state.runs[i])
			var all_items = tag_values(p.values)
			draw_tray(Vector2(385, 232), all_items, TEAL, Vector2(130, 24))
		"merge":
			if state.m < state.plan.size():
				var m: Dictionary = state.plan[state.m]
				draw_tray(TRAY_MID[0], m.left.slice(state.l))
				draw_tray(TRAY_MID[1], m.right.slice(state.r), TEAL)
				draw_tray(Vector2(380, 516), state.out, WOOD, Vector2(130, 24))
				plate(Vector2(385, 232), "합치기 %d / %d" % [state.m + 1, state.plan.size()], 22)
		"quick":
			var s = current_segment()
			if s < 0:
				return
			var items: Array = state.segs[s].items
			draw_tray(Vector2(880, 228), items, BLUE, Vector2(138, 24))
			plate(Vector2(880, 190), "기준 %d · 지금 %d" % [items.back()[0], items[state.k][0]], 20, GOLD)
			draw_tray(TRAY_MID[2], state.lt, TEAL, Vector2(70, 24), 34)
			draw_tray(TRAY_MID[3], state.eq, WOOD, Vector2(44, 24), 28)
			draw_tray(TRAY_MID[4], state.gt, TEAL, Vector2(70, 24), 34)
			var flat = []
			for seg in state.segs:
				flat += seg.items
			draw_tray(Vector2(872, 516), flat, Color("6a5a9a"), Vector2(148, 24), 40)

func draw_path_board() -> void:
	var p: Dictionary = problems()[problem]
	for e in p.edges:
		var a: Vector2 = p.pos[e[0]]
		var b: Vector2 = p.pos[e[1]]
		var d = (b - a).normalized()
		var side = Vector2(-d.y, d.x) * 8
		var on_path = false
		for i in range(1, state.path.size()):
			if state.path[i - 1] == e[0] and state.path[i] == e[1]:
				on_path = true
		ink_arrow(a + d * 34 + side, b - d * 36 + side, GOLD if on_path else (RED if e[2] < 0 else Color("5fd6ff")))
		plate((a + b) / 2 + side * 2.5, str(e[2]), 20, CREAM, RED if e[2] < 0 else INK, 34)
	for v in p.pos:
		var fill = CREAM
		if state.settled.has(v):
			fill = Color("bfe3b4")
		if v == state.cur:
			fill = GOLD
		plate(p.pos[v], v, 26, fill, INK, 44)
	var rows = []
	for v in p.pos:
		rows.append([v, dist_text(state.dist[v]), state.prev[v] if state.prev[v] != "" else "-", "확정" if state.settled.has(v) else "-"])
	table_at(Vector2(1016, 300), ["정점", "거리", "이전", "상태"], rows, 188, 34, 18)
	var tip = ""
	match state.phase:
		"negative": tip = "음수 간선이 있어요. 다익스트라를 쓸 수 있을까요?"
		"select": tip = "미확정 중 거리가 가장 짧은 곳에서 E"
		"relax":
			var n: Array = state.queue[0]
			tip = "%s → %s: %d + %d = %d, 현재 %s" % [state.cur, n[0], state.dist[state.cur], n[1], state.dist[state.cur] + n[1], dist_text(state.dist[n[0]])]
		"path": tip = "경로를 차례로: " + " → ".join(state.path)
	plate(Vector2(612, 532), tip, 20, CREAM)
