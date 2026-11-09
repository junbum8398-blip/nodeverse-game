class_name StageHUD
extends CanvasLayer
## 스테이지 공통 HUD (Godot Control 노드): 제목, 목표, 정보 패널, 조작 안내, 알림, 플레이 방법, 클리어 창.

signal next_pressed
signal retry_pressed
signal tutorial_closed

const INK := Color("1d1b2a")
const PAPER := Color("f6e7c8")
const WOOD := Color("6b4a2b")
const NAVY := Color("1d3a73")
const BLUE := Color("2f5fb3")
const GOLD := Color("f2c14e")
const GREEN := Color("3f9d48")
const RED := Color("d64545")

var title_id: Label
var title_name: Label
var goal_label: Label
var info_box: VBoxContainer
var level_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var tutorial_panel: Control
var clear_panel: Control
var clear_title: Label
var clear_stars: Label
var clear_detail: Label
var next_button: Button
var controls_label: Label
var _toast_tween: Tween
var toast_y := 80.0            # 알림 위치 (스테이지가 상단을 쓰면 아래로 옮긴다)
var toast_center_x := 640.0

static func box(bg: Color, border := INK, bw := 4, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(0)
	s.content_margin_left = pad + 4
	s.content_margin_right = pad + 4
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_offset = Vector2(0, 4)
	s.shadow_size = 1
	return s

static func label(t: String, size: int, col: Color, outline := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline:
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", INK)
	return l

static func panel(bg: Color, pad := 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, INK, 4, pad))
	return p

static func make_button(t: String, col: Color) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", box(col, INK, 4, 10))
	b.add_theme_stylebox_override("hover", box(col.lightened(0.15), INK, 4, 10))
	b.add_theme_stylebox_override("pressed", box(col.darkened(0.15), INK, 4, 10))
	b.add_theme_stylebox_override("focus", box(col.lightened(0.15), GOLD, 4, 10))
	b.custom_minimum_size = Vector2(200, 54)
	return b

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# 제목 + 목표 (왼쪽 위)
	var top := HBoxContainer.new()
	top.position = Vector2(16, 12)
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var tp := panel(WOOD, 6)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	var idp := panel(BLUE, 2)
	title_id = label("ST00", 20, Color.WHITE)
	idp.add_child(title_id)
	th.add_child(idp)
	title_name = label("", 24, Color.WHITE)
	th.add_child(title_name)
	tp.add_child(th)
	top.add_child(tp)
	var gp := panel(PAPER, 8)
	var gh := HBoxContainer.new()
	gh.add_child(label("목표: ", 20, RED))
	goal_label = label("", 20, INK)
	gh.add_child(goal_label)
	gp.add_child(gh)
	top.add_child(gp)
	# 정보 패널 (오른쪽 위)
	var ip := panel(NAVY, 10)
	ip.position = Vector2(968, 12)
	ip.custom_minimum_size = Vector2(296, 0)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 6)
	level_label = label("", 18, GOLD)
	iv.add_child(level_label)
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 6)
	iv.add_child(info_box)
	ip.add_child(iv)
	root.add_child(ip)
	# 조작 안내 (왼쪽 아래)
	var cp := panel(Color(0.08, 0.08, 0.12, 0.85), 4)
	cp.position = Vector2(16, 628)
	controls_label = label("", 16, Color.WHITE)
	cp.add_child(controls_label)
	root.add_child(cp)
	# 알림
	toast_panel = panel(Color(0.08, 0.08, 0.12, 0.92), 8)
	toast_label = label("", 22, Color.WHITE)
	toast_panel.add_child(toast_label)
	toast_panel.modulate.a = 0.0
	root.add_child(toast_panel)
	_build_tutorial(root)
	_build_dialogue(root)
	_build_clear(root)

func _build_tutorial(root: Control) -> void:
	tutorial_panel = ColorRect.new()
	(tutorial_panel as ColorRect).color = Color(0, 0, 0, 0.55)
	tutorial_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	tutorial_panel.visible = false
	root.add_child(tutorial_panel)

func show_tutorial(title: String, steps: Array) -> void:
	for c in tutorial_panel.get_children():
		c.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	tutorial_panel.add_child(center)
	var p := panel(PAPER, 20)
	p.custom_minimum_size = Vector2(820, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	p.add_child(v)
	var hp := panel(BLUE, 8)
	var hl := label(title + " · 플레이 방법", 26, Color.WHITE)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.add_child(hl)
	v.add_child(hp)
	for i in steps.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var badge := panel(GOLD, 6)
		badge.custom_minimum_size = Vector2(48, 48)
		var bl := label(str(i + 1), 24, INK)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(bl)
		row.add_child(badge)
		var col := VBoxContainer.new()
		col.add_child(label(steps[i][0], 22, NAVY))
		for j in range(1, steps[i].size()):
			var d := label(steps[i][j], 18, INK)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size = Vector2(680, 0)
			col.add_child(d)
		row.add_child(col)
		v.add_child(row)
	var foot := label("아무 키나 누르거나 클릭하면 시작 · 게임 중 H 로 다시 보기", 17, WOOD)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)
	tutorial_panel.visible = true

func tutorial_open() -> bool:
	return tutorial_panel.visible

func close_tutorial() -> void:
	tutorial_panel.visible = false
	tutorial_closed.emit()

# ---------- 코드 패널 ----------
var code_panel: PanelContainer
var code_state: RichTextLabel
var code_log: RichTextLabel
var code_title: Label

static func code_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["D2Coding", "Consolas", "Cascadia Mono", "Malgun Gothic"])
	return f

func build_code_panel(pos: Vector2, size: Vector2) -> void:
	code_panel = panel(Color(0.09, 0.11, 0.17, 0.94), 10)
	code_panel.position = pos
	code_panel.custom_minimum_size = size
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	code_title = label("{ } 코드로 보기", 18, GOLD)
	v.add_child(code_title)
	code_state = _rich(Vector2(size.x - 28, 86))
	v.add_child(code_state)
	v.add_child(label("실행한 코드", 15, Color(0.7, 0.75, 0.85)))
	code_log = _rich(Vector2(size.x - 28, size.y - 170))
	code_log.scroll_following = true
	v.add_child(code_log)
	code_panel.add_child(v)
	get_child(0).add_child(code_panel)
	get_child(0).move_child(code_panel, 1)

func _rich(min_size: Vector2) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.custom_minimum_size = min_size
	r.scroll_active = true
	r.add_theme_font_override("normal_font", code_font())
	r.add_theme_font_size_override("normal_font_size", 14)
	r.add_theme_color_override("default_color", Color(0.9, 0.92, 0.96))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.1)
	sb.set_content_margin_all(8)
	r.add_theme_stylebox_override("normal", sb)
	return r

func set_code(state_bb: String, log_bb: String) -> void:
	code_state.text = state_bb
	code_log.text = log_bb

# ---------- NPC 대화창 ----------
signal dialogue_finished

var dlg: Control
var dlg_portrait: TextureRect
var dlg_name: Label
var dlg_text: Label
var dlg_more: Label
var dlg_page: Label
var _pages: Array = []
var _page := 0
var _type_tween: Tween

func _build_dialogue(root: Control) -> void:
	dlg = Control.new()
	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dlg.visible = false
	root.add_child(dlg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dlg.add_child(dim)
	# 초상화
	var pp := panel(PAPER, 6)
	pp.position = Vector2(48, 438)
	pp.custom_minimum_size = Vector2(212, 212)
	dlg_portrait = TextureRect.new()
	dlg_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dlg_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dlg_portrait.custom_minimum_size = Vector2(196, 196)
	pp.add_child(dlg_portrait)
	dlg.add_child(pp)
	# 대사 상자
	var tp := panel(Color(0.99, 0.95, 0.86), 18)
	tp.position = Vector2(276, 470)
	tp.custom_minimum_size = Vector2(956, 180)
	var tv := VBoxContainer.new()
	dlg_text = label("", 23, INK)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_text.custom_minimum_size = Vector2(910, 112)
	tv.add_child(dlg_text)
	var foot := HBoxContainer.new()
	dlg_page = label("", 16, WOOD)
	dlg_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(dlg_page)
	dlg_more = label("▼ E / Space 다음", 17, BLUE)
	foot.add_child(dlg_more)
	tv.add_child(foot)
	tp.add_child(tv)
	dlg.add_child(tp)
	# 이름표
	var np := panel(BLUE, 4)
	np.position = Vector2(292, 444)
	dlg_name = label("", 20, Color.WHITE)
	np.add_child(dlg_name)
	dlg.add_child(np)
	var skip := label("Tab 건너뛰기", 15, Color(1, 1, 1, 0.8), true)
	skip.position = Vector2(1130, 660)
	dlg.add_child(skip)

func start_dialogue(speaker: String, portrait: Texture2D, pages: Array) -> void:
	dlg_name.text = speaker
	dlg_portrait.texture = portrait
	_pages = pages
	_page = 0
	dlg.visible = true
	dlg.modulate.a = 0.0
	create_tween().tween_property(dlg, "modulate:a", 1.0, 0.2)
	_show_page()

func _show_page() -> void:
	dlg_text.text = _pages[_page]
	dlg_text.visible_ratio = 0.0
	dlg_page.text = "%d / %d" % [_page + 1, _pages.size()]
	dlg_more.text = "▼ E / Space 다음" if _page < _pages.size() - 1 else "▶ E / Space 시작하기"
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(dlg_text, "visible_ratio", 1.0, dlg_text.text.length() * 0.028)

func dialogue_open() -> bool:
	return dlg.visible

func dialogue_advance() -> void:
	if dlg_text.visible_ratio < 1.0:
		if _type_tween:
			_type_tween.kill()
		dlg_text.visible_ratio = 1.0
		return
	if _page < _pages.size() - 1:
		_page += 1
		_show_page()
	else:
		dialogue_skip()

func dialogue_skip() -> void:
	if _type_tween:
		_type_tween.kill()
	dlg.visible = false
	dialogue_finished.emit()

func _build_clear(root: Control) -> void:
	clear_panel = ColorRect.new()
	(clear_panel as ColorRect).color = Color(0, 0, 0, 0.4)
	clear_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	clear_panel.visible = false
	root.add_child(clear_panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	clear_panel.add_child(center)
	var p := panel(PAPER, 20)
	p.custom_minimum_size = Vector2(520, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var hp := panel(BLUE, 8)
	clear_title = label("", 28, Color.WHITE)
	clear_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.add_child(clear_title)
	v.add_child(hp)
	clear_stars = label("", 46, GOLD, true)
	clear_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(clear_stars)
	clear_detail = label("", 20, INK)
	clear_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(clear_detail)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	next_button = make_button("다음 레벨 (Enter)", BLUE)
	next_button.pressed.connect(func(): next_pressed.emit())
	var retry := make_button("다시 하기 (R)", WOOD)
	retry.pressed.connect(func(): retry_pressed.emit())
	hb.add_child(next_button)
	hb.add_child(retry)
	v.add_child(hb)

func show_clear(title: String, stars: int, detail: String, last: bool) -> void:
	clear_title.text = title
	clear_stars.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	clear_detail.text = detail
	next_button.text = "메뉴로 (Enter)" if last else "다음 레벨 (Enter)"
	clear_panel.visible = true
	if code_panel:
		code_panel.move_to_front()
	clear_panel.modulate.a = 0.0
	create_tween().tween_property(clear_panel, "modulate:a", 1.0, 0.25)

func hide_clear() -> void:
	clear_panel.visible = false
	if code_panel:
		code_panel.get_parent().move_child(code_panel, 1)

func set_title(id: String, name: String) -> void:
	title_id.text = id
	title_name.text = name

func set_goal(t: String) -> void:
	goal_label.text = t

func set_controls(t: String) -> void:
	controls_label.text = t

func set_info(level_text: String, rows: Array) -> void:
	level_label.text = level_text
	while info_box.get_child_count() < rows.size():
		var pr := panel(PAPER, 2)
		var h := HBoxContainer.new()
		var k := label("", 16, INK)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(k)
		h.add_child(label("", 17, NAVY))
		pr.add_child(h)
		info_box.add_child(pr)
	for i in info_box.get_child_count():
		var pr: Control = info_box.get_child(i)
		pr.visible = i < rows.size()
		if i < rows.size():
			var h: HBoxContainer = pr.get_child(0)
			(h.get_child(0) as Label).text = str(rows[i][0])
			(h.get_child(1) as Label).text = str(rows[i][1])

func toast(t: String, col := Color.WHITE, dur := 2.6) -> void:
	toast_label.text = t
	toast_label.add_theme_color_override("font_color", col)
	toast_panel.reset_size()
	await get_tree().process_frame
	toast_panel.position = Vector2(toast_center_x - toast_panel.size.x / 2, toast_y)
	if _toast_tween:
		_toast_tween.kill()
	toast_panel.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(dur)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.4)
