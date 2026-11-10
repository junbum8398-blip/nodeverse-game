extends SceneTree
## SQL 5x5 서랍 게임 검사: 명세 필수 값, 12개 레벨 풀이, 오답·미완성 차단, 되돌리기, 재진입.
## 실행: Godot --headless --path . --script res://scripts/tools/test_sql_drawer.gd

const Model = preload("res://scripts/minigames/sql_query_model.gd")
const Data = preload("res://scripts/minigames/sql_drawer_levels.gd")
const Drawer = preload("res://scripts/minigames/sql_drawer.gd")
const SCENES := {"query": "SQL01_Query", "group": "SQL02_GroupBy", "join": "SQL03_Join", "sub": "SQL04_Subquery"}
var failures := 0
var checks := 0
var g

func check(v: bool, msg: String) -> void:
	checks += 1
	if not v:
		failures += 1
		print("FAIL ", msg)

func _init() -> void:
	call_deferred("run")

func open(mode: String) -> void:
	Drawer.saved.clear()
	g = (load("res://scenes/stages/%s.tscn" % SCENES[mode]) as PackedScene).instantiate()
	g.instant = true
	root.add_child(g)
	g.phase = "play"

func level(n: int) -> void:
	g._load_level(n)
	g.instant = true

func at(row: int, col: int) -> void:
	g.r = row
	g.c = col

func paint(tool_name: String, row: int, col: int) -> void:
	g.tool_id = tool_name
	at(row, col)
	g.press_e()

func cond(tool_name: String, row: int, col: int, op: String, val: int) -> void:
	paint(tool_name, row, col)
	var ops: Array = g.COMPARE_OPS if g.palette.mode == "compare" else Model.NUMERIC_OPS
	g.palette.op = ops.find(op)
	if g.palette.has("val"):
		g.palette.val = g.WHERE_VALUES.find(val)
	g.confirm_palette()

func solved(msg: String) -> void:
	g.submit()
	check(g.phase == "solved", msg + " :: " + g.message)

func run() -> void:
	MiniGameBase.progress_saving = false
	var nm = root.get_node_or_null("NetworkManager")
	if nm:
		nm.auto_send_enabled = false
	test_model()
	test_query()
	test_group()
	test_join()
	test_sub()
	test_shared()
	await test_keyboard()
	print("SQL_DRAWER_TEST_DONE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func compile(mode: String, patch: Dictionary, right = null) -> Dictionary:
	var m := Model.new_model()
	m.merge(patch, true)
	var t := {"left": Data.STUDENTS_J if mode == "join" else Data.STUDENTS}
	if right != null:
		t.right = right
	return Model.compile(mode, m, t)

func test_model() -> void:
	var r := compile("query", {"select": ["name", "score"], "cond": {"col": "score", "op": ">=", "val": 80}})
	check(r.rows == [["민지", 90], ["서연", 80]], "≥80은 민지·서연")
	r = compile("sub", {"inner": {"fn": "AVG", "col": "score"}})
	check(is_equal_approx(r.token, 73.75), "평균 73.75")
	r = compile("group", {"group": "dept", "aggs": [{"fn": "COUNT", "col": "*"}, {"fn": "COUNT", "col": "score"}, {"fn": "AVG", "col": "score"}]})
	var total_rows := 0
	var total_vals := 0
	for row in r.rows:
		total_rows += row[1]
		total_vals += row[2]
	check(total_rows == 5 and total_vals == 4, "COUNT(*) 합 5, COUNT(score) 합 4")
	check(r.rows == [["개발", 2, 2, 85.0], ["디자인", 2, 1, 55.0], ["기획", 1, 1, 70.0]], "부서별 집계 값")
	r = compile("join", {"lk": "dept_id", "rk": "id", "join": "LEFT"}, Data.DEPTS)
	check(r.rows.size() == 5 and r.rows.filter(func(x): return x[1] == null).size() == 2, "LEFT 5행, 미매칭 2명")
	r = compile("join", {"lk": "dept_id", "rk": "id", "join": "INNER"}, Data.DEPTS)
	check(r.rows == [["민지", "개발"], ["준호", "디자인"], ["서연", "개발"]], "INNER 3행")
	r = compile("join", {"lk": "dept_id", "rk": "dept_id", "join": "INNER"}, Data.PROJECTS)
	check(r.rows.size() == 5 and r.rows.filter(func(x): return x[0] == "민지").size() == 2 and r.rows.filter(func(x): return x[0] == "서연").size() == 2, "프로젝트 5행, 중복 학생 보존")
	r = compile("join", {"lk": "dept_id"}, Data.DEPTS)
	check(not r.complete and r.sql.back().kind == "comment", "ON 미완성은 실행 가능한 척하지 않음")
	r = compile("query", {"select": ["name"], "cond": {"col": "score", "op": ">", "val": 100}})
	check(r.complete and r.rows.is_empty(), "빈 결과도 유효")
	r = compile("query", {"select": ["score"], "cond": {"col": "score", "op": ">=", "val": 0}})
	check(r.rows.size() == 4, "NULL은 비교 통과 안 함")

func test_query() -> void:
	open("query")
	g.submit()
	check(g.phase == "play" and g.mistakes == 0, "빈 선택 제출 차단")
	paint("col", 0, 1)
	g.submit()
	check(g.mistakes == 1 and g.wrong_cols == ["score"], "누락 열은 제목에 ? 표시")
	paint("col", 2, 2)
	check(g.res.sql[0].text == "SELECT name, score", "실시간 SELECT")
	solved("SQL01 L1")
	level(1)
	paint("col", 0, 1)
	paint("col", 0, 2)
	cond("cond", 0, 2, ">=", 80)
	check(g.res.sql.back().text == "WHERE score >= 80", "실시간 WHERE")
	check(g._cell_style(0, 1) == "cell_hit" and g._cell_style(0, 0) == "cell_row" and g._cell_style(1, 1) == "cell_col" and g._cell_style(1, 0) == "cell_plain", "열·행·교집합 색")
	solved("SQL01 L2")
	level(2)
	paint("col", 0, 1)
	paint("col", 0, 2)
	cond("cond", 0, 2, ">=", 60)
	paint("limit", 0, 2)
	check(g.m.limit == -1 and g.message.contains("정렬"), "정렬 전 LIMIT 차단")
	paint("order", 0, 2)
	paint("limit", 0, 2)
	check(g.res.rows == [["민지", 90]], "상위 1명")
	solved("SQL01 L3")
	g.free()

func test_group() -> void:
	open("group")
	paint("group", 0, 3)
	check(g.res.groups.size() == 3 and g._group_of(0) == g._group_of(2) and g._group_of(1) == g._group_of(3), "같은 부서 한 그룹")
	paint("count", 0, 3)
	solved("SQL02 L1")
	level(1)
	paint("group", 0, 3)
	paint("count", 0, 0)
	paint("countcol", 0, 2)
	paint("avg", 0, 2)
	solved("SQL02 L2")
	level(2)
	paint("group", 0, 3)
	paint("avg", 0, 2)
	paint("having", 0, 0)
	check(g.phase == "play" and g.message.contains("요약"), "조건은 요약 서랍에서만")
	at(5, 0)
	g.tool_id = "having"
	g.press_e()
	g.palette.op = 0
	g.palette.val = g.WHERE_VALUES.find(80)
	g.confirm_palette()
	check(g.res.rows == [["개발", 85.0]], "HAVING 개발만")
	check(g.res.groups.filter(func(x): return x.hidden).size() == 2, "숨겨진 그룹은 흐리게 남음")
	solved("SQL02 L3")
	g.free()

func test_join() -> void:
	open("join")
	paint("key", 0, 7)
	check(g.m.lk == "dept_id" or g.message.contains("왼쪽"), "오른쪽 먼저 칠 수 없음")
	paint("key", 0, 2)
	check(not g.res.complete, "한쪽 키는 미완성")
	g.submit()
	check(g.phase == "play" and g.mistakes == 0, "ON 미완성 제출 차단")
	paint("key", 0, 5)
	solved("SQL03 L1")
	level(1)
	paint("key", 0, 2)
	paint("key", 0, 5)
	g.submit()
	check(g.mistakes == 1 and g.message.contains("도윤"), "짝 없는 학생을 짚어 줌")
	paint("mode", 0, 0)
	solved("SQL03 L2")
	level(2)
	paint("key", 0, 2)
	paint("key", 0, 5)
	g.submit()
	check(g.message.contains("오른쪽 키"), "프로젝트 id는 틀린 키")
	paint("key", 0, 7)
	solved("SQL03 L3")
	g.free()

func test_sub() -> void:
	open("sub")
	paint("avg", 0, 1)
	check(g.m.inner == null, "문자 열 평균 차단")
	paint("avg", 0, 2)
	check(g.res.sql[0].text == "SELECT AVG(score)", "안쪽 SELECT")
	solved("SQL04 L1")
	level(1)
	paint("compare", 0, 2)
	check(g.phase == "play" and g.palette == null, "토큰 없이는 비교 불가")
	paint("avg", 0, 2)
	cond("compare", 0, 2, ">", 0)
	check(g.res.sql.size() == 6 and g.res.sql[2].kind == "where" and g.res.sql[3].kind == "inner", "안쪽·바깥 블록")
	g.submit()
	check(g.phase == "play" and g.mistakes == 0, "출력 열 없으면 미완성 차단")
	paint("col", 0, 1)
	paint("col", 0, 2)
	solved("SQL04 L2")
	check(g.res.rows == [["민지", 90], ["서연", 80]], "평균 초과 결과")
	level(2)
	paint("max", 0, 2)
	cond("compare", 0, 2, "=", 0)
	paint("col", 0, 1)
	paint("col", 0, 2)
	solved("SQL04 L3")
	check(g.res.rows == [["민지", 90]], "최댓값 결과")
	g.free()

func test_shared() -> void:
	open("query")
	level(1)
	paint("col", 0, 1)
	cond("cond", 0, 2, ">=", 80)
	var before = g.m.duplicate(true)
	cond("cond", 0, 2, ">=", 60)
	g.undo()
	check(g.m == before and g.res.sql.back().text == "WHERE score >= 80", "Z는 색·코드·결과 함께 복원")
	paint("erase", 0, 2)
	check(g.m.cond == null and g.res.rows.size() == 5, "지우개로 WHERE 제거, 결과 5행")
	g.reset_problem()
	check(g.m.select.is_empty() and g.m.cond == null, "X는 문제 초기화")
	paint("col", 0, 1)
	var data := str(Data.STUDENTS)
	check(data == str(g.tables.left), "원본 무변경")
	paint("col", 0, 1)
	paint("col", 0, 1)
	check(g.m.select == ["name"], "반복 색칠은 켜고 끔")
	g._save_progress()
	var snap = Drawer.saved["SQL01"].m.duplicate(true)
	g.free()
	var again = (load("res://scenes/stages/SQL01_Query.tscn") as PackedScene).instantiate()
	Drawer.saved["SQL01"] = {"level": 1, "m": snap, "r": 0, "c": 1, "tool": "col"}
	root.add_child(again)
	check(again.level == 1 and again.m == snap and again.res.sql[0].text == "SELECT name", "재진입 복원")
	again.free()
	Drawer.saved.clear()

func test_keyboard() -> void:
	open("query")
	g.instant = true
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.keycode = KEY_E
	ev.pressed = true
	g._unhandled_input(ev)
	check(g.m.select == ["id"], "E 적용")
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_E
	echo.keycode = KEY_E
	echo.pressed = true
	echo.echo = true
	g._unhandled_input(echo)
	check(g.m.select == ["id"], "E 누르고 있어도 한 번만 적용")
	var d := InputEventKey.new()
	d.physical_keycode = KEY_D
	d.keycode = KEY_D
	d.pressed = true
	g._unhandled_input(d)
	check(g.c == 1 and g.m.select == ["id"], "이동만으로는 데이터가 안 바뀜")
	var two := InputEventKey.new()
	two.physical_keycode = KEY_2
	two.keycode = KEY_2
	two.pressed = true
	g._unhandled_input(two)
	check(g.tool_id == "col", "1단계에 없는 도구는 안 열림")
	g.free()
	await process_frame
