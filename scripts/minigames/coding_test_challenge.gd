extends "res://scripts/minigames/mini_game_base.gd"
## 종합 도전 섬 (CHALLENGE) — 판테온 종합 코딩테스트 미니게임
## 목표 결과(Target Output)를 화면에 띄워놓고, 직접 키보드 타이핑 또는 단어 조각 클릭으로
## 내 코드의 실시간 출력(Live Output)을 목표 결과와 일치시키는 하이브리드 코딩테스트.
## 타이핑할 때마다 오른쪽 코딩 데스크의 로봇이 촐싹거리며 타자를 치는 애니메이션이 재생된다.

const STAGE_ID := "ST10"
const ROBOT_BASE_POS := Vector2(1098.0, 360.0)
const ROBOT_BASE_SCALE := Vector2(0.54, 0.54)

const LEVELS := [
	{
		"badge": "STAGE 1/4 · 자료구조 (스택)",
		"title": "작업 취소(UNDO) 로그 복구기",
		"goal": "입력 로그에서 'UNDO'가 나오면 직전 기록을 스택에서 꺼내 제거하여 목표 결과가 나오게 하세요.",
		"input_label": "logs = [\"연결\", \"검증\", \"오류\", \"UNDO\", \"완료\"]",
		"target_output": "[\"연결\", \"검증\", \"완료\"]",
		"code_before": [
			"def process_logs(logs):",
			"    stack = []",
			"    for item in logs:",
			"        if item == \"UNDO\":"
		],
		"code_prefix": "            ",
		"code_suffix": "",
		"code_after": [
			"        else:",
			"            stack.append(item)",
			"    return stack"
		],
		"tokens": ["stack", ".pop()", ".append(item)", ".clear()", "logs", "[0]"],
		"answers": ["stack.pop()"],
		"hint": "스택(Stack)에서 가장 마지막에 넣은 원소 하나를 꺼내 제거하는 메서드는 stack.pop() 입니다."
	},
	{
		"badge": "STAGE 2/4 · 알고리즘 (탐색·필터링)",
		"title": "80점 이상 우수 탐험가 점수 추출",
		"goal": "점수 배열에서 80점 이상인 점수만 순서대로 남아 목표 결과가 나오도록 if 조건식을 완성하세요.",
		"input_label": "scores = [55, 92, 78, 85, 60, 96]",
		"target_output": "[92, 85, 96]",
		"code_before": [
			"def filter_passed(scores):",
			"    passed = []",
			"    for s in scores:"
		],
		"code_prefix": "        if ",
		"code_suffix": ":",
		"code_after": [
			"            passed.append(s)",
			"    return passed"
		],
		"tokens": ["s", ">=", ">", "<=", "==", "80", "60", "90"],
		"answers": ["s >= 80", "s>=80", "80 <= s", "80<=s", "s > 79", "s>79"],
		"hint": "변수 s가 80 이상인지 검사하려면 s >= 80 을 입력하세요."
	},
	{
		"badge": "STAGE 3/4 · SQL (조건 조회 & 정렬)",
		"title": "판테온 명예의 전당 높은 점수순 정렬",
		"goal": "80점 이상 영웅을 점수(score)가 높은 순서(내림차순·DESC)로 정렬해 목표 결과가 나오게 하세요.",
		"input_label": "heroes = [(민지, 90), (준호, 65), (서연, 95), (하늘, 82)]",
		"target_output": "[[\"서연\", 95], [\"민지\", 90], [\"하늘\", 82]]",
		"code_before": [
			"SELECT name, score",
			"FROM heroes",
			"WHERE score >= 80"
		],
		"code_prefix": "",
		"code_suffix": "",
		"code_after": [],
		"tokens": ["ORDER BY", "GROUP BY", "score", "name", "DESC", "ASC", "LIMIT 1"],
		"answers": ["ORDER BY score DESC", "ORDER BY SCORE DESC"],
		"hint": "점수 기준 내림차순 정렬은 ORDER BY score DESC 입니다."
	},
	{
		"badge": "STAGE 4/4 · 데이터 분석 (결측치 정제)",
		"title": "결측치(None) 제거 후 센서 평균 계산",
		"goal": "센서 기록에서 결측치(None)가 아닌 정상 값만 골라내어 목표 평균(90.0)이 나오게 하세요.",
		"input_label": "raw = [80, None, 90, None, 100]",
		"target_output": "90.0   (정제된 데이터: [80, 90, 100])",
		"code_before": [
			"def clean_average(raw):"
		],
		"code_prefix": "    clean = [x for x in raw if ",
		"code_suffix": "]",
		"code_after": [
			"    return sum(clean) / len(clean)"
		],
		"tokens": ["x", "!=", "is not", "==", "None", "0", "> 0"],
		"answers": ["x != None", "x!=None", "x is not None", "x > 0", "x>0"],
		"hint": "x가 결측치(None)가 아닌 조건은 x != None 또는 x is not None 입니다."
	}
]

const TYPING_CHATTER := [
	"타닥타닥! ⚡",
	"오오 코딩중! 🐾",
	"영차영차! 💻",
	"키보드 불난다🔥",
	"척척 완성중! ✨",
	"타자 소리 경쾌해! 🎵"
]

var typed_code := ""
var code_font: Font
var bot_sprite: Sprite2D
var robot_bubble := "키보드로 타이핑하거나 아래 단어 조각을 눌러보세요!"
var robot_bounce_t := 0.0
var robot_tilt_dir := 1.0
var keycap_sparks: Array = [] # [{pos: Vector2, txt: String, t: float, vel: Vector2}]
var phase := "play" # play / solved / all_cleared
var status_msg := ""
var status_good := false
var hints_used := 0

func _ready() -> void:
	load_progress()
	font = load("res://fonts/NotoSansKR_Medium.tres")
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["D2Coding", "Consolas", "Cascadia Mono", "Malgun Gothic"])
	code_font = f
	bg = load("res://textures/stages/ST10/bg_game.png")

	bot_sprite = Sprite2D.new()
	bot_sprite.texture = load("res://textures/sprites/robot.png")
	bot_sprite.position = ROBOT_BASE_POS
	bot_sprite.scale = ROBOT_BASE_SCALE
	bot_sprite.offset = Vector2(0, -71)
	bot_sprite.z_index = 4
	add_child(bot_sprite)

	_telemetry("start_task", [STAGE_ID, {"level": 1, "mode": "coding_test"}])
	_load_level(0)

func _telemetry(fn: String, args: Array) -> void:
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.callv(fn, args)

func _load_level(idx: int) -> void:
	level = clampi(idx, 0, LEVELS.size() - 1)
	typed_code = ""
	phase = "play"
	status_msg = "목표 결과가 나오도록 빈칸 코드를 직접 타이핑하거나 아래 단어 조각을 클릭하세요!"
	status_good = false
	robot_bubble = "준비 완료! 타자를 치면 제가 옆에서 열심히 응원할게요! 🤖"
	_reset_robot_pose()
	_telemetry("start_attempt", [STAGE_ID, level + 1, {"goal": LEVELS[level].title}])
	queue_redraw()

func _reset_robot_pose() -> void:
	if bot_sprite == null:
		return
	bot_sprite.position = ROBOT_BASE_POS
	bot_sprite.scale = ROBOT_BASE_SCALE
	bot_sprite.rotation_degrees = 0.0

## 타이핑할 때마다 로봇이 옆에서 촐싹거리며(좌우 까딱 + 점프 + 젤리 스쿼시) 반응한다!
func _trigger_robot_typing_hop(key_label: String, is_backspace := false) -> void:
	if bot_sprite == null:
		return
	robot_tilt_dir = -robot_tilt_dir
	robot_bounce_t = 0.35
	if is_backspace:
		robot_bubble = "앗 지워지워! 다시 쳐봐요 💦"
	else:
		robot_bubble = TYPING_CHATTER[randi() % TYPING_CHATTER.size()]
	var tw := create_tween()
	var jump_y := -18.0 if not is_backspace else -8.0
	var tilt := (14.0 if not is_backspace else 20.0) * robot_tilt_dir
	tw.tween_property(bot_sprite, "position", ROBOT_BASE_POS + Vector2(robot_tilt_dir * 9.0, jump_y), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bot_sprite, "scale", Vector2(ROBOT_BASE_SCALE.x * 1.14, ROBOT_BASE_SCALE.y * 0.86), 0.05)
	tw.parallel().tween_property(bot_sprite, "rotation_degrees", tilt, 0.06)
	tw.tween_property(bot_sprite, "position", ROBOT_BASE_POS, 0.11).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bot_sprite, "scale", ROBOT_BASE_SCALE, 0.11)
	tw.parallel().tween_property(bot_sprite, "rotation_degrees", 0.0, 0.11)

	# 키캡 이펙트 파티클 추가
	if key_label != "":
		keycap_sparks.append({
			"pos": ROBOT_BASE_POS + Vector2(randf_range(-42.0, 42.0), -64.0),
			"txt": key_label,
			"t": 0.55,
			"vel": Vector2(randf_range(-28.0, 28.0), -68.0)
		})
	if _is_output_matched():
		robot_bubble = "와아!! 내 출력이 목표 결과랑 100% 똑같아요! [제출] 눌러요!! 🎉"

func _normalize_code(s: String) -> String:
	var out := s.strip_edges()
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out

func _is_output_matched() -> bool:
	var lv: Dictionary = LEVELS[level]
	var norm := _normalize_code(typed_code)
	for ans: String in lv.answers:
		if norm.to_lower() == _normalize_code(ans).to_lower():
			return true
	return false

## 현재 작성 중인 코드의 실시간 실행 결과(Live Output)를 시뮬레이션하여 문자열로 반환한다.
func _evaluate_live_output() -> Dictionary:
	var norm := _normalize_code(typed_code)
	var low := norm.to_lower()
	if _is_output_matched():
		return {
			"matched": true,
			"output": str(LEVELS[level].target_output),
			"note": "🎯 목표 결과와 100% 일치합니다! [Enter] 또는 [채점 & 제출] 버튼을 누르세요!"
		}
	if norm == "":
		match level:
			0: return {"matched": false, "output": "[\"연결\", \"검증\", \"오류\", \"완료\"]", "note": "아직 빈칸입니다 — '오류'가 UNDO에서 제거되지 않고 남아 있어요."}
			1: return {"matched": false, "output": "[] (조건식 미입력)", "note": "아직 if 조건식이 비어 있습니다."}
			2: return {"matched": false, "output": "[[\"민지\", 90], [\"서연\", 95], [\"하늘\", 82]]", "note": "80점 이상만 추려졌지만 아직 높은 점수순(DESC) 정렬이 안 됐어요."}
			3: return {"matched": false, "output": "TypeError: None 값은 더할 수 없습니다!", "note": "결측치(None)를 걸러내는 if 조건을 완성해 주세요."}
	match level:
		0:
			if low.contains("clear"):
				return {"matched": false, "output": "[\"완료\"]", "note": "stack.clear()는 이전 기록을 전부 지워버려요! 직전 1개만 꺼내는 메서드를 써보세요."}
			elif low.contains("append"):
				return {"matched": false, "output": "[\"연결\", \"검증\", \"오류\", \"UNDO\", \"완료\"]", "note": "append는 오히려 UNDO를 추가해요! 꺼내는(pop) 메서드가 필요합니다."}
			elif low == "stack":
				return {"matched": false, "output": "[\"연결\", \"검증\", \"오류\", \"완료\"]", "note": "stack 뒤에 마지막 원소를 꺼내는 메서드(.pop())를 붙여 보세요!"}
		1:
			if low.contains("60"):
				return {"matched": false, "output": "[92, 78, 85, 60, 96]", "note": "60점 이상이 모두 나왔어요! 목표 결과([92, 85, 96])가 되려면 기준 점수를 확인하세요."}
			elif low.contains("90"):
				return {"matched": false, "output": "[92, 96]", "note": "85점이 빠졌어요! 80점 이상이 남도록 조건을 맞춰 보세요."}
			elif low == "s > 80" or low == "s>80":
				return {"matched": false, "output": "[92, 85, 96] (주의: 경계값 80점 포함 필요)", "note": "80점 이상이므로 '>' 대신 '>=' 연산자를 사용해 보세요!"}
		2:
			if low.contains("asc"):
				return {"matched": false, "output": "[[\"하늘\", 82], [\"민지\", 90], [\"서연\", 95]]", "note": "점수가 낮은 순(ASC)으로 정렬되었어요! 높은 순(DESC)으로 바꿔보세요."}
			elif low.contains("order by score"):
				return {"matched": false, "output": "[[\"하늘\", 82], [\"민지\", 90], [\"서연\", 95]]", "note": "기본 정렬은 오름차순이에요. 뒤에 내림차순 키워드(DESC)를 붙여 보세요!"}
			elif low.contains("group by"):
				return {"matched": false, "output": "SQL 알림: 그룹 묶기가 아니라 줄 세우기(ORDER BY)가 필요합니다.", "note": "정렬에는 ORDER BY를 사용합니다."}
		3:
			if low.contains("== none"):
				return {"matched": false, "output": "ZeroDivisionError / TypeError (None만 남음)", "note": "None과 같은 값이 아니라 None이 아닌(!= None 또는 is not None) 값만 남겨야 해요!"}
	return {
		"matched": false,
		"output": "실행 대기 중... (현재 입력: \"%s\")" % norm,
		"note": "단어 조각을 조합하거나 타이핑을 마저 입력해 목표 결과와 똑같이 만들어 보세요!"
	}

func _append_token(tok: String) -> void:
	if phase != "play":
		return
	if typed_code == "" or typed_code.ends_with(" ") or tok.begins_with(".") or tok.begins_with("["):
		typed_code += tok
	else:
		typed_code += " " + tok
	_trigger_robot_typing_hop(tok, false)
	_telemetry("record_operation", ["token_click", true, "", {"token": tok}, {}, {"stage": STAGE_ID, "level": level + 1}])
	queue_redraw()

func _backspace_word_or_char(word_mode := false) -> void:
	if phase != "play" or typed_code.is_empty():
		return
	if word_mode:
		var stripped := typed_code.strip_edges()
		var last_sp := stripped.rfind(" ")
		var last_dot := stripped.rfind(".")
		var cut := maxi(last_sp, last_dot)
		typed_code = stripped.substr(0, cut) if cut > 0 else ""
	else:
		typed_code = typed_code.substr(0, typed_code.length() - 1)
	_trigger_robot_typing_hop("⌫", true)
	queue_redraw()

func _submit_code() -> void:
	if phase == "solved":
		if level < LEVELS.size() - 1:
			_load_level(level + 1)
		else:
			phase = "all_cleared"
			var stars := 3 if mistakes == 0 else (2 if mistakes <= 2 else 1)
			MiniGameBase.record_clear(STAGE_ID, stars)
			_telemetry("complete_task", [STAGE_ID, {"mistakes": mistakes, "stars": stars, "completed_levels": LEVELS.size()}])
			robot_bubble = "축하합니다!! 4개 섬 종합 코딩테스트를 모두 정복했어요!! 🏆"
			queue_redraw()
		return
	if phase == "all_cleared":
		_back_to_world()
		return
	if _is_output_matched():
		phase = "solved"
		status_good = true
		status_msg = "✅ 테스트케이스 1~3 모두 PASS! [Enter 키] 또는 [다음 문제] 버튼을 누르세요!"
		robot_bubble = "정답이에요!! 타자 실력 최고!! 🎉"
		var stars := 3 if mistakes == 0 else (2 if mistakes <= 2 else 1)
		_telemetry("complete_attempt", [STAGE_ID, true, "", {"level": level + 1, "mistakes": mistakes, "stars": stars}])
		_trigger_robot_typing_hop("PASS! 🎉", false)
	else:
		mistakes += 1
		status_good = false
		var ev := _evaluate_live_output()
		status_msg = "❌ 출력 불일치: " + str(ev.get("note", "목표 결과와 내 출력을 비교해 보세요!"))
		robot_bubble = "앗! 목표 결과랑 내 출력이 아직 조금 달라요! 힌트(F)나 조각을 확인해봐요!"
		_telemetry("record_operation", ["submit_wrong", false, status_msg, {"typed": typed_code}, {}, {"stage": STAGE_ID, "level": level + 1, "mistakes": mistakes}])
		_trigger_robot_typing_hop("?!", true)
	queue_redraw()

func _show_hint() -> void:
	hints_used += 1
	status_good = false
	status_msg = "💡 힌트: " + str(LEVELS[level].hint)
	robot_bubble = "힌트를 찾았어요! 아래 파란 안내창을 확인해 보세요! 💡"
	_telemetry("record_operation", ["hint", true, "", {}, {}, {"hint_id": "1", "level": level + 1, "mistakes": mistakes}])
	queue_redraw()

func _back_to_world() -> void:
	var world = load("res://scripts/nodeverse_world.gd")
	if world.return_from_2d(get_tree()):
		return
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		mouse = ev.position
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for b in _buttons:
			if b[0].has_point(ev.position) and b[2]:
				_on_button(str(b[1]))
				return
		return
	if not (ev is InputEventKey and ev.pressed):
		return
	var k: int = ev.keycode if ev.keycode != 0 else ev.physical_keycode
	if k == KEY_ESCAPE:
		_back_to_world()
		return
	if k == KEY_ENTER or k == KEY_KP_ENTER:
		if not ev.echo:
			_submit_code()
		return
	if k == KEY_BACKSPACE:
		_backspace_word_or_char(false)
		return
	if ev.unicode >= 32 and ev.unicode < 127 and phase == "play":
		var ch := char(ev.unicode)
		typed_code += ch
		_trigger_robot_typing_hop(ch, false)
		queue_redraw()

func _on_button(action: String) -> void:
	if action == "world":
		_back_to_world()
	elif action == "submit":
		_submit_code()
	elif action == "hint":
		_show_hint()
	elif action == "clear":
		typed_code = ""
		_trigger_robot_typing_hop("CLR", true)
		queue_redraw()
	elif action == "back_word":
		_backspace_word_or_char(true)
	elif action.begins_with("tok:"):
		_append_token(action.substr(4))
	elif action.begins_with("lv:"):
		_load_level(int(action.substr(3)))

func _process(delta: float) -> void:
	time += delta
	for i in range(keycap_sparks.size() - 1, -1, -1):
		var sp: Dictionary = keycap_sparks[i]
		sp["t"] = float(sp["t"]) - delta
		sp["pos"] = (sp["pos"] as Vector2) + (sp["vel"] as Vector2) * delta
		if float(sp["t"]) <= 0.0:
			keycap_sparks.remove_at(i)
	queue_redraw()

func _draw() -> void:
	_buttons.clear()
	if bg:
		draw_texture_rect(bg, Rect2(0, 0, 1280, 720), false)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.08, 0.15, 0.92))

	var lv: Dictionary = LEVELS[level]
	# 상단 헤더 바
	pbox(Rect2(24, 14, 1232, 62), Color("111b2e"), Color("38bdf8"))
	text("🏛️ 판테온 종합 코딩테스트 — " + str(lv.badge), Vector2(42, 42), 20, Color("7dd3fc"))
	text(str(lv.title) + " : " + str(lv.goal), Vector2(42, 66), 15, Color("e2e8f0"))
	button(Rect2(890, 24, 150, 42), "💡 힌트 보기", "hint", true, 16, Color("1e3a8a"))
	button(Rect2(1052, 24, 188, 42), "3D 월드로 복귀", "world", true, 16, Color("2d6a4f"))

	# 1. 좌상단: 주어진 입력 (Input) vs 우상단: 만들어야 할 목표 결과 (Target Output)
	var in_box := Rect2(24, 84, 444, 78)
	pbox(in_box, Color("16213a"), Color("475569"))
	text("📥 주어진 입력 데이터 (Input)", in_box.position + Vector2(16, 25), 16, Color("93c5fd"))
	draw_string(code_font, in_box.position + Vector2(16, 56), str(lv.input_label), HORIZONTAL_ALIGNMENT_LEFT, 412, 16, Color("f8fafc"))

	var target_box := Rect2(480, 84, 444, 78)
	pbox(target_box, Color("132a24"), Color("34d399"))
	text("🎯 만들어야 할 목표 결과 (Target Output)", target_box.position + Vector2(16, 25), 16, Color("6ee7b7"))
	draw_string(code_font, target_box.position + Vector2(16, 56), "▶ " + str(lv.target_output), HORIZONTAL_ALIGNMENT_LEFT, 412, 17, Color("a7f3d0"))

	# 2. 중앙 코드 에디터 (직접 키보드 타이핑 + 단어 조각 클릭 모두 가능, 8줄 이상 여유롭게 표시)
	var ed_box := Rect2(24, 170, 900, 258)
	pbox(ed_box, Color("0b111e"), Color("60a5fa"))
	text("⌨️ 코드 에디터 — 키보드로 직접 타이핑하거나 아래 단어 조각을 클릭해 빈칸을 완성하세요!", ed_box.position + Vector2(16, 24), 15, Color("93c5fd"))

	var y := ed_box.position.y + 52.0
	var line_step := 24.0
	var line_no := 1
	for ln: String in lv.code_before:
		draw_string(code_font, Vector2(ed_box.position.x + 18, y), "%d | %s" % [line_no, ln], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("cbd5e1"))
		y += line_step
		line_no += 1

	# 플레이어가 타이핑하는 핵심 줄 하이라이트
	var input_line_rect := Rect2(ed_box.position.x + 14, y - 18, ed_box.size.x - 28, 26)
	draw_rect(input_line_rect, Color(0.22, 0.38, 0.68, 0.35))
	draw_rect(input_line_rect, Color("fbbf24"), false, 2.0)
	var cursor_str := "▌" if int(time * 2.5) % 2 == 0 and phase == "play" else ""
	var active_line := "%d | %s%s%s%s" % [line_no, str(lv.code_prefix), typed_code, cursor_str, str(lv.code_suffix)]
	draw_string(code_font, Vector2(ed_box.position.x + 18, y), active_line, HORIZONTAL_ALIGNMENT_LEFT, ed_box.size.x - 36, 18, Color("fde047"))
	y += line_step + 2.0
	line_no += 1

	for ln2: String in lv.code_after:
		draw_string(code_font, Vector2(ed_box.position.x + 18, y), "%d | %s" % [line_no, ln2], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("cbd5e1"))
		y += line_step
		line_no += 1

	# 3. 단어 조각 조립 트레이 (클릭 한 번으로 코드 입력)
	var tok_box := Rect2(24, 434, 900, 90)
	pbox(tok_box, Color("151f36"), Color("475569"))
	text("🧩 단어 조각 클릭으로 조립 (직접 키보드 타이핑도 가능!):", tok_box.position + Vector2(16, 23), 15, Color("cbd5e1"))
	var tx := tok_box.position.x + 16.0
	var ty := tok_box.position.y + 34.0
	for tok: String in lv.tokens:
		var bw := maxf(float(tok.length()) * 13.0 + 30.0, 68.0)
		button(Rect2(tx, ty, bw, 42), tok, "tok:" + tok, phase == "play", 17, Color("1e3a5f"))
		tx += bw + 10.0
	button(Rect2(tok_box.end.x - 236, ty, 108, 42), "⌫ 단어지움", "back_word", phase == "play", 15, Color("475569"))
	button(Rect2(tok_box.end.x - 118, ty, 102, 42), "↺ 초기화", "clear", phase == "play", 15, Color("7f1d1d"))

	# 4. 실시간 내 코드 출력 비교 콘솔 (Live Output vs Target Output)
	var ev := _evaluate_live_output()
	var matched: bool = ev.get("matched", false)
	var out_box := Rect2(24, 530, 900, 116)
	pbox(out_box, Color("0f291e") if matched else Color("1c1926"), Color("34d399") if matched else Color("f59e0b"))
	text("⚡ 내 코드의 실시간 출력 (Live Output) — 위쪽 [🎯 목표 결과]와 비교해 보세요!", out_box.position + Vector2(16, 26), 16, Color("6ee7b7") if matched else Color("fcd34d"))
	draw_string(code_font, out_box.position + Vector2(16, 62), "▶ " + str(ev.get("output", "")), HORIZONTAL_ALIGNMENT_LEFT, 680, 18, Color("a7f3d0") if matched else Color("fef08a"))
	text(str(ev.get("note", "")), out_box.position + Vector2(16, 96), 15, Color("86efac") if matched else Color("cbd5e1"))

	var sub_lbl := "▶ 다음 단계로 (Enter)" if phase == "solved" else ("🏆 코딩테스트 완료!" if phase == "all_cleared" else "▶ 채점 & 제출 (Enter)")
	button(Rect2(out_box.end.x - 216, out_box.position.y + 32, 198, 56), sub_lbl, "submit", true, 18, Color("059669") if (matched or phase != "play") else Color("2563eb"))

	# 5. 우측 전용 코딩 로봇 데스크 (글씨를 절대 가리지 않는 독립 코너 + 타자 애니메이션)
	var desk_box := Rect2(936, 84, 320, 562)
	pbox(desk_box, Color("131c31"), Color("38bdf8"))
	text("🤖 코딩 파트너 로봇", desk_box.position + Vector2(20, 30), 19, Color("7dd3fc"))
	text("타자를 칠 때마다 함께 코딩해요!", desk_box.position + Vector2(20, 52), 14, Color("94a3b8"))

	# 로봇 말풍선 (헤더 아래에 깔끔하게 배치)
	var bubble_rect := Rect2(954, 148, 284, 68)
	pbox(bubble_rect, Color("fffbeb"), Color("f59e0b"))
	text_c(robot_bubble, bubble_rect.get_center() + Vector2(0, 5), 14, Color("1e293b"))

	# 로봇 책상과 미니 노트북 그림
	var table_rect := Rect2(968, 356, 256, 22)
	draw_rect(table_rect, Color("78350f"))
	draw_rect(table_rect, Color("b45309"), false, 2.0)
	var laptop_base := Rect2(1042, 344, 112, 12)
	var laptop_screen := Rect2(1056, 304, 84, 42)
	draw_rect(laptop_screen, Color("1e293b"))
	draw_rect(laptop_screen, Color("38bdf8") if matched else Color("94a3b8"), false, 2.0)
	draw_rect(laptop_base, Color("64748b"))

	# 타이핑할 때 튀어오르는 키캡 파티클
	for sp: Dictionary in keycap_sparks:
		var sp_pos: Vector2 = sp["pos"]
		var alpha := clampf(float(sp["t"]) * 2.0, 0.0, 1.0)
		var krect := Rect2(sp_pos.x - 18, sp_pos.y - 14, 36, 26)
		draw_rect(krect, Color(0.98, 0.85, 0.25, alpha))
		draw_string(code_font, sp_pos + Vector2(-8, 5), str(sp["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.1, 0.1, 0.15, alpha))

	# 우측 로봇 데스크 하단 스테이지 선택 탭 (1~4단계)
	text("📚 코딩테스트 문제 목록 (4단계)", Vector2(956, 422), 16, Color("93c5fd"))
	for i in LEVELS.size():
		var lv_btn := Rect2(954, 438 + i * 48, 284, 40)
		var prefix := "✅ " if i < level or phase == "all_cleared" else ("▶ " if i == level else "   ")
		var bcol := Color("047857") if i == level else Color("1e293b")
		button(lv_btn, prefix + str(LEVELS[i].badge), "lv:" + str(i), true, 15, bcol)

	# 6. 하단 상태 표시 바
	var foot_box := Rect2(24, 656, 1232, 48)
	pbox(foot_box, Color("064e3b") if status_good else Color("0f172a"), Color("34d399") if status_good else Color("475569"))
	text(status_msg, foot_box.position + Vector2(18, 30), 17, Color("a7f3d0") if status_good else Color("f8fafc"))
