extends Node2D
## ST01 배열 - 순서가 있는 보관소 (걸어 다니는 버전)
## 배경 속 보관함 0~4번 칸이 배열. 로봇을 WASD 로 움직여 칸 앞에서 E 로 상자를 집고/놓는다.
## 규칙: 보관함 상자는 바로 옆 칸으로만 옮길 수 있다. 새 상자는 입고 트레이, 지울 상자는 반환 레버로.

const S := 1281.0 / 1672.0
const CAP := 5
const SLOT_X := [477.0, 642.0, 807.0, 972.0, 1137.0]
const CRATE_SCENE := preload("res://scenes/play/Crate.tscn")
const LEVELS := [
	{"arr": [10, 30, 40], "tray": 20, "target": [10, 20, 30, 40], "goal": "인덱스 1에 20 넣기", "opt": 3, "ins": 1},
	{"arr": [10, 20, 30, 40], "tray": null, "target": [20, 30, 40], "goal": "인덱스 0의 10 지우고 빈칸 없이 당기기", "opt": 4, "del": 0},
	{"arr": [15, 25, 35, 45], "tray": 5, "target": [5, 15, 25, 35, 45], "goal": "인덱스 0에 5 넣기", "opt": 5, "ins": 0},
	{"arr": [7, 14, 99, 21, 28], "tray": null, "target": [7, 14, 21, 28], "goal": "인덱스 2의 99 지우고 빈칸 없이 당기기", "opt": 3, "del": 2},
]
const NPC_NAME := "보관소 관리인"
const NPC_PORTRAIT := preload("res://textures/npc_portraits/NPC01_portrait.png")
const INTRO := [
	"어서 와, 꼬마 로봇! 난 이 보관소를 지키는 보관소 관리인이야. 일을 맡기기 전에 이곳 규칙부터 알려 줄게.",
	"저기 0번부터 4번까지 번호가 붙은 보관함 보이지? 이렇게 같은 크기의 칸이 한 줄로 빈틈없이 붙어 있는 구조를 '배열(Array)'이라고 해.",
	"칸에 붙은 번호를 '인덱스'라고 불러. 인덱스는 1이 아니라 0부터 시작해! 그래서 첫 번째 칸이 0번, 다섯 번째 칸이 4번이야.",
	"배열의 장점은 인덱스만 알면 '3번 칸!' 하고 바로 꺼낼 수 있다는 거야. 처음부터 하나씩 세어 볼 필요가 없지. 이걸 임의 접근이라고 해.",
	"대신 중간에 새 상자를 넣는 건 힘들어. 넣을 자리 뒤에 있는 상자들을 한 칸씩 뒤로 밀어서 자리를 만들어야 하거든. 맨 뒤 상자부터 밀어야 서로 부딪히지 않아.",
	"빼는 것도 마찬가지야. 상자를 빼면 빈칸이 생기는데, 배열은 빈틈이 있으면 안 되니까 뒤쪽 상자들을 한 칸씩 앞으로 당겨 메워야 해.",
	"그리고 보관함은 딱 5칸이야. 이렇게 정해진 크기를 '용량', 지금 들어 있는 상자 수를 '길이'라고 해. 꽉 차면 더 넣을 수 없어.",
	"조작법! WASD로 걷고, 보관함 앞에서 E를 누르면 상자를 집거나 내려놔. 새 상자는 입고 트레이에, 지울 상자는 반환 레버로 보내면 돼. 막히면 노란 화살표를 따라가!",
]
const LEVEL_TALK := [
	"첫 번째 일이야. 인덱스 1에 새 상자 20을 넣어 줘! 1번 칸을 비우려면 40, 30 순서로 뒤로 밀어야겠지?",
	"이번엔 삭제야. 0번 칸의 10을 반환 레버로 보내고, 나머지 상자들을 앞으로 당겨서 빈틈을 없애 줘.",
	"맨 앞, 인덱스 0에 5를 넣어 볼래? 맨 앞에 넣으려면 상자 4개를 전부 한 칸씩 밀어야 해. 배열 앞쪽 삽입이 왜 느린지 느껴 봐!",
	"마지막! 2번 칸의 99는 잘못 들어온 상자야. 지우고 뒤의 21, 28을 앞으로 당겨 줘.",
]
static var intro_seen := false
var _talked_level := -1

var level := 0
var slots: Array = []          # 값 또는 null
var tray = null
var hand = null                # {"v": 값, "from": 칸 번호 또는 "tray"}
var target: Array = []
var opt := 0
var moves := 0
var mistakes := 0
var done := false
var _undo: Array = []
var code_lines: Array = []     # [코드, 주석]
var crates := {}               # "slot0".."slot4", "tray", "hand" -> StageCrate

@onready var world: Node2D = $Field/World
@onready var player: StagePlayer = $Field/World/Player
@onready var hud: StageHUD = $HUD
@onready var hint: Node2D = $Field/World/HintArrow
@onready var hint_label: Label = $Field/World/HintArrow/Label
@onready var bubble: Control = $Field/World/Player/Bubble
@onready var bubble_label: Label = $Field/World/Player/Bubble/Label

func _ready() -> void:
	hud.set_title("ST01", "순서가 있는 보관소")
	hud.set_controls("WASD 이동 · E 상호작용 · Z 되돌리기 · R 초기화 · H 도움말 · Esc 메뉴")
	hud.next_pressed.connect(_next_level)
	hud.retry_pressed.connect(func(): start_level(level))
	player.interacted.connect(_on_interact)
	player.focus_changed.connect(func(_t): _refresh())
	var tw := create_tween().set_loops()
	tw.tween_property(hint, "position:y", -10.0, 0.4).as_relative().set_trans(Tween.TRANS_SINE)
	tw.tween_property(hint, "position:y", 10.0, 0.4).as_relative().set_trans(Tween.TRANS_SINE)
	hud.dialogue_finished.connect(_on_dialogue_done)
	hud.build_code_panel(Vector2(968, 214), Vector2(296, 494))
	start_level(0)

func _talk(pages: Array) -> void:
	player.active = false
	bubble.visible = false
	hint.visible = false
	hud.start_dialogue(NPC_NAME, NPC_PORTRAIT, pages)

func _on_dialogue_done() -> void:
	intro_seen = true
	player.active = not done
	_refresh()
# ---------- 레벨 ----------
func start_level(n: int) -> void:
	level = n
	var L: Dictionary = LEVELS[n]
	slots = []
	for i in CAP:
		slots.append(L.arr[i] if i < L.arr.size() else null)
	tray = L.tray
	hand = null
	target = L.target
	opt = L.opt
	moves = 0
	mistakes = 0
	done = false
	_undo.clear()
	code_lines = []
	hud.hide_clear()
	hud.set_goal(L.goal)
	player.position = Vector2(560, 450)
	_rebuild_crates()
	_refresh()
	hud.toast("레벨 %d / %d : %s" % [n + 1, LEVELS.size(), L.goal], StageHUD.GOLD)
	if n != _talked_level:
		_talked_level = n
		if n == 0 and not intro_seen:
			_talk(INTRO + [LEVEL_TALK[0]])
		else:
			_talk([LEVEL_TALK[n]])
	else:
		player.active = true

func _next_level() -> void:
	if level < LEVELS.size() - 1:
		start_level(level + 1)
	else:
		get_tree().change_scene_to_file("res://scenes/Main.tscn")

func slot_pos(i: int) -> Vector2:
	return Vector2(SLOT_X[i] * S, 361)

func tray_pos() -> Vector2:
	return Vector2(665 * S, 528)

func _rebuild_crates() -> void:
	for c in crates.values():
		if is_instance_valid(c):
			c.queue_free()
	crates.clear()
	player.carried = null
	for i in CAP:
		if slots[i] != null:
			crates["slot%d" % i] = _spawn(slots[i], slot_pos(i))
	if tray != null:
		crates["tray"] = _spawn(tray, tray_pos())
	if hand != null:
		var c := _spawn(hand.v, world.to_local(player.carry_point.global_position))
		c.z_index = 2
		crates["hand"] = c
		player.carried = c

func _spawn(v: int, p: Vector2) -> StageCrate:
	var c: StageCrate = CRATE_SCENE.instantiate()
	world.add_child(c)
	c.position = p
	c.set_value(v)
	return c

# ---------- 상호작용 ----------
func _snapshot() -> void:
	_undo.append({"slots": slots.duplicate(), "tray": tray, "hand": hand.duplicate() if hand else null, "moves": moves, "code": code_lines.duplicate(true)})

# ---------- 코드 표시 ----------
func _code(code: String, comment: String) -> void:
	code_lines.append([code, comment])

func _code_replace(code: String, comment: String) -> void:
	if not code_lines.is_empty():
		code_lines.pop_back()
	_code(code, comment)

func _num(v) -> String:
	return "[color=#f2a65a]%s[/color]" % str(v)

func _fmt(code: String) -> String:
	# 숫자·키워드 색칠 (대괄호는 BBCode 로 해석되지 않게 치환)
	if code.begins_with("//"):
		return "[color=#7fbf7f]%s[/color]" % code
	var out := code.replace("[", "\u0001").replace("]", "\u0002")
	for kw in ["for", "int", "null"]:
		out = out.replace(kw + " ", "[color=#6fa8ff]%s[/color] " % kw).replace(kw + ";", "[color=#6fa8ff]%s[/color];" % kw)
	var re := RegEx.new()
	re.compile("(?<![\\w#])(\\d+)")
	out = re.sub(out, "[color=#f2a65a]$1[/color]", true)
	return out.replace("\u0001", "[lb]").replace("\u0002", "[rb]")

func _render_code() -> void:
	var cells := []
	var count := 0
	for v in slots:
		cells.append("_" if v == null else _num(v))
		if v != null:
			count += 1
	var st := "arr = [lb]%s[rb]\nlength = %s" % [", ".join(cells), _num(count)]
	if hand != null:
		st += "\ntemp = %s   [color=#7fbf7f]// 로봇이 든 상자[/color]" % _num(hand.v)
	var log_bb := ""
	for i in code_lines.size():
		var ln: Array = code_lines[i]
		var line := _fmt(ln[0])
		if ln[1] != "":
			line += "  [color=#7fbf7f]// %s[/color]" % ln[1]
		if i == code_lines.size() - 1 and not done:
			line = "[bgcolor=#3a3f1e]%s[/bgcolor]" % line
		log_bb += line + "\n"
	if code_lines.is_empty():
		log_bb = "[color=#7f8796]// 상자를 옮기면 여기에\n// 코드가 한 줄씩 쌓여요[/color]"
	hud.set_code(st, log_bb)

func _summary_code() -> void:
	var L: Dictionary = LEVELS[level]
	var n0: int = L.arr.size()
	_code("length = %d;" % target.size(), "길이 갱신")
	_code("", "")
	_code("// ── 반복문으로 쓰면 ──", "")
	if L.has("ins"):
		var k: int = L.ins
		_code("// 뒤에서부터 한 칸씩 밀기", "")
		_code("for (int i = %d; i >= %d; i--)" % [n0 - 1, k], "")
		_code("    arr[i + 1] = arr[i];", "")
		_code("arr[%d] = %d;" % [k, L.tray], "")
		_code("length++;", "")
	else:
		var k: int = L.del
		_code("// 앞으로 한 칸씩 당기기", "")
		_code("for (int i = %d; i < %d; i++)" % [k, n0 - 1], "")
		_code("    arr[i] = arr[i + 1];", "")
		_code("length--;", "")

func _on_interact(t: Interactable) -> void:
	if done:
		return
	match t.kind:
		"slot": _slot(t.index)
		"tray": _tray()
		"bin": _bin()
		"npc":
			_talk(INTRO.slice(1) + [LEVEL_TALK[level]])
			return
	_refresh()
	_check()

func _slot(i: int) -> void:
	if hand == null:
		if slots[i] == null:
			_wrong("%d번 칸은 비어 있어요." % i)
			return
		_snapshot()
		hand = {"v": slots[i], "from": i}
		_code("temp = arr[%d];" % i, "%d 집기" % slots[i])
		slots[i] = null
		_carry(crates["slot%d" % i])
		crates.erase("slot%d" % i)
		return
	if slots[i] != null:
		_wrong("%d번 칸에는 이미 상자가 있어요." % i)
		return
	if typeof(hand.from) == TYPE_INT and absi(int(hand.from) - i) > 1:
		_wrong("상자는 바로 옆 칸으로만 한 칸씩 옮길 수 있어요.")
		return
	_snapshot()
	slots[i] = hand.v
	if typeof(hand.from) != TYPE_INT:
		_code_replace("arr[%d] = %d;" % [i, hand.v], "새 값 저장")
	elif hand.from == i:
		code_lines.pop_back()
	else:
		_code_replace("arr[%d] = arr[%d];" % [i, hand.from], "%d→%d번" % [hand.v, i])
	if typeof(hand.from) != TYPE_INT or hand.from != i:
		moves += 1
	hand = null
	var c: StageCrate = crates["hand"]
	crates.erase("hand")
	crates["slot%d" % i] = c
	player.carried = null
	c.z_index = 0
	c.move_to(slot_pos(i)).finished.connect(c.pop)

func _tray() -> void:
	if hand == null and tray != null:
		_snapshot()
		hand = {"v": tray, "from": "tray"}
		_code("temp = %d;" % tray, "새 상자")
		tray = null
		_carry(crates["tray"])
		crates.erase("tray")
	elif hand != null and typeof(hand.from) != TYPE_INT:
		_snapshot()
		tray = hand.v
		hand = null
		if not code_lines.is_empty():
			code_lines.pop_back()
		var c: StageCrate = crates["hand"]
		crates.erase("hand")
		crates["tray"] = c
		player.carried = null
		c.z_index = 0
		c.move_to(tray_pos())
	elif hand != null:
		_wrong("입고 트레이에는 새 상자만 돌려놓을 수 있어요.")
	else:
		_wrong("입고 트레이가 비어 있어요.")

func _bin() -> void:
	if hand == null:
		_wrong("먼저 지울 상자를 집어 오세요.")
		return
	if typeof(hand.from) != TYPE_INT:
		_wrong("새 상자는 버리지 말고 배열에 넣어야 해요.")
		return
	if hand.v in target:
		_wrong("%d 은(는) 남겨야 하는 상자예요." % hand.v)
		return
	_snapshot()
	moves += 1
	_code_replace("arr[%d] = null;" % hand.from, "%d 삭제" % hand.v)
	hud.toast("%d 삭제! 이제 뒤쪽 상자들을 왼쪽으로 한 칸씩 당기세요." % hand.v, StageHUD.GREEN)
	hand = null
	var c: StageCrate = crates["hand"]
	crates.erase("hand")
	player.carried = null
	c.vanish()

func _carry(c: StageCrate) -> void:
	crates["hand"] = c
	c.z_index = 2
	var tw := c.move_to(world.to_local(player.carry_point.global_position), 0.15)
	tw.finished.connect(func(): if hand != null: player.carried = c)

func _wrong(msg: String) -> void:
	mistakes += 1
	hud.toast("✗ " + msg, StageHUD.RED, 3.0)
	var tw := create_tween()
	for k in 3:
		tw.tween_property(player.sprite, "position:x", 6.0, 0.04)
		tw.tween_property(player.sprite, "position:x", -6.0, 0.04)
	tw.tween_property(player.sprite, "position:x", 0.0, 0.04)

func _check() -> void:
	if hand != null:
		return
	var arr := []
	var gap := false
	for v in slots:
		if v == null:
			gap = true
		elif gap:
			return
		else:
			arr.append(v)
	if arr == target:
		done = true
		_summary_code()
		_render_code()
		player.active = false
		if moves > opt:
			mistakes = maxi(mistakes, 1)
		var stars := 3 if mistakes == 0 else (2 if mistakes <= 2 else 1)
		var last := level >= LEVELS.size() - 1
		hud.show_clear("스테이지 클리어!" if last else "레벨 %d 클리어!" % (level + 1), stars,
			"배열 %s 완성\n이동 %d회 (최소 %d회) · 실수 %d회" % [str(arr), moves, opt, mistakes], last)
		if last:
			MiniGameBase.cleared["ST01"] = maxi(int(MiniGameBase.cleared.get("ST01", 0)), stars)

func _undo_last() -> void:
	if done or _undo.is_empty():
		return
	var s: Dictionary = _undo.pop_back()
	slots = s.slots
	tray = s.tray
	hand = s.hand
	moves = s.moves
	code_lines = s.code
	_rebuild_crates()
	_refresh()
	hud.toast("되돌렸어요.")

# ---------- 안내 ----------
func _next_action() -> Array:
	if hand != null:
		if typeof(hand.from) != TYPE_INT:
			var t := target.find(hand.v)
			return ["slot", t, "%d번 칸에 놓기" % t]
		if not (hand.v in target):
			return ["bin", -1, "반환 레버로 삭제"]
		var ti := target.find(hand.v)
		var j: int = hand.from
		if ti == j:
			return ["slot", j, "제자리에 다시 놓기"]
		var to := j + (1 if ti > j else -1)
		return ["slot", to, "%d번 칸으로 한 칸 옮기기" % to]
	for j in CAP:
		if slots[j] != null and not (slots[j] in target):
			return ["slot", j, "지울 상자 %d 집기" % slots[j]]
	for j in range(CAP - 1, -1, -1):
		if slots[j] != null and target.find(slots[j]) > j and j + 1 < CAP and slots[j + 1] == null:
			return ["slot", j, "맨 뒤 상자 %d 부터 오른쪽으로" % slots[j]]
	for j in range(1, CAP):
		if slots[j] != null and target.find(slots[j]) < j and slots[j - 1] == null:
			return ["slot", j, "상자 %d 를 왼쪽으로 당기기" % slots[j]]
	if tray != null:
		return ["tray", -1, "입고 트레이의 새 상자 집기"]
	return ["", -1, ""]

func _refresh() -> void:
	_render_code()
	var count := 0
	for v in slots:
		if v != null:
			count += 1
	hud.set_info("레벨 %d / %d" % [level + 1, LEVELS.size()], [["길이", count], ["용량", CAP], ["이동", "%d (최소 %d)" % [moves, opt]], ["들고 있는 상자", "-" if hand == null else str(hand.v)]])
	# 다음 행동 화살표
	var a := _next_action()
	hint.visible = a[0] != "" and not done and not hud.dialogue_open()
	match a[0]:
		"slot": hint.position = Vector2(SLOT_X[a[1]] * S, 200)
		"tray": hint.position = Vector2(tray_pos().x, 418)
		"bin": hint.position = Vector2(904, 410)
	hint_label.text = a[2]
	# E 말풍선
	var f := player.focus
	bubble.visible = f != null and not done and not hud.dialogue_open()
	if f:
		bubble_label.text = "E  " + _prompt(f)

func _prompt(t: Interactable) -> String:
	match t.kind:
		"slot":
			if hand == null:
				return "%d 집기" % slots[t.index] if slots[t.index] != null else "%d번 칸 (비어 있음)" % t.index
			return "%d번 칸에 놓기" % t.index
		"tray":
			if hand == null:
				return "새 상자 %d 집기" % tray if tray != null else "입고 트레이 (비어 있음)"
			return "트레이에 돌려놓기"
		"bin":
			return "반환 레버 (삭제)" if hand != null else "반환 레버"
		"npc":
			return "보관소 관리인과 대화"
	return t.prompt

func _unhandled_input(ev: InputEvent) -> void:
	if hud.dialogue_open():
		var adv := false
		if ev is InputEventKey and ev.pressed and not ev.echo:
			match ev.keycode:
				KEY_ESCAPE: get_tree().change_scene_to_file("res://scenes/Main.tscn")
				KEY_TAB: hud.dialogue_skip()
				KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER: adv = true
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			adv = true
		if adv:
			hud.dialogue_advance()
		get_viewport().set_input_as_handled()
		return
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	match ev.keycode:
		KEY_ESCAPE: get_tree().change_scene_to_file("res://scenes/Main.tscn")
		KEY_R: start_level(level)
		KEY_Z: _undo_last()
		KEY_H: _talk(INTRO.slice(1) + [LEVEL_TALK[level]])
		KEY_ENTER, KEY_KP_ENTER:
			if done:
				_next_level()