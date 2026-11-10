extends SceneTree
## 클릭형 실습 14종과 메뉴를 검사한다: 정상 풀이, 대표 오답, 경계값, 되돌리기, 메뉴 구성.
## 실행: Godot --headless --path . --script res://scripts/tools/test_learning_labs.gd

const Catalog = preload("res://scripts/learning_catalog.gd")
var failures := 0
var checks := 0
var game

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL ", message)

func _init() -> void:
	call_deferred("run")

func open(scene: String) -> void:
	game = (load("res://scenes/stages/%s.tscn" % scene) as PackedScene).instantiate()
	root.add_child(game)
	game.set("fast_flow", true)
	game.hud.dialogue_skip()

func close() -> void:
	game.free()

func level(n: int) -> void:
	game.start_level(n)
	game.hud.dialogue_skip()

func press(keys: Array) -> void:
	for k in keys:
		game.on_button(k)

func expect_wrong(keys: Array, message: String) -> void:
	var before: int = game.mistakes
	press(keys)
	check(game.mistakes > before, message + " (오답으로 처리돼야 함)")

func run() -> void:
	MiniGameBase.progress_saving = false
	var nm = root.get_node_or_null("NetworkManager")
	if nm:
		nm.auto_send_enabled = false
	create_timer(300).timeout.connect(func(): print("TIMEOUT"); quit(1))
	test_catalog()
	test_tree()
	test_graph()
	test_search()
	test_sort()
	test_divide()
	test_shortest()
	test_profile()
	test_clean()
	test_stats()
	test_chart()
	await test_world_terminals()
	print("LEARNING_LABS_TEST_DONE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func test_world_terminals() -> void:
	var world = (load("res://scenes/NodeverseWorld.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await world.world_built
	world._set_game_state(world.GameState.PLAYING)
	current_scene = world
	var seen := {}
	for terminal in world.computer_terminals:
		world.player.teleport_to(terminal.global_position + terminal.global_basis.z * 1.6)
		var camera = world.player.cam
		world.player.cam = null
		await world._open_computer_game()
		world.player.cam = camera
		var menu = current_scene
		var zone: String = terminal.get_meta("quiz_zone", "DS")
		seen[zone] = true
		check(menu != world and menu.get_script().resource_path == "res://scripts/main_menu.gd", "컴퓨터에서 메뉴 열기")
		check(Catalog.selected_category == zone and Catalog.CATEGORIES.has(zone), "분야 탭 연결 " + zone)
		check(not world.is_quiz_open, "예전 퀴즈가 열리면 안 됨")
		await process_frame
		await process_frame
		check(menu._buttons.filter(func(b): return str(b[1]).begins_with("category:")).is_empty(), "메뉴에 다른 분야 탭이 없어야 함")
		var other_game: Array = Catalog.GAMES.filter(func(g): return g[3] != zone)
		check(menu._buttons.filter(func(b): return other_game.any(func(g): return g[4] == str(b[1]))).is_empty(), "다른 분야 게임이 보이면 안 됨 " + zone)
		menu._go_back_to_world()
		check(current_scene == world, "월드 복귀")
		await process_frame
	check(seen.size() == 4, "네 분야 컴퓨터, 실제 %d" % seen.size())
	world.queue_free()
	await process_frame
	print("TERMINAL_ROUTES ok ", seen.keys())

func test_catalog() -> void:
	var ids := {}
	var plan := {}
	for g in Catalog.GAMES:
		check(not ids.has(g[0]), "중복 ID " + g[0])
		ids[g[0]] = true
		if g[7] != "보너스":
			plan[g[7]] = true
		check(ResourceLoader.exists("res://scenes/stages/%s.tscn" % g[4]), "씬 없음 " + g[4])
		var folder: String = g[6]
		check(ResourceLoader.exists("res://textures/stages/%s/bg_game.png" % folder), "배경 없음 " + folder)
	check(plan.size() == 23, "기획 게임 23개여야 함, 실제 %d" % plan.size())
	check(Catalog.CATEGORIES.size() == 4, "분야는 4개")
	check(Catalog.games_for("DS").size() == 10, "자료구조 9+보너스")
	check(Catalog.games_for("ALGO").size() == 6, "알고리즘 6")
	check(Catalog.games_for("SQL").size() == 4, "SQL 4")
	check(Catalog.games_for("DATA").size() == 4, "데이터 4")
	for keep in ["ST01", "ST02", "ST03", "ST04", "ST05", "ST06", "ST07", "ST08", "ST09", "ST10", "DS09", "ALG01", "ALG02", "SQL01", "DATA01"]:
		check(ids.has(keep), "기존 저장 ID 유지 " + keep)
	var tree: Array = Catalog.GAMES.filter(func(g): return g[0] == "DS09")[0]
	var graph: Array = Catalog.GAMES.filter(func(g): return g[0] == "DS10")[0]
	check(tree[6] == "ST06" and graph[6] == "ST09", "트리·그래프는 ST06·ST09 배경")
	print("CATALOG ok games=", Catalog.GAMES.size())

func test_tree() -> void:
	open("DS09_TreeStructure")
	check(game.level_count == 3, "트리 3레벨")
	press(["A", "A", "left"])
	check(game.mistakes == 1, "자기 연결 거부")
	game.state.parent = ""
	game.state.child = ""
	press(["A", "B", "left", "A", "C", "left"])
	check(game.mistakes == 2, "슬롯 중복 거부")
	game.state.parent = ""
	game.state.child = ""
	press(["A", "C", "right", "check"])
	check(game.level_done, "트리 L1 완료")
	level(1)
	press(["B", "A", "left"])
	check(game.mistakes == 1, "루트를 자식으로 거부")
	game.state.parent = ""
	game.state.child = ""
	press(["A", "B", "left", "C", "B", "left"])
	check(game.mistakes == 2, "중복 부모 거부")
	game.state.parent = ""
	game.state.child = ""
	press(["A", "C", "right", "B", "D", "left", "C", "E", "right", "check"])
	check(game.level_done, "트리 L2 완료")
	level(2)
	press(["C", "D", "unlink", "B", "C", "unlink"])
	check(game.state.edges == {"A": ["B", null]}, "연결 해제")
	press(["D", "A", "left"])
	check(game.mistakes == 1, "루트 거부2")
	game.state.parent = ""
	game.state.child = ""
	press(["B", "D", "left"])
	press(["D", "B", "left"])
	check(game.mistakes == 2, "순환 거부")
	game.state.parent = ""
	game.state.child = ""
	game.undo()
	check(game.state.edges == {"A": ["B", null]}, "되돌리기 복원")
	press(["B", "D", "left", "A", "C", "right", "B", "E", "right", "check"])
	check(game.level_done, "트리 L3 복원 완료")
	close()
	print("TREE ok")

func test_graph() -> void:
	open("DS10_GraphBuild")
	press(["A", "A", "add"])
	check(game.mistakes == 1, "자기 간선 거부")
	press(["A", "B", "add", "B", "A", "add"])
	check(game.mistakes == 2, "무방향 평행 간선 거부")
	press(["B", "D", "add", "check"])
	check(game.mistakes == 3 and not game.level_done, "미완성 제출")
	press(["C", "A", "add", "D", "C", "add", "check"])
	check(game.level_done, "그래프 L1 완료")
	level(1)
	press(["B", "A", "add", "check"])
	check(game.mistakes == 1, "방향 반대 안내")
	press(["B", "A", "del", "A", "B", "add", "B", "C", "add", "C", "A", "add", "D", "A", "add"])
	check(game.reachable("D") == ["A", "B", "C"], "방향 도달 계산")
	check(game.reachable("A").has("C") and not game.reachable("A").has("D"), "역방향 도달 불가")
	press(["check"])
	check(game.level_done, "순환 포함 L2 완료")
	level(2)
	press(["C", "B", "del"])
	game.state.cost = 3
	press(["A", "B", "add"])
	check(game.state.edges["A>B"] == 3, "비용 수정")
	press(["cost-", "B", "C", "add"])
	game.state.cost = 4
	press(["C", "A", "add"])
	game.state.cost = 1
	press(["D", "A", "add", "check"])
	check(game.level_done, "단절 정점 포함 L3 완료")
	close()
	print("GRAPH ok")

func test_search() -> void:
	open("ALG02_Search")
	expect_wrong(["2"], "선형은 왼쪽부터")
	press(["0", "1", "2", "3"])
	check(game.problem == 1, "선형 찾기 후 다음 문제")
	press(["0", "1", "2"])
	check(game.level_done, "선형 끝까지 없음")
	level(1)
	expect_wrong(["0"], "중앙이 아닌 칸 거부")
	press(["3", "5", "4"])
	check(game.problem == 1, "16은 3→5→4")
	press(["0"])
	check(game.level_done, "한 원소 탐색")
	level(2)
	press(["3", "5", "4"])
	check(game.problem == 1, "없는 값 종료")
	press(["2"])
	check(game.problem == 2, "중복 값 찾기")
	expect_wrong(["pick:binary"], "미정렬 이진 탐색 차단")
	press(["pick:linear", "0", "1", "2"])
	check(game.problem == 3, "방법 선택 후 선형")
	press(["none"])
	check(game.level_done, "빈 배열 없음 선언")
	close()
	print("SEARCH ok")

func vals() -> Array:
	return game.state.a.map(func(c): return c[0])

func test_sort() -> void:
	open("ALG01_Sorting")
	expect_wrong(["3"], "비인접 교환 거부")
	expect_wrong(["keep"], "교환해야 할 때 유지 거부")
	var guard := 0
	while game.problem == 0 and guard < 30:
		guard += 1
		var a: Array = vals()
		var j: int = game.state.j
		press(["swap" if a[j] > a[j + 1] else "keep"])
	check(game.problem == 1, "버블 첫 문제 완료")
	var moves_before: int = game.state.cmp
	press(["keep", "keep"])
	check(game.level_done and moves_before == 0, "정렬된 입력은 한 패스로 종료")
	level(1)
	expect_wrong(["0"], "최솟값 아닌 카드 거부")
	press(["4", "1", "2"])
	press(["3"])
	check(game.level_done, "선택 정렬 완료")
	check(vals() == [1, 3, 3, 6, 7], "선택 정렬 결과와 중복 보존")
	level(2)
	expect_wrong(["2"], "다음 key 아닌 카드 거부")
	press(["1"])
	expect_wrong(["place"], "큰 값을 밀지 않고 놓기 거부")
	guard = 0
	while not game.level_done and guard < 200:
		guard += 1
		if game.state.phase == "lift":
			press([str(game.state.i)])
		else:
			var a: Array = vals()
			var j: int = game.state.hole - 1
			press(["shift" if j >= 0 and a[j] > game.state.key[0] else "place"])
	check(game.level_done and vals() == [-2, 0, 1, 3, 5, 9], "삽입 정렬 음수 포함")
	close()
	print("SORT ok")

func test_divide() -> void:
	open("ALG03_DivideSort")
	press(["run:0"])
	check(game.state.runs.size() == 2, "한 번 분할")
	press(["run:0", "run:2"])
	check(game.problem == 1, "4원소 모두 분할")
	press(["run:0", "run:0"])
	expect_wrong(["run:0"], "한 원소 분할 거부")
	var guard := 0
	while not game.level_done and guard < 20:
		guard += 1
		for i in game.state.runs.size():
			if game.state.runs[i].size() > 1:
				press(["run:%d" % i])
				break
	check(game.level_done, "홀수 길이 분할")
	level(1)
	check(game.state.plan.size() == 3, "4원소 병합 3번")
	guard = 0
	while not game.level_done and guard < 100:
		guard += 1
		var m: Dictionary = game.state.plan[game.state.m]
		var l: int = game.state.l
		var r: int = game.state.r
		var left_ok: bool = l < m.left.size() and (r >= m.right.size() or m.left[l][0] <= m.right[r][0])
		if guard == 1:
			expect_wrong(["right" if left_ok else "left"], "병합 순서 오류 거부")
		press(["left" if left_ok else "right"])
	check(game.level_done, "병합 L2 완료")
	level(2)
	var pivot = game.state.segs[0].items.back()[0]
	check(pivot == 4, "첫 pivot은 마지막 값")
	expect_wrong(["lt"], "6은 pivot보다 큼")
	guard = 0
	while not game.level_done and guard < 200:
		guard += 1
		var s: int = game.current_segment()
		var items: Array = game.state.segs[s].items
		var p = items.back()[0]
		var c = items[game.state.k][0]
		press(["eq" if c == p else ("lt" if c < p else "gt")])
	check(game.level_done, "퀵 정렬 완료, 모두 같은 값 포함")
	close()
	print("DIVIDE ok")

func solve_path() -> void:
	var p: Dictionary = game.problems()[game.problem]
	var pid: int = game.problem
	var guard := 0
	while not game.level_done and game.problem == pid and guard < 200:
		guard += 1
		match game.state.phase:
			"negative":
				press(["unusable"])
			"select":
				var low: int = game.INF
				var best := ""
				var names: Array = p.pos.keys()
				names.sort()
				for v in names:
					if not game.state.settled.has(v) and game.state.dist[v] < low:
						low = game.state.dist[v]
						best = v
				press(["unreachable" if best == "" else best])
			"relax":
				var n: Array = game.state.queue[0]
				press(["update" if game.state.dist[game.state.cur] + n[1] < game.state.dist[n[0]] else "keep"])
			"path":
				var from: String = game.state.path.back()
				var moved := false
				for e in p.edges:
					if e[0] == from and game.state.settled.has(e[1]) and game.state.dist[from] + e[2] == game.state.dist[e[1]] and game.on_tight_route(p, e[1]):
						press([e[1]])
						moved = true
						break
				if not moved:
					return

func test_shortest() -> void:
	open("ALG04_ShortestPath")
	expect_wrong(["B"], "미확정 최소 아닌 정점 거부")
	press(["A"])
	expect_wrong(["keep"], "갱신해야 할 때 유지 거부")
	solve_path()
	check(game.level_done, "최단 경로 L1")
	check(game.state.dist["D"] == 4, "A→C→B→D 비용 4")
	check(game.state.path == ["A", "C", "B", "D"], "경로 복원")
	level(1)
	solve_path()
	check(game.level_done and game.state.dist["E"] == 7, "우회 경로 비용 7")
	level(2)
	solve_path()
	check(game.problem == 1 and game.mistakes == 0, "동률 최단 경로")
	var p: Dictionary = game.problems()[1]
	press(["A", "update"])
	expect_wrong(["unreachable"], "남은 정점이 있을 때 도달 불가 거부")
	game.mistakes = 0
	solve_path()
	check(game.problem == 2, "도달 불가 판정")
	press(["A"])
	check(game.problem == 3, "시작=목적지 비용 0")
	expect_wrong(["A"], "음수 지도 실행 거부")
	press(["unusable"])
	check(game.level_done, "음수 간선 사용 불가")
	check(p.goal == "D", "데이터 유지")
	close()
	print("SHORTEST ok")

func type_field(key: String, text: String) -> void:
	press(["field:" + key])
	for ch in text:
		press(["key:" + ch])

func pick(key: String, n: int) -> void:
	for i in n:
		press(["pick:" + key])

func test_profile() -> void:
	open("DATA02_Profile")
	var source := str(game.PROFILE_ROWS)
	expect_wrong(["submit"], "빈 점검표 거부")
	type_field("rows", "5")
	type_field("cols", "4")
	pick("unit", 1)
	expect_wrong(["submit"], "틀린 열 수 거부")
	press(["field:cols", "key:back", "key:5", "submit"])
	check(game.level_done, "행·열·단위")
	level(1)
	pick("age_type", 1)
	pick("zip_type", 1)
	pick("joined_type", 3)
	pick("age_unit", 1)
	pick("visits_unit", 2)
	press(["submit"])
	check(game.mistakes == 1 and not game.level_done, "우편번호를 숫자로 고르면 오답")
	pick("zip_type", 1)
	press(["submit"])
	check(game.level_done, "자료형·단위")
	level(2)
	type_field("age_missing", "2")
	type_field("age_rate", "40")
	type_field("visits_missing", "1")
	pick("odd_col", 4)
	press(["submit"])
	check(game.mistakes == 1, "0을 결측으로 세면 오답")
	press(["field:visits_missing", "key:back", "key:0", "submit"])
	check(game.level_done, "결측률·형식 이상")
	check(str(game.PROFILE_ROWS) == source, "원본 무변경")
	close()
	print("PROFILE ok")

func ids() -> Array:
	var p: Dictionary = game.problems()[game.problem]
	return game.run_pipeline(p.rows, game.state.pipeline).rows.map(func(r): return r[0])

func test_clean() -> void:
	open("DATA01_Explore")
	expect_wrong(["submit"], "처리 없이 제출 거부")
	press(["missing"])
	check(ids() == [1, 3, 5], "결측만 제거, 0 유지")
	expect_wrong(["missing"], "같은 처리 중복 거부")
	press(["submit"])
	check(game.level_done, "DA-02 L1")
	level(1)
	press(["dedup"])
	check(ids() == [1, 3, 4, 6], "group+value 첫 등장 유지")
	press(["missing", "submit"])
	check(game.level_done and ids() == [1, 3, 4], "중복→결측")
	level(2)
	press(["dedup_key", "dedup"])
	press(["trim", "number", "date", "submit"])
	check(game.mistakes == 1, "표준화 전 중복 제거는 오답")
	game.undo()
	game.undo()
	game.undo()
	game.undo()
	check(game.state.pipeline.is_empty(), "취소 시 원본 복원")
	press(["trim", "number", "date", "dedup", "submit"])
	check(game.level_done, "DA-02 L3 완료")
	close()
	print("CLEAN ok")

func test_stats() -> void:
	open("DATA03_Stats")
	type_field("count", "4")
	type_field("mean", "5")
	type_field("range", "7")
	press(["submit"])
	check(game.mistakes == 1, "틀린 범위")
	press(["field:range", "key:back", "key:6", "submit"])
	check(game.level_done, "DA-03 L1")
	level(1)
	type_field("median", "5")
	press(["submit"])
	check(game.problem == 1, "홀수 중앙값")
	type_field("median", "13")
	press(["submit"])
	check(game.problem == 2, "짝수 중앙값")
	type_field("count", "2")
	type_field("mean", "6")
	press(["submit"])
	check(game.level_done, "NULL 제외")
	level(2)
	for pair in [["mean", "34"], ["median", "13"], ["range", "90"], ["mean_ex", "12"], ["median_ex", "12"], ["range_ex", "4"]]:
		type_field(pair[0], pair[1])
	press(["claim:1", "submit"])
	check(game.mistakes == 1, "이상치 삭제 결론 거부")
	press(["claim:2", "submit"])
	check(game.mistakes == 2, "인과 단정 거부")
	press(["claim:0", "submit"])
	check(game.problem == 1, "이상치 비교")
	type_field("range", "0")
	type_field("range2", "20")
	press(["claim:1", "submit"])
	check(game.mistakes == 3, "같은 평균 같은 분포 거부")
	press(["claim:0", "submit"])
	check(game.problem == 2, "분포 비교")
	press(["claim:1", "submit"])
	check(game.mistakes == 4, "빈 집단 평균 0 거부")
	press(["claim:0", "submit"])
	check(game.level_done, "빈 집단")
	close()
	print("STATS ok")

func test_chart() -> void:
	open("DATA04_Chart")
	press(["draw"])
	check(game.mistakes == 1, "축 뒤바꿈 거부")
	press(["x", "y", "draw"])
	check(game.mistakes == 2, "집계 없음 거부")
	press(["agg", "draw"])
	check(game.mistakes == 3 and not game.state.drawn, "막대 축 절단 거부")
	press(["zero", "draw"])
	check(game.state.drawn, "막대 차트 설정 완료")
	var d: Array = game.chart_data(game.problems()[0])
	var best := 0
	for i in d.size():
		if d[i][1] > d[best][1]:
			best = i
	check(d[best][0] == "공책" and d[best][1] == 55.0, "제품별 합계")
	press(["mark:%d" % ((best + 1) % d.size()), "claim:0", "submit"])
	check(game.mistakes == 4, "근거 오답")
	press(["mark:%d" % best, "claim:2", "submit"])
	check(game.mistakes == 5, "원인 단정 거부")
	press(["claim:0", "submit"])
	check(game.level_done, "DA-04 L1")
	level(1)
	press(["x", "y", "ctype"])
	press(["draw"])
	check(game.mistakes == 1, "시간순 정렬 없음 거부")
	press(["sort", "draw"])
	var months: Array = game.chart_data(game.problems()[0]).map(func(r): return r[0])
	check(months == ["2026-01", "2026-02", "2026-03"], "날짜 시간순")
	press(["mark:1", "claim:0", "submit"])
	check(game.level_done, "DA-04 L2")
	level(2)
	press(["ctype", "ctype", "draw"])
	check(game.state.drawn, "산점도 x/y 교환도 허용")
	check(game.chart_data(game.problems()[0]).size() == 4, "NULL 쌍 제외")
	press(["mark:0", "claim:1", "submit"])
	check(game.mistakes == 1, "상관을 인과로 해석 거부")
	press(["claim:0", "submit"])
	check(game.level_done, "DA-04 L3")
	close()
	print("CHART ok")

