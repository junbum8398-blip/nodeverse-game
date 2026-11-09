class_name WalkStage
extends Node2D
## 걸어 다니는 스테이지 공통 틀 (ST01 과 같은 구조).
## NPC 설명 → WASD 로 로봇을 걸려서 E 로 상호작용 → 오른쪽 코드 패널에 실행한 코드가 쌓인다.
## 씬 구조는 tools/write_stage_scenes.py 가 만들고, 하위 클래스는 규칙만 구현한다.

const CRATE_SCENE := preload("res://scenes/play/Crate.tscn")
const TOKEN_SCENE := preload("res://scenes/play/Token.tscn")
const MENU := "res://scenes/Main.tscn"
const C_LINK := Color("5fd6ff")
const C_HEAD := Color("f2c14e")

static var intro_seen := {}

# ---------- 하위 클래스가 _init 에서 정하는 값 ----------
var stage_id := "ST00"
var stage_title := ""
var npc_name := ""
var npc_portrait: Texture2D
var intro: Array = []
var level_talk: Array = []
var level_count := 1
var hint_after_mistake := false   # true: 실수하기 전에는 다음 행동 화살표를 숨긴다 (순서를 맞히는 스테이지)
var code_keywords := ["for", "int", "null", "if", "else", "return", "while", "new", "void", "true", "false", "break"]

# ---------- 공통 진행 상태 ----------
var level := 0
var moves := 0
var mistakes := 0
var done := false
var code_lines: Array = []
var goal_text := ""
var items := {}             # 아이디 -> StageCrate (sync_items 로 관리)
var _held_id = null
var _undo: Array = []
var _talked_level := -1
var _spots := {}
var _num_re := RegEx.new()

@onready var field: Node2D = $Field
@onready var world: Node2D = $Field/World
@onready var links: Node2D = $Field/Links
@onready var overlay: Node2D = $Field/Overlay
@onready var player: StagePlayer = $Field/World/Player
@onready var hud: StageHUD = $HUD
@onready var hint: Node2D = $Field/World/HintArrow
@onready var hint_label: Label = $Field/World/HintArrow/Label
@onready var bubble: Control = $Field/World/Player/Bubble
@onready var bubble_label: Label = $Field/World/Player/Bubble/Label

# ---------- 하위 클래스가 구현 ----------
func build_stage() -> void: pass                   # 고정 장식(글자판 등) 만들기, _ready 에서 1번
func setup_level(_n: int) -> void: pass            # 레벨 데이터 초기화 + goal_text 지정
func get_state() -> Dictionary: return {}          # 되돌리기용 현재 상태
func set_state(_s: Dictionary) -> void: pass
func rebuild() -> void: pass                       # 상태를 화면에 반영
func interact(_t: Interactable) -> void: pass      # E 를 눌렀을 때
func next_action() -> Array: return [null, ""]     # [Interactable 또는 null, 안내 문구]
func prompt(t: Interactable) -> String: return t.prompt
func hint_allowed(_t: Interactable) -> bool: return not hint_after_mistake or mistakes > 0
func state_text() -> String: return ""             # 코드 패널 위쪽 (현재 값)
func info_rows() -> Array: return []
func summary_code() -> void: pass                  # 클리어 시 코드 패널에 덧붙일 정리

# ---------- 수명 주기 ----------
func _ready() -> void:
	_num_re.compile("(?<![\\w#])(\\d+)")
	for c in world.get_children():
		if c is Interactable:
			_spots[_spot_key(c.kind, c.index)] = c
		for g in c.get_children():
			if g is Interactable:
				_spots[_spot_key(g.kind, g.index)] = g
	hud.set_title(stage_id, stage_title)
	hud.set_controls("WASD 이동 · E 상호작용 · Z 되돌리기 · R 초기화 · H 도움말 · Esc 메뉴")
	hud.next_pressed.connect(_next_level)
	hud.retry_pressed.connect(func(): start_level(level))
	hud.dialogue_finished.connect(_on_dialogue_done)
	hud.build_code_panel(Vector2(968, 214), Vector2(296, 494))
	player.interacted.connect(_on_interact)
	player.focus_changed.connect(func(_t): refresh())
	var tw := create_tween().set_loops()
	tw.tween_property(hint, "position:y", -10.0, 0.4).as_relative().set_trans(Tween.TRANS_SINE)
	tw.tween_property(hint, "position:y", 10.0, 0.4).as_relative().set_trans(Tween.TRANS_SINE)
	build_stage()
	start_level(0)

func _spot_key(kind: String, index: int) -> String:
	return "%s:%d" % [kind, index]

func spot(kind: String, index := -1) -> Interactable:
	return _spots.get(_spot_key(kind, index))

func mark(n: String) -> Vector2:
	return (world.get_node(n) as Node2D).position

# ---------- 레벨 ----------
func start_level(n: int) -> void:
	level = n
	moves = 0
	mistakes = 0
	done = false
	_undo.clear()
	code_lines = []
	_held_id = null
	player.carried = null
	for c in items.values():
		if is_instance_valid(c):
			c.queue_free()
	items.clear()
	setup_level(n)
	hud.hide_clear()
	hud.set_goal(goal_text)
	player.position = mark("Spawn")
	rebuild()
	refresh()
	hud.toast("레벨 %d / %d : %s" % [n + 1, level_count, goal_text], StageHUD.GOLD)
	if n != _talked_level:
		_talked_level = n
		if n == 0 and not intro_seen.get(stage_id, false):
			talk(intro + [level_talk[0]])
		else:
			talk([level_talk[n]])
	else:
		player.active = true

func talk(pages: Array) -> void:
	player.active = false
	bubble.visible = false
	hint.visible = false
	hud.start_dialogue(npc_name, npc_portrait, pages)

func _on_dialogue_done() -> void:
	intro_seen[stage_id] = true
	player.active = not done
	refresh()

func _next_level() -> void:
	if level < level_count - 1:
		start_level(level + 1)
	else:
		get_tree().change_scene_to_file(MENU)

func set_goal(t: String) -> void:
	goal_text = t
	hud.set_goal(t)

# ---------- 실수·칭찬·클리어 ----------
func wrong(msg: String) -> void:
	mistakes += 1
	hud.toast("✗ " + msg, StageHUD.RED, 3.0)
	var tw := create_tween()
	for k in 3:
		tw.tween_property(player.sprite, "position:x", 6.0, 0.04)
		tw.tween_property(player.sprite, "position:x", -6.0, 0.04)
	tw.tween_property(player.sprite, "position:x", 0.0, 0.04)

func good(msg: String) -> void:
	hud.toast("✓ " + msg, StageHUD.GREEN)

func stars() -> int:
	return 3 if mistakes == 0 else (2 if mistakes <= 2 else 1)

func win(detail: String) -> void:
	done = true
	summary_code()
	render_code()
	player.active = false
	var last := level >= level_count - 1
	var s := stars()
	hud.show_clear("스테이지 클리어!" if last else "레벨 %d 클리어!" % (level + 1), s, detail, last)
	if last:
		MiniGameBase.cleared[stage_id] = maxi(int(MiniGameBase.cleared.get(stage_id, 0)), s)

# ---------- 되돌리기 ----------
func snapshot() -> void:
	_undo.append({"s": get_state().duplicate(true), "m": moves, "c": code_lines.duplicate(true)})

func undo_last() -> void:
	if done or _undo.is_empty():
		return
	var u: Dictionary = _undo.pop_back()
	set_state(u.s)
	moves = u.m
	code_lines = u.c
	rebuild()
	refresh()
	hud.toast("되돌렸어요.")

# ---------- 물건 관리 ----------
## want: 아이디 -> {"text", "pos", "scale"(선택), "color"(선택, 있으면 토큰), "z"(선택)}.
## 없어진 아이디는 사라지고, 새 아이디는 생기고, 있던 것은 새 위치로 움직인다.
## held_id 는 로봇이 드는 물건 (want 에 넣어 두면 없을 때 만들어진다).
func sync_items(want: Dictionary, held_id = null) -> void:
	for id in items.keys():
		if not want.has(id) and id != held_id:
			var gone: StageCrate = items[id]
			items.erase(id)
			if player.carried == gone:
				player.carried = null
			gone.vanish()
	for id in want:
		var w: Dictionary = want[id]
		var c: StageCrate = items.get(id)
		if c == null:
			c = _spawn(w)
			items[id] = c
		elif id == held_id:
			pass
		else:
			c.set_value(w.text)
			if w.has("scale") and not is_equal_approx(c.base_scale.x, float(w.scale)):
				c.set_base_scale(float(w.scale))
			if player.carried == c:
				player.carried = null
			c.z_index = int(w.get("z", 0))
			if c.position.distance_to(w.pos) > 1.0:
				c.move_to(w.pos).finished.connect(c.pop)
	if held_id != null and items.has(held_id):
		_held_id = held_id
		var c: StageCrate = items[held_id]
		c.z_index = 2
		if player.carried != c:
			c.move_to(world.to_local(player.carry_point.global_position), 0.15).finished.connect(func():
				if _held_id == held_id and items.get(held_id) == c:
					player.carried = c)
	else:
		_held_id = null

func hold_pos() -> Vector2:
	return world.to_local(player.carry_point.global_position)

func _spawn(w: Dictionary) -> StageCrate:
	var c: StageCrate = (TOKEN_SCENE if w.has("color") else CRATE_SCENE).instantiate()
	world.add_child(c)
	c.position = w.pos
	c.set_value(w.text)
	if w.has("scale"):
		c.set_base_scale(float(w.scale))
	if w.has("color"):
		c.set_tint(w.color)
	c.z_index = int(w.get("z", 0))
	return c

# ---------- 코드 패널 ----------
func code(c: String, comment := "") -> void:
	code_lines.append([c, comment])

func code_replace(c: String, comment := "") -> void:
	if not code_lines.is_empty():
		code_lines.pop_back()
	code(c, comment)

func num(v) -> String:
	return "[color=#f2a65a]%s[/color]" % str(v)

func fmt(c: String) -> String:
	if c.begins_with("//"):
		return "[color=#7fbf7f]%s[/color]" % c
	var out := c.replace("[", "\u0001").replace("]", "\u0002")
	out = _num_re.sub(out, "[color=#f2a65a]$1[/color]", true)
	for kw in code_keywords:
		var re := RegEx.new()
		re.compile("\\b%s\\b" % kw)
		out = re.sub(out, "[color=#6fa8ff]%s[/color]" % kw, true)
	return out.replace("\u0001", "[lb]").replace("\u0002", "[rb]")

func render_code() -> void:
	var log_bb := ""
	for i in code_lines.size():
		var ln: Array = code_lines[i]
		var line := fmt(ln[0])
		if ln[1] != "":
			line += "  [color=#7fbf7f]// %s[/color]" % ln[1]
		if i == code_lines.size() - 1 and not done:
			line = "[bgcolor=#3a3f1e]%s[/bgcolor]" % line
		log_bb += line + "\n"
	if code_lines.is_empty():
		log_bb = "[color=#7f8796]// 행동하면 여기에\n// 코드가 한 줄씩 쌓여요[/color]"
	hud.set_code(state_text(), log_bb)

# ---------- 화면 갱신 ----------
func refresh() -> void:
	render_code()
	hud.set_info("레벨 %d / %d" % [level + 1, level_count], info_rows())
	var a := next_action()
	var t: Interactable = a[0]
	hint.visible = t != null and hint_allowed(t) and not done and not hud.dialogue_open()
	if t != null:
		hint.position = t.position + t.bubble_offset
		hint_label.text = a[1]
	var f := player.focus
	bubble.visible = f != null and not done and not hud.dialogue_open()
	if f:
		bubble_label.text = "E  " + prompt(f)

func _on_interact(t: Interactable) -> void:
	if done:
		return
	if t.kind == "npc":
		talk(intro.slice(1) + [level_talk[level]])
		return
	interact(t)
	refresh()

func _unhandled_input(ev: InputEvent) -> void:
	if hud.dialogue_open():
		var adv := false
		if ev is InputEventKey and ev.pressed and not ev.echo:
			match ev.keycode:
				KEY_ESCAPE: get_tree().change_scene_to_file(MENU)
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
		KEY_ESCAPE: get_tree().change_scene_to_file(MENU)
		KEY_R: start_level(level)
		KEY_Z: undo_last()
		KEY_H: talk(intro.slice(1) + [level_talk[level]])
		KEY_ENTER, KEY_KP_ENTER:
			if done:
				_next_level()

# ---------- 그리기 도우미 ----------
## World 위에 얹는 글자 (p 는 글자 중앙)
func text_at(t: String, p: Vector2, size := 22, col := Color.WHITE, outline := 6, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", StageHUD.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(300, size * 1.6)
	l.position = p - l.size / 2
	(parent if parent else overlay).add_child(l)
	return l

## World 위에 얹는 판 (양피지, 칸 등)
func panel_at(r: Rect2, bg: Color, border := StageHUD.INK, bw := 3, parent: Node = null) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", sb)
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else overlay).add_child(p)
	return p

func clear_children(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()

## 빛나는 연결선 + 화살촉 (links 층)
func link(a: Vector2, b: Vector2, col := C_LINK, bend := 0.0) -> void:
	var dir := (b - a).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var mid := (a + b) / 2 + perp * bend
	var pts := PackedVector2Array()
	for i in 21:
		var t := i / 20.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	var glow := Line2D.new()
	glow.points = pts
	glow.width = 16.0
	glow.default_color = Color(col, 0.28)
	glow.joint_mode = Line2D.LINE_JOINT_ROUND
	links.add_child(glow)
	var core := Line2D.new()
	core.points = pts
	core.width = 6.0
	core.default_color = col
	core.antialiased = true
	links.add_child(core)
	var tip := pts[20]
	var back := (tip - pts[17]).normalized()
	var side := Vector2(-back.y, back.x)
	var head := Polygon2D.new()
	head.color = col
	head.polygon = PackedVector2Array([tip + back * 14, tip - back * 12 + side * 12, tip - back * 12 - side * 12])
	links.add_child(head)
