extends "res://scripts/minigames/learning_lab.gd"
## SQL 실습: 기록 조회(SQL01) · 그룹 집계(SQL02) · 테이블 연결(SQL03) · 서브쿼리(SQL04).
## 정답 표를 저장하지 않고 고정 연습 데이터에서 목표 질의와 학습자 질의를 각각 계산해 비교한다.

const GUIDE_LINE := "화면 아래 카드에 의뢰가 적혀 있어요. 장치를 설정하고, 몇 행이 나올지 예측한 다음 실행하면 데이터가 움직이는 모습을 볼 수 있어요. 막히면 F로 힌트를 보세요. 세 번째 힌트에서 정답 경로가 열려요."
const STUDENTS := [[1, "민지", 90, "개발"], [2, "준호", 55, "디자인"], [3, "서연", 80, "개발"], [4, "도윤", null, "디자인"], [5, "하늘", 70, "기획"], [6, "유진", 80, "기획"]]
const STUDENT_COLS := ["id", "name", "score", "dept"]
const QUERY_COLS := ["id", "name", "score", "dept", "email"]
const SCORE_PREDS := ["없음", "score >= 60", "score >= 80", "score >= 100", "score < 70"]
const DEPT_PREDS := ["없음", "dept = '개발'", "dept = '기획'"]
const ANIM_STEP := 1.1
const JOIN_LEFT_Y := [340.0, 405.0, 465.0, 522.0]
const JOIN_RIGHT_Y := [360.0, 425.0, 490.0]
const LIMITS := [-1, 0, 1, 2, 3]
const QUERY_LEVELS := [
	[{"goal": "안내문을 보내게 전교생 이름과 부서만 뽑아 주세요", "columns": ["name", "dept"]}, {"goal": "성적표에 번호 먼저, 그다음 점수가 나오게 해 주세요", "columns": ["id", "score"]}],
	[{"goal": "개발팀 장학생(80점 이상)의 이름을 찾아 주세요", "columns": ["name"], "p1": "score >= 80", "link": "AND", "p2": "dept = '개발'"},
	 {"goal": "기획팀 전원과 80점 이상 우수자를 함께 초대할 명단을 만들어 주세요", "columns": ["name", "score"], "p1": "score >= 80", "link": "OR", "p2": "dept = '기획'"}],
	[{"goal": "60점 이상 학생 중 시상할 상위 2명의 이름과 점수를 뽑아 주세요", "columns": ["name", "score"], "p1": "score >= 60", "order": "DESC", "limit": 2},
	 {"goal": "시상 인원이 0명이면 명단이 어떻게 보이는지 점수순으로 확인해 주세요", "columns": ["name"], "order": "DESC", "limit": 0},
	 {"goal": "100점 만점자가 있는지 이름으로 확인해 주세요", "columns": ["name"], "p1": "score >= 100"}],
]

const SALES := [[1, "A", "서울", 10], [2, "A", "부산", 20], [3, "B", "서울", 5], [4, "B", "부산", null], [5, "C", "서울", 40], [6, "C", "서울", 30], [7, "D", "부산", 10]]
const SALES_COLS := ["id", "dept", "region", "amount"]
const GROUP_ITEMS := ["dept", "region", "amount", "COUNT(*)", "COUNT(amount)", "SUM(amount)", "AVG(amount)"]
const GROUP_CHIP := {"dept": "dept", "region": "지역", "amount": "금액", "COUNT(*)": "행수", "COUNT(amount)": "값수", "SUM(amount)": "SUM", "AVG(amount)": "AVG"}
const GROUP_WHERE := ["없음", "amount >= 10", "amount >= 100"]
const GROUP_BY := ["없음", "dept", "region"]
const GROUP_HAVING := ["없음", "SUM(amount) > 10", "COUNT(*) >= 2", "AVG(amount) >= 15"]
const GROUP_LEVELS := [
	[{"goal": "부서별 실적판에 건수와 금액 합계를 올려 주세요", "select": ["dept", "COUNT(*)", "SUM(amount)"], "group": "dept"}],
	[{"goal": "전체 건수와 금액이 적힌 건수가 다른 이유가 보이게 부서별 평균까지 내 주세요", "select": ["dept", "COUNT(*)", "COUNT(amount)", "AVG(amount)"], "group": "dept"}],
	[{"goal": "10 이상인 거래만 모아서 합계가 10을 넘는 부서만 실적판에 올려 주세요", "select": ["dept", "SUM(amount)"], "where": "amount >= 10", "group": "dept", "having": "SUM(amount) > 10"},
	 {"goal": "100 이상인 큰 거래가 부서별로 몇 건인지 세어 주세요", "select": ["dept", "COUNT(*)"], "where": "amount >= 100", "group": "dept"}],
]

const EMPLOYEES := [[1, "민지", 10], [2, "서연", 20], [3, "준호", 90], [4, "하늘", null]]
const DEPARTMENTS := [[20, "운영"], [10, "개발"]]
const PROJECTS := [[10, "앱"], [10, "웹"], [20, "물류"]]
const JOIN_KEYS := ["e.dept_id = d.id", "e.id = d.id", "행 번호로 연결"]
const JOIN_LEVELS := [
	[{"goal": "소속 부서를 찾은 직원에게 부서 명찰을 지급해 주세요", "right": DEPARTMENTS, "type": "INNER", "predict": false}],
	[{"goal": "부서를 못 찾은 직원도 빠지지 않게 명찰 명단을 만들어 주세요", "right": DEPARTMENTS, "type": "LEFT", "predict": false}],
	[{"goal": "직원별 담당 프로젝트 명단을 만들어 주세요 (한 부서에 프로젝트가 여럿이에요)", "right": PROJECTS, "type": "INNER", "predict": true},
	 {"goal": "부서 자료가 아직 없어도 직원 명단은 남겨 주세요", "right": [], "type": "LEFT", "predict": false}],
]

const SCORES := [["민지", "개발", 60], ["준호", "개발", 80], ["서연", "기획", 100], ["하늘", "디자인", null]]
const TEAMS := [["개발", "서울"], ["기획", "부산"], ["디자인", "서울"]]
const SUB_OPS := [">", ">=", "=", "IN"]
const SUB_LEVELS := [
	[{"goal": "평균을 넘은 학생을 선발해 주세요", "inner": ["AVG", "MAX", "ALL"], "answer": "AVG", "col": "score", "op": ">"}],
	[{"goal": "서울에 있는 팀 소속 학생 명단을 뽑아 주세요", "inner": ["CITY:서울", "CITY:부산"], "answer": "CITY:서울", "col": "dept", "op": "IN"}],
	[{"goal": "최고 점수를 받은 학생을 찾아 주세요", "inner": ["ALL", "MAX"], "answer": "MAX", "col": "score", "op": "="},
	 {"goal": "제주에 있는 팀 소속 학생을 찾아 주세요", "inner": ["CITY:제주", "CITY:서울"], "answer": "CITY:제주", "col": "dept", "op": "IN"}],
]

var fast_flow := false   # 자동 테스트 전용: 예측·연출·확인 단계를 건너뛴다
var final_hint := false
var hint_calls := 0
var _anim_step := 0
var _anim_p := 0.0

func lab_table() -> Dictionary:
	return {
		"query": {"id": "SQL01", "title": "필요한 기록 찾기", "levels": 3, "art": "SQL01", "npc": "NPC05", "npc_name": "기록 보관 담당자",
			"intro": ["반가워요. 이 서랍에는 학생 기록이 잔뜩 있어요. 필요한 것만 꺼내는 말이 바로 SQL이에요.",
				"SELECT는 볼 열, WHERE는 남길 행, ORDER BY는 순서, LIMIT은 개수를 정해요. 점수가 NULL인 기록은 비교 조건을 통과하지 못해요.",
				"블록을 골라 질의를 조립하고 실행하면 원본에서 바로 계산한 결과표가 나와요.", GUIDE_LINE],
			"talk": ["먼저 필요한 열만 골라요. 열을 E를 누른 순서대로 결과에 나와요.", "조건을 두 개 걸어 볼게요. AND는 둘 다, OR는 하나만 맞아도 통과예요.", "정렬한 다음 LIMIT이 적용돼요. 빈 결과도 올바른 결과일 수 있어요."],
			"hints": ["SELECT는 열, WHERE는 행, ORDER BY는 순서, LIMIT은 개수를 정해요.", "결과표의 열 순서와 행 수를 목표와 비교해 보세요.", "score >= 80, 점수 내림차순, LIMIT 1이면 가장 높은 한 명만 나와요."]},
		"group": {"id": "SQL02", "title": "부서별 실적 보고서", "levels": 3, "art": "SQL02", "npc": "NPC04", "npc_name": "보고서 담당자",
			"intro": ["안녕하세요! 낱개 기록을 부서별로 묶어서 보고서를 만들어 볼게요. 묶는 말이 GROUP BY예요.",
				"COUNT(*)는 모든 행, COUNT(amount)는 값이 있는 행만 세요. SUM과 AVG도 NULL은 빼고 계산해요.",
				"WHERE는 묶기 전에 행을 거르고, HAVING은 묶은 뒤에 그룹을 걸러요. 화면의 단계별 행 수를 보면 차이가 보여요.", GUIDE_LINE],
			"talk": ["부서별로 묶어서 행 수와 합계를 내 주세요.", "COUNT(*)와 COUNT(amount)가 왜 다른지 B 부서를 보세요.", "WHERE와 HAVING을 함께 써요. 조건이 모든 행을 지우면 결과가 비는 것도 확인해요."],
			"hints": ["GROUP BY로 묶으면 그룹 열과 집계식만 SELECT할 수 있어요.", "행을 거르면 WHERE, 그룹을 거르면 HAVING이에요.", "(A,10),(A,20),(B,5)를 묶으면 A는 합 30, B는 합 5. HAVING SUM>10이면 A만 남아요."]},
		"join": {"id": "SQL03", "title": "기록 연결 사무소", "levels": 3, "art": "SQL03", "npc": "NPC02", "npc_name": "기록 연결 담당자",
			"intro": ["안녕! 직원표와 부서표처럼 나뉜 기록은 공통 키로 이어야 해. 이걸 JOIN이라고 해.",
				"INNER JOIN은 키가 맞는 행만, LEFT JOIN은 왼쪽 행을 모두 남기고 짝이 없으면 NULL을 채워. 키가 NULL이면 어떤 값과도 맞지 않아.",
				"연결 키와 종류를 고르고 실행하면 어떤 행끼리 이어졌는지 선으로 보여 줄게.", GUIDE_LINE],
			"talk": ["직원의 dept_id와 부서의 id를 이어 줘.", "부서를 못 찾은 직원도 빠지면 안 돼. 어떤 JOIN을 써야 할까?", "키 하나에 여러 행이 맞으면 결과도 늘어나. 행 수를 먼저 세어 봐."],
			"hints": ["JOIN은 키가 같은 행끼리 이어 붙여요.", "미매칭 왼쪽 행을 남겨야 하면 LEFT JOIN이에요.", "직원 (민,1),(준,9), 부서 (1,개발)을 LEFT JOIN하면 민/개발, 준/NULL이에요."]},
		"subquery": {"id": "SQL04", "title": "조건 속의 조건", "levels": 3, "art": "SQL04", "npc": "NPC06", "npc_name": "조건 분석가",
			"intro": ["어서 오렴. 질문 안에 또 질문이 있을 때가 있지. '평균보다 높은 학생'을 찾으려면 평균부터 알아야 하잖니.",
				"안쪽 질의를 먼저 실행하면 값 하나 또는 값 여러 개가 나와. 값 하나는 비교(>, =)에, 여러 값은 IN에 쓸 수 있단다.",
				"안쪽 질의를 고르고 실행한 뒤, 그 결과를 바깥 조건에 이어 실행해 보렴.", GUIDE_LINE],
			"talk": ["평균 점수를 먼저 구하고, 그보다 큰 학생을 찾아 보렴.", "서울 팀 목록은 여러 값이야. 어떤 연산자가 필요할까?", "값 여러 개를 =에 연결하면 형태 오류가 난단다. 빈 집합일 때 결과도 확인해 보렴."],
			"hints": ["안쪽 결과가 바깥 조건의 값 또는 집합이 돼요.", "안쪽이 한 행 한 열이면 비교 연산, 여러 행이면 IN을 써요.", "[60,80,100]의 평균은 80. score > 80이면 100인 행만 남아요."]},
	}

func problems_for(n: int) -> Array:
	match activity:
		"query": return QUERY_LEVELS[n]
		"group": return GROUP_LEVELS[n]
		"join": return JOIN_LEVELS[n]
	return SUB_LEVELS[n]

func setup_problem(p: Dictionary) -> void:
	goal = p.goal
	final_hint = false
	hint_calls = 0
	var common = {"phase": "setup", "stage": -1, "predict": -1, "result": null, "error": "", "review_ok": false, "review_text": "", "timeline": []}
	match activity:
		"query":
			state = {"columns": [], "p1": 0, "link": 0, "p2": 0, "order": 0, "limit": 0}
		"group":
			state = {"select": [], "where": 0, "group": 0, "having": 0, "stages": []}
		"join":
			state = {"key": -1, "type": -1, "pairs": []}
		"subquery":
			state = {"inner": -1, "op": -1, "token": null}
	state.merge(common)

func handle(key: String) -> void:
	if state.phase != "setup":
		return
	mark_stage(key)
	if key == "predict":
		step()
		state.predict = (state.predict + 1) % 10
		return
	if key == "run":
		if state.predict < 0 and not fast_flow:
			hud.toast("먼저 예측 장치에서 몇 행이 나올지 정하세요", StageHUD.GOLD)
			return
		moves += 1
		match activity:
			"query": run_query()
			"group": run_group()
			"join": run_join()
			"subquery": run_outer()
		return
	if key == "inner_run":
		moves += 1
		run_inner()
		return
	step()
	state.result = null
	state.error = ""
	match activity:
		"query": edit_query(key)
		"group": edit_group(key)
		"join": edit_join(key)
		"subquery": edit_sub(key)

func cycle(k: String, n: int) -> void:
	state[k] = (state[k] + 1) % n

func lab_rows() -> Array:
	return [["실행", moves], ["실수", mistakes], ["결과 행", "-" if state.result == null else str(result_count())]]

func result_count() -> int:
	return state.result.size()

func state_code() -> String:
	match activity:
		"query": return query_text(user_query())
		"group": return group_text(user_group())
		"join": return join_text()
	return sub_text()

func same_rows(a: Array, b: Array) -> bool:
	return sorted_rows(a) == sorted_rows(b)

func sorted_rows(rows: Array) -> Array:
	var out = rows.map(func(r): return str(r.map(func(v): return display(v))))
	out.sort()
	return out

# ---------- 기록 조회 ----------
func edit_query(key: String) -> void:
	if key.begins_with("col:"):
		var c = key.trim_prefix("col:")
		if state.columns.has(c):
			state.columns.erase(c)
		else:
			state.columns.append(c)
		return
	match key:
		"p1": cycle("p1", SCORE_PREDS.size())
		"link": cycle("link", 2)
		"p2": cycle("p2", DEPT_PREDS.size())
		"order": cycle("order", 3)
		"limit": cycle("limit", LIMITS.size())

func user_query() -> Dictionary:
	return {"columns": state.columns, "p1": SCORE_PREDS[state.p1], "link": ["AND", "OR"][state.link], "p2": DEPT_PREDS[state.p2], "order": ["", "DESC", "ASC"][state.order], "limit": LIMITS[state.limit]}

func target_query(p: Dictionary) -> Dictionary:
	return {"columns": p.columns, "p1": p.get("p1", "없음"), "link": p.get("link", "AND"), "p2": p.get("p2", "없음"), "order": p.get("order", ""), "limit": p.get("limit", -1)}

func pred_match(pred: String, row: Array):
	if pred == "없음":
		return null
	var score = row[2]
	match pred:
		"score >= 60": return score != null and score >= 60
		"score >= 80": return score != null and score >= 80
		"score >= 100": return score != null and score >= 100
		"score < 70": return score != null and score < 70
		"dept = '개발'": return row[3] == "개발"
		"dept = '기획'": return row[3] == "기획"
	return false

func eval_query(q: Dictionary) -> Array:
	var rows = []
	for row in STUDENTS:
		var a = pred_match(q.p1, row)
		var b = pred_match(q.p2, row)
		var keep = true
		if a != null and b != null:
			keep = (a and b) if q.link == "AND" else (a or b)
		elif a != null:
			keep = a
		elif b != null:
			keep = b
		if keep:
			rows.append(row)
	if q.order != "":
		var desc: bool = q.order == "DESC"
		rows.sort_custom(func(x, y):
			var sx = x[2] if x[2] != null else -1
			var sy = y[2] if y[2] != null else -1
			if sx != sy:
				return sx > sy if desc else sx < sy
			return x[0] < y[0])
	if q.limit >= 0:
		rows = rows.slice(0, q.limit)
	var out = []
	for row in rows:
		out.append(q.columns.map(func(c): return row[STUDENT_COLS.find(c)]))
	return out

func run_query() -> void:
	state.error = ""
	if state.columns.is_empty():
		wrong("SELECT할 열을 하나 이상 고르세요.")
		return
	if state.columns.has("email"):
		state.error = "email 열은 students 표에 없어요."
		wrong(state.error)
		return
	var q = user_query()
	state.result = eval_query(q)
	var p: Dictionary = problems()[problem]
	var t = target_query(p)
	var expect = eval_query(t)
	code(query_text(q))
	if q.columns != t.columns:
		conclude(false, "의뢰한 열과 달라요. 어떤 열이 필요한지, 순서는 맞는지 보세요.")
		return
	var ok: bool = state.result == expect if t.order != "" else same_rows(state.result, expect)
	if t.order != "" and q.order != t.order:
		ok = false
	if ok:
		conclude(true, "의뢰와 같은 명단이에요.")
	else:
		var same_cols_order: bool = t.order != "" and same_rows(state.result, expect)
		conclude(false, names_diff(first_cells(state.result), first_cells(expect), same_cols_order or t.order != ""))

func query_text(q: Dictionary) -> String:
	var t = "SELECT %s FROM students" % (", ".join(q.columns) if not q.columns.is_empty() else "...")
	var conds = []
	if q.p1 != "없음":
		conds.append(q.p1)
	if q.p2 != "없음":
		conds.append(q.p2)
	if not conds.is_empty():
		t += " WHERE " + (" %s " % q.link).join(conds)
	if q.order != "":
		t += " ORDER BY score %s, id ASC" % q.order
	if q.limit >= 0:
		t += " LIMIT %d" % q.limit
	return t

# ---------- 그룹 집계 ----------
func edit_group(key: String) -> void:
	if key.begins_with("sel:"):
		var c = key.trim_prefix("sel:")
		if state.select.has(c):
			state.select.erase(c)
		else:
			state.select.append(c)
		return
	match key:
		"where": cycle("where", GROUP_WHERE.size())
		"by": cycle("group", GROUP_BY.size())
		"having": cycle("having", GROUP_HAVING.size())

func user_group() -> Dictionary:
	return {"select": state.select, "where": GROUP_WHERE[state.where], "group": GROUP_BY[state.group], "having": GROUP_HAVING[state.having]}

func target_group(p: Dictionary) -> Dictionary:
	return {"select": p.select, "where": p.get("where", "없음"), "group": p.get("group", "없음"), "having": p.get("having", "없음")}

func aggregate(item: String, rows: Array):
	var nums = []
	for r in rows:
		if r[3] != null:
			nums.append(float(r[3]))
	var total = 0.0
	for v in nums:
		total += v
	match item:
		"COUNT(*)": return rows.size()
		"COUNT(amount)": return nums.size()
		"SUM(amount)": return total if not nums.is_empty() else null
		"AVG(amount)": return total / nums.size() if not nums.is_empty() else null
	return null

## 반환: {"rows": 결과 행(select 순서), "stages": [원본, WHERE 후, 그룹 수, HAVING 후]}
func eval_group(q: Dictionary) -> Dictionary:
	var kept = SALES.filter(func(r):
		if q.where == "없음":
			return true
		var limit = 10 if q.where == "amount >= 10" else 100
		return r[3] != null and r[3] >= limit)
	var groups = {}
	if q.group == "없음":
		groups["전체"] = kept
	else:
		var idx = SALES_COLS.find(q.group)
		for r in kept:
			if not groups.has(r[idx]):
				groups[r[idx]] = []
			groups[r[idx]].append(r)
	var names = groups.keys()
	names.sort()
	var out = []
	var after_having = 0
	for name in names:
		var rows: Array = groups[name]
		if not having_pass(q.having, rows):
			continue
		after_having += 1
		var row = []
		for item in q.select:
			row.append(name if item == q.group else aggregate(item, rows))
		out.append(row)
	return {"rows": out, "stages": [SALES.size(), kept.size(), groups.size(), after_having]}

func having_pass(h: String, rows: Array) -> bool:
	match h:
		"SUM(amount) > 10":
			var s = aggregate("SUM(amount)", rows)
			return s != null and s > 10
		"COUNT(*) >= 2":
			return rows.size() >= 2
		"AVG(amount) >= 15":
			var a = aggregate("AVG(amount)", rows)
			return a != null and a >= 15
	return true

func canonical(select: Array, rows: Array) -> Array:
	var order = select.duplicate()
	order.sort()
	var out = []
	for row in rows:
		out.append(order.map(func(c): return display(row[select.find(c)])))
	return out

func run_group() -> void:
	state.error = ""
	var q = user_group()
	if q.select.is_empty():
		wrong("SELECT할 항목을 하나 이상 고르세요.")
		return
	for item in q.select:
		if item in ["dept", "region", "amount"] and item != q.group:
			state.error = "%s은(는) GROUP BY 열이나 집계식이 아니에요." % item
			wrong(state.error)
			return
	var user = eval_group(q)
	state.result = user.rows
	state.stages = user.stages
	code(group_text(q))
	var p: Dictionary = problems()[problem]
	var t = target_group(p)
	var expect = eval_group(t)
	var want = t.select.duplicate()
	var got = q.select.duplicate()
	want.sort()
	got.sort()
	if want != got:
		conclude(false, "의뢰한 항목과 보고서 항목이 달라요.")
		return
	if same_rows(canonical(q.select, user.rows), canonical(t.select, expect.rows)):
		conclude(true, "의뢰와 같은 실적판이에요.")
	else:
		var key_i: int = q.select.find(q.group)
		var mine = user.rows.map(func(r): return display(r[key_i])) if key_i >= 0 else first_cells(user.rows)
		var ti: int = t.select.find(t.group)
		var theirs = expect.rows.map(func(r): return display(r[ti])) if ti >= 0 else first_cells(expect.rows)
		conclude(false, names_diff(mine, theirs))

func group_text(q: Dictionary) -> String:
	var t = "SELECT %s FROM sales" % (", ".join(q.select) if not q.select.is_empty() else "...")
	if q.where != "없음":
		t += " WHERE " + q.where
	if q.group != "없음":
		t += " GROUP BY " + q.group
	if q.having != "없음":
		t += " HAVING " + q.having
	return t

# ---------- 테이블 연결 ----------
func edit_join(key: String) -> void:
	match key:
		"key": cycle("key", JOIN_KEYS.size())
		"type": cycle("type", 2)

## 반환: {"rows": [[직원 이름, 오른쪽 값]...], "pairs": [[왼쪽 행, 오른쪽 행 또는 -1]...]}
func eval_join(right: Array, key_i: int, join_type: String) -> Dictionary:
	var rows = []
	var pairs = []
	for l in EMPLOYEES.size():
		var e: Array = EMPLOYEES[l]
		var matched = false
		for r in right.size():
			var d: Array = right[r]
			var hit = false
			match key_i:
				0: hit = e[2] != null and e[2] == d[0]
				1: hit = e[0] == d[0]
				2: hit = l == r
			if hit:
				matched = true
				rows.append([e[1], d[1]])
				pairs.append([l, r])
		if not matched and join_type == "LEFT":
			rows.append([e[1], null])
			pairs.append([l, -1])
	return {"rows": rows, "pairs": pairs}

func run_join() -> void:
	var p: Dictionary = problems()[problem]
	if state.key < 0 or state.type < 0:
		wrong("연결 키와 처리 방식을 먼저 정하세요.")
		return
	var t: String = type_name()
	var user = eval_join(p.right, state.key, t)
	state.result = user.rows
	state.pairs = user.pairs
	code(join_text())
	if p.predict and state.predict != user.rows.size():
		conclude(false, "예측이 달라요. 부서 하나에 프로젝트가 몇 개인지 세어 보세요.")
		return
	var expect = eval_join(p.right, 0, p.type)
	if same_rows(user.rows, expect.rows) and state.key == 0:
		conclude(true, "모든 직원이 올바른 명찰을 받았어요.")
	elif state.key != 0:
		conclude(false, "엉뚱한 값끼리 이어졌어요. 직원의 어느 열이 부서의 id와 같은 뜻일까요?")
	else:
		conclude(false, names_diff(first_cells(user.rows), first_cells(expect.rows)) + " · 짝 없는 직원 처리 방식을 보세요.")

func join_text() -> String:
	var p: Dictionary = problems()[problem]
	var table = "projects" if p.right == PROJECTS else "departments"
	return "SELECT e.name, d.name FROM employees e %s JOIN %s d ON %s" % [type_name(), table, key_name()]

# ---------- 서브쿼리 ----------
func edit_sub(key: String) -> void:
	var p: Dictionary = problems()[problem]
	match key:
		"inner":
			state.inner = (state.inner + 1) % p.inner.size()
			state.token = null
		"op":
			cycle("op", SUB_OPS.size())

func inner_sql(id: String) -> String:
	match id:
		"": return "(안쪽 질의 미설정)"
		"AVG": return "SELECT AVG(score) FROM scores"
		"MAX": return "SELECT MAX(score) FROM scores"
		"ALL": return "SELECT score FROM scores"
	return "SELECT team FROM teams WHERE city = '%s'" % id.trim_prefix("CITY:")

## 안쪽 질의 결과: {"shape": "scalar" 또는 "set", "values": [...]}
func eval_inner(id: String) -> Dictionary:
	var nums = []
	for r in SCORES:
		if r[2] != null:
			nums.append(float(r[2]))
	match id:
		"AVG":
			var total = 0.0
			for n in nums:
				total += n
			return {"shape": "scalar", "values": [total / nums.size()]}
		"MAX":
			return {"shape": "scalar", "values": [nums.max()]}
		"ALL":
			return {"shape": "set", "values": nums}
	var city = id.trim_prefix("CITY:")
	var teams = []
	for t in TEAMS:
		if t[1] == city:
			teams.append(t[0])
	return {"shape": "set", "values": teams}

func outer_rows(col: String, op: String, token: Dictionary) -> Array:
	var out = []
	var idx = 2 if col == "score" else 1
	for r in SCORES:
		var v = r[idx]
		var keep = false
		if v != null:
			if op == "IN":
				keep = token.values.has(float(v) if col == "score" else v)
			else:
				var c: float = token.values[0]
				match op:
					">": keep = v > c
					">=": keep = v >= c
					"=": keep = is_equal_approx(float(v), c)
		if keep:
			out.append([r[0], r[2]])
	return out

func run_inner() -> void:
	var p: Dictionary = problems()[problem]
	if state.inner < 0:
		wrong("안쪽 장치에서 값을 먼저 고르세요.")
		return
	var id: String = inner_id(p)
	state.token = eval_inner(id)
	state.result = null
	code(inner_sql(id), "안쪽 먼저")

func run_outer() -> void:
	var p: Dictionary = problems()[problem]
	if state.inner < 0 or state.token == null:
		wrong("안쪽 질의를 먼저 실행하세요.")
		return
	if state.op < 0:
		wrong("토큰과 비교할 연산자를 고르세요.")
		return
	var op: String = op_name()
	var id: String = inner_id(p)
	if state.token.shape == "set" and state.token.values.size() != 1 and op != "IN":
		state.error = "안쪽 결과가 여러 행이에요. %s에는 값 하나만 연결할 수 있어요." % op
		wrong(state.error)
		return
	state.error = ""
	state.result = outer_rows(p.col, op, state.token)
	code(sub_text())
	var expect = outer_rows(p.col, p.op, eval_inner(p.answer))
	if id == p.answer and same_rows(state.result, expect):
		conclude(true, "안쪽 결과로 바깥 조건을 정확히 만들었어요.")
	elif id != p.answer:
		conclude(false, "안쪽 장치가 의뢰에 필요한 값을 만들지 않았어요.")
	else:
		conclude(false, names_diff(first_cells(state.result), first_cells(expect)) + " · 경계값이 포함되는지 보세요.")

func sub_text() -> String:
	var p: Dictionary = problems()[problem]
	return "SELECT name, score FROM scores WHERE %s %s (%s)" % [("dept" if p.col == "dept" else "score"), op_name(), inner_sql(inner_id(p))]

# ---------- 시안 위 배치 ----------
func stations() -> Array:
	match activity:
		"query": return query_stations()
		"group": return group_stations()
		"join": return join_stations()
	return sub_stations()

func query_stations() -> Array:
	var q = user_query()
	var out: Array = [predict_station()]
	for c in QUERY_COLS:
		var order: int = state.columns.find(c)
		out.append(["col:" + c, "열 렌즈 %s %s" % [c, "빼기" if order >= 0 else "꽂기"], ("%d.%s" % [order + 1, c]) if order >= 0 else c])
	out.append(["p1", "점수 게이트: %s (E 바꾸기)" % q.p1, "점수"])
	out.append(["link", "두 게이트 관계: %s (E 바꾸기)" % q.link, q.link])
	out.append(["p2", "부서 게이트: %s (E 바꾸기)" % q.p2, "부서"])
	out.append(["order", "정렬: %s (E 바꾸기)" % ("없음" if q.order == "" else "score " + q.order), "정렬"])
	out.append(["limit", "LIMIT: %s (E 바꾸기)" % ("없음" if q.limit < 0 else str(q.limit)), "개수"])
	out.append(["run", "질의 실행", "④ 실행"])
	return out

func group_stations() -> Array:
	var q = user_group()
	var out: Array = [predict_station()]
	for c in GROUP_ITEMS:
		out.append(["sel:" + c, "SELECT %s %s" % [c, "빼기" if state.select.has(c) else "넣기"], ("✓" if state.select.has(c) else "") + GROUP_CHIP[c]])
	out.append(["where", "WHERE: %s (E 바꾸기)" % q.where, "WHERE"])
	out.append(["by", "GROUP BY: %s (E 바꾸기)" % q.group, "GROUP"])
	out.append(["having", "HAVING: %s (E 바꾸기)" % q.having, "HAVING"])
	out.append(["run", "보고서 실행", "⑤ 실행"])
	return out

func join_stations() -> Array:
	var p: Dictionary = problems()[problem]
	return [null,
		["key", "연결 키: %s (E 바꾸기)" % key_name(), "① 연결 키"],
		["type", "처리 방식: %s (E 바꾸기)" % type_name(), "② " + type_name()],
		predict_station(),
		["run", "연결 실행", "④ 실행"]]

func sub_stations() -> Array:
	var p: Dictionary = problems()[problem]
	return [predict_station(),
		["inner", "안쪽: %s (E 바꾸기)" % inner_sql(inner_id(p)), "① 안쪽 고르기"],
		["inner_run", "안쪽 실행", "② 안쪽 실행"],
		["op", "연산자: %s (E 바꾸기)" % op_name(), "③ " + op_name()],
		["run", "바깥 실행", "④ 바깥 실행"]]

func draw_board() -> void:
	match activity:
		"query": draw_query_board()
		"group": draw_group_board()
		"join": draw_join_board()
		"subquery": draw_sub_board()
	draw_anim()
	draw_mission()

## 화살표는 다음에 바꿔야 할 장치만 가리킨다. 답이 되는 값은 실수한 뒤에만 알려 준다.
func hint_allowed(_t: Interactable) -> bool:
	return true

func next_action() -> Array:
	if input_locked():
		return [null, ""]
	var a: Array = super.next_action()
	a[1] = "여기서 E"
	return a

func next_key() -> String:
	if final_hint:
		return answer_key()
	var stages: Array = stage_order()
	return stage_station(stages[mini(state.stage + 1, stages.size() - 1)])

func stage_order() -> Array:
	match activity:
		"query": return ["col", "gate", "order", "predict", "run"]
		"group": return ["sel", "where", "by", "having", "predict", "run"]
		"join": return ["key", "type", "predict", "run"]
	return ["inner", "inner_run", "op", "predict", "run"]

func stage_station(stage: String) -> String:
	match stage:
		"col": return "col:id"
		"gate": return "p1"
		"sel": return "sel:dept"
	return stage

func key_stage(key: String) -> String:
	if key.begins_with("col:"):
		return "col"
	if key.begins_with("sel:"):
		return "sel"
	if key in ["p1", "p2", "link"]:
		return "gate"
	if key == "limit":
		return "order"
	return key

func mark_stage(key: String) -> void:
	state.stage = maxi(state.stage, stage_order().find(key_stage(key)))

func answer_key() -> String:
	var p: Dictionary = problems()[problem]
	match activity:
		"query": return next_query_key(p)
		"group": return next_group_key(p)
		"join": return next_join_key(p)
	return next_sub_key(p)

## 세 번째 힌트부터 실제 정답 경로를 알려 준다. 평소 화살표는 작업 순서만 가리킨다.
func use_hint() -> void:
	if done:
		return
	hint_calls += 1
	if hint_calls >= 3:
		final_hint = true
		hints_used += 1
		hud.toast("정답 경로: " + answer_text(), StageHUD.GOLD, 9.0)
		rebuild()
		refresh()
		return
	super.use_hint()

func answer_text() -> String:
	var p: Dictionary = problems()[problem]
	match activity:
		"query":
			var t = target_query(p)
			return "%s · %s %s %s · %s · LIMIT %s" % [", ".join(t.columns), t.p1, t.link, t.p2, t.order if t.order != "" else "정렬 없음", str(t.limit) if t.limit >= 0 else "없음"]
		"group":
			var t = target_group(p)
			return "%s · WHERE %s · GROUP %s · HAVING %s" % [", ".join(t.select), t.where, t.group, t.having]
		"join":
			return "%s · %s JOIN" % [JOIN_KEYS[0], p.type]
	return "%s · %s" % [inner_short(p.answer), p.op]

func key_name() -> String:
	return JOIN_KEYS[state.key] if state.key >= 0 else "미설정"

func type_name() -> String:
	return ["INNER", "LEFT"][state.type] if state.type >= 0 else "미설정"

func op_name() -> String:
	return SUB_OPS[state.op] if state.op >= 0 else "미설정"

func inner_id(p: Dictionary) -> String:
	return p.inner[state.inner] if state.inner >= 0 else ""

func next_query_key(p: Dictionary) -> String:
	var t = target_query(p)
	var q = user_query()
	for i in t.columns.size():
		if i >= state.columns.size():
			return "col:" + t.columns[i]
		if state.columns[i] != t.columns[i]:
			return "col:" + state.columns[i]
	if state.columns.size() > t.columns.size():
		return "col:" + state.columns.back()
	if q.p1 != t.p1:
		return "p1"
	if t.p2 != "없음" and q.link != t.link:
		return "link"
	if q.p2 != t.p2:
		return "p2"
	if q.order != t.order:
		return "order"
	if q.limit != t.limit:
		return "limit"
	return "run"

func next_group_key(p: Dictionary) -> String:
	var t = target_group(p)
	var q = user_group()
	for c in t.select:
		if not state.select.has(c):
			return "sel:" + c
	for c in state.select:
		if not t.select.has(c):
			return "sel:" + c
	if q.where != t.where:
		return "where"
	if q.group != t.group:
		return "by"
	if q.having != t.having:
		return "having"
	return "run"

func next_join_key(p: Dictionary) -> String:
	if state.key != 0:
		return "key"
	if type_name() != p.type:
		return "type"
	if state.predict != eval_join(p.right, 0, p.type).rows.size():
		return "predict"
	return "run"

func next_sub_key(p: Dictionary) -> String:
	if inner_id(p) != p.answer:
		return "inner"
	if state.token == null:
		return "inner_run"
	if op_name() != p.op:
		return "op"
	if state.predict < 0:
		return "predict"
	return "run"

## [지금 할 일, 값을 알려 주는 덧붙임]
func step_text() -> String:
	var stages: Array = stage_order()
	var stage: String = stages[mini(state.stage + 1, stages.size() - 1)]
	match stage:
		"col": return "① 열 렌즈: 의뢰에 필요한 열만 차례로 꽂으세요"
		"sel": return "① 보고서에 넣을 항목을 고르세요"
		"gate": return "② 게이트: 어떤 행을 통과시킬지 정하세요 (필요 없으면 건너뛰기)"
		"order": return "③ 줄 세우기와 개수 제한이 필요한지 정하세요"
		"where": return "② 모으기 전에 거를 행이 있나요?"
		"by": return "③ 무엇을 기준으로 바구니에 모을까요?"
		"having": return "④ 모은 뒤에 거를 바구니가 있나요?"
		"key": return "① 두 표에서 같은 값을 가진 열을 소켓에 이으세요"
		"type": return "② 짝이 없는 직원의 처리 방식을 정하세요"
		"inner": return "① 조건을 만들기 위해 먼저 알아야 할 값을 고르세요"
		"inner_run": return "② 안쪽 장치를 실행해 값 토큰을 만드세요"
		"op": return "③ 토큰과 어떻게 비교할지 정하세요"
		"predict": return "표를 보고 결과가 몇 행일지 예측하세요"
	return "준비됐으면 실행 장치에서 E를 누르세요"

func target_shape() -> String:
	var p: Dictionary = problems()[problem]
	match activity:
		"query": return "의뢰에 맞는 행만 담긴 %s 명단" % ", ".join(target_query(p).columns)
		"group": return "%s 값이 담긴 실적판" % ", ".join(target_group(p).select)
		"join": return "직원 이름과 연결된 값이 나란한 명단"
	return "조건을 통과한 학생의 name, score 명단"

func predict_station() -> Array:
	var shown: String = "?" if state.predict < 0 else "%d행" % state.predict
	return ["predict", "결과 행 수 예측: %s (E 바꾸기)" % shown, "예측 " + shown]

func draw_mission() -> void:
	var r = Rect2(60, 612, 1160, 104)
	_cv.draw_rect(r, INK)
	_cv.draw_rect(r.grow(-3), Color("fff6dc"))
	var labels = ["의뢰", "지금", "목표"]
	var lines = [goal, step_text(), target_shape()]
	var colors = [RED, BLUE, TEAL]
	if state.phase == "anim":
		var cap: String = state.timeline[_anim_step].cap if _anim_step < state.timeline.size() else ""
		labels = ["실행", "관찰", ""]
		lines = [cap, "데이터가 처리되는 모습을 보세요 (E: 건너뛰기)", ""]
	elif state.phase == "review":
		var ok: bool = state.review_ok
		labels = ["성공" if ok else "다시", "근거", "해설"]
		colors = [TEAL if ok else RED, BLUE, TEAL]
		lines = ["예측 %d행 → 실제 %d행 · %s" % [state.predict, state.result.size() if state.result != null else 0, "E: 다음으로" if ok else "E: 고치러 가기"], state.review_text, review_reason()]
	for i in 3:
		if lines[i] != "":
			text(Vector2(82, 643 + i * 32), labels[i], 23, colors[i])
			text(Vector2(160, 643 + i * 32), lines[i], fit_size(lines[i], 1040, 23), INK)

## 어느 행·그룹·연결이 왜 남았는지와 행동이 어떤 SQL 인지 짝지어 보여 준다.
func review_reason() -> String:
	match activity:
		"query":
			var out = query_dim().map(func(i): return STUDENTS[i][1])
			return "게이트=WHERE · 렌즈=SELECT · 계단=ORDER BY/LIMIT · 걸러진 행: " + (", ".join(out) if not out.is_empty() else "없음")
		"group":
			return "1차 게이트=WHERE, 바구니=GROUP BY, 2차 게이트=HAVING · 원본 %d행 → WHERE %d행 → %d그룹 → 남은 %d그룹" % state.stages
		"join":
			var lone = state.pairs.filter(func(x): return x[1] < 0).size()
			return "소켓=ON, 처리 방식=INNER/LEFT · 연결 %d쌍, 짝 없는 직원 %d명" % [state.pairs.size() - lone, lone]
	var vals = state.token.values.map(func(v): return display(v)) if state.token != null else []
	return "안쪽 장치=서브쿼리, 토큰 %s, 바깥 게이트=WHERE" % ", ".join(vals)

func conclude(ok: bool, note_text: String) -> void:
	if fast_flow:
		if ok:
			finish_problem(note_text)
		else:
			wrong(note_text)
		return
	if not ok:
		wrong(note_text)
	state.review_ok = ok
	state.review_text = note_text
	state.timeline = build_timeline()
	_anim_step = 0
	_anim_p = 0.0
	state.phase = "anim"
	if state.timeline.is_empty():
		enter_review()

func enter_review() -> void:
	state.phase = "review"
	rebuild()
	refresh()

func skip_anim() -> void:
	if state.phase == "anim":
		enter_review()

func confirm_review() -> void:
	if state.phase != "review":
		return
	if state.review_ok:
		finish_problem(state.review_text)
	else:
		state.phase = "setup"
	rebuild()
	refresh()

func input_locked() -> bool:
	return state.get("phase", "setup") != "setup"

func _process(delta: float) -> void:
	if state.get("phase", "") != "anim":
		return
	_anim_p += delta / ANIM_STEP
	if _anim_p >= 1.0:
		_anim_p = 0.0
		_anim_step += 1
		if _anim_step >= state.timeline.size():
			enter_review()
	board.queue_redraw()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and input_locked() and not hud.dialogue_open() and ev.keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		if state.phase == "anim":
			skip_anim()
		else:
			confirm_review()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(ev)

func names_diff(mine: Array, want: Array, ordered := false) -> String:
	var parts = []
	var lost = want.filter(func(n): return not mine.has(n))
	var extra = mine.filter(func(n): return not want.has(n))
	if not lost.is_empty():
		parts.append("빠진 행: " + ", ".join(lost))
	if not extra.is_empty():
		parts.append("남으면 안 되는 행: " + ", ".join(extra))
	if parts.is_empty():
		return "행 순서가 의뢰와 달라요. 정렬 방향을 확인해 보세요." if ordered else "값이 의뢰와 달라요. 설정을 다시 살펴보세요."
	return " · ".join(parts)

func first_cells(rows: Array) -> Array:
	return rows.map(func(r): return display(r[0]))

func pass_fill() -> Color:
	return Color("bfe3b4")

func fail_fill() -> Color:
	return Color("ffb3a8")

func mv(a: Vector2, b: Vector2, t: String, c: Color) -> Dictionary:
	return {"a": a, "b": b, "t": t, "c": c}

func build_timeline() -> Array:
	match activity:
		"query": return query_timeline()
		"group": return group_timeline()
		"join": return join_timeline()
	return sub_timeline()

func query_timeline() -> Array:
	var q = user_query()
	var dim: Array = query_dim()
	var out = []
	var moves_a = []
	for i in STUDENTS.size():
		var from = Vector2(855, 36 + (i + 1.5) * 26)
		var pass_row: bool = not dim.has(i)
		moves_a.append(mv(from, Vector2(632, 400) if pass_row else Vector2(632, 520), str(STUDENTS[i][1]), pass_fill() if pass_row else fail_fill()))
	out.append({"cap": "게이트가 조건에 맞는 행만 통과시켜요", "moves": moves_a})
	var finals: Array = state.result
	if q.order != "" or q.limit >= 0:
		var moves_b = []
		for i in finals.size():
			moves_b.append(mv(Vector2(632, 400), Vector2(818, 340 + i * 26), display(finals[i][0]), pass_fill()))
		out.append({"cap": "계단에서 줄을 세우고 개수를 잘라요", "moves": moves_b})
	var moves_c = []
	for i in finals.size():
		var label = " ".join(finals[i].map(func(v): return display(v)))
		moves_c.append(mv(Vector2(740, 400), Vector2(1047, 340 + i * 25), label, CREAM))
	out.append({"cap": "렌즈에 꽂은 열만 결과판에 복사돼요", "moves": moves_c})
	return out

func group_timeline() -> Array:
	var q = user_group()
	var dim: Array = group_dim()
	var out = []
	var moves_a = []
	var kept = []
	for i in SALES.size():
		var pass_row: bool = not dim.has(i)
		if pass_row:
			kept.append(SALES[i])
		moves_a.append(mv(Vector2(835, 36 + (i + 1.5) * 23), Vector2(428, 250) if pass_row else Vector2(428, 545), "%s %s" % [SALES[i][1], display(SALES[i][3])], pass_fill() if pass_row else fail_fill()))
	out.append({"cap": "모으기 전에 WHERE가 행을 걸러요", "moves": moves_a})
	var groups = {}
	var idx: int = SALES_COLS.find(q.group)
	for r in kept:
		var name = r[idx] if idx >= 0 else "전체"
		if not groups.has(name):
			groups[name] = []
		groups[name].append(r)
	var names: Array = groups.keys()
	names.sort()
	var moves_b = []
	var moves_c = []
	var moves_d = []
	var agg: String = "COUNT(*)"
	for item in q.select:
		if item.ends_with(")"):
			agg = item
	for g in names.size():
		var basket = Vector2(628, 300 + g * 48)
		for r in groups[names[g]]:
			moves_b.append(mv(Vector2(428, 250), basket, display(r[3]), pass_fill()))
		var ok: bool = having_pass(q.having, groups[names[g]])
		var label = "%s %s" % [names[g], display(aggregate(agg, groups[names[g]]))]
		moves_c.append(mv(basket, Vector2(806, 370) if ok else Vector2(806, 545), label, pass_fill() if ok else fail_fill()))
		if ok:
			moves_d.append(mv(Vector2(806, 370), Vector2(1060, 340 + moves_d.size() * 28), label, CREAM))
	out.append({"cap": "같은 기준끼리 바구니에 모여요", "moves": moves_b})
	out.append({"cap": "바구니마다 계산한 뒤 HAVING이 그룹을 걸러요", "moves": moves_c})
	if not moves_d.is_empty():
		out.append({"cap": "남은 그룹이 실적판에 올라가요", "moves": moves_d})
	return out

func join_timeline() -> Array:
	var moves_a = []
	for pair in state.pairs:
		var ly: float = JOIN_LEFT_Y[pair[0]]
		if pair[1] >= 0 and pair[1] < JOIN_RIGHT_Y.size():
			moves_a.append(mv(Vector2(332, ly), Vector2(630, JOIN_RIGHT_Y[pair[1]]), display(EMPLOYEES[pair[0]][2]), pass_fill()))
		else:
			moves_a.append(mv(Vector2(332, ly), Vector2(480, ly), "짝 없음", fail_fill()))
	var cap_a = "키 소켓이 같은 값끼리 이어 줘요"
	var moves_b = []
	var rows: Array = state.result
	for i in rows.size():
		moves_b.append(mv(Vector2(480, 340), Vector2(1055, 340 + i * 36), "%s · %s" % [rows[i][0], display(rows[i][1])], CREAM))
	return [{"cap": cap_a, "moves": moves_a}, {"cap": "만들어진 명찰이 결과판으로 이동해요", "moves": moves_b}]

func sub_timeline() -> Array:
	var p: Dictionary = problems()[problem]
	var moves_a = []
	var id = inner_id(p)
	if id.begins_with("CITY"):
		for i in TEAMS.size():
			var hit: bool = TEAMS[i][1] == id.trim_prefix("CITY:")
			moves_a.append(mv(Vector2(1030, 36 + (i + 1.5) * 28), Vector2(385, 380) if hit else Vector2(1030, 200), TEAMS[i][0], pass_fill() if hit else fail_fill()))
	else:
		for i in SCORES.size():
			moves_a.append(mv(Vector2(740, 36 + (i + 1.5) * 28), Vector2(385, 380), display(SCORES[i][2]), pass_fill()))
	var vals: Array = state.token.values.map(func(v): return display(v))
	var token_text = ", ".join(vals) if not vals.is_empty() else "빈 집합"
	var keep: Array = first_cells(state.result)
	var moves_c = []
	for i in SCORES.size():
		var hit: bool = keep.has(str(SCORES[i][0]))
		moves_c.append(mv(Vector2(740, 36 + (i + 1.5) * 28), Vector2(1070, 410) if hit else Vector2(835, 545), "%s %s" % [SCORES[i][0], display(SCORES[i][2])], pass_fill() if hit else fail_fill()))
	return [{"cap": "안쪽 장치가 값을 계산해요", "moves": moves_a},
		{"cap": "결과 토큰이 바깥 게이트로 전달돼요", "moves": [mv(Vector2(505, 345), Vector2(835, 400), token_text, Color("9fd3ff"))]},
		{"cap": "바깥 게이트가 토큰과 비교해 행을 통과시켜요", "moves": moves_c}]

func draw_anim() -> void:
	if state.phase != "anim" or _anim_step >= state.timeline.size():
		return
	var moves_now: Array = state.timeline[_anim_step].moves
	for i in moves_now.size():
		var m: Dictionary = moves_now[i]
		var f: float = clampf(_anim_p * 1.5 - i * 0.05, 0.0, 1.0)
		plate(m.a.lerp(m.b, smoothstep(0.0, 1.0, f)), m.t, 18, m.c)

func step_sign(c: Vector2, t: String) -> void:
	plate(c, t, 18, GOLD)

func query_dim() -> Array:
	var q = user_query()
	var out := []
	for i in STUDENTS.size():
		var a = pred_match(q.p1, STUDENTS[i])
		var b = pred_match(q.p2, STUDENTS[i])
		var keep := true
		if a != null and b != null:
			keep = (a and b) if q.link == "AND" else (a or b)
		elif a != null:
			keep = a
		elif b != null:
			keep = b
		if not keep:
			out.append(i)
	return out

func group_dim() -> Array:
	var where_text: String = user_group().where
	var out := []
	if where_text == "없음":
		return out
	var limit: int = 10 if where_text == "amount >= 10" else 100
	for i in SALES.size():
		if SALES[i][3] == null or SALES[i][3] < limit:
			out.append(i)
	return out

func result_board(r: Rect2, headers: Array, row_h := 24.0, size := 15) -> void:
	if state.result == null or state.phase == "anim":
		return
	cover(r, Color("eef2f8"))
	if state.result.is_empty():
		text(r.get_center(), "(결과 0행)", 20, INK, true)
	else:
		table_at(r.position, headers, state.result.slice(0, int(r.size.y / row_h) - 1), r.size.x, row_h, size)

func draw_query_board() -> void:
	plate(Vector2(445, 345), "① SELECT", 20)
	plate(Vector2(632, 345), "② WHERE", 20)
	plate(Vector2(818, 345), "③ ORDER·LIMIT", 18)
	plate(Vector2(445, 420), ", ".join(state.columns) if not state.columns.is_empty() else "열 없음", 16)
	var q = user_query()
	plate(Vector2(632, 410), "점수: " + q.p1, 14)
	plate(Vector2(632, 438), q.link + " 부서: " + q.p2, 14)
	plate(Vector2(818, 410), "정렬 없음" if q.order == "" else "score " + q.order, 15)
	plate(Vector2(818, 438), "개수 제한 없음" if q.limit < 0 else "LIMIT %d" % q.limit, 15)
	step_sign(Vector2(456, 530), "① 열 렌즈")
	step_sign(Vector2(768, 530), "② 행 게이트")
	step_sign(Vector2(963, 530), "③ 순서·개수")
	plate(Vector2(1040, 290), "④ 결과", 18)
	wall_table(Vector2(640, 36), "students 원본 (회색 = 조건에서 제외)", STUDENT_COLS, STUDENTS, 430, 26, 19, query_dim())
	result_board(Rect2(956, 304, 182, 150), state.columns, 25, 17)
	if state.error != "":
		cover(Rect2(956, 304, 182, 150), Color("ffe6c8"))
		wrapped(Vector2(964, 332), state.error, 166, 17, RED)

func draw_group_board() -> void:
	plate(Vector2(428, 228), "② WHERE", 18)
	plate(Vector2(428, 345), "③ GROUP BY", 18)
	plate(Vector2(806, 300), "④ HAVING", 18)
	step_sign(Vector2(478, 538), "① 넣을 항목")
	step_sign(Vector2(860, 538), "② ③ ④ 조건과 묶기")
	var q = user_group()
	plate(Vector2(428, 268), q.where, 15)
	plate(Vector2(428, 385), q.group, 16)
	plate(Vector2(806, 400), q.having, 14)
	plate(Vector2(628, 250), "① SELECT", 18)
	wall_table(Vector2(600, 36), "sales 원본 (회색 = WHERE 제외)", SALES_COLS, SALES, 470, 23, 17, group_dim())
	var short_heads: Array = state.select.map(func(c): return GROUP_CHIP[c])
	result_board(Rect2(944, 296, 240, 160), short_heads, 26, 16)
	if state.error != "":
		cover(Rect2(944, 296, 240, 160), Color("ffe6c8"))
		wrapped(Vector2(954, 324), state.error, 220, 17, RED)
	if not state.stages.is_empty():
		plate(Vector2(1062, 470), "원본 %d → WHERE %d → %d그룹 → %d" % state.stages, 15)

func draw_join_board() -> void:
	var p: Dictionary = problems()[problem]
	cover(Rect2(380, 318, 208, 232), Color("c9a78e"))
	cover(Rect2(912, 292, 276, 262), Color("eef2f8"))
	plate(Vector2(484, 340), "키 소켓", 18)
	plate(Vector2(255, 298), "employees: name · dept_id", 16)
	plate(Vector2(715, 318), "오른쪽 표: id · name", 16)
	for i in EMPLOYEES.size():
		var e: Array = EMPLOYEES[i]
		box_cell(Rect2(170, JOIN_LEFT_Y[i] - 20, 90, 40), e[1], CREAM, INK, 20)
		box_cell(Rect2(260, JOIN_LEFT_Y[i] - 20, 72, 40), display(e[2]), NULL_FILL if e[2] == null else CREAM, INK, 20)
	for i in JOIN_RIGHT_Y.size():
		if i < p.right.size():
			box_cell(Rect2(630, JOIN_RIGHT_Y[i] - 20, 72, 40), str(p.right[i][0]), CREAM, INK, 20)
			box_cell(Rect2(702, JOIN_RIGHT_Y[i] - 20, 96, 40), str(p.right[i][1]), CREAM, INK, 20)
		else:
			box_cell(Rect2(630, JOIN_RIGHT_Y[i] - 20, 168, 40), "(비어 있음)", NULL_FILL, INK, 18)
	plate(Vector2(540, 165), key_name() + " · " + type_name(), 18, GOLD)
	if state.result != null and state.phase != "anim":
		for pair in state.pairs:
			if pair[1] >= 0 and pair[1] < JOIN_RIGHT_Y.size():
				ink_line(Vector2(332, JOIN_LEFT_Y[pair[0]]), Vector2(630, JOIN_RIGHT_Y[pair[1]]), Color("5fd6ff"), 3.0)
		result_board(Rect2(930, 300, 250, 225), ["e.name", "d.name"], 36, 18)

func draw_sub_board() -> void:
	var p: Dictionary = problems()[problem]
	wall_table(Vector2(590, 36), "scores", ["name", "dept", "score"], SCORES, 300, 28, 19)
	wall_table(Vector2(926, 36), "teams", ["team", "city"], TEAMS, 210, 28, 19)
	plate(Vector2(342, 233), "① 안쪽 질의", 20)
	plate(Vector2(385, 380), inner_short(inner_id(p)), 18, GOLD)
	if state.token != null:
		var vals: Array = state.token.values.map(func(v): return display(v))
		plate(Vector2(505, 345), ", ".join(vals) if not vals.is_empty() else "빈 집합", 18, Color("9fd3ff"))
	plate(Vector2(835, 230), "② %s %s (안쪽)" % [p.col, op_name()], 20, GOLD)
	result_board(Rect2(996, 346, 146, 130), ["name", "score"], 26, 16)
	if state.error != "":
		plate(Vector2(640, 575), state.error, 18, Color("ffd7a8"))

func inner_short(id: String) -> String:
	match id:
		"": return "미설정"
		"AVG": return "AVG(score)"
		"MAX": return "MAX(score)"
		"ALL": return "모든 score"
	return "팀 (%s)" % id.trim_prefix("CITY:")


