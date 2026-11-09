extends WalkStage
## ST03 스택 - 최근 작업 복구실
## 복구 레벨: 입고 레일의 상자를 차례로 탑에 넣고(push) 꺼내(pop) 복구 작업대에 목표 순서대로 놓는다.
## 괄호 레벨: 글자 하나씩 탑(push) / 레버(pop) / 책상(불일치 선언)을 골라 괄호 검사기를 직접 돌린다.

const CAP := 3
const LEVELS := [
	{"type": "order", "in": ["A", "B", "C"], "out": ["C", "B", "A"], "goal": "복구 순서 C → B → A 맞추기"},
	{"type": "order", "in": ["A", "B", "C"], "out": ["B", "C", "A"], "goal": "복구 순서 B → C → A 맞추기"},
	{"type": "bracket", "s": "([]{})", "goal": "괄호 검사: 여는 괄호는 push, 닫는 괄호는 짝이면 pop"},
	{"type": "bracket", "s": "{[(])}", "goal": "괄호 검사: 짝이 안 맞는 순간 책상에서 불일치 선언"},
	{"type": "bracket", "s": "(()", "goal": "괄호 검사: 끝까지 읽고 결과 판정하기"},
]
const PAIR := {")": "(", "]": "[", "}": "{"}
const ORDER_KINDS := ["tower", "intake", "output"]

var L: Dictionary
var stack: Array = []
var inbox: Array = []
var out: Array = []
var target: Array = []
var hand = null
var step := 0
var board: Node2D

func _init() -> void:
	stage_id = "ST03"
	stage_title = "최근 작업 복구실"
	npc_name = "복구실 장인"
	npc_portrait = preload("res://textures/npc_portraits/NPC03_portrait.png")
	level_count = LEVELS.size()
	code_keywords += ["char"]
	intro = [
		"어이쿠, 왔구나! 난 복구실 장인이란다. 잘못된 작업은 가장 최근 것부터 되돌려야 해. 그래서 여기엔 아주 특별한 탑이 있지.",
		"저 왼쪽 탑을 보렴. 입구가 위쪽 하나뿐이라, 상자는 맨 위에만 쌓을 수 있고 맨 위에서만 꺼낼 수 있어. 이런 구조를 '스택'이라고 한단다.",
		"나중에 들어간 게 먼저 나온다고 해서 후입선출, LIFO라고 불러. 접시를 쌓는 거랑 똑같지. 맨 아래 접시는 위를 다 치워야 꺼낼 수 있어.",
		"넣는 걸 push, 꺼내는 걸 pop, 맨 위를 'top'이라고 해. 실행 취소나 뒤로 가기가 다 스택으로 만들어졌단다.",
		"조작법! 입고 레일에서 E로 상자를 집고, 탑 앞에서 E를 누르면 push, 빈손으로 E를 누르면 pop이야. 작업대에는 정해진 순서대로만 놓을 수 있어.",
		"뒤의 괄호 검사는 책상 위 글자판을 앞에서부터 읽는 일이란다. 여는 괄호는 탑에 push, 닫는 괄호는 레버로 pop하며 짝을 맞춰 보렴. 막히면 노란 화살표를 따라가!",
	]
	level_talk = [
		"첫 일감이야. A, B, C가 차례로 들어오는데 복구는 C, B, A 순서로 해야 해. 전부 탑에 넣었다가 꺼내면 저절로 거꾸로 되지!",
		"이번엔 B, C, A 순서야. 상자가 어떤 순서로 나올지 머릿속으로 그리면서 push와 pop을 번갈아 해 보렴.",
		"이제 괄호 검사기야! ([]{})를 읽자. 여는 괄호는 탑에 넣고, 닫는 괄호를 만나면 맨 위와 짝이 맞는지 보고 레버로 꺼내렴. 다 읽고 탑이 비면 복구 작업대에서 '올바름'을 선언해.",
		"{[(])} 이건 수상한데? 닫는 괄호가 맨 위와 짝이 안 맞는 순간, 책상으로 가서 '불일치'를 선언하렴.",
		"마지막은 (() 란다. 끝까지 읽었는데 탑에 괄호가 남아 있으면 닫히지 않은 거야. 그땐 입고 레일에서 '남음'을 선언해.",
	]

func build_stage() -> void:
	board = Node2D.new()
	overlay.add_child(board)

func setup_level(n: int) -> void:
	L = LEVELS[n]
	stack = []
	out = []
	hand = null
	step = 0
	goal_text = L.goal
	if L.type == "order":
		inbox = L.in.duplicate()
		target = L.out
	else:
		inbox = []
		target = []
	spot("lever").enabled = L.type == "bracket"
	spot("desk").enabled = L.type == "bracket"

func get_state() -> Dictionary:
	return {"s": stack, "i": inbox, "o": out, "h": hand, "t": step}

func set_state(s: Dictionary) -> void:
	stack = s.s
	inbox = s.i
	out = s.o
	hand = s.h
	step = s.t

func rebuild() -> void:
	var want := {}
	if L.type == "order":
		for i in stack.size():
			want[stack[i]] = {"text": stack[i], "pos": mark("Stack%d" % i), "scale": 0.72}
		for i in out.size():
			want[out[i]] = {"text": out[i], "pos": mark("Out%d" % i), "scale": 0.8}
		for i in inbox.size():
			want[inbox[i]] = {"text": inbox[i], "pos": mark("Inbox") + Vector2(-i * 60, -i * 14), "scale": 0.8}
		if hand != null:
			want[hand] = {"text": hand, "pos": hold_pos(), "scale": 0.8}
	else:
		for i in stack.size():
			want["b%d" % i] = {"text": stack[i], "pos": mark("Stack%d" % i), "scale": 0.72}
	sync_items(want, hand)
	_draw_board()

func _draw_board() -> void:
	clear_children(board)
	if L.type != "bracket":
		return
	var s: String = L.s
	var w := 58.0
	var c := mark("Board")
	panel_at(Rect2(c.x - s.length() * w / 2 - 14, c.y - 44, s.length() * w + 28, 88), Color("3b2a1c"), StageHUD.INK, 4, board)
	for i in s.length():
		var fill := Color("f6e7c8")
		if i < step:
			fill = Color("8fa08b")
		elif i == step:
			fill = StageHUD.GOLD
		var x := c.x - s.length() * w / 2 + i * w
		panel_at(Rect2(x + 3, c.y - 34, w - 6, 68), fill, StageHUD.INK, 3, board)
		text_at(s[i], Vector2(x + w / 2, c.y), 38, StageHUD.INK, 0, board)

func info_rows() -> Array:
	var rows := [["스택", "[" + ", ".join(stack) + "]"], ["top", "-" if stack.is_empty() else stack.back()], ["크기", "%d / %d" % [stack.size(), CAP]]]
	if L.type == "order":
		rows.append(["들고 있는 상자", "-" if hand == null else hand])
	else:
		rows.append(["읽는 위치", "%d / %d" % [mini(step + 1, L.s.length()), L.s.length()]])
	return rows

func state_text() -> String:
	var cells := []
	for v in stack:
		cells.append("'%s'" % v)
	var t := "stack = [lb]%s[rb]" % ", ".join(cells)
	t += "\ntop = %s" % ("없음" if stack.is_empty() else "'%s'" % stack.back())
	if L.type == "order" and hand != null:
		t += "\ntemp = '%s'  [color=#7fbf7f]// 로봇이 든 상자[/color]" % hand
	elif L.type == "bracket" and step < L.s.length():
		t += "\nch = '%s'" % L.s[step]
	return t

func prompt(t: Interactable) -> String:
	if L.type == "order":
		match t.kind:
			"tower": return "push (%s 넣기)" % hand if hand != null else ("pop (%s 꺼내기)" % stack.back() if not stack.is_empty() else "탑 (비어 있음)")
			"intake": return "다음 상자 집기" if hand == null else "입고 레일"
			"output": return "%d번 자리에 놓기" % (out.size() + 1) if hand != null else "복구 작업대"
	else:
		var more: bool = step < L.s.length()
		match t.kind:
			"tower": return "push '%s'" % L.s[step] if more else "괄호 탑"
			"lever": return "pop (짝 맞추기)" if more else "pop 레버"
			"desk": return "불일치 선언"
			"output": return "다 읽음: 올바름 선언"
			"intake": return "다 읽음: 괄호 남음 선언"
	return t.prompt

func interact(t: Interactable) -> void:
	if L.type == "order":
		_order(t)
	else:
		_bracket(t)
	rebuild()

func _order(t: Interactable) -> void:
	match t.kind:
		"intake":
			if hand != null:
				wrong("이미 상자를 들고 있어요.")
			elif inbox.is_empty():
				wrong("입고 레일이 비어 있어요.")
			else:
				snapshot()
				hand = inbox.pop_front()
				code("temp = '%s';" % hand, "새 상자")
		"tower":
			if hand != null:
				if stack.size() >= CAP:
					wrong("탑이 가득 찼어요. 먼저 pop 하세요.")
					return
				snapshot()
				stack.append(hand)
				code_replace("stack.push('%s');" % hand, "맨 위에 쌓기")
				hand = null
				moves += 1
			elif stack.is_empty():
				wrong("탑이 비어 있어요.")
			else:
				snapshot()
				hand = stack.pop_back()
				code("temp = stack.pop();", "'%s' 꺼내기" % hand)
		"output":
			if hand == null:
				wrong("먼저 상자를 들고 오세요.")
			elif hand != target[out.size()]:
				wrong("지금 복구할 상자는 %s 예요." % target[out.size()])
			else:
				snapshot()
				out.append(hand)
				code("result.add('%s');" % hand, "%d번째 복구" % out.size())
				hand = null
				moves += 1
				if out == target:
					win("복구 순서 %s 완성!\n실수 %d회" % [" → ".join(out), mistakes])

func _bracket(t: Interactable) -> void:
	var s: String = L.s
	if t.kind == "output" or t.kind == "intake":
		if step < s.length():
			wrong("아직 글자를 다 읽지 않았어요.")
			return
		var correct := "output" if stack.is_empty() else "intake"
		if t.kind != correct:
			wrong("스택 상태를 다시 보세요.")
			return
		code("return %s;" % ("true" if correct == "output" else "false"), "스택이 비었나?")
		win("판정 정답! " + ("스택이 비어 올바른 괄호예요." if correct == "output" else "닫히지 않은 괄호 %d개가 남았어요." % stack.size()) + "\n실수 %d회" % mistakes)
		return
	if step >= s.length():
		wrong("다 읽었어요. 복구 작업대(올바름)나 입고 레일(남음)에서 판정하세요.")
		return
	var ch := s[step]
	var need := "tower"
	if PAIR.has(ch):
		need = "lever" if not stack.is_empty() and stack.back() == PAIR[ch] else "desk"
	if t.kind != need:
		match need:
			"tower": wrong("'%s' 는 여는 괄호라 탑에 push 해야 해요." % ch)
			"lever": wrong("'%s' 의 짝이 top 과 맞으니 레버로 pop 해야 해요." % ch)
			"desk": wrong("'%s' 의 짝이 top 과 맞지 않아요. 책상에서 불일치 선언!" % ch)
		return
	snapshot()
	moves += 1
	match need:
		"tower":
			stack.append(ch)
			code("stack.push('%s');" % ch, "여는 괄호")
			step += 1
		"lever":
			stack.pop_back()
			code("stack.pop();", "'%s' 와 짝" % ch)
			step += 1
		"desk":
			code("return false;", "'%s' 짝이 안 맞음" % ch)
			win("정답! '%s' 에서 짝이 어긋나는 걸 찾아냈어요.\n실수 %d회" % [ch, mistakes])

func summary_code() -> void:
	if L.type != "bracket":
		code("")
		code("// 나중에 넣은 것이 먼저 나와요 (LIFO)")

func next_action() -> Array:
	if L.type == "order":
		if hand != null:
			if hand == target[out.size()]:
				return [spot("output"), "복구 작업대에 놓기"]
			return [spot("tower"), "탑에 push"]
		if not stack.is_empty() and stack.back() == target[out.size()]:
			return [spot("tower"), "%s pop" % stack.back()]
		if not inbox.is_empty():
			return [spot("intake"), "다음 상자 집기"]
		return [null, ""]
	var s: String = L.s
	if step >= s.length():
		return [spot("output"), "올바름 선언"] if stack.is_empty() else [spot("intake"), "괄호 남음 선언"]
	var ch := s[step]
	if not PAIR.has(ch):
		return [spot("tower"), "'%s' push" % ch]
	if not stack.is_empty() and stack.back() == PAIR[ch]:
		return [spot("lever"), "'%s' 짝 맞추기" % ch]
	return [spot("desk"), "불일치 선언"]
