extends "res://scripts/minigames/sql_labs.gd"
## SQL을 고르기 전에 레코드로 해결하는 실습. 기존 계산기는 정답 검증에 재사용한다.
## 공개 조작은 카드 운반·바구니·키 연결·결과 토큰 전달이며 SQL은 해설로 생성한다.

var work_spots := {}
var work_labels := {}
var work_note := ""
const CARD = Vector2(144, 64)
const AGGS = ["COUNT(*)", "COUNT(amount)", "SUM(amount)", "AVG(amount)"]
const AGG_NAMES = ["전체 건수", "값 있는 건수", "금액 합계", "금액 평균"]

func lab_table() -> Dictionary:
	var data = super.lab_table()
	for mode in data:
		data[mode].intro = ["이번에는 SQL 문장을 고르지 않아요. 기록 카드를 집어 직접 옮겨서 의뢰를 해결해요.",
			"WASD로 걷고 카드 앞에서 E로 집으세요. 목적지에서 E로 놓습니다. 잘못 옮겼으면 Z로 되돌리거나 같은 원본 카드를 다시 집으세요.",
			"마지막에 제출 레버를 당기면 실제 결과와 SQL 해설을 함께 볼 수 있어요. 힌트는 정답 위치 대신 판단할 기준을 알려 줘요."]
	data.query.talk = ["출력할 열 렌즈를 순서대로 꽂고, 학생 카드를 명단이나 제외함으로 보내세요.", "점수와 부서를 읽고 의뢰에 맞는 학생만 명단으로 보내세요.", "명단은 놓은 순서대로 만들어져요. 상위 인원과 점수 순서도 확인하세요."]
	data.group.talk = ["묶을 기준과 계산 도구를 정한 뒤 거래를 같은 바구니에 모으세요. 완성한 바구니는 빈손으로 E를 눌러 실적판에 배달해요.", "NULL도 거래 한 건이에요. 전체 건수와 값 있는 건수, 평균을 바구니에서 비교해 보세요.", "거래를 먼저 거르고, 바구니별 합계를 본 뒤 실적판에 올릴 바구니를 정하세요."]
	data.join.talk = ["직원 명찰을 집어 같은 부서 번호의 카드에 연결하세요. 짝이 없으면 제외함으로 보냅니다.", "이번에는 직원 모두 남겨야 해요. 짝이 없는 직원은 NULL 명찰함으로 보내세요.", "프로젝트가 여럿이면 같은 직원 명찰을 다시 집어 여러 번 연결하세요. 빈 부서표 문제도 있어요."]
	data.subquery.talk = ["점수 카드를 계산기에 모으고 평균 토큰을 만드세요. 토큰을 게이트에 꽂은 뒤 학생을 분류해요.", "팀 카드를 도시 조건에 따라 모아 팀 목록 토큰을 만드세요. 학생의 팀이 그 목록에 있는지 확인하세요.", "최고 점수 토큰이나 빈 팀 목록도 만들 수 있어요. 먼저 안쪽 계산부터 끝내세요."]
	return data

func build_stage() -> void:
	super.build_stage()
	var floor_layer = Node2D.new()
	field.add_child(floor_layer)
	field.move_child(floor_layer, 1)
	floor_layer.draw.connect(func():
		floor_layer.draw_rect(Rect2(76, 98, 1138, 496), Color("dbc9a5"))
		floor_layer.draw_rect(Rect2(86, 108, 1118, 476), Color("f2e8ce"))
		for x in range(90, 1200, 64): floor_layer.draw_line(Vector2(x, 110), Vector2(x, 580), Color("dfd2b4"), 1)
		for y in range(110, 580, 64): floor_layer.draw_line(Vector2(88, y), Vector2(1200, y), Color("dfd2b4"), 1))
	# 이 실습 안의 낡은 장치 충돌만 해제한다. 월드 맵의 노드·좌표에는 관여하지 않는다.
	for c in field.get_node("Walls").get_children():
		if c is CollisionPolygon2D: c.set_deferred("disabled", true)
	var boundary = StaticBody2D.new()
	field.add_child(boundary)
	for r in [Rect2(65, 85, 1160, 12), Rect2(65, 585, 1160, 12), Rect2(65, 85, 12, 512), Rect2(1213, 85, 12, 512)]:
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		boundary.add_child(shape)
	world.get_node("Spawn").position = Vector2(540, 550)

func setup_problem(p: Dictionary) -> void:
	super.setup_problem(p)
	state.work = {"hand": {}, "rows": {}, "output": [], "columns": [], "criterion": "", "aggs": [], "groups": {}, "pairs": [], "excluded": [], "mode": "", "inner": "", "inputs": {}, "token": null, "plugged": false, "op": ""}
	work_note = "카드를 읽고 의뢰에 맞는 곳으로 운반하세요"

func stations() -> Array:
	return []

func lab_rows() -> Array:
	return [["운반·조작", moves], ["실수", mistakes], ["결과 행", "-" if state.result == null else str(state.result.size())]]

func add_work(key: String, pos: Vector2, label: String) -> void:
	if not work_spots.has(key):
		var node = Interactable.new()
		node.kind = "work"
		node.name = "Work_" + str(work_spots.size())
		var shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 26
		shape.shape = circle
		node.add_child(shape)
		node.bubble_offset = Vector2(0, -82)
		world.add_child(node)
		work_spots[key] = node
	var sp: Interactable = work_spots[key]
	sp.position = pos
	sp.prompt = label
	sp.enabled = true
	work_labels[key] = label

func source_pos(i: int) -> Vector2:
	return Vector2(180 + (i % 2) * 164, 235 + (i / 2) * 88)

func rebuild() -> void:
	super.rebuild()
	for sp in work_spots.values(): sp.enabled = false
	work_labels.clear()
	if not state.has("work"): return
	add_work("submit", Vector2(1100, 552), "결과 제출 / 검토")
	match activity:
		"query":
			for i in STUDENTS.size(): add_work("row:%d" % i, source_pos(i), "학생 카드 집기 / 다시 옮기기")
			for i in STUDENT_COLS.size(): add_work("lens:" + STUDENT_COLS[i], Vector2(550 + i * 165, 152), "열 렌즈 " + STUDENT_COLS[i] + " 꽂기 / 빼기")
			add_work("put:out", Vector2(760, 320), "명단의 마지막에 카드 놓기")
			add_work("put:reject", Vector2(1050, 320), "이번 명단에서 제외하기")
		"group":
			for i in SALES.size(): add_work("row:%d" % i, source_pos(i), "거래 카드 집기 / 다시 옮기기")
			for i in AGGS.size(): add_work("agg:" + AGGS[i], Vector2(550 + i * 165, 152), "계산 도구: " + AGG_NAMES[i])
			add_work("criterion", Vector2(470, 520), "바구니 기준: 부서 / 지역")
			var keys = basket_keys()
			for i in keys.size(): add_work("basket:" + str(keys[i]), Vector2(650 + (i % 2) * 180, 265 + (i / 2) * 170), "거래 놓기 / 빈손이면 바구니 보고서 집기")
			add_work("put:out", Vector2(1060, 270), "바구니 보고서를 실적판에 올리기")
			add_work("put:reject", Vector2(1060, 435), "거래 또는 바구니 제외하기")
		"join":
			for i in EMPLOYEES.size(): add_work("employee:%d" % i, Vector2(245, 220 + i * 92), "직원 명찰 집기 (여러 프로젝트에는 다시 집기)")
			var right: Array = problems()[problem].right
			for i in right.size(): add_work("match:%d" % i, Vector2(700, 235 + i * 105), "들고 온 직원과 이 키 연결 / 같은 연결이면 해제")
			add_work("mode", Vector2(700, 150), "짝 있는 직원만 / 직원 모두 남기기")
			add_work("put:out", Vector2(1050, 265), "짝 없는 직원에게 NULL 명찰 지급")
			add_work("put:reject", Vector2(1050, 435), "짝 없는 직원은 명단에서 제외")
		"subquery":
			var input: Array = inner_sources()
			for i in input.size(): add_work("input:%d" % i, Vector2(170 + (i % 2) * 155, 240 + (i / 2) * 105), "안쪽 계산에 쓸 자료 집기")
			add_work("function", Vector2(460, 150), "안쪽 도구: 평균 / 최고 / 팀 목록")
			add_work("collect", Vector2(460, 280), "자료를 계산기에 넣기 / 빈손이면 계산하여 토큰 만들기")
			add_work("ignore", Vector2(460, 410), "안쪽 계산에서 제외 (NULL / 다른 도시)")
			add_work("token", Vector2(460, 515), "계산 결과 토큰 집기")
			add_work("operator", Vector2(800, 150), "비교 게이트: 초과 / 이상 / 같음 / 목록 안")
			add_work("plug", Vector2(1050, 150), "들고 온 결과 토큰을 게이트에 꽂기")
			for i in SCORES.size(): add_work("student:%d" % i, Vector2(645 + (i % 2) * 160, 255 + (i / 2) * 155), "토큰과 비교할 학생 카드 집기")
			add_work("put:out", Vector2(1050, 280), "게이트를 통과한 학생 놓기")
			add_work("put:reject", Vector2(1050, 445), "조건 밖의 학생 놓기")
	board.queue_redraw()

func prompt(t: Interactable) -> String:
	return t.prompt if t.kind == "work" else super.prompt(t)

func refresh() -> void:
	super.refresh()
	if state.get("phase", "setup") != "setup": bubble.visible = false

func interact(t: Interactable) -> void:
	if t.kind != "work":
		super.interact(t)
		return
	for key in work_spots:
		if work_spots[key] == t:
			work_action(key)
			return

func next_action() -> Array:
	return [null, ""] # 정답 카드나 목적지를 자동으로 가리키지 않는다.

func use_hint() -> void:
	var tips = {
		"query": ["의뢰의 이름·번호·점수·부서를 열 렌즈와 대응해 보세요.", "각 학생이 의뢰의 점수와 부서 조건을 만족하는지 판단하세요. 제외함도 목적지예요.", "순서가 필요한 명단은 높은 점수부터 놓으세요. 잘못 놓은 카드는 원본에서 다시 집어 옮길 수 있어요."],
		"group": ["같은 부서의 거래는 같은 바구니에 모으세요. 거래를 거르는 것과 바구니를 거르는 것은 달라요.", "NULL도 거래 한 건이지만, 금액이 있는 건수와 평균 계산에서는 제외돼요.", "거래를 모두 분류했으면 빈손으로 바구니를 집어 실적판이나 제외함으로 운반하세요."],
		"join": ["이름이나 줄 위치가 아니라 직원의 부서 번호와 오른쪽 키 값을 비교하세요.", "직원을 모두 남기라는 의뢰라면, 짝이 없는 직원도 NULL 명찰이 필요해요.", "한 부서에 프로젝트가 두 개면 같은 직원 명찰로 두 연결을 모두 만드세요."],
		"subquery": ["먼저 무엇을 계산해야 학생을 고를 수 있는지 생각하세요. 안쪽 계산 자료부터 모아요.", "계산기에 빈손으로 E → 만든 토큰 집기 → 게이트에 꽂기 순서예요.", "초과는 같은 값을 빼고, 이상은 같은 값도 포함해요. 팀 목록과의 비교는 목록 안(IN)이에요."]}
	var lines: Array = tips[activity]
	work_note = lines[mini(hints_used, lines.size() - 1)]
	hints_used += 1
	hud.toast(work_note, StageHUD.GOLD, 7)

func work_action(key: String) -> void:
	if state.phase != "setup" or done: return
	if key == "submit":
		submit_work()
		return
	snapshot()
	moves += 1
	var w: Dictionary = state.work
	work_note = ""
	if key.begins_with("lens:"):
		toggle(w.columns, key.trim_prefix("lens:"))
	elif key.begins_with("agg:"):
		toggle(w.aggs, key.trim_prefix("agg:"))
		w.groups.clear()
	elif key == "criterion":
		if not w.rows.is_empty() or not w.hand.is_empty():
			work_note = "기준을 바꾸려면 R로 거래를 원위치에 두세요."
		else: w.criterion = "region" if w.criterion == "dept" else "dept"
	elif key == "mode":
		w.mode = "LEFT" if w.mode == "INNER" else "INNER"
	elif key == "function":
		if not w.inputs.is_empty() or not w.hand.is_empty():
			work_note = "계산 도구를 바꾸려면 R로 안쪽 자료를 돌려놓으세요."
		else:
			var opts: Array = problems()[problem].inner
			w.inner = opts[(opts.find(w.inner) + 1) % opts.size()]
	elif key == "operator":
		w.op = SUB_OPS[(SUB_OPS.find(w.op) + 1) % SUB_OPS.size()]
	elif key.begins_with("row:"):
		pickup("row", int(key.get_slice(":", 1)))
	elif key.begins_with("employee:"):
		pickup("employee", int(key.get_slice(":", 1)))
	elif key.begins_with("input:"):
		pickup("input", int(key.get_slice(":", 1)))
	elif key.begins_with("student:"):
		if not w.plugged or w.op == "": work_note = "먼저 안쪽 토큰을 게이트에 꽂고 비교 방법을 정하세요."
		else: pickup("student", int(key.get_slice(":", 1)))
	elif key.begins_with("basket:"):
		var name = key.trim_prefix("basket:")
		if w.hand.is_empty():
			if members(name).is_empty(): work_note = "이 바구니에는 거래가 없어요."
			else:
				w.groups.erase(name)
				w.hand = {"type": "group", "key": name}
		elif w.hand.type == "row": drop_row(name)
		else: work_note = "거래 카드만 바구니에 넣을 수 있어요."
	elif key.begins_with("match:"):
		if w.hand.get("type", "") == "employee":
			var pair = [w.hand.id, int(key.get_slice(":", 1))]
			w.excluded.erase(w.hand.id)
			if w.pairs.has(pair): w.pairs.erase(pair)
			else: w.pairs.append(pair)
			w.hand = {}
		else: work_note = "왼쪽 직원 명찰을 먼저 집으세요."
	elif key in ["put:out", "put:reject"]:
		place_hand(key.trim_prefix("put:"))
	elif key == "collect":
		if w.hand.get("type", "") == "input":
			w.inputs[w.hand.id] = "in"; w.hand = {}; w.token = null; w.plugged = false
		elif w.hand.is_empty(): make_token()
		else: work_note = "안쪽 자료 카드만 계산기에 넣을 수 있어요."
	elif key == "ignore":
		if w.hand.get("type", "") == "input":
			w.inputs[w.hand.id] = "reject"; w.hand = {}; w.token = null; w.plugged = false
		else: work_note = "안쪽 계산에서 뺄 자료를 먼저 집으세요."
	elif key == "token":
		if w.token == null: work_note = "계산기에 자료를 모두 분류한 뒤 빈손으로 E를 눌러 계산하세요."
		elif w.hand.is_empty(): w.hand = {"type": "token"}; w.plugged = false
		else: work_note = "먼저 들고 있는 카드를 놓으세요."
	elif key == "plug":
		if w.hand.get("type", "") == "token": w.plugged = true; w.hand = {}; work_note = "이제 학생 카드와 이 토큰을 비교하세요."
		else: work_note = "계산기에서 결과 토큰을 집어 오세요."
	if work_note == "": work_note = "손: " + hand_text() if not w.hand.is_empty() else "기록이 이동했어요. 바뀐 표와 바구니를 확인하세요."
	rebuild()
	refresh()

func toggle(a: Array, value) -> void:
	if a.has(value): a.erase(value)
	else: a.append(value)

func pickup(kind: String, i: int) -> void:
	var w: Dictionary = state.work
	if not w.hand.is_empty():
		work_note = "손에 든 카드를 목적지에 먼저 놓으세요."
		return
	if kind == "input" and w.inner == "":
		work_note = "먼저 안쪽 계산 도구를 정하세요."
		return
	if kind in ["row", "student"]:
		w.rows.erase(i); w.output.erase(i)
		if activity == "group": w.groups.clear()
	if kind == "input":
		w.inputs.erase(i); w.token = null; w.plugged = false
	w.hand = {"type": kind, "id": i}

func drop_row(dest: String) -> void:
	var w: Dictionary = state.work
	w.rows[w.hand.id] = dest
	if dest == "out": w.output.append(w.hand.id)
	w.hand = {}

func place_hand(dest: String) -> void:
	var w: Dictionary = state.work
	if w.hand.is_empty():
		work_note = "원본 카드나 완성한 바구니를 집어 오세요."
		return
	match w.hand.type:
		"row", "student":
			if activity == "group" and dest == "out": work_note = "거래를 바구니에 모은 뒤 바구니 보고서를 배달하세요."
			else: drop_row(dest)
		"group": w.groups[w.hand.key] = dest; w.hand = {}
		"employee":
			var i: int = w.hand.id
			if dest == "out":
				if not w.pairs.has([i, -1]): w.pairs.append([i, -1])
				w.excluded.erase(i)
			else:
				w.pairs = w.pairs.filter(func(p): return p[0] != i)
				if not w.excluded.has(i): w.excluded.append(i)
			w.hand = {}
		_: work_note = "이 카드는 계산기나 게이트로 전달해야 해요."

func basket_keys() -> Array:
	return ["서울", "부산"] if state.work.criterion == "region" else ["A", "B", "C", "D"]

func members(name: String) -> Array:
	var rows: Array = []
	for id in state.work.rows:
		if state.work.rows[id] == name: rows.append(SALES[id])
	return rows

func inner_sources() -> Array:
	return TEAMS if str(state.work.inner).begins_with("CITY:") else SCORES

func make_token() -> void:
	var w: Dictionary = state.work
	if w.inner == "" or w.inputs.size() != inner_sources().size():
		work_note = "모든 안쪽 자료를 계산기와 제외함에 분류하세요."
		return
	var values: Array = []
	for id in w.inputs:
		if w.inputs[id] != "in": continue
		var v = TEAMS[id][0] if w.inner.begins_with("CITY:") else SCORES[id][2]
		if v != null: values.append(v)
	if w.inner in ["AVG", "MAX"]:
		var number = null
		if not values.is_empty():
			if w.inner == "MAX": number = values.max()
			else:
				number = 0.0
				for value in values: number += value
				number /= values.size()
		w.token = {"shape": "scalar", "values": [number]}
	else: w.token = {"shape": "set", "values": values}
	work_note = "결과 토큰이 만들어졌어요. 토큰 받침에서 집어 게이트로 전달하세요."

func work_error() -> String:
	var w: Dictionary = state.work
	var p: Dictionary = problems()[problem]
	if not w.hand.is_empty(): return "들고 있는 카드부터 목적지에 놓으세요."
	match activity:
		"query":
			if w.columns != p.columns: return "출력 렌즈가 의뢰와 달라요. 열 종류와 꽂은 순서를 확인하세요."
			if w.rows.size() != STUDENTS.size(): return "아직 분류하지 않은 학생이 있어요. 모두 명단 또는 제외함에 보내세요."
			var actual = w.output.map(func(i): return w.columns.map(func(c): return STUDENTS[i][STUDENT_COLS.find(c)]))
			var expected = eval_query(target_query(p))
			if (actual != expected if p.get("order", "") != "" else not same_rows(actual, expected)):
				return "명단의 학생·인원·순서를 의뢰와 비교하세요. 놓은 순서가 결과 순서예요."
		"group":
			if w.criterion != p.group: return "같은 바구니로 모으는 기준이 의뢰와 달라요."
			var wanted: Array = p.select.filter(func(s): return s.ends_with(")"))
			var selected: Array = w.aggs.duplicate(); selected.sort(); wanted.sort()
			if wanted != selected: return "실적판에 필요한 계산 도구를 확인하세요. 건수·값 있는 건수·합계·평균은 달라요."
			if w.rows.size() != SALES.size(): return "아직 분류하지 않은 거래가 있어요."
			var q = target_group(p)
			for i in SALES.size():
				var row: Array = SALES[i]
				var keep: bool = q.where == "없음" or (row[3] != null and row[3] >= (10 if q.where == "amount >= 10" else 100))
				var dest = row[SALES_COLS.find(q.group)] if keep else "reject"
				if w.rows[i] != dest: return "거래 #%d의 부서·금액을 다시 읽으세요. 모으기 전 제외할 거래인지도 확인하세요." % row[0]
			for name in basket_keys():
				if members(name).is_empty(): continue
				var destination = "out" if having_pass(q.having, members(name)) else "reject"
				if w.groups.get(name, "") != destination: return "%s 바구니의 계산값을 보고 실적판에 올릴지 판단하세요." % name
		"join":
			if w.mode != p.type: return "직원 모두를 남기는 의뢰인지, 짝이 있는 직원만 남기는 의뢰인지 확인하세요."
			var expected = eval_join(p.right, 0, p.type)
			if not same_rows(w.pairs, expected.pairs): return "연결이 빠졌거나 키가 달라요. 줄 위치 대신 부서 번호를 보세요. 프로젝트가 여럿이면 연결도 여러 개예요."
			for i in EMPLOYEES.size():
				var matched = w.pairs.any(func(pair): return pair[0] == i)
				if not matched and not w.excluded.has(i): return "짝이 없는 직원도 제외함 또는 NULL 명찰함으로 처리하세요."
				if matched and w.excluded.has(i): return "연결된 직원을 제외함에도 넣을 수는 없어요."
		"subquery":
			if w.inner != p.answer: return "의뢰를 해결하려면 안쪽에서 무엇을 먼저 구해야 할까요?"
			if w.inputs.size() != inner_sources().size(): return "안쪽 자료부터 모두 분류하세요."
			for i in inner_sources().size():
				var include: bool = TEAMS[i][1] == w.inner.trim_prefix("CITY:") if w.inner.begins_with("CITY:") else SCORES[i][2] != null
				if w.inputs[i] != ("in" if include else "reject"): return "안쪽 자료 #%d가 계산에 포함돼야 하는지 다시 확인하세요. NULL과 다른 도시는 제외해요." % (i + 1)
			if not w.plugged or w.token == null: return "안쪽 결과 토큰을 바깥 게이트에 전달하세요."
			if w.op != p.op: return "초과·이상·같음·목록 안의 차이를 확인하세요. 경계값을 포함하나요?"
			if w.rows.size() != SCORES.size(): return "토큰과 비교해 학생 카드를 모두 분류하세요."
			var actual = w.output.map(func(i): return [SCORES[i][0], SCORES[i][2]])
			if not same_rows(actual, outer_rows(p.col, p.op, eval_inner(p.answer))): return "게이트의 토큰과 학생 값을 비교하세요. 통과하면 명단, 아니면 제외함이에요."
	return ""

func submit_work() -> void:
	var error = work_error()
	if error != "":
		work_note = error
		wrong(error)
		rebuild(); refresh()
		return
	var w: Dictionary = state.work
	var p: Dictionary = problems()[problem]
	match activity:
		"query":
			state.columns = w.columns.duplicate()
			state.result = w.output.map(func(i): return w.columns.map(func(c): return STUDENTS[i][STUDENT_COLS.find(c)]))
			code(query_text(target_query(p)), "렌즈·분류·놓은 순서와 대응하는 SQL")
		"group":
			var q = target_group(p)
			state.select = p.select.duplicate()
			state.result = eval_group(q).rows
			code(group_text(q), "거래 분류 → 바구니 → 계산 → 바구니 선별")
		"join":
			state.result = w.pairs.map(func(pair): return [EMPLOYEES[pair[0]][1], null if pair[1] < 0 else p.right[pair[1]][1]])
			var table_name = "projects" if p.right == PROJECTS else "departments"
			code("SELECT e.name, d.name FROM employees e %s JOIN %s d ON e.dept_id = d.id" % [w.mode, table_name], "직접 연결한 키와 NULL 명찰")
		"subquery":
			state.result = w.output.map(func(i): return [SCORES[i][0], SCORES[i][2]])
			code("SELECT name, score FROM scores WHERE %s %s (%s)" % [p.col, w.op, inner_sql(w.inner)], "직접 계산하고 전달한 안쪽 토큰")
	state.review_ok = true
	state.review_text = "직접 만든 결과가 의뢰와 일치해요. 오른쪽 SQL과 행동을 연결해 보세요."
	enter_review()

func state_code() -> String:
	if not state.has("work"): return super.state_code()
	return "레코드 체험 중 · SQL은 제출 후 해설로 연결돼요" if state.phase != "review" else (code_lines.back()[0] if not code_lines.is_empty() else "")

func hand_text() -> String:
	var h: Dictionary = state.work.hand
	if h.is_empty(): return "빈손"
	match h.type:
		"row": return row_title(h.id)
		"employee": return "%s · 부서 %s" % [EMPLOYEES[h.id][1], display(EMPLOYEES[h.id][2])]
		"student": return "%s · %s" % [SCORES[h.id][0], display(SCORES[h.id][2])]
		"input": return input_title(h.id)
		"group": return str(h.key) + " 바구니 보고서"
	return "결과 토큰 " + token_text()

func row_title(i: int) -> String:
	if activity == "query": return "%s · %s점 · %s" % [STUDENTS[i][1], display(STUDENTS[i][2]), STUDENTS[i][3]]
	return "#%d · %s · %s · %s" % [SALES[i][0], SALES[i][1], SALES[i][2], display(SALES[i][3])]

func input_title(i: int) -> String:
	if str(state.work.inner).begins_with("CITY:"): return "%s · %s" % TEAMS[i]
	return "%s · %s" % [SCORES[i][0], display(SCORES[i][2])]

func token_text() -> String:
	if state.work.token == null: return "아직 없음"
	var a: Array = state.work.token.values
	return "빈 집합" if a.is_empty() else ", ".join(a.map(func(v): return display(v)))

func _process(delta: float) -> void:
	if not state.has("work"): return
	board.queue_redraw() # 손에 든 카드가 로봇을 따라 이동한다.

func draw_board() -> void:
	if not state.has("work"): return
	var w: Dictionary = state.work
	text(Vector2(104, 152), "SQL 데이터 작업장", 23, NAVY)
	match activity:
		"query": draw_query_work()
		"group": draw_group_work()
		"join": draw_join_work()
		"subquery": draw_sub_work()
	card_at("submit", "제출 레버", "직접 만든 결과 검토", Color("f2c14e"))
	if state.phase == "review": draw_work_review()
	elif not w.hand.is_empty():
		var at = player.position + Vector2(0, -76)
		box_cell(Rect2(at - Vector2(100, 22), Vector2(200, 44)), hand_text(), GOLD, INK, 18)
	draw_work_mission()

func card_at(key: String, title: String, detail := "", fill := CREAM) -> void:
	if not work_spots.has(key): return
	var sp: Interactable = work_spots[key]
	var r = Rect2(sp.position - CARD / 2, CARD)
	_cv.draw_rect(r.grow(3), GOLD if player.focus == sp else WOOD)
	_cv.draw_rect(r, fill)
	text(Vector2(sp.position.x, sp.position.y - 5), title, fit_size(title, 138, 19), INK, true)
	if detail != "": text(Vector2(sp.position.x, sp.position.y + 19), detail, fit_size(detail, 138, 16), NAVY, true)
	if player.focus == sp: text(Vector2(sp.position.x, sp.position.y + 49), "E", 19, BLUE, true)

func draw_query_work() -> void:
	var w: Dictionary = state.work
	text(Vector2(110, 195), "원본 기록 · E로 복사본 집기", 17, WOOD)
	for i in STUDENT_COLS.size():
		var col: String = STUDENT_COLS[i]
		var index: int = w.columns.find(col)
		card_at("lens:" + col, ["번호 id", "이름 name", "점수 score", "부서 dept"][i], "출력 %d번" % (index+1) if index >= 0 else "출력 렌즈 꽂기", Color("bfe3b4") if index >= 0 else CREAM)
	for i in STUDENTS.size():
		var dest: String = w.rows.get(i, "")
		var carrying: bool = w.hand.get("type", "") == "row" and w.hand.id == i
		card_at("row:%d" % i, STUDENTS[i][1] + " · #" + str(STUDENTS[i][0]), "운반 중" if carrying else "%s점 / %s" % [display(STUDENTS[i][2]), STUDENTS[i][3]], Color("cbd1cc") if dest != "" or carrying else CREAM)
	card_at("put:out", "명단 트레이", "놓은 순서 = 결과 순서", Color("bfe3b4"))
	card_at("put:reject", "제외함", "이번 의뢰에 없는 학생", Color("f0c1ae"))
	for i in w.output.size():
		text(Vector2(685, 385 + i * 25), "%d. %s" % [i + 1, STUDENTS[w.output[i]][1]], 20, NAVY)
	var rejected: Array = []
	for id in w.rows:
		if w.rows[id] == "reject": rejected.append(STUDENTS[id][1])
	wrapped(Vector2(978, 385), ", ".join(rejected), 185, 18, RED)

func draw_group_work() -> void:
	var w: Dictionary = state.work
	for i in AGGS.size(): card_at("agg:" + AGGS[i], AGG_NAMES[i], "장착됨" if w.aggs.has(AGGS[i]) else "계산 도구 장착", Color("bfe3b4") if w.aggs.has(AGGS[i]) else CREAM)
	for i in SALES.size(): card_at("row:%d" % i, "거래 #%d · %s" % [SALES[i][0], SALES[i][1]], "%s / %s" % [SALES[i][2], display(SALES[i][3])], Color("cbd1cc") if w.rows.has(i) else CREAM)
	card_at("criterion", "묶는 기준", {"": "미설정", "dept": "부서", "region": "지역"}[w.criterion])
	for name in basket_keys():
		var rows: Array = members(name)
		card_at("basket:" + name, str(name) + " 바구니", "%d건 · 합 %s" % [rows.size(), display(aggregate("SUM(amount)", rows))], Color("bbdbed"))
		var pos: Vector2 = work_spots["basket:" + name].position
		text(pos + Vector2(-70, 57), "금액: " + ",".join(rows.map(func(r): return display(r[3]))), 15, INK)
		if not rows.is_empty(): text(pos + Vector2(-70, 78), "값수 %s · 평균 %s" % [display(aggregate("COUNT(amount)", rows)), display(aggregate("AVG(amount)", rows))], 15, NAVY)
		if w.groups.has(name): text(pos + Vector2(-70, 99), "→ " + ("실적판" if w.groups[name] == "out" else "제외"), 17, TEAL)
	card_at("put:out", "실적판", "바구니 보고서 배달", Color("bfe3b4"))
	card_at("put:reject", "제외함", "거래 / 바구니 제외", Color("f0c1ae"))

func draw_join_work() -> void:
	var w: Dictionary = state.work
	var right: Array = problems()[problem].right
	for pair in w.pairs:
		var start: Vector2 = work_spots["employee:%d" % pair[0]].position + Vector2(74, 0)
		var end: Vector2 = work_spots["put:out"].position - Vector2(74, 0) if pair[1] < 0 else work_spots["match:%d" % pair[1]].position - Vector2(74, 0)
		ink_line(start, end, Color("358cb0"), 3)
	for i in EMPLOYEES.size(): card_at("employee:%d" % i, EMPLOYEES[i][1], "부서 " + display(EMPLOYEES[i][2]))
	for i in right.size(): card_at("match:%d" % i, str(right[i][1]), "키 " + str(right[i][0]), Color("bbdbed"))
	if right.is_empty(): plate(Vector2(700, 320), "오른쪽 표 0행", 22)
	card_at("mode", "직원 처리 방식", {"": "미설정", "INNER": "짝 있는 직원만", "LEFT": "직원 모두 남기기"}[w.mode])
	card_at("put:out", "NULL 명찰함", "짝 없는 직원 남기기", Color("bfe3b4"))
	card_at("put:reject", "제외함", "짝 없는 직원 제외", Color("f0c1ae"))
	text(Vector2(980, 505), "연결 %d개 / 제외 %d명" % [w.pairs.size(), w.excluded.size()], 17, NAVY)

func draw_sub_work() -> void:
	var w: Dictionary = state.work
	card_at("function", "안쪽 계산 도구", inner_short(w.inner))
	for i in inner_sources().size():
		card_at("input:%d" % i, "안쪽 자료 #%d" % (i + 1), input_title(i), Color("cbd1cc") if w.inputs.has(i) else CREAM)
	card_at("collect", "안쪽 계산기", "자료 넣기 / 빈손 계산", Color("bbdbed"))
	card_at("ignore", "안쪽 제외함", "NULL / 조건 밖 자료", Color("f0c1ae"))
	card_at("token", "결과 토큰", token_text(), Color("bfe3b4"))
	card_at("operator", "비교 게이트", {"": "미설정", ">": "초과 >", ">=": "이상 >=", "=": "같음 =", "IN": "목록 안 IN"}[w.op])
	card_at("plug", "토큰 소켓", token_text() if w.plugged else "결과 토큰 꽂기", Color("bfe3b4") if w.plugged else CREAM)
	for i in SCORES.size(): card_at("student:%d" % i, SCORES[i][0] + " · " + SCORES[i][1], "점수 " + display(SCORES[i][2]), Color("cbd1cc") if w.rows.has(i) else CREAM)
	card_at("put:out", "통과 명단", "%d명" % w.output.size(), Color("bfe3b4"))
	card_at("put:reject", "바깥 제외함", "토큰과 조건 비교", Color("f0c1ae"))

func draw_work_review() -> void:
	var headers: Array = state.work.columns if activity == "query" else (problems()[problem].select if activity == "group" else ["이름", "연결 값" if activity == "join" else "점수"])
	cover(Rect2(400, 205, 790, 365), Color("e9f2e3"))
	text(Vector2(425, 240), "직접 만든 결과 · SQL과 연결해 보기", 26, TEAL)
	table_at(Vector2(425, 260), headers, state.result, 730, 30, 19)
	text(Vector2(425, 546), "E / Enter: 결과 확인 후 다음 문제", 21, NAVY)

func draw_work_mission() -> void:
	cover(Rect2(60, 612, 1160, 104), Color("fff6dc"))
	text(Vector2(80, 640), "의뢰", 22, RED)
	text(Vector2(150, 640), goal, fit_size(goal, 1040, 22), INK)
	var line: String = "손: " + hand_text() + " · E 집기/놓기 · Z 되돌리기 · 제출 레버로 검토"
	if state.phase == "review": line = "결과표와 오른쪽 SQL을 확인하세요 · E / Enter로 다음 의뢰"
	text(Vector2(80, 670), line, fit_size(line, 1120, 21), BLUE)
	var note = "분류=WHERE · 열 렌즈=SELECT · 놓은 순서=ORDER BY" if state.phase == "review" else work_note
	if state.phase == "review" and activity == "group": note = "거래 제외=WHERE · 바구니=GROUP BY · 계산=집계 · 바구니 제외=HAVING"
	if state.phase == "review" and activity == "join": note = "같은 키 연결=ON · 직원 모두 남기기=LEFT JOIN · NULL 명찰=미매칭 행"
	if state.phase == "review" and activity == "subquery": note = "안쪽 계산=서브쿼리 · 토큰 전달=조건의 값/집합 · 학생 분류=바깥 WHERE"
	text(Vector2(80, 702), note, fit_size(note, 1120, 20), TEAL)
