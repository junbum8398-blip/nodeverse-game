extends MiniGameBase
## ST03 스택 - 최근 작업 복구실
## 예측 레벨: push/pop 작업표를 보고 꺼내질 순서를 미리 고른 뒤, 실행해서 채점.
## 괄호 레벨: 문자 하나씩 Push / Pop / 짝 불일치 를 골라 괄호 검사기를 직접 돌린다.

const LEVELS := [
	{"type": "predict", "ops": ["push A", "push B", "push C", "pop", "pop", "pop"], "goal": "꺼낼 순서를 예측하세요"},
	{"type": "predict", "ops": ["push A", "push B", "pop", "push C", "push D", "pop", "pop", "pop"], "goal": "꺼낼 순서를 예측하세요"},
	{"type": "bracket", "s": "([]{})", "goal": "괄호 검사기: 여는 괄호는 Push, 닫는 괄호는 짝이 맞으면 Pop"},
	{"type": "bracket", "s": "{[(])}", "goal": "괄호 검사기: 짝이 안 맞는 순간 '불일치'를 선언하세요"},
	{"type": "bracket", "s": "(()", "goal": "괄호 검사기: 끝까지 읽은 뒤 결과를 판정하세요"},
]
const PAIR := {")": "(", "]": "[", "}": "{"}

var L: Dictionary
var stack: Array = []
var guess: Array = []
var answer: Array = []
var step := 0
var running := false
var run_t := 0.0
var out: Array = []

func _init() -> void:
	stage_id = "ST03"
	stage_title = "최근 작업 복구실"
	level_count = LEVELS.size()

func setup_level(n: int) -> void:
	L = LEVELS[n]
	goal = L.goal
	stack = []
	guess = []
	out = []
	step = 0
	running = false
	answer = []
	if L.type == "predict":
		var s := []
		for op in L.ops:
			if op.begins_with("push"):
				s.append(op.substr(5))
			else:
				answer.append(s.pop_back())

func get_state() -> Dictionary:
	return {"stack": stack, "guess": guess, "step": step, "out": out, "moves": moves}

func set_state(s: Dictionary) -> void:
	stack = s.stack
	guess = s.guess
	step = s.step
	out = s.out
	moves = s.moves

func info_lines() -> Array:
	return [["STACK", "[" + ",".join(stack) + "]"], ["top", "-" if stack.is_empty() else stack.back()], ["크기", stack.size()]]

func controls_text() -> String:
	return "버튼 클릭으로 선택 · Z 되돌리기 · R 초기화 · Esc 메뉴"

func _process(delta: float) -> void:
	super(delta)
	if running:
		run_t -= delta
		if run_t <= 0:
			_run_step()

func letters() -> Array:
	var ls := []
	for op in L.ops:
		if op.begins_with("push"):
			ls.append(op.substr(5))
	return ls

func on_button(id) -> void:
	if running:
		return
	var sid := str(id)
	if L.type == "predict":
		if sid.begins_with("pick_"):
			var c := sid.substr(5)
			if c in guess or guess.size() >= answer.size():
				return
			push_undo()
			guess.append(c)
		elif sid == "run":
			running = true
			run_t = 0.3
			step = 0
			stack = []
			out = []
		return
	# bracket
	var s: String = L.s
	if sid == "push" or sid == "pop" or sid == "mismatch":
		if step >= s.length():
			return
		var ch := s[step]
		var opener := not PAIR.has(ch)
		var ok_action := ""
		if opener:
			ok_action = "push"
		elif not stack.is_empty() and stack.back() == PAIR[ch]:
			ok_action = "pop"
		else:
			ok_action = "mismatch"
		if sid != ok_action:
			var why := {"push": "'%s'는 여는 괄호라 Push 해야 해요." % ch,
				"pop": "'%s'의 짝이 top(%s)과 맞으니 Pop 해야 해요." % [ch, "" if stack.is_empty() else stack.back()],
				"mismatch": "'%s'의 짝이 top과 맞지 않아요 → 불일치!" % ch}
			wrong(why[ok_action], "act")
			return
		push_undo()
		moves += 1
		if sid == "push":
			stack.append(ch)
		elif sid == "pop":
			stack.pop_back()
		else:
			win("정답! '%s' 에서 짝이 어긋나는 걸 찾아냈어요." % ch)
			return
		step += 1
	elif sid == "valid" or sid == "leftover":
		if step < s.length():
			wrong("아직 문자를 다 읽지 않았어요.")
			return
		var correct := "valid" if stack.is_empty() else "leftover"
		if sid == correct:
			win("판정 정답! " + ("스택이 비어 올바른 괄호예요." if correct == "valid" else "닫히지 않은 괄호 %d개가 남았어요." % stack.size()))
		else:
			wrong("스택 상태를 다시 보세요.", "act")

func _run_step() -> void:
	if step >= L.ops.size():
		running = false
		if out == guess:
			win("예측 성공! 꺼낸 순서 %s" % " ".join(out))
		else:
			mistakes += 1
			say("✗ 예측 %s ≠ 실제 %s. Z로 고쳐 보세요." % [" ".join(guess), " ".join(out)], C_RED, 5.0)
		return
	var op: String = L.ops[step]
	if op.begins_with("push"):
		stack.append(op.substr(5))
	else:
		out.append(stack.pop_back())
	step += 1
	run_t = 0.55

func draw_game() -> void:
	# 스택 탑(세로 보관함)
	var base := Vector2(200, 560)
	pbox(Rect2(base.x - 70, 150, 140, 430), Color("8d8f99"), C_INK)
	draw_rect(Rect2(base.x - 54, 166, 108, 398), Color("3b3f4a"))
	for i in stack.size():
		var r := Rect2(base.x - 50, base.y - 4 - (i + 1) * 56, 100, 52)
		if L.type == "predict":
			crate(r, stack[i], C_GOLD.darkened(0.1), i == stack.size() - 1)
		else:
			crate(r, stack[i], C_CRATE, i == stack.size() - 1)
	text_c("top ↓", Vector2(base.x, 140), 18, C_GOLD)
	robot(Vector2(330, 580), "")
	if L.type == "predict":
		_draw_predict()
	else:
		_draw_bracket()

func _draw_predict() -> void:
	pbox(Rect2(420, 110, 580, 120), C_PANEL, C_INK)
	text("작업표", Vector2(440, 144), 18, C_PANEL_DARK)
	var x := 440.0
	for i in L.ops.size():
		var op: String = L.ops[i]
		var lab := op.replace("push ", "push(") + (")" if op.begins_with("push") else "()")
		var w := text_w(lab, 17) + 18
		if x + w > 990:
			x = 440
		var fill := C_BLUE if op.begins_with("push") else C_RED
		if running and i == step - 1:
			fill = C_GOLD
		label_box(Rect2(x, 160 + (0 if i < 5 else 0), w, 36), lab, fill, C_WHITE, 17)
		x += w + 6
	pbox(Rect2(420, 260, 580, 300), C_PANEL, C_INK)
	text("나의 예측 (pop 될 순서대로 클릭)", Vector2(440, 296), 18, C_PANEL_DARK)
	for i in answer.size():
		var r := Rect2(440 + i * 84, 316, 72, 72)
		pbox(r, Color("d8c7a3"), C_INK, false)
		if i < guess.size():
			crate(r.grow(-6), guess[i], C_GOLD)
		if i < out.size():
			text_c(out[i], r.get_center() + Vector2(0, 66), 22, C_GREEN if out[i] == guess[i] else C_RED)
	if not out.is_empty():
		text("실제:", Vector2(440, 446), 16, C_INK)
	var ls := letters()
	for i in ls.size():
		button(Rect2(440 + i * 84, 470, 72, 52), ls[i], "pick_" + ls[i], not (ls[i] in guess) and not running and not level_done, 24)
	button(Rect2(820, 470, 160, 52), "실행 ▶", "run", guess.size() == answer.size() and not running and not level_done, 20, C_GREEN)

func _draw_bracket() -> void:
	var s: String = L.s
	pbox(Rect2(420, 110, 580, 130), C_PANEL, C_INK)
	text("입력 문자열", Vector2(440, 144), 18, C_PANEL_DARK)
	for i in s.length():
		var r := Rect2(440 + i * 70, 160, 60, 64)
		var fill := C_WHITE
		if i < step:
			fill = Color("b9c2b0")
		elif i == step:
			fill = C_GOLD
		pbox(r, fill, C_INK, false)
		text_c(s[i], r.get_center() + Vector2(0, 12), 34, C_INK)
	var enabled := not level_done and step < s.length()
	var flash := flashing("act")
	pbox(Rect2(420, 270, 580, 150), C_RED.darkened(0.4) if flash else C_PANEL, C_INK)
	text("현재 문자에 맞는 동작은?", Vector2(440, 306), 18, C_WHITE if flash else C_PANEL_DARK)
	button(Rect2(440, 330, 170, 64), "Push", "push", enabled, 24)
	button(Rect2(625, 330, 170, 64), "Pop", "pop", enabled, 24, C_GREEN)
	button(Rect2(810, 330, 170, 64), "짝 불일치!", "mismatch", enabled, 22, C_RED)
	pbox(Rect2(420, 440, 580, 120), C_PANEL, C_INK)
	text("끝까지 읽었다면 판정", Vector2(440, 476), 18, C_PANEL_DARK)
	var fin := not level_done and step >= s.length()
	button(Rect2(440, 490, 260, 52), "올바른 괄호", "valid", fin, 20, C_GREEN)
	button(Rect2(720, 490, 260, 52), "닫히지 않은 괄호 남음", "leftover", fin, 18, C_RED)
