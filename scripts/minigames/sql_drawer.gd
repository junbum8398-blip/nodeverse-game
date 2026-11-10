extends Node2D
## SQL 5x5 서랍 색칠 게임. 작은 로봇이 칸을 옮겨 다니며 붓을 찍고, 오른쪽 LIVE SQL 과 결과가 즉시 바뀐다.
## 색칠·SQL·결과는 sql_query_model 의 같은 상태에서 계산한다.

const Model = preload("res://scripts/minigames/sql_query_model.gd")
const Data = preload("res://scripts/minigames/sql_drawer_levels.gd")
const MOVE_TIME := 0.14
const PATH := "res://textures/sql_drawer/%s.png"
const INK := Color("1d1b2a")
const CREAM := Color("fbf1d6")
const GOLD := Color("f2c14e")
const RED := Color("d64545")
const NAVY := Color("1d3a73")
const CODE_TEXT := Color("e8edf5")
const CODE_KEY := Color("5fd6ff")
const CODE_INNER := Color("f2c14e")
const CODE_COMMENT := Color("8d98ab")
const KEYWORDS := ["SELECT", "FROM", "WHERE", "GROUP", "BY", "HAVING", "ORDER", "LIMIT", "JOIN", "LEFT", "INNER", "ON", "DESC", "ASC"]
const WHERE_VALUES := [50, 55, 60, 70, 80, 90]
const COMPARE_OPS := [">", ">=", "="]
const JOIN_COLORS := [Color("5fd6ff"), Color("b78cf2"), GOLD, Color("7ddc8a"), Color("f28cb1")]

static var saved := {}
static var help_seen := {}

@export var activity := "query"

var game: Dictionary
var stage_id := ""
var level := 0
var m := {}
var res := {}
var undo_stack: Array = []
var r := 0
var c := 0
var tool_id := ""
var palette = null
var phase := "play"        # play / palette / solved / help
var message := ""
var message_good := false
var message_t := 0.0
var wrong_cols: Array = []
var changed: Dictionary = {}
var hint_i := 0
var mistakes := 0
var hints_used := 0
var instant := false       # 자동 테스트: 이동 연출 없이 바로 처리
var moving := false
var splash := 0.0
var font: Font
var code_font: Font
var textures := {}
var robot: Sprite2D
var tables := {}

# ---------- 준비 ----------
func _ready() -> void:
	game = Data.GAMES[activity]
	stage_id = game.id
	font = load("res://fonts/NotoSansKR_Medium.tres")
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["D2Coding", "Consolas", "Cascadia Mono", "Malgun Gothic"])
	code_font = f
	robot = Sprite2D.new()
	robot.texture = load("res://textures/sprites/robot.png")
	robot.scale = Vector2(0.42, 0.42)
	robot.offset = Vector2(0, -71)
	robot.z_index = 5
	add_child(robot)
	var snapshot = saved.get(stage_id)
	if snapshot != null:
		level = snapshot.level
		_load_level(level)
		m = snapshot.m.duplicate(true)
		r = snapshot.r
		c = snapshot.c
		tool_id = snapshot.tool
		_recompile()
	else:
		_load_level(0)
		_telemetry("start_task", [stage_id, {"title": game.title, "goal": _level().mission, "total_levels": 3}])
	if not help_seen.get(stage_id, false):
		phase = "help"
		help_seen[stage_id] = true
	_place_robot(true)

func _level() -> Dictionary:
	return game.levels[level]

func _load_level(n: int) -> void:
	level = n
	var L: Dictionary = game.levels[n]
	tables = {"left": Data.STUDENTS_J if activity == "join" else Data.STUDENTS}
	if activity == "join":
		tables.right = Data.DEPTS if L.right == "DEPTS" else Data.PROJECTS
	m = Model.new_model()
	undo_stack.clear()
	r = 0
	c = 0
	tool_id = L.tools["1"]
	palette = null
	phase = "play"
	wrong_cols = []
	hint_i = 0
	_recompile()
	_telemetry("start_attempt", [stage_id, n + 1, {"goal": L.mission}])

func _telemetry(fn: String, args: Array) -> void:
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.callv(fn, args)

func _op(name: String, ok: bool, reason := "") -> void:
	_telemetry("record_operation", [name, ok, reason, {}, {}, {"stage": stage_id, "level": level + 1, "mistakes": mistakes}])

func _recompile() -> void:
	var old: Array = res.get("sql", [])
	res = Model.compile(activity, m, tables)
	changed.clear()
	for i in res.sql.size():
		if i >= old.size() or old[i].text != res.sql[i].text:
			changed[i] = 0.4
	queue_redraw()

func say(t: String, good := false) -> void:
	message = t
	message_good = good
	message_t = 4.0

func _save_progress() -> void:
	saved[stage_id] = {"level": level, "m": m.duplicate(true), "r": r, "c": c, "tool": tool_id}

func _go_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# ---------- 판 배치 ----------
func grid_cols() -> int:
	return 10 if activity == "join" else 5

func grid_rows() -> int:
	return 6 if activity == "group" and not res.groups.is_empty() else 5

func board_of(col: int) -> Dictionary:
	if activity == "join":
		return {"table": tables.right, "x": 540.0, "col": col - 5, "y": 240.0, "w": 74.0, "h": 66.0} if col >= 5 else {"table": tables.left, "x": 102.0, "col": col, "y": 240.0, "w": 74.0, "h": 66.0}
	var geo: Dictionary = {"query": {"x": 175.0, "y": 190.0, "w": 124.0, "h": 92.0}, "group": {"x": 150.0, "y": 132.0, "w": 120.0, "h": 74.0}, "sub": {"x": 172.0, "y": 226.0, "w": 110.0, "h": 70.0}}[activity]
	return {"table": tables.left, "x": geo.x, "col": col, "y": geo.y, "w": geo.w, "h": geo.h}

func cell_rect(row: int, col: int) -> Rect2:
	var b := board_of(col)
	return Rect2(b.x + b.col * (b.w + 2), b.y + row * (b.h + 2), b.w, b.h)

func summary_rect(i: int) -> Rect2:
	var n: int = maxi(res.groups.size(), 3)
	var w: float = minf(195.0, 618.0 / n - 6)
	return Rect2(150 + i * (w + 8), 524, w, 112)

func robot_pos() -> Vector2:
	var rect: Rect2 = summary_rect(mini(c, res.groups.size() - 1)) if activity == "group" and r == 5 else cell_rect(r, c)
	return rect.position + Vector2(rect.size.x * 0.82, rect.size.y * 0.98)

func _place_robot(now := false) -> void:
	var p := robot_pos()
	if now or instant:
		robot.position = p
		return
	moving = true
	var tw := create_tween()
	tw.tween_property(robot, "position", p, MOVE_TIME).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(robot, "offset:y", -82.0, MOVE_TIME * 0.5)
	tw.tween_property(robot, "offset:y", -71.0, 0.05)
	tw.finished.connect(func(): moving = false)

func cell_column() -> Dictionary:
	var b := board_of(c)
	return {"table": b.table, "name": b.table.cols[b.col], "side": "right" if activity == "join" and c >= 5 else "left"}

func move(dr: int, dc: int) -> void:
	if moving and not instant:
		return
	var nr: int = clampi(r + dr, 0, grid_rows() - 1)
	var nc: int = clampi(c + dc, 0, grid_cols() - 1)
	if activity == "group" and nr == 5:
		nc = mini(nc, res.groups.size() - 1)
	if nr == r and nc == c:
		return
	r = nr
	c = nc
	_place_robot()
	queue_redraw()

# ---------- 입력 ----------
func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed):
		return
	if phase == "help":
		if not ev.echo:
			phase = "play"
			queue_redraw()
		return
	if phase == "palette":
		_palette_input(ev)
		return
	var k: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
	match k:
		KEY_W, KEY_UP: move(-1, 0)
		KEY_S, KEY_DOWN: move(1, 0)
		KEY_A, KEY_LEFT: move(0, -1)
		KEY_D, KEY_RIGHT: move(0, 1)
	if ev.echo:
		return
	match k:
		KEY_E, KEY_SPACE:
			if phase == "play":
				press_e()
		KEY_ENTER, KEY_KP_ENTER:
			if phase == "solved":
				_after_solved()
			elif phase == "play":
				submit()
		KEY_Z: undo()
		KEY_X: reset_problem()
		KEY_F: use_hint()
		KEY_H:
			phase = "help"
			queue_redraw()
		KEY_ESCAPE:
			_save_progress()
			_go_menu()
		_:
			var digit: int = k - KEY_0
			if digit >= 1 and digit <= 6 and phase == "play":
				pick_tool(str(digit))

func pick_tool(slot: String) -> void:
	var tools: Dictionary = _level().tools
	if tools.has(slot):
		tool_id = tools[slot]
		queue_redraw()
	else:
		say("이번 단계에서는 아직 없는 도구예요.")

func set_tool(id: String) -> void:
	tool_id = id

func _push_undo() -> void:
	undo_stack.append(m.duplicate(true))

func undo() -> void:
	if phase != "play" or undo_stack.is_empty():
		return
	m = undo_stack.pop_back()
	_recompile()
	_op("undo", true)

func reset_problem() -> void:
	if phase == "solved":
		return
	m = Model.new_model()
	undo_stack.clear()
	wrong_cols = []
	palette = null
	phase = "play"
	_recompile()
	say("이 문제를 처음 상태로 돌렸어요.")

func use_hint() -> void:
	var h: Array = _level().hints
	say(h[hint_i])
	hint_i = mini(hint_i + 1, h.size() - 1)
	hints_used += 1
	_op("hint", true)

func press_e() -> void:
	if phase != "play":
		return
	splash = 0.3
	match tool_id:
		"col": _brush_col()
		"cond": _brush_cond()
		"erase": _erase()
		"order": _tool_order()
		"limit": _tool_limit()
		"group": _brush_group()
		"count": _toggle_agg({"fn": "COUNT", "col": "*"})
		"countcol": _toggle_agg({"fn": "COUNT", "col": cell_column().name})
		"avg": _tool_avg()
		"having": _tool_having()
		"key": _brush_key()
		"mode": _tool_mode()
		"max": _tool_inner("MAX")
		"compare": _tool_compare()
	queue_redraw()

func _commit() -> void:
	wrong_cols = []
	_recompile()
	_op("paint", true)

func _column_is_numeric(col: String) -> bool:
	return col in ["id", "score"]

func _brush_col() -> void:
	if activity == "group" and r == 5:
		return
	var col: String = cell_column().name
	_push_undo()
	if m.select.has(col):
		m.select.erase(col)
	else:
		m.select.append(col)
	_commit()

func _brush_cond() -> void:
	var col: String = cell_column().name
	if _column_is_numeric(col):
		palette = {"mode": "where", "col": col, "op": 0, "val": WHERE_VALUES.find(80)}
		phase = "palette"
		return
	var v = cell_column().table.rows[r][cell_column().table.cols.find(col)]
	if v == null:
		say("NULL은 값 도장으로 쓸 수 없어요.")
		return
	_push_undo()
	m.cond = {"col": col, "op": "=", "val": v}
	_commit()

func _erase() -> void:
	var col: String = cell_column().name if not (activity == "group" and r == 5) else ""
	if activity == "group" and r == 5:
		if m.having != null:
			_push_undo()
			m.having = null
			_commit()
		return
	_push_undo()
	var done := true
	if m.cond != null and m.cond.col == col:
		m.cond = null
	elif m.order != null and m.order.col == col:
		m.order = null
		m.limit = -1
	elif m.outer_op != "" and m.outer_col == col:
		m.outer_op = ""
		m.outer_col = ""
	elif m.inner != null and m.inner.col == col:
		m.inner = null
		m.outer_op = ""
		m.outer_col = ""
	elif m.select.has(col):
		m.select.erase(col)
	elif m.group == col:
		m.group = ""
		m.having = null
	elif activity == "group" and not m.aggs.is_empty():
		m.aggs.pop_back()
		m.having = null
	elif activity == "join" and (m.lk != "" or m.rk != ""):
		if m.rk != "" and m.rk == col:
			m.rk = ""
		elif m.lk == col:
			m.lk = ""
			m.rk = ""
		else:
			done = false
	else:
		done = false
	if done:
		_commit()
	else:
		undo_stack.pop_back()
		say("이 열에는 지울 칠이 없어요.")

func _tool_order() -> void:
	var col: String = cell_column().name
	_push_undo()
	if m.order == null or m.order.col != col:
		m.order = {"col": col, "dir": "DESC"}
	elif m.order.dir == "DESC":
		m.order = {"col": col, "dir": "ASC"}
	else:
		m.order = null
		m.limit = -1
	_commit()

func _tool_limit() -> void:
	if m.order == null:
		say("정렬 전에 개수를 자를 수 없어요. 먼저 줄을 세워 주세요.")
		_op("limit_before_order", false)
		return
	_push_undo()
	m.limit = {-1: 1, 1: 2, 2: 3, 3: -1}[m.limit]
	_commit()

func _brush_group() -> void:
	if r == 5:
		return
	var col: String = cell_column().name
	_push_undo()
	if m.group == col:
		m.group = ""
		m.having = null
	else:
		m.group = col
		m.having = null
	_commit()

func _toggle_agg(a: Dictionary) -> void:
	if activity == "group" and r == 5:
		a = {"fn": a.fn, "col": a.col if a.col == "*" else "score"}
	_push_undo()
	var i: int = m.aggs.find(a)
	if i >= 0:
		m.aggs.remove_at(i)
		m.having = null
	else:
		m.aggs.append(a)
	_commit()

func _tool_avg() -> void:
	var col: String = cell_column().name if not (activity == "group" and r == 5) else "score"
	if not _column_is_numeric(col):
		say("평균은 숫자 열에서만 계산할 수 있어요.")
		return
	if activity == "sub":
		_tool_inner("AVG")
	else:
		_toggle_agg({"fn": "AVG", "col": col})

func _tool_having() -> void:
	if r != 5:
		say("로봇을 아래 요약 서랍으로 내려서 조건을 찍어 주세요.")
		return
	var labels: Array = m.aggs.map(func(a): return Model.agg_label(a))
	if labels.is_empty():
		say("먼저 계산 도구로 요약 값을 만드세요.")
		return
	var avg_i: int = labels.find("AVG(score)")
	palette = {"mode": "having", "agg": labels[avg_i if avg_i >= 0 else labels.size() - 1], "op": 0, "val": WHERE_VALUES.find(80)}
	phase = "palette"

func _brush_key() -> void:
	var info := cell_column()
	_push_undo()
	if info.side == "left":
		m.lk = info.name
		m.rk = ""
	elif m.lk == "":
		undo_stack.pop_back()
		say("왼쪽 표의 키 열부터 칠해 주세요.")
		return
	else:
		m.rk = info.name
	_commit()

func _tool_mode() -> void:
	_push_undo()
	m.join = "LEFT" if m.join == "INNER" else "INNER"
	_commit()

func _tool_inner(fn: String) -> void:
	var col: String = cell_column().name
	if not _column_is_numeric(col):
		say("숫자 열에서 계산해 주세요.")
		return
	_push_undo()
	m.inner = {"fn": fn, "col": col}
	_commit()

func _tool_compare() -> void:
	if m.inner == null:
		say("아직 비교할 토큰이 없어요. 계산 붓을 먼저 쓰세요.")
		return
	var col: String = cell_column().name
	if not _column_is_numeric(col):
		say("토큰은 숫자 열과 비교해요.")
		return
	palette = {"mode": "compare", "col": col, "op": 0}
	phase = "palette"

func _palette_input(ev: InputEventKey) -> void:
	var k: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
	var ops: Array = COMPARE_OPS if palette.mode == "compare" else Model.NUMERIC_OPS
	match k:
		KEY_A, KEY_LEFT: palette.op = wrapi(palette.op - 1, 0, ops.size())
		KEY_D, KEY_RIGHT: palette.op = wrapi(palette.op + 1, 0, ops.size())
		KEY_W, KEY_UP:
			if palette.has("val"):
				palette.val = wrapi(palette.val + 1, 0, WHERE_VALUES.size())
		KEY_S, KEY_DOWN:
			if palette.has("val"):
				palette.val = wrapi(palette.val - 1, 0, WHERE_VALUES.size())
		KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if not ev.echo:
				confirm_palette()
		KEY_ESCAPE, KEY_X:
			palette = null
			phase = "play"
	queue_redraw()

func confirm_palette() -> void:
	var ops: Array = COMPARE_OPS if palette.mode == "compare" else Model.NUMERIC_OPS
	_push_undo()
	match palette.mode:
		"where":
			m.cond = {"col": palette.col, "op": ops[palette.op], "val": WHERE_VALUES[palette.val]}
		"having":
			m.having = {"agg": palette.agg, "op": ops[palette.op], "val": WHERE_VALUES[palette.val]}
		"compare":
			m.outer_op = ops[palette.op]
			m.outer_col = palette.col
	palette = null
	phase = "play"
	_commit()

# ---------- 판정 ----------
func _target_model() -> Dictionary:
	var t := Model.new_model()
	t.merge(_level().target, true)
	return t

func judge() -> Dictionary:
	var t := _target_model()
	var want := Model.compile(activity, t, tables)
	match activity:
		"query": return _judge_query(t, want)
		"group": return _judge_group(t, want)
		"join": return _judge_join(t, want)
	return _judge_sub(t, want)

func _names(rows: Array) -> Array:
	return rows.map(func(row): return Model.fmt(row[0]))

func _diff_rows(mine: Array, want: Array) -> String:
	var parts := []
	var lost: Array = want.filter(func(n): return not mine.has(n))
	var extra: Array = mine.filter(func(n): return not want.has(n))
	if not lost.is_empty():
		parts.append("빠진 행: " + ", ".join(lost))
	if not extra.is_empty():
		parts.append("남으면 안 되는 행: " + ", ".join(extra))
	return " · ".join(parts)

func _same_rows(a: Array, b: Array) -> bool:
	var x: Array = a.map(func(row): return str(row))
	var y: Array = b.map(func(row): return str(row))
	x.sort()
	y.sort()
	return x == y

func _judge_query(t: Dictionary, want: Dictionary) -> Dictionary:
	if m.select != t.select:
		var missing: Array = t.select.filter(func(col): return not m.select.has(col))
		if not missing.is_empty():
			return {"ok": false, "msg": "의뢰에 필요한 열이 아직 안 칠해졌어요.", "cols": missing}
		var extra: Array = m.select.filter(func(col): return not t.select.has(col))
		if not extra.is_empty():
			return {"ok": false, "msg": "의뢰에 없는 열이 칠해져 있어요: " + ", ".join(extra), "cols": []}
		return {"ok": false, "msg": "열 순서가 의뢰와 달라요.", "cols": []}
	if t.order != null and (m.order == null or m.limit < 0):
		return {"ok": false, "msg": "1등을 고르려면 줄을 세우고 개수를 정해야 해요.", "cols": []}
	var same: bool = res.rows == want.rows if t.order != null else _same_rows(res.rows, want.rows)
	if same:
		return {"ok": true, "msg": "의뢰한 명단이 정확히 나왔어요."}
	var diff := _diff_rows(_names(res.rows), _names(want.rows))
	return {"ok": false, "msg": diff if diff != "" else "행 순서가 의뢰와 달라요.", "cols": []}

func _judge_group(t: Dictionary, want: Dictionary) -> Dictionary:
	if m.group != t.group:
		return {"ok": false, "msg": "묶는 기준 열이 의뢰와 달라요.", "cols": [t.group] if m.group == "" else []}
	var mine: Array = m.aggs.map(func(a): return Model.agg_label(a))
	var need: Array = t.aggs.map(func(a): return Model.agg_label(a))
	var lost: Array = need.filter(func(x): return not mine.has(x))
	var extra: Array = mine.filter(func(x): return not need.has(x))
	if not lost.is_empty():
		return {"ok": false, "msg": "요약에 필요한 계산이 빠졌어요: " + ", ".join(lost), "cols": []}
	if not extra.is_empty():
		return {"ok": false, "msg": "의뢰에 없는 계산이 있어요: " + ", ".join(extra), "cols": []}
	var a := _names(res.rows)
	var b := _names(want.rows)
	a.sort()
	b.sort()
	if a == b:
		return {"ok": true, "msg": "부서별 요약이 맞아요."}
	return {"ok": false, "msg": _diff_rows(_names(res.rows), _names(want.rows)).replace("행", "그룹"), "cols": []}

func _judge_join(t: Dictionary, want: Dictionary) -> Dictionary:
	if m.lk != t.lk:
		return {"ok": false, "msg": "왼쪽 키 열이 달라요. 부서 번호가 있는 열을 찾아 보세요.", "cols": []}
	if m.rk != t.rk:
		return {"ok": false, "msg": "오른쪽 키 열이 달라요. 같은 번호가 들어 있는 열을 찾아 보세요.", "cols": []}
	if _same_rows(res.rows, want.rows):
		return {"ok": true, "msg": "같은 키끼리 정확히 연결됐어요."}
	return {"ok": false, "msg": _diff_rows(_names(res.rows), _names(want.rows)) + " · 짝 없는 학생을 어떻게 처리할지 보세요.", "cols": []}

func _judge_sub(t: Dictionary, want: Dictionary) -> Dictionary:
	if m.inner == null or m.inner.fn != t.inner.fn or m.inner.col != t.inner.col:
		return {"ok": false, "msg": "안쪽 계산이 의뢰에 필요한 값이 아니에요.", "cols": []}
	if t.outer_op == "":
		return {"ok": m.outer_op == "", "msg": "평균 토큰이 만들어졌어요." if m.outer_op == "" else "이번 의뢰는 평균만 구하면 돼요.", "cols": []}
	if m.outer_op == "":
		return {"ok": false, "msg": "토큰을 비교 붓으로 표에 적용해 주세요.", "cols": []}
	if m.select != t.select:
		return {"ok": false, "msg": "출력할 열을 확인해 주세요.", "cols": t.select.filter(func(col): return not m.select.has(col))}
	if _same_rows(res.rows, want.rows):
		return {"ok": true, "msg": "계산한 값으로 정확히 골랐어요."}
	return {"ok": false, "msg": _diff_rows(_names(res.rows), _names(want.rows)) + " · 비교 기호의 뜻을 확인해 보세요.", "cols": []}

func submit() -> void:
	if phase != "play":
		return
	if not res.complete:
		say("아직 질의가 완성되지 않았어요. 오른쪽 SQL의 주석을 보세요.")
		_op("submit_incomplete", false)
		return
	var v := judge()
	if v.ok:
		phase = "solved"
		wrong_cols = []
		say(v.msg + " Enter로 다음으로 가요.", true)
		var stars := _stars()
		_telemetry("complete_attempt", [stage_id, true, "", {"level": level + 1, "mistakes": mistakes, "stars": stars}])
	else:
		mistakes += 1
		wrong_cols = v.cols
		say(v.msg)
		_op("submit_wrong", false, v.msg)
	queue_redraw()

func _stars() -> int:
	return 3 if mistakes == 0 else (2 if mistakes <= 2 else 1)

func _after_solved() -> void:
	if level < game.levels.size() - 1:
		_load_level(level + 1)
		_place_robot(true)
		return
	var stars := _stars()
	MiniGameBase.record_clear(stage_id, stars)
	_telemetry("complete_task", [stage_id, {"mistakes": mistakes, "stars": stars, "completed_levels": 3}])
	saved.erase(stage_id)
	_go_menu()

# ---------- 화면 ----------
func _process(delta: float) -> void:
	var need := false
	if message_t > 0.0:
		message_t -= delta
		need = message_t <= 0.0
	if splash > 0.0:
		splash -= delta
		need = true
	for k in changed.keys():
		changed[k] -= delta
		need = true
		if changed[k] <= 0.0:
			changed.erase(k)
	if need:
		queue_redraw()

func tex(name: String) -> Texture2D:
	if not textures.has(name):
		textures[name] = load(PATH % name)
	return textures[name]

func img(name: String, rect: Rect2, tint := Color.WHITE) -> void:
	draw_texture_rect(tex(name), rect, false, tint)

func text_at(p: Vector2, t: String, size: int, col := INK, center := true, f: Font = null) -> void:
	var fnt: Font = f if f else font
	var x := p.x
	if center:
		x -= fnt.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2
	draw_string(fnt, Vector2(x, p.y + size * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func fit(t: String, width: float, size: int, f: Font = null) -> int:
	var fnt: Font = f if f else font
	var s := size
	while s > 10 and fnt.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width:
		s -= 1
	return s

func _draw() -> void:
	img("bg_" + game.bg, Rect2(0, 0, 1280, 720))
	_draw_mission()
	match activity:
		"query", "sub": _draw_board_single()
		"group": _draw_board_single()
		"join": _draw_board_join()
	if activity == "group":
		_draw_summary()
	if activity == "sub":
		_draw_strip()
	_draw_panel()
	_draw_tools()
	_draw_tooltip()
	_draw_footer()
	if phase == "palette":
		_draw_palette()
	if phase == "help":
		_draw_help()

func _draw_mission() -> void:
	var rect: Rect2 = {"query": Rect2(73, 8, 810, 92), "group": Rect2(329, 6, 621, 70), "join": Rect2(434, 6, 413, 94), "sub": Rect2(452, 6, 380, 80)}[activity]
	img("mission_plate", rect)
	var t: String = _level().mission
	var size := fit(t, rect.size.x - 60, 24)
	text_at(rect.get_center() + Vector2(0, -8), t, size, NAVY)
	text_at(rect.get_center() + Vector2(0, 22), "%s · %d / 3단계" % [game.id, level + 1], 15, Color("7a5a2a"))

func _is_col_selected(col: String) -> bool:
	return m.select.has(col)

func _row_hits(i: int) -> bool:
	var active: bool = m.cond != null or m.outer_op != ""
	return active and res.pass.has(i)

func _group_of(row: int) -> int:
	for g in res.groups.size():
		if res.groups[g].rows.has(row):
			return g
	return -1

func _cell_style(row: int, col: int) -> String:
	var name: String = tables.left.cols[col]
	if activity == "group":
		var g := _group_of(row)
		if g >= 0 and m.group != "":
			return "cell_g%d" % ((g % 3) + 1)
		return "cell_plain"
	var sel := _is_col_selected(name)
	var hit := _row_hits(row)
	if sel and hit:
		return "cell_hit"
	if hit:
		return "cell_row"
	if sel:
		return "cell_col"
	return "cell_plain"

func _draw_board_single() -> void:
	var t: Dictionary = tables.left
	for col in 5:
		var rect := cell_rect(0, col)
		var hr := Rect2(rect.position.x + 3, rect.position.y - 44, rect.size.x - 6, 40)
		var name: String = t.cols[col]
		var on: bool = _is_col_selected(name) or m.group == name or (m.inner != null and m.inner.col == name)
		img("header_on" if on else "header_plain", hr)
		text_at(hr.get_center(), name, 20)
		var order_i: int = m.select.find(name)
		if order_i >= 0:
			text_at(hr.position + Vector2(16, 14), str(order_i + 1), 15, NAVY)
		if wrong_cols.has(name):
			text_at(hr.position + Vector2(hr.size.x - 14, 12), "?", 22, RED)
	for row in 5:
		var rect := cell_rect(row, 0)
		var size_b: float = minf(rect.size.y - 8, 58.0)
		var br := Rect2(rect.position.x - size_b - 6, rect.get_center().y - size_b / 2, size_b, size_b)
		img("row_badge", br)
		text_at(br.get_center(), str(row + 1), 22, Color.WHITE)
		if _row_hits(row):
			text_at(br.position + Vector2(-8, 6), "✓", 20, Color("2d7a3a"))
		for col in 5:
			_draw_cell(row, col, t)
	_draw_cursor()

func _draw_cell(row: int, col: int, t: Dictionary) -> void:
	var rect := cell_rect(row, col)
	var style := _cell_style(row, col)
	var dim: bool = activity == "group" and _group_hidden(row)
	img(style, rect, Color(1, 1, 1, 0.45) if dim else Color.WHITE)
	if activity == "group":
		var g := _group_of(row)
		if g >= 0 and m.group != "" and g % 3 > 0:
			img("pattern_g%d" % ((g % 3) + 1), rect)
	var v = t.rows[row][col]
	if v == null:
		img("pattern_null", rect)
	var s := fit(Model.fmt(v), rect.size.x - 12, 24 if rect.size.x > 90 else 20)
	text_at(rect.get_center() + Vector2(0, -6), Model.fmt(v), s, INK.lerp(Color(0.5, 0.5, 0.5), 0.5) if v == null else INK)

func _group_hidden(row: int) -> bool:
	var g := _group_of(row)
	return g >= 0 and res.groups[g].hidden

func _draw_cursor() -> void:
	if phase == "palette" and palette.mode == "having":
		return
	if activity == "group" and r == 5:
		return
	var rect := cell_rect(r, c)
	draw_rect(rect.grow(2), GOLD, false, 4.0)
	if splash > 0.0:
		draw_arc(rect.get_center(), 40.0 + (0.3 - splash) * 130.0, 0, TAU, 28, Color(GOLD, splash * 3.0), 4.0)

func _draw_board_join() -> void:
	_draw_join_table(tables.left, 0, 102.0)
	_draw_join_table(tables.right, 5, 540.0)
	if res.complete:
		var lc: int = tables.left.cols.find(m.lk)
		for p in res.pairs:
			if p[1] < 0:
				continue
			var a := cell_rect(p[0], lc)
			var b := cell_rect(p[1], 5 + tables.right.cols.find(m.rk))
			var from := a.position + Vector2(a.size.x, a.size.y / 2)
			var to := b.position + Vector2(0, b.size.y / 2)
			var col: Color = JOIN_COLORS[_key_color(tables.left.rows[p[0]][lc])]
			var pts := PackedVector2Array()
			for i in 21:
				var t := i / 20.0
				var mid := Vector2((from.x + to.x) / 2, from.y)
				var mid2 := Vector2((from.x + to.x) / 2, to.y)
				pts.append(from.lerp(mid, t).lerp(mid.lerp(mid2, t), t).lerp(mid.lerp(mid2, t).lerp(mid2.lerp(to, t), t), t))
			draw_polyline(pts, INK, 6.0, true)
			draw_polyline(pts, col, 3.5, true)
	_draw_cursor()

## 실제로 연결된 키 값에만 색을 준다. 값이 같으면 양쪽 표에서 같은 색이다.
func _key_color(v) -> int:
	var lc: int = tables.left.cols.find(m.lk)
	var keys := []
	for p in res.pairs:
		if p[1] >= 0 and not keys.has(tables.left.rows[p[0]][lc]):
			keys.append(tables.left.rows[p[0]][lc])
	keys.sort()
	return maxi(keys.find(v), 0) % JOIN_COLORS.size()

func _key_is_linked(v) -> bool:
	if not res.complete:
		return false
	var lc: int = tables.left.cols.find(m.lk)
	for p in res.pairs:
		if p[1] >= 0 and tables.left.rows[p[0]][lc] == v:
			return true
	return false

func _draw_join_table(t: Dictionary, offset: int, x: float) -> void:
	var plate := Rect2(x + 90, 150, 200, 40)
	img("header_plain", plate)
	text_at(plate.get_center(), t.name, 22, NAVY)
	var key: String = m.lk if offset == 0 else m.rk
	for col in 5:
		var rect := cell_rect(0, col + offset)
		var hr := Rect2(rect.position.x + 1, rect.position.y - 42, rect.size.x - 2, 38)
		var name: String = t.cols[col]
		img("header_on" if key == name else "header_plain", hr)
		text_at(hr.get_center(), name, fit(name, hr.size.x - 8, 16))
		for row in 5:
			var cr := cell_rect(row, col + offset)
			img("cell_plain", cr)
			var v = t.rows[row][col]
			if key == name and v != null:
				var c_tint: Color = JOIN_COLORS[_key_color(v)] if _key_is_linked(v) else Color("9fd3ff")
				draw_rect(cr.grow(-4), Color(c_tint, 0.5 if _key_is_linked(v) else 0.22))
			if key == name and offset == 0 and res.complete and not _matched(row):
				img("pattern_null", cr)
			if v == null:
				img("pattern_null", cr)
			text_at(cr.get_center() + Vector2(0, -4), Model.fmt(v), fit(Model.fmt(v), cr.size.x - 8, 18), Color("6a6a6a") if v == null else INK)

func _matched(row: int) -> bool:
	for p in res.pairs:
		if p[0] == row and p[1] >= 0:
			return true
	return false

func _draw_summary() -> void:
	for i in res.groups.size():
		var g: Dictionary = res.groups[i]
		var rect := summary_rect(i)
		img("summary_%d" % ((i % 3) + 1), rect, Color(1, 1, 1, 0.45) if g.hidden else Color.WHITE)
		var text_value: String = Model.fmt(g.key)
		if not g.values.is_empty():
			text_value += ": " + " / ".join(g.values.map(func(v): return Model.fmt(v)))
		text_at(Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.27), text_value, fit(text_value, rect.size.x - 44, 20), Color("777777") if g.hidden else NAVY)
		if activity == "group" and r == 5 and c == i:
			draw_rect(rect.grow(2), GOLD, false, 4.0)

func _draw_strip() -> void:
	var y := 606.0
	var col_i: int = tables.left.cols.find(m.inner.col) if m.inner != null else 2
	for i in 5:
		var v = tables.left.rows[i][col_i]
		var rect := Rect2(172 + i * 88, y, 82, 50)
		img("strip_null" if v == null else "strip_cell", rect)
		text_at(rect.get_center(), Model.fmt(v), 20)
	if res.token != null:
		var token_rect := Rect2(616, y - 6, 160, 62)
		img("token", token_rect)
		text_at(token_rect.get_center(), Model.fmt(res.token), 26, Color("1f6a3a"))
		if m.outer_op != "":
			var plate := Rect2(330, 128, 280, 50)
			img("mission_plate", plate)
			text_at(plate.get_center(), "%s  %s %s" % [m.outer_col, m.outer_op, Model.fmt(res.token)], 22, NAVY)

func _draw_panel() -> void:
	var wide := activity == "join"
	var panel := Rect2(930, 118, 340, 406) if wide else Rect2(826, 112, 360, 432)
	var k: float = panel.size.x / 472.0
	img("panel_sql", panel)
	var code_box := Rect2(panel.position + Vector2(26, 50) * (k / 0.7627), Vector2(436, 224) * k * 0.92)
	var y := code_box.position.y + 12
	var line_h: float = minf(26.0, (code_box.size.y - 10) / maxi(res.sql.size(), 1))
	for i in res.sql.size():
		var ln: Dictionary = res.sql[i]
		if changed.has(i):
			draw_rect(Rect2(code_box.position.x - 4, y - 2, code_box.size.x + 6, line_h - 2), Color(GOLD, 0.35))
		if ln.kind == "inner":
			draw_rect(Rect2(code_box.position.x - 4, y - 2, code_box.size.x + 6, line_h - 2), Color(GOLD, 0.14))
		_draw_code_line(Vector2(code_box.position.x + 4, y + 16), ln, code_box.size.x - 8)
		y += line_h
	_draw_result(Rect2(panel.position + Vector2(68, 344) * k, Vector2(340, 156) * k))

func _draw_code_line(p: Vector2, ln: Dictionary, width: float) -> void:
	var size := fit(ln.text, width, 17, code_font)
	var x := p.x
	if ln.kind == "comment":
		draw_string(code_font, p, ln.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, CODE_COMMENT)
		return
	var base := CODE_INNER if ln.kind == "inner" else CODE_TEXT
	for token in ln.text.split(" ", true):
		var word: String = token + " "
		var col := CODE_KEY if KEYWORDS.has(token.strip_edges()) else base
		draw_string(code_font, Vector2(x, p.y), word, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += code_font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func _draw_result(rect: Rect2) -> void:
	if not res.complete:
		text_at(rect.get_center(), "결과 없음", 18, Color("8a7a60"))
		return
	var cols: Array = res.columns
	if res.rows.is_empty():
		text_at(rect.get_center(), "(결과 0행)", 18, Color("8a7a60"))
		return
	var w: float = rect.size.x / cols.size()
	var row_h := 22.0
	for i in cols.size():
		var cell := Rect2(rect.position + Vector2(i * w, 0), Vector2(w, row_h))
		draw_rect(cell, Color("2f5fb3"))
		var label: String = str(cols[i])
		text_at(cell.get_center(), label, fit(label, w - 6, 14), Color.WHITE)
	var rows: Array = res.rows
	for j in mini(rows.size(), 5):
		for i in cols.size():
			var cell := Rect2(rect.position + Vector2(i * w, (j + 1) * row_h), Vector2(w, row_h))
			draw_rect(cell, Color("fff9e8"))
			draw_rect(cell, Color("d9c9a8"), false, 1.0)
			var t := Model.fmt(rows[j][i])
			text_at(cell.get_center(), t, fit(t, w - 6, 15), Color("888888") if rows[j][i] == null else INK)
	if rows.size() > 5:
		text_at(Vector2(rect.get_center().x, rect.end.y + 2), "+%d행 더" % (rows.size() - 5), 13, NAVY)

func _draw_tools() -> void:
	var wide := activity == "join"
	var tray := Rect2(930, 538, 340, 124) if wide else Rect2(826, 556, 360, 122)
	img("tool_tray", tray)
	var tools: Dictionary = _level().tools
	var slots: Array = tools.keys()
	slots.sort()
	var n: int = slots.size() + 1
	var cell_w: float = (tray.size.x - 28) / n
	var i := 0
	for slot in slots:
		var id: String = tools[slot]
		var info: Array = Data.TOOL_INFO[id]
		var rect := Rect2(tray.position.x + 14 + i * cell_w, tray.position.y + 14, cell_w - 6, tray.size.y - 50)
		img(info[1] if info[1] != "" else "tool_blank", rect)
		if info[1] == "":
			text_at(rect.get_center(), info[0], fit(info[0], rect.size.x - 8, 18), NAVY)
		if id == tool_id:
			draw_rect(rect.grow(2), GOLD, false, 4.0)
		text_at(rect.position + Vector2(10, 10), slot, 16, NAVY)
		text_at(Vector2(rect.get_center().x, rect.end.y + 12), info[0], fit(info[0], rect.size.x + 4, 13), Color.WHITE)
		i += 1
	var rect := Rect2(tray.position.x + 14 + i * cell_w, tray.position.y + 14, cell_w - 6, tray.size.y - 50)
	img("tool_submit", rect)
	text_at(Vector2(rect.get_center().x, rect.end.y + 12), "Enter 제출", 13, Color.WHITE)

func _draw_tooltip() -> void:
	if activity == "group" and r == 5:
		return
	var rect := cell_rect(r, c)
	var b := board_of(c)
	var v = b.table.rows[r][b.col]
	var t := Model.fmt(v)
	var w: float = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 16
	var tip := Rect2(rect.end.x - w, rect.position.y - 6, w, 24)
	draw_rect(tip, Color("fff6dc"))
	draw_rect(tip, INK, false, 2.0)
	text_at(tip.get_center(), t, 16)

func _draw_footer() -> void:
	draw_rect(Rect2(0, 690, 1280, 30), Color(0.08, 0.08, 0.12, 0.8))
	var controls := "WASD 이동 · E 칠하기 · 숫자키 도구 · Z 취소 · X 처음으로 · F 힌트 · H 설명 · Enter 제출 · Esc 메뉴"
	text_at(Vector2(16, 705), controls, 15, Color.WHITE, false)
	if message_t > 0.0 and message != "":
		var w: float = font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 36
		var box := Rect2(640 - w / 2, 652, w, 34)
		draw_rect(box, Color(0.08, 0.08, 0.12, 0.92))
		text_at(box.get_center(), message, 20, Color("7ddc8a") if message_good else Color("ffd38a"))

func _draw_palette() -> void:
	var ops: Array = COMPARE_OPS if palette.mode == "compare" else Model.NUMERIC_OPS
	var box := Rect2(280, 250, 500, 150)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.3))
	img("mission_plate", box)
	var title: String = {"where": palette.get("col", "") + " 조건", "having": palette.get("agg", "") + " 조건", "compare": "토큰과 비교"}[palette.mode]
	text_at(box.get_center() + Vector2(0, -44), title, 22, NAVY)
	var preview: String = "%s %s" % [ops[palette.op], Model.fmt(WHERE_VALUES[palette.val]) if palette.has("val") else Model.fmt(res.token)]
	text_at(box.get_center(), preview, 34, INK)
	var meaning: String = {">=": "이상", ">": "초과", "=": "같음", "<=": "이하", "<": "미만"}[ops[palette.op]]
	text_at(box.get_center() + Vector2(0, 44), "%s  ·  A/D 기호  W/S 숫자  E 적용  Esc 취소" % meaning, 15, Color("7a5a2a"))

func _draw_help() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.55))
	var box := Rect2(240, 190, 800, 300)
	img("mission_plate", box)
	text_at(box.get_center() + Vector2(0, -90), game.title, 30, NAVY)
	var lines := ["로봇을 WASD로 옮기고 E로 붓을 찍어요. 값은 바뀌지 않아요.", "붓 한 번이 SQL 한 줄이 되어 오른쪽에 바로 보여요.", "숫자키로 도구를 바꾸고, 다 됐으면 Enter로 제출해요."]
	for i in lines.size():
		text_at(box.get_center() + Vector2(0, -28 + i * 38), lines[i], 21)
	text_at(box.get_center() + Vector2(0, 100), "아무 키나 누르면 시작", 16, Color("7a5a2a"))
