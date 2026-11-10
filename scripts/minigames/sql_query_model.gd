extends RefCounted
## SQL 5x5 서랍 게임의 단일 상태 모델.
## 색칠 범위, SQL 문장, 결과표를 모두 이 상태에서 계산한다. 정답 SQL 을 따로 보여 주는 코드는 없다.

const NUMERIC_OPS := [">=", ">", "=", "<=", "<"]

static func new_model() -> Dictionary:
	return {"select": [], "cond": null, "order": null, "limit": -1,
		"group": "", "aggs": [], "having": null,
		"lk": "", "rk": "", "join": "INNER",
		"inner": null, "outer_op": "", "outer_col": ""}

static func agg_label(a: Dictionary) -> String:
	return "%s(%s)" % [a.fn, a.col]

static func test(v, op: String, x) -> bool:
	if v == null or x == null:
		return false
	if typeof(v) == TYPE_STRING or typeof(x) == TYPE_STRING:
		return op == "=" and str(v) == str(x)
	match op:
		">=": return v >= x
		">": return v > x
		"=": return is_equal_approx(float(v), float(x))
		"<=": return v <= x
		"<": return v < x
	return false

static func aggregate(fn: String, values: Array):
	var nums := values.filter(func(v): return v != null)
	match fn:
		"COUNT": return nums.size()
		"AVG":
			if nums.is_empty():
				return null
			var total := 0.0
			for v in nums:
				total += float(v)
			return total / nums.size()
		"MAX":
			return nums.max() if not nums.is_empty() else null
	return null

static func literal(x) -> String:
	return "'%s'" % x if typeof(x) == TYPE_STRING else str(x)

static func fmt(v) -> String:
	if v == null:
		return "NULL"
	if v is float:
		return str(int(v)) if is_equal_approx(v, round(v)) else str(snappedf(v, 0.01))
	return str(v)

static func line(text: String, kind := "plain") -> Dictionary:
	return {"text": text, "kind": kind}

## mode: query / group / join / sub.  tables: {"left": {name, cols, rows}, "right": {...}}
static func compile(mode: String, m: Dictionary, tables: Dictionary) -> Dictionary:
	match mode:
		"query": return _query(m, tables.left)
		"group": return _group(m, tables.left)
		"join": return _join(m, tables.left, tables.right)
	return _sub(m, tables.left)

static func _empty(sql: Array) -> Dictionary:
	return {"complete": false, "sql": sql, "columns": [], "rows": [], "pass": [], "groups": [], "pairs": [], "token": null}

static func _pass_rows(table: Dictionary, cond) -> Array:
	var out := []
	var col: int = table.cols.find(cond.col) if cond != null else -1
	for i in table.rows.size():
		if cond == null or test(table.rows[i][col], cond.op, cond.val):
			out.append(i)
	return out

static func _query(m: Dictionary, t: Dictionary) -> Dictionary:
	var kept := _pass_rows(t, m.cond)
	if m.select.is_empty():
		var r := _empty([line("-- 열 붓으로 가져올 열을 칠하세요", "comment"), line("FROM %s" % t.name)])
		if m.cond != null:
			r.sql.append(line("WHERE %s %s %s" % [m.cond.col, m.cond.op, literal(m.cond.val)], "where"))
		r.pass = kept
		return r
	var sql := [line("SELECT " + ", ".join(m.select)), line("FROM " + t.name)]
	if m.cond != null:
		sql.append(line("WHERE %s %s %s" % [m.cond.col, m.cond.op, literal(m.cond.val)], "where"))
	var ordered := kept.duplicate()
	if m.order != null:
		var c: int = t.cols.find(m.order.col)
		var desc: bool = m.order.dir == "DESC"
		ordered.sort_custom(func(a, b):
			var x = t.rows[a][c]
			var y = t.rows[b][c]
			if x == null or y == null:
				return x != null and y == null if x != y else a < b
			if x == y:
				return a < b
			return x > y if desc else x < y)
		sql.append(line("ORDER BY %s %s" % [m.order.col, m.order.dir]))
	if m.limit >= 0:
		ordered = ordered.slice(0, m.limit)
		sql.append(line("LIMIT %d" % m.limit))
	var rows := []
	for i in ordered:
		rows.append(m.select.map(func(col): return t.rows[i][t.cols.find(col)]))
	return {"complete": true, "sql": sql, "columns": m.select.duplicate(), "rows": rows, "pass": kept, "groups": [], "pairs": [], "token": null}

static func _group(m: Dictionary, t: Dictionary) -> Dictionary:
	var kept := _pass_rows(t, m.cond)
	var labels: Array = m.aggs.map(func(a): return agg_label(a))
	var select_text := ", ".join(([m.group] if m.group != "" else []) + labels)
	var sql := []
	if select_text == "":
		sql.append(line("-- 그룹 붓이나 계산 도구를 쓰세요", "comment"))
	elif labels.size() >= 2 and m.group != "":
		sql.append(line("SELECT %s," % m.group))
		sql.append(line("  " + ", ".join(labels)))
	else:
		sql.append(line("SELECT " + select_text))
	sql.append(line("FROM " + t.name))
	if m.cond != null:
		sql.append(line("WHERE %s %s %s" % [m.cond.col, m.cond.op, literal(m.cond.val)], "where"))
	if m.group != "":
		sql.append(line("GROUP BY " + m.group))
	if m.having != null:
		sql.append(line("HAVING %s %s %s" % [m.having.agg, m.having.op, literal(m.having.val)], "where"))
	if select_text == "":
		return _empty(sql)
	var keys := []
	var buckets := {}
	var c: int = t.cols.find(m.group)
	for i in kept:
		var key = t.rows[i][c] if c >= 0 else "전체"
		if not buckets.has(key):
			buckets[key] = []
			keys.append(key)
		buckets[key].append(i)
	var groups := []
	var rows := []
	for key in keys:
		var values := []
		for a in m.aggs:
			values.append(_agg_value(a, buckets[key], t))
		var hidden := false
		if m.having != null:
			var hit := labels.find(m.having.agg)
			hidden = hit < 0 or not test(values[hit], m.having.op, m.having.val)
		groups.append({"key": key, "rows": buckets[key], "values": values, "hidden": hidden})
		if not hidden:
			rows.append(([key] if m.group != "" else []) + values)
	var columns := ([m.group] if m.group != "" else []) + labels
	return {"complete": true, "sql": sql, "columns": columns, "rows": rows, "pass": kept, "groups": groups, "pairs": [], "token": null}

static func _agg_value(a: Dictionary, indices: Array, t: Dictionary):
	if a.col == "*":
		return indices.size()
	var c: int = t.cols.find(a.col)
	return aggregate(a.fn, indices.map(func(i): return t.rows[i][c]))

static func _join(m: Dictionary, left: Dictionary, right: Dictionary) -> Dictionary:
	var head := [line("SELECT s.name, d.name"), line("FROM %s s" % left.name), line("%s JOIN %s d" % [m.join, right.name])]
	if m.lk == "":
		head.append(line("-- ON s.____ = d.____", "comment"))
		return _empty(head)
	if m.rk == "":
		head.append(line("-- ON s.%s = d.____" % m.lk, "comment"))
		return _empty(head)
	head.append(line("ON s.%s = d.%s" % [m.lk, m.rk], "where"))
	var lc: int = left.cols.find(m.lk)
	var rc: int = right.cols.find(m.rk)
	var ln: int = left.cols.find("name")
	var rn: int = right.cols.find("name")
	var rows := []
	var pairs := []
	for i in left.rows.size():
		var v = left.rows[i][lc]
		var found := false
		for j in right.rows.size():
			if v != null and right.rows[j][rc] == v:
				found = true
				rows.append([left.rows[i][ln], right.rows[j][rn]])
				pairs.append([i, j])
		if not found and m.join == "LEFT":
			rows.append([left.rows[i][ln], null])
			pairs.append([i, -1])
	return {"complete": true, "sql": head, "columns": ["s.name", "d.name"], "rows": rows, "pass": [], "groups": [], "pairs": pairs, "token": null}

static func _sub(m: Dictionary, t: Dictionary) -> Dictionary:
	if m.inner == null:
		return _empty([line("-- 계산 붓으로 먼저 값을 만드세요", "comment")])
	var c: int = t.cols.find(m.inner.col)
	var token = aggregate(m.inner.fn, t.rows.map(func(r): return r[c]))
	var inner_text := "SELECT %s(%s)" % [m.inner.fn, m.inner.col]
	if m.outer_op == "":
		var r := [line(inner_text, "inner"), line("FROM " + t.name, "inner")]
		return {"complete": true, "sql": r, "columns": ["%s(%s)" % [m.inner.fn, m.inner.col]], "rows": [[token]], "pass": [], "groups": [], "pairs": [], "token": token}
	var oc: int = t.cols.find(m.outer_col)
	var kept := []
	for i in t.rows.size():
		if test(t.rows[i][oc], m.outer_op, token):
			kept.append(i)
	var select_text: String = ", ".join(m.select) if not m.select.is_empty() else "____"
	var sql := [line("SELECT " + select_text if not m.select.is_empty() else "-- 열 붓으로 가져올 열을 칠하세요", "plain" if not m.select.is_empty() else "comment"),
		line("FROM " + t.name), line("WHERE %s %s (" % [m.outer_col, m.outer_op], "where"), line("  " + inner_text, "inner"), line("  FROM " + t.name, "inner"), line(");", "where")]
	if m.select.is_empty():
		var r := _empty(sql)
		r.pass = kept
		r.token = token
		return r
	var rows := []
	for i in kept:
		rows.append(m.select.map(func(col): return t.rows[i][t.cols.find(col)]))
	return {"complete": true, "sql": sql, "columns": m.select.duplicate(), "rows": rows, "pass": kept, "groups": [], "pairs": [], "token": token}
