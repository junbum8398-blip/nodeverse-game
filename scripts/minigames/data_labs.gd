extends "res://scripts/minigames/learning_lab.gd"
## 데이터 탐색 실습: 데이터 점검(DATA02) · 데이터 정제(DATA01) · 통계 비교(DATA03) · 시각화 해석(DATA04).
## 원본 표는 절대 바꾸지 않고, 정답은 원본에서 다시 계산한다.

# ---------- 점검 데이터 ----------
const PROFILE_COLS := ["id", "age", "zip", "joined", "visits"]
const PROFILE_ROWS := [[1, 20, "06236", "2026-01-03", 0], [2, null, "01012", "2026-01-04", 12], [3, 30, "48058", "2026/02/11", 8], [4, 40, "61452", "2026-02-20", 5], [5, null, "34126", "2026-03-02", 3]]
const DICTIONARY := "데이터 사전: 1행 = 학생 1명 · age 나이(세) · zip 우편번호 · joined 가입일 · visits 방문 수(회) · 비어 있음(NULL)만 결측"
const TYPE_OPTS := ["숫자", "문자", "날짜"]
const UNIT_OPTS := ["세", "회", "원"]
const ROW_UNIT_OPTS := ["학생 1명", "방문 1회", "학교 1곳"]
const PROFILE_LEVELS := [
	[[{"key": "rows", "label": "행 개수", "kind": "number"}, {"key": "cols", "label": "열 개수", "kind": "number"}, {"key": "unit", "label": "1행의 관측 단위", "kind": "choice", "options": ROW_UNIT_OPTS}]],
	[[{"key": "age_type", "label": "age 자료형", "kind": "choice", "options": TYPE_OPTS}, {"key": "zip_type", "label": "zip 자료형", "kind": "choice", "options": TYPE_OPTS},
	  {"key": "joined_type", "label": "joined 자료형", "kind": "choice", "options": TYPE_OPTS}, {"key": "age_unit", "label": "age 단위", "kind": "choice", "options": UNIT_OPTS}, {"key": "visits_unit", "label": "visits 단위", "kind": "choice", "options": UNIT_OPTS}]],
	[[{"key": "age_missing", "label": "age 결측 개수", "kind": "number"}, {"key": "age_rate", "label": "age 결측률 %", "kind": "number"},
	  {"key": "visits_missing", "label": "visits 결측 개수", "kind": "number"}, {"key": "odd_col", "label": "형식이 섞인 열", "kind": "choice", "options": PROFILE_COLS}]],
]

# ---------- 정제 데이터 ----------
const CLEAN_COLS := ["id", "group", "value", "date"]
const CLEAN_LEVELS := [
	[{"goal": "value가 비어 있는 행만 제거하기", "rows": [[1, "A", "10", "2026-01-01"], [2, "B", null, "2026-01-02"], [3, "A", "30", "2026-01-03"], [4, "C", null, "2026-01-04"], [5, "B", "0", "2026-01-05"]], "pipeline": ["missing"]}],
	[{"goal": "group+value가 같은 중복을 지우고 결측 제거", "rows": [[1, "A", "10", "2026-01-01"], [2, "A", "10", "2026-01-02"], [3, "B", "20", "2026-01-02"], [4, "B", "25", "2026-01-03"], [5, "A", "10", "2026-01-05"], [6, "C", null, "2026-01-06"]], "pipeline": ["dedup:group+value", "missing"]}],
	[{"goal": "형식을 맞춘 뒤 중복을 지워 3행 만들기", "rows": [[1, " A ", "1,000", "2026/01/05"], [2, "A", "1000", "2026-01-05"], [3, "B", "abc", "2026-02-01"], [4, "B", "200", "2026-13-40"], [5, "C", "300", "2026-03-01"], [6, " C", "300", "2026-03-01"], [7, "D", "50", "2026-03-02"]], "pipeline": ["trim", "number", "date", "dedup:all"]}],
]
const DEDUP_KEYS := ["group", "group+value", "all"]
const DEDUP_NAMES := {"group": "group", "group+value": "group+value", "all": "id 제외 전체"}

# ---------- 통계 ----------
const STAT_LEVELS := [
	[{"title": "점수 집단", "values": [4, 8, 6, 2], "fields": ["count", "mean", "range"]}],
	[{"title": "홀수 개", "values": [3, 9, 5], "fields": ["median"]}, {"title": "짝수 개", "values": [10, 12, 14, 100], "fields": ["median"]},
	 {"title": "NULL 포함", "values": [3, null, 9], "fields": ["count", "mean"]}],
	[{"title": "이상치 비교", "values": [10, 12, 14, 100], "outlier": 100, "fields": ["mean", "median", "range", "mean_ex", "median_ex", "range_ex"],
	  "claims": ["100 하나 때문에 평균은 크게 달라지지만 중앙값은 적게 달라진다", "100을 삭제해야 올바른 데이터가 된다", "평균이 높으니 이 집단의 실력이 원인이다"], "answer": 0},
	 {"title": "같은 평균 다른 분포", "values": [10, 10], "second": [0, 20], "fields": ["range", "range2"],
	  "claims": ["평균은 같지만 두 번째 집단의 값이 더 넓게 퍼져 있다", "평균이 같으니 두 집단은 같은 분포다", "두 번째 집단이 공부를 덜 해서 범위가 크다"], "answer": 0},
	 {"title": "한 값과 빈 집단", "values": [], "fields": [], "claims": ["값이 없으므로 평균을 계산할 수 없다", "빈 집단의 평균은 0이다"], "answer": 0}],
]
const STAT_LABELS := {"count": "개수", "mean": "평균", "median": "중앙값", "range": "범위", "mean_ex": "제외 후 평균", "median_ex": "제외 후 중앙값", "range_ex": "제외 후 범위", "range2": "둘째 집단 범위"}

# ---------- 차트 ----------
const CHART_TYPES := ["막대", "선", "산점도"]
const AGGS := ["없음", "합계", "평균", "개수"]
const CHART_LEVELS := [
	[{"question": "제품별 총판매량 중 가장 많이 팔린 제품은?", "cols": ["제품", "판매량"], "units": ["", "개"],
	  "rows": [["연필", 30], ["공책", 50], ["연필", 20], ["지우개", 10], ["공책", 5]],
	  "type": "막대", "x": 0, "y": 1, "agg": "합계", "evidence": "best",
	  "claims": ["공책의 총판매량이 55개로 가장 많다", "연필이 가장 많이 팔렸다", "공책이 싸서 많이 팔렸다"], "answer": 0}],
	[{"question": "월별 판매량 변화에서 가장 높은 달은?", "cols": ["월", "판매량"], "units": ["", "개"],
	  "rows": [["2026-03", 12], ["2026-01", 10], ["2026-02", 15]],
	  "type": "선", "x": 0, "y": 1, "agg": "없음", "evidence": "best", "needs_sort": true,
	  "claims": ["2월 판매량이 15개로 가장 높다", "3월이 첫 달이라 가장 중요하다", "2월에 광고를 해서 늘었다"], "answer": 0}],
	[{"question": "키와 몸무게의 관계를 살펴보자", "cols": ["키", "몸무게"], "units": ["cm", "kg"],
	  "rows": [[150, 45], [160, 52], [170, 61], [null, 70], [180, 72], [175, null]],
	  "type": "산점도", "x": 0, "y": 1, "agg": "없음", "evidence": "any", "swap_ok": true,
	  "claims": ["키가 클수록 몸무게도 큰 경향이 보이지만 원인이라 단정할 수 없다", "키가 몸무게를 늘리는 원인이다", "두 값은 아무 관련이 없다"], "answer": 0}],
]

func lab_table() -> Dictionary:
	return {
		"profile": {"id": "DATA02", "title": "관측 준비실", "levels": 3, "art": "DATA02", "npc": "NPC00", "npc_name": "데이터 관측 담당자",
			"intro": ["어서 오세요. 데이터를 고치기 전에 먼저 살펴봐야 해요. 행이 뭘 뜻하는지, 열은 어떤 값인지부터요.",
				"숫자처럼 보여도 우편번호는 계산하지 않는 문자예요. 0은 값이 있는 것이고, 비어 있어야 결측이에요.",
				"데이터 사전과 표를 보고 점검표를 채워 제출하세요. 원본은 바꾸지 않아요."],
			"talk": ["몇 행 몇 열인지, 1행이 무엇을 뜻하는지 적어 주세요.", "각 열의 자료형과 단위를 데이터 사전과 비교해 주세요.", "결측 개수와 결측률을 계산하고, 형식이 섞인 열을 찾아 주세요."],
			"hints": ["행은 관측 하나, 열은 관측의 속성이에요.", "결측률 = 결측 개수 / 전체 행 × 100. 0은 결측이 아니에요.", "age가 [20, NULL, 30, 40, NULL]이면 결측 2개, 결측률 40%예요."]},
		"clean": {"id": "DATA01", "title": "기록 수리 공방", "levels": 3, "art": "DATA01", "npc": "NPC08", "npc_name": "기록 수리 담당자",
			"intro": ["시간 없어요, 얼른 고쳐 봐요! 결측과 중복, 형식이 제멋대로인 기록을 규칙대로 정리하는 곳이에요.",
				"처리 버튼을 누르면 순서대로 적용되어 미리보기가 바뀌어요. 중복은 첫 등장 행을 남기고, 0과 NULL은 달라요.",
				"처리 순서에 따라 결과가 달라질 수 있어요. 잘못 적용했으면 Z로 취소하면 원본 상태로 돌아가요."],
			"talk": ["value가 빈 행만 지워 주세요. 0은 남겨야 해요.", "중복 기준을 group+value로 정하고 지운 다음 결측을 지워 주세요.", "공백과 숫자·날짜 형식을 먼저 맞춘 뒤 중복을 지워 주세요. 순서가 중요해요."],
			"hints": ["정제는 기준을 먼저 정하고 그 기준대로 적용해요.", "형식이 다르면 같은 값도 중복으로 잡히지 않아요. 표준화부터 하세요.", "(1,A,10),(2,A,10),(3,B,NULL)은 group+value 중복을 지우고 결측을 지우면 1행이 남아요."]},
		"stats": {"id": "DATA03", "title": "대표값 실험실", "levels": 3, "art": "DATA03", "npc": "NPC03", "npc_name": "통계 실험가",
			"intro": ["호호, 왔구나. 숫자 묶음을 값 하나로 요약하는 법을 실험해 보자꾸나.",
				"평균은 합을 개수로 나눈 값, 중앙값은 정렬했을 때 가운데 값, 범위는 최댓값 빼기 최솟값이란다. 값이 짝수 개면 가운데 두 값의 평균이 중앙값이야.",
				"칸 앞에서 E를 누르고 숫자 키로 값을 넣어 제출해. NULL은 계산에서 빼고, 이상치는 비교할 때만 제외한단다."],
			"talk": ["개수, 평균, 범위를 계산해 보렴.", "홀수 개와 짝수 개의 중앙값이 어떻게 다른지, NULL은 어떻게 빠지는지 보렴.", "이상치를 뺐을 때 대표값이 어떻게 변하는지 비교하고, 데이터로 말할 수 있는 결론만 고르렴."],
			"hints": ["평균·중앙값·범위는 각각 다른 면을 요약해요.", "먼저 정렬하고, NULL은 분모에서 뺀 뒤 계산하세요.", "[10,12,14,100]은 평균 34, 중앙값 13, 범위 90. 100을 빼면 평균·중앙값 12, 범위 4예요."]},
		"chart": {"id": "DATA04", "title": "차트 관측소", "levels": 3, "art": "DATA04", "npc": "NPC07", "npc_name": "차트 관측 담당자",
			"intro": ["좋아, 왔군. 차트는 예쁘게 그리는 게 아니라 질문에 답하려고 그리는 거다.",
				"범주별 비교는 막대, 시간 변화는 선, 두 수치의 관계는 산점도. 축과 집계를 고르면 진짜 데이터로 그려 주지.",
				"다 그렸으면 근거 지점에서 E로 표시를 옮기고 결론을 골라. 차트가 보여 주지 않는 원인을 단정하면 틀린다."],
			"talk": ["제품별 총판매량을 비교해. 같은 제품은 합쳐야 한다. 막대는 0부터 시작해야 공정하지.", "월별 흐름이다. 날짜를 시간순으로 정렬하는 걸 잊지 마라.", "키와 몸무게의 관계다. 값이 빠진 행은 점을 찍을 수 없어. 상관과 인과를 구분해라."],
			"hints": ["질문이 무엇을 비교하는지 먼저 정하세요.", "범주 비교는 막대, 시간은 선, 두 수치는 산점도. 같은 범주가 여러 행이면 집계해요.", "월별 판매량 [10,15,12]는 시간순 선그래프로 2월 최고를 읽어요."]},
	}

func problems_for(n: int) -> Array:
	match activity:
		"profile": return PROFILE_LEVELS[n]
		"clean": return CLEAN_LEVELS[n]
		"stats": return STAT_LEVELS[n]
	return CHART_LEVELS[n]

func setup_problem(p) -> void:
	match activity:
		"profile":
			goal = "점검표를 데이터 사전과 원본으로 채우기"
			var fields = {}
			var picks = {}
			for q in p:
				if q.kind == "number":
					fields[q.key] = ""
				else:
					picks[q.key] = -1
			state = {"fields": fields, "picks": picks}
		"clean":
			goal = p.goal
			state = {"pipeline": [], "dedup": 1}
		"stats":
			goal = "%s: 값을 계산해 제출하기" % p.title
			var fields = {}
			for f in p.fields:
				fields[f] = ""
			state = {"fields": fields, "claim": -1, "show_ex": false}
		"chart":
			goal = p.question
			state = {"type": 0, "x": 1, "y": 0, "agg": 0, "sort": false, "zero": false, "drawn": false, "evidence": -1, "claim": -1}

func setup_level(n: int) -> void:
	super.setup_level(n)

func handle(key: String) -> void:
	match activity:
		"profile": profile_action(key)
		"clean": clean_action(key)
		"stats": stats_action(key)
		"chart": chart_action(key)

func lab_rows() -> Array:
	return [["행동", moves], ["실수", mistakes], ["힌트", hints_used]]

func state_code() -> String:
	match activity:
		"clean":
			return "df" + "".join(state.pipeline.map(func(s): return ".%s()" % s))
		"chart":
			return "chart(type=%s, x=%s, y=%s, agg=%s)" % [CHART_TYPES[state.type], problems()[problem].cols[state.x], problems()[problem].cols[state.y], AGGS[state.agg]]
	return ""

# ---------- 데이터 점검 ----------
func profile_answer(key: String):
	match key:
		"rows": return PROFILE_ROWS.size()
		"cols": return PROFILE_COLS.size()
		"unit": return 0
		"age_type": return 0
		"zip_type": return 1
		"joined_type": return 2
		"age_unit": return 0
		"visits_unit": return 1
		"age_missing": return missing_count(1)
		"age_rate": return 100.0 * missing_count(1) / PROFILE_ROWS.size()
		"visits_missing": return missing_count(4)
		"odd_col": return odd_format_column()
	return null

func missing_count(col: int) -> int:
	var n = 0
	for r in PROFILE_ROWS:
		if r[col] == null:
			n += 1
	return n

func odd_format_column() -> int:
	for r in PROFILE_ROWS:
		if str(r[3]).contains("/"):
			return 3
	return -1

func profile_action(key: String) -> void:
	if key.begins_with("pick:"):
		var k = key.trim_prefix("pick:")
		var q = find_question(k)
		step()
		state.picks[k] = (state.picks[k] + 1) % q.options.size()
		return
	if key != "submit":
		return
	moves += 1
	for q in problems()[problem]:
		if q.kind == "number":
			var v = field_number(q.key)
			if is_nan(v) or absf(v - float(profile_answer(q.key))) > 0.1:
				wrong("'%s' 값을 다시 계산해 보세요." % q.label)
				return
		elif state.picks[q.key] != profile_answer(q.key):
			wrong("'%s' 선택을 데이터 사전과 비교해 보세요." % q.label)
			return
	code("df.info();", "점검 완료")
	win("점검표가 데이터와 일치해요. 원본은 그대로예요.")

func find_question(k: String) -> Dictionary:
	for q in problems()[problem]:
		if q.key == k:
			return q
	return {}

# ---------- 데이터 정제 ----------
## 원본을 복사해 파이프라인을 차례로 적용한다. 반환: {"rows": 남은 행, "dropped": [[id, 사유]...]}
func run_pipeline(rows: Array, pipeline: Array) -> Dictionary:
	var cur: Array = rows.duplicate(true)
	var dropped = []
	for s in pipeline:
		if s == "missing":
			var kept = []
			for r in cur:
				if r[2] == null:
					dropped.append([r[0], "결측"])
				else:
					kept.append(r)
			cur = kept
		elif s == "trim":
			for r in cur:
				r[1] = str(r[1]).strip_edges()
		elif s == "number":
			var kept = []
			for r in cur:
				if r[2] == null:
					kept.append(r)
					continue
				var t = str(r[2]).replace(",", "")
				if t.is_valid_float():
					r[2] = t
					kept.append(r)
				else:
					dropped.append([r[0], "숫자 형식 오류"])
			cur = kept
		elif s == "date":
			var kept = []
			for r in cur:
				var t = str(r[3]).replace("/", "-")
				if valid_date(t):
					r[3] = t
					kept.append(r)
				else:
					dropped.append([r[0], "무효 날짜"])
			cur = kept
		elif s.begins_with("dedup:"):
			var mode: String = s.trim_prefix("dedup:")
			var seen = {}
			var kept = []
			for r in cur:
				var k = str(r[1]) if mode == "group" else (str(r[1]) + "|" + str(r[2]) if mode == "group+value" else str(r[1]) + "|" + str(r[2]) + "|" + str(r[3]))
				if seen.has(k):
					dropped.append([r[0], "중복"])
				else:
					seen[k] = true
					kept.append(r)
			cur = kept
	return {"rows": cur, "dropped": dropped}

func valid_date(t: String) -> bool:
	var parts = t.split("-")
	if parts.size() != 3 or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return false
	return int(parts[1]) >= 1 and int(parts[1]) <= 12 and int(parts[2]) >= 1 and int(parts[2]) <= 31

func clean_action(key: String) -> void:
	var p: Dictionary = problems()[problem]
	match key:
		"dedup_key":
			step()
			state.dedup = (state.dedup + 1) % DEDUP_KEYS.size()
		"missing", "trim", "number", "date":
			clean_add(key)
		"dedup":
			clean_add("dedup:" + DEDUP_KEYS[state.dedup])
		"submit":
			clean_submit(p)

func clean_add(s: String) -> void:
	if state.pipeline.has(s):
		wrong("이미 적용한 처리예요. 취소하려면 Z를 누르세요.")
		return
	step()
	state.pipeline.append(s)
	code("df = df.%s();" % s.replace("dedup:", "dedup_"))

func clean_submit(p: Dictionary) -> void:
	moves += 1
	var mine = run_pipeline(p.rows, state.pipeline)
	var want = run_pipeline(p.rows, p.pipeline)
	if str(mine.rows) == str(want.rows):
		var reasons = {}
		for d in mine.dropped:
			reasons[d[1]] = int(reasons.get(d[1], 0)) + 1
		win("정제 완료: %d행 남음 (원본 %d행) · 제외 %s" % [mine.rows.size(), p.rows.size(), str(reasons)])
		return
	if state.pipeline.is_empty():
		wrong("아직 어떤 처리도 하지 않았어요.")
	elif mine.rows.size() > want.rows.size():
		wrong("아직 %d행이 더 남아 있어요. 기준과 처리 순서를 확인하세요." % (mine.rows.size() - want.rows.size()))
	elif mine.rows.size() < want.rows.size():
		wrong("지운 행이 너무 많아요. 중복 기준을 확인하세요.")
	else:
		wrong("행 수는 같지만 값이 달라요. 표준화 처리를 확인하세요.")

# ---------- 통계 ----------
func clean_nums(values: Array) -> Array:
	var out = values.filter(func(v): return v != null)
	out.sort()
	return out

func stat(name: String, values: Array) -> float:
	var v = clean_nums(values)
	match name:
		"count": return v.size()
		"mean":
			var total = 0.0
			for x in v:
				total += x
			return total / v.size()
		"median":
			var n = v.size()
			return float(v[n / 2]) if n % 2 == 1 else (v[n / 2 - 1] + v[n / 2]) / 2.0
		"range":
			return float(v.back()) - float(v[0])
	return NAN

func stat_answer(p: Dictionary, f: String) -> float:
	if f.ends_with("_ex"):
		var kept: Array = p.values.filter(func(v): return v != p.outlier)
		return stat(f.trim_suffix("_ex"), kept)
	if f == "range2":
		return stat("range", p.second)
	return stat(f, p.values)

func stats_action(key: String) -> void:
	var p: Dictionary = problems()[problem]
	if key.begins_with("claim:"):
		step()
		state.claim = int(key.trim_prefix("claim:"))
		return
	if key == "toggle_ex":
		step()
		state.show_ex = not state.show_ex
		return
	if key != "submit":
		return
	moves += 1
	for f in p.fields:
		var v = field_number(f)
		if is_nan(v) or absf(v - stat_answer(p, f)) > 0.01:
			wrong("'%s' 값을 다시 계산해 보세요." % STAT_LABELS[f])
			return
	if p.has("claims"):
		if state.claim < 0:
			wrong("해석을 하나 고르세요.")
			return
		if state.claim != p.answer:
			wrong("데이터만으로 말할 수 있는 해석이 아니에요.")
			return
	code("describe(%s);" % p.title, "값 일치")
	finish_problem("계산과 해석이 데이터와 일치해요.")

# ---------- 시각화 ----------
func chart_data(p: Dictionary) -> Array:
	var rows = []
	for r in p.rows:
		if r[state.x] != null and r[state.y] != null:
			rows.append([r[state.x], r[state.y]])
	match AGGS[state.agg]:
		"합계", "평균", "개수":
			var groups = {}
			for r in rows:
				if not groups.has(r[0]):
					groups[r[0]] = []
				groups[r[0]].append(float(r[1]))
			rows = []
			for k in groups:
				var total = 0.0
				for v in groups[k]:
					total += v
				var val: float = total
				if AGGS[state.agg] == "평균":
					val = total / groups[k].size()
				elif AGGS[state.agg] == "개수":
					val = groups[k].size()
				rows.append([k, val])
	if state.sort:
		rows.sort_custom(func(a, b): return str(a[0]) < str(b[0]))
	return rows

func chart_problem_text(p: Dictionary) -> String:
	if CHART_TYPES[state.type] != p.type:
		return {"막대": "범주별 비교는 막대그래프가 맞아요.", "선": "시간 흐름은 선그래프로 봐요.", "산점도": "두 수치의 관계는 산점도로 봐요."}[p.type]
	var straight: bool = state.x == p.x and state.y == p.y
	var swapped: bool = p.get("swap_ok", false) and state.x == p.y and state.y == p.x
	if not straight and not swapped:
		return "가로축과 세로축이 질문과 맞지 않아요."
	if AGGS[state.agg] != p.agg:
		return "집계 방식을 다시 확인하세요. 같은 범주가 여러 행이면 합쳐야 해요." if p.agg != "없음" else "이 차트는 원본 값을 그대로 써요."
	if p.type == "막대" and not state.zero:
		return "막대그래프의 세로축은 0에서 시작해야 해요."
	if p.get("needs_sort", false) and not state.sort:
		return "날짜를 시간순으로 정렬해야 해요."
	return ""

func chart_action(key: String) -> void:
	var p: Dictionary = problems()[problem]
	if key.begins_with("mark:"):
		if not state.drawn:
			return
		step()
		state.evidence = int(key.trim_prefix("mark:"))
		return
	if key.begins_with("claim:"):
		step()
		state.claim = int(key.trim_prefix("claim:"))
		return
	if key.begins_with("type:"):
		chart_edit()
		state.type = int(key.trim_prefix("type:"))
		return
	match key:
		"ctype":
			chart_edit()
			state.type = (state.type + 1) % CHART_TYPES.size()
		"x":
			chart_edit()
			state.x = (state.x + 1) % p.cols.size()
		"y":
			chart_edit()
			state.y = (state.y + 1) % p.cols.size()
		"agg":
			chart_edit()
			state.agg = (state.agg + 1) % AGGS.size()
		"sort":
			chart_edit()
			state.sort = not state.sort
		"zero":
			chart_edit()
			state.zero = not state.zero
		"draw":
			moves += 1
			var problem_text = chart_problem_text(p)
			if problem_text != "":
				wrong(problem_text)
				return
			step()
			state.drawn = true
			code('chart("%s", x=%s, y=%s);' % [CHART_TYPES[state.type], p.cols[state.x], p.cols[state.y]])
			good("차트를 그렸어요. 근거 지점에서 E로 표시를 옮기세요.")
		"submit":
			chart_submit(p)

func chart_edit() -> void:
	step()
	state.drawn = false
	state.evidence = -1

func chart_submit(p: Dictionary) -> void:
	moves += 1
	if not state.drawn:
		wrong("먼저 차트를 그리세요.")
		return
	if state.evidence < 0:
		wrong("근거 지점에서 E로 표시를 고르세요.")
		return
	if p.evidence == "best":
		var data = chart_data(p)
		var best = 0
		for i in data.size():
			if data[i][1] > data[best][1]:
				best = i
		if state.evidence != best:
			wrong("질문의 답이 되는 값을 근거로 고르세요.")
			return
	if state.claim != p.answer:
		wrong("차트가 보여 주는 내용만으로 결론을 고르세요." if state.claim >= 0 else "결론을 하나 고르세요.")
		return
	win("근거와 결론이 차트와 일치해요.")

# ---------- 시안 위 배치 ----------
func stations() -> Array:
	match activity:
		"profile": return profile_stations()
		"clean": return clean_stations()
		"stats": return stats_stations()
	return chart_stations()

func field_text(key: String) -> String:
	var t: String = state.fields.get(key, "")
	return t if t != "" else "_"

func profile_stations() -> Array:
	var out = []
	for q in problems()[problem]:
		if q.kind == "number":
			out.append(["field:" + q.key, "%s 입력 (숫자 키)" % q.label, "%s: %s" % [q.label, field_text(q.key)]])
		else:
			var i: int = state.picks[q.key]
			var pick_text: String = "선택" if i < 0 else str(q.options[i])
			out.append(["pick:" + q.key, "%s: %s (E 바꾸기)" % [q.label, pick_text], "%s: %s" % [q.label, pick_text]])
	while out.size() < 5:
		out.append(null)
	out.append(["submit", "점검표 제출", "제출"])
	return out

func clean_stations() -> Array:
	return [["view:clean", "원본·미리보기 크게 보기", "표 보기"],
		["missing", "결측 행 제거", ""],
		["dedup", "중복 제거 (%s)" % DEDUP_NAMES[DEDUP_KEYS[state.dedup]], ""],
		["dedup_key", "중복 기준: %s (E 바꾸기)" % DEDUP_NAMES[DEDUP_KEYS[state.dedup]], ""],
		["trim", "공백 정리", "공백"],
		["number", "숫자 형식 통일", "숫자"],
		["date", "날짜 형식 통일", "날짜"],
		["submit", "결과 제출", "제출"]]

func stats_stations() -> Array:
	var p: Dictionary = problems()[problem]
	var out = []
	for f in p.fields:
		out.append(["field:" + f, "%s 입력 (숫자 키)" % STAT_LABELS[f], "%s: %s" % [STAT_LABELS[f], field_text(f)]])
	while out.size() < 6:
		out.append(null)
	out.append(["toggle_ex", "이상치 제외 비교", "제외 비교"] if p.has("outlier") else null)
	if p.has("claims"):
		out.append(["claim:%d" % ((state.claim + 1) % p.claims.size()), "해석 바꾸기", "해석"])
	else:
		out.append(null)
	out.append(["submit", "제출", "제출"])
	return out

func chart_stations() -> Array:
	var p: Dictionary = problems()[problem]
	var n: int = chart_data(p).size()
	var out: Array = []
	for i in 3:
		out.append(["type:%d" % i, "%s 차트 고르기" % CHART_TYPES[i], ""])
	out.append(["x", "가로축: %s (E 바꾸기)" % p.cols[state.x], "가로 " + p.cols[state.x]])
	out.append(["y", "세로축: %s (E 바꾸기)" % p.cols[state.y], "세로 " + p.cols[state.y]])
	out.append(["agg", "집계: %s (E 바꾸기)" % AGGS[state.agg], AGGS[state.agg]])
	out.append(["sort", "날짜순 정렬 %s" % ("끄기" if state.sort else "켜기"), "정렬 " + ("ON" if state.sort else "OFF")])
	out.append(["zero", "세로축 0부터 %s" % ("끄기" if state.zero else "켜기"), "0축 " + ("ON" if state.zero else "OFF")])
	out.append(["draw", "차트 그리기", "그리기"])
	out.append(["mark:%d" % ((state.evidence + 1) % maxi(n, 1)), "근거 표시 옮기기", "근거"] if state.drawn else null)
	out.append(["view:data", "데이터와 결론 크게 보기", "표 보기"])
	out.append(["claim:%d" % ((state.claim + 1) % p.claims.size()), "결론 바꾸기", "결론"])
	out.append(["submit", "결론 제출", "제출"])
	return out

func draw_board() -> void:
	match activity:
		"profile": draw_profile_board()
		"clean": draw_clean_board()
		"stats": draw_stats_board()
		"chart": draw_chart_board()

func draw_profile_board() -> void:
	cover(Rect2(380, 238, 348, 244), Color("eef2f8"))
	table_at(Vector2(382, 240), PROFILE_COLS, PROFILE_ROWS, 344, 40, 17)
	cover(Rect2(155, 322, 165, 188), CREAM)
	wrapped(Vector2(162, 348), "1행=학생 1명\nage 나이(세)\nzip 우편번호\njoined 가입일\nvisits 방문(회)\nNULL만 결측", 170, 17, INK)
	plate(Vector2(1000, 330), "결측·형식 점검", 18)

func draw_clean_board() -> void:
	var p: Dictionary = problems()[problem]
	var result = run_pipeline(p.rows, state.pipeline)
	plate(Vector2(475, 280), "결측 제거", 18)
	plate(Vector2(637, 280), "중복 제거", 18)
	plate(Vector2(800, 280), DEDUP_NAMES[DEDUP_KEYS[state.dedup]], 16)
	plate(Vector2(275, 380), "원본 %d행 → 남은 %d행" % [p.rows.size(), result.rows.size()], 18)
	var order: String = " → ".join(state.pipeline.map(func(s): return s.replace("dedup:", "dedup "))) if not state.pipeline.is_empty() else "처리 없음"
	cover(Rect2(925, 240, 170, 102), Color("2a3448"))
	wrapped(Vector2(932, 262), order, 156, 15, Color.WHITE)

func draw_stats_board() -> void:
	var p: Dictionary = problems()[problem]
	cover(Rect2(350, 204, 200, 56))
	if not p.values.is_empty():
		plate(Vector2(450, 232), ", ".join(p.values.map(func(v): return display(v))), 20)
	else:
		plate(Vector2(450, 232), "빈 집단", 22)
	if p.has("second"):
		cover(Rect2(630, 204, 200, 56))
		plate(Vector2(730, 232), ", ".join(p.second.map(func(v): return display(v))), 20)
	var nums = clean_nums(p.values)
	if not nums.is_empty():
		var low: float = float(nums[0])
		var high: float = float(nums.back())
		if is_equal_approx(low, high):
			low -= 1
			high += 1
		cover(Rect2(270, 322, 570, 72), Color("f3e5c4"))
		_cv.draw_line(Vector2(290, 360), Vector2(820, 360), NAVY, 3)
		for i in nums.size():
			var x: float = 300 + (float(nums[i]) - low) / (high - low) * 510
			var outlier: bool = p.has("outlier") and nums[i] == p.outlier
			_cv.draw_circle(Vector2(x, 360), 10, RED if outlier else BLUE)
			text(Vector2(x, 346 if i % 2 == 0 else 388), display(nums[i]), 16, INK, true)
	cover(Rect2(890, 305, 300, 215), Color("eef2f8"))
	if p.has("claims") and state.claim >= 0:
		wrapped(Vector2(902, 334), p.claims[state.claim], 276, 19, INK)
	elif p.has("claims"):
		wrapped(Vector2(902, 334), "해석 장치에서 E로 고르세요", 276, 19, WOOD)
	else:
		wrapped(Vector2(902, 334), "평균 = 합 ÷ 개수\n중앙값 = 정렬 후 가운데\n범위 = 최대 - 최소", 276, 19, INK)
	if state.show_ex:
		var kept: Array = p.values.filter(func(v): return v != p.outlier)
		plate(Vector2(1040, 500), "제외: " + ", ".join(kept.map(func(v): return display(v))), 18, Color("ffd7a8"))

func chart_area() -> Rect2:
	var x: float = [290.0, 560.0, 842.0][state.type]
	return Rect2(x, 128, 160, 114)

func draw_chart_board() -> void:
	var p: Dictionary = problems()[problem]
	cover(Rect2(240, 405, 118, 52), Color("f6e7c8"))
	wrapped(Vector2(235, 428), p.question, 124, 13, INK)
	var area = chart_area()
	plate(Vector2(area.get_center().x, 268), CHART_TYPES[state.type] + " 선택", 18, GOLD)
	if state.drawn:
		cover(area, CREAM)
		_cv.draw_rect(area, INK, false, 2)
		chart_marks(p, area)
	cover(Rect2(502, 348, 276, 92), Color("eef2f8"))
	var lines = p.rows.slice(0, 4).map(func(r): return "%s  %s" % [display(r[0]), display(r[1])])
	wrapped(Vector2(512, 368), "\n".join(lines), 256, 15, INK)
	if state.claim >= 0:
		plate(Vector2(985, 440), "결론 선택됨", 16, GOLD)

func draw_popup(kind: String) -> void:
	match kind:
		"clean":
			var p: Dictionary = problems()[problem]
			var result = run_pipeline(p.rows, state.pipeline)
			text(Vector2(150, 136), "원본", 24, NAVY)
			table_at(Vector2(150, 150), CLEAN_COLS, p.rows, 480, 38, 19)
			text(Vector2(660, 136), "미리보기", 24, NAVY)
			table_at(Vector2(660, 150), CLEAN_COLS, result.rows, 480, 38, 19)
			var dropped_text = ", ".join(result.dropped.map(func(d): return "#%d %s" % [d[0], d[1]]))
			wrapped(Vector2(150, 480), "제외: " + (dropped_text if dropped_text != "" else "없음"), 980, 20, RED)
			wrapped(Vector2(150, 530), "처리 순서: " + (" → ".join(state.pipeline) if not state.pipeline.is_empty() else "(없음)"), 980, 20, NAVY)
		"data":
			var p: Dictionary = problems()[problem]
			text(Vector2(150, 136), p.question, 24, NAVY)
			table_at(Vector2(150, 160), p.cols, p.rows, 420, 40, 20)
			text(Vector2(620, 180), "결론 후보", 22, NAVY)
			for i in p.claims.size():
				wrapped(Vector2(620, 216 + i * 70), ("▶ " if state.claim == i else "") + p.claims[i], 500, 20, RED if state.claim == i else INK)

func chart_marks(p: Dictionary, area: Rect2) -> void:
	var data = chart_data(p)
	if data.is_empty():
		return
	var ymax = 0.0
	for d in data:
		ymax = maxf(ymax, float(d[1]))
	ymax = maxf(ymax, 1.0) * 1.15
	var kind: String = CHART_TYPES[state.type]
	var n = data.size()
	if kind == "산점도":
		var xmin: float = INF
		var xmax: float = -INF
		for d in data:
			xmin = minf(xmin, float(d[0]))
			xmax = maxf(xmax, float(d[0]))
		var span = maxf(xmax - xmin, 1.0)
		for i in n:
			var c = Vector2(area.position.x + 14 + (float(data[i][0]) - xmin) / span * (area.size.x - 28), area.end.y - float(data[i][1]) / ymax * (area.size.y - 8) - 4)
			_cv.draw_circle(c, 7, GOLD if state.evidence == i else BLUE)
		return
	var slot: float = area.size.x / n
	var pts = PackedVector2Array()
	for i in n:
		var h = float(data[i][1]) / ymax * (area.size.y - 22)
		var cx = area.position.x + slot * (i + 0.5)
		var top = area.end.y - h - 14
		if kind == "막대":
			_cv.draw_rect(Rect2(cx - slot * 0.3, top, slot * 0.6, h), GOLD if state.evidence == i else BLUE)
		else:
			pts.append(Vector2(cx, top))
			_cv.draw_circle(Vector2(cx, top), 6, GOLD if state.evidence == i else BLUE)
		text(Vector2(cx, area.end.y - 2), str(data[i][0]).right(4), 11, INK, true)
		text(Vector2(cx, top - 3), display(data[i][1]), 12, INK, true)
	if kind == "선" and pts.size() > 1:
		_cv.draw_polyline(pts, BLUE, 3)
