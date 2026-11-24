class_name LiveTestBotOverlay
extends CanvasLayer
## NODEVERSE Live Visual Test Bot (In-Game Real-Time Auto-Play Simulator)
## Attaches to SceneTree.root so it persists across 3D World, 2D Computer Menu, and all 24 2D Minigames.
## Lets users watch the bot physically walk the 3D/2D robot, talk to NPCs, solve quizzes,
## enter computer terminals, and play 2D minigames step-by-step on screen.

const Catalog = preload("res://scripts/learning_catalog.gd")
const SqlModel = preload("res://scripts/minigames/sql_query_model.gd")

const ISLAND_ORDER: Array[String] = ["MAIN", "INTRO", "DS", "SQL", "ALGO", "DATA", "CHALLENGE"]
const ISLAND_NAMES: Dictionary = {
	"MAIN": "메인 섬 (Main Hub)",
	"INTRO": "입문 섬 (Intro Basics)",
	"DS": "자료구조 섬 (Data Structures)",
	"ALGO": "알고리즘 섬 (Algorithms)",
	"SQL": "SQL 섬 (Database & Query)",
	"DATA": "데이터 탐험 섬 (Data Exploration)",
	"CHALLENGE": "종합 도전 섬 (Grand Challenge)"
}
# Representative minigame per computer terminal island
const ISLAND_DEFAULT_STAGE: Dictionary = {
	"DS": "ST01",
	"ALGO": "ALG01",
	"SQL": "SQL01",
	"DATA": "DATA01",
	"CHALLENGE": "CHAL01_CodingTest"
}

var _nav_astar: AStar2D = null
var _active_2d_category: String = ""

var is_running: bool = false
var stop_requested: bool = false
var speed_mult: float = 1.0
var _run_token: int = 0

# UI Nodes
var launcher_panel: PanelContainer
var running_bar: PanelContainer
var step_title_lbl: Label
var step_action_lbl: Label
var speed_btn: Button
var stop_btn: Button
var result_banner: PanelContainer
var result_lbl: Label

func _ready() -> void:
	layer = 126
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "LiveTestBotOverlay"
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			if is_running:
				stop_bot("사용자가 F5 키로 테스트 봇을 중지했습니다.")
			else:
				toggle_launcher()
			get_viewport().set_input_as_handled()

func toggle_launcher() -> void:
	if is_running:
		stop_bot("테스트 봇을 중지했습니다.")
		return
	if result_banner != null:
		result_banner.visible = false
	if launcher_panel != null:
		launcher_panel.visible = false
	# Immediately start moving and playing on the current screen!
	_on_start_current_scene_bot()

func toggle_course_menu() -> void:
	if launcher_panel != null:
		launcher_panel.visible = not launcher_panel.visible

func open_launcher() -> void:
	if is_running:
		return
	if result_banner != null:
		result_banner.visible = false
	if launcher_panel != null:
		launcher_panel.visible = true

func _cycle_speed() -> void:
	if is_equal_approx(speed_mult, 1.0):
		speed_mult = 2.0
	elif is_equal_approx(speed_mult, 2.0):
		speed_mult = 3.5
	else:
		speed_mult = 1.0
	_update_speed_buttons()

func _update_speed_buttons() -> void:
	var txt := "⚡ 속도 %.1fx" % speed_mult if not is_equal_approx(speed_mult, round(speed_mult)) else "⚡ 속도 %dx" % int(speed_mult)
	if speed_btn != null:
		speed_btn.text = txt
	var l_spd = launcher_panel.find_child("LauncherSpeedBtn", true, false) as Button if launcher_panel else null
	if l_spd != null:
		l_spd.text = txt

func _wait_sec(sec: float, token: int) -> bool:
	if stop_requested or token != _run_token:
		return false
	var scaled := maxf(0.03, sec / maxf(0.5, speed_mult))
	var elapsed := 0.0
	while elapsed < scaled:
		if stop_requested or token != _run_token:
			return false
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return not stop_requested and token == _run_token

func _set_live_status(step_text: String, action_text: String) -> void:
	if step_title_lbl != null:
		step_title_lbl.text = "🤖 " + step_text
	if step_action_lbl != null:
		step_action_lbl.text = "▶ " + action_text

# ============================================================================
# UI CONSTRUCTION
# ============================================================================
func _make_box_style(bg: Color, border: Color, radius: int = 12, pad_x: int = 16, pad_y: int = 12, bw: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 10
	return sb

func _style_btn(btn: Button, bg: Color, hover_bg: Color, fg: Color = Color.WHITE, fsize: int = 14) -> void:
	btn.add_theme_font_size_override("font_size", fsize)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.add_theme_stylebox_override("normal", _make_box_style(bg, bg.lightened(0.25), 8, 12, 6, 1))
	btn.add_theme_stylebox_override("hover", _make_box_style(hover_bg, hover_bg.lightened(0.35), 8, 12, 6, 1))
	btn.add_theme_stylebox_override("pressed", _make_box_style(bg.darkened(0.15), bg.lightened(0.2), 8, 12, 6, 1))
	btn.focus_mode = Control.FOCUS_NONE

func _build_ui() -> void:
	# 1. Launcher Control Panel (Top-Right dropdown modal, cleanly below running bar)
	launcher_panel = PanelContainer.new()
	launcher_panel.name = "BotLauncherPanel"
	launcher_panel.visible = false
	launcher_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	launcher_panel.offset_left = -520.0
	launcher_panel.offset_top = 88.0
	launcher_panel.offset_right = -24.0
	launcher_panel.offset_bottom = 456.0
	launcher_panel.add_theme_stylebox_override(
		"panel",
		_make_box_style(Color(0.06, 0.10, 0.15, 0.96), Color(0.18, 0.72, 0.58, 0.9), 14, 18, 16, 2)
	)
	add_child(launcher_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	launcher_panel.add_child(vb)

	var hdr := HBoxContainer.new()
	vb.add_child(hdr)
	var title := Label.new()
	title.text = "🤖 시나리오 테스트 봇 (실시간 플레이 시뮬레이터)"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.35, 0.98, 0.82))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)

	var l_spd := Button.new()
	l_spd.name = "LauncherSpeedBtn"
	l_spd.text = "⚡ 속도 1x"
	l_spd.custom_minimum_size = Vector2(92, 30)
	_style_btn(l_spd, Color(0.14, 0.24, 0.34), Color(0.20, 0.34, 0.48), Color(1.0, 0.92, 0.45), 13)
	l_spd.pressed.connect(_cycle_speed)
	hdr.add_child(l_spd)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(30, 30)
	_style_btn(close_btn, Color(0.28, 0.12, 0.14), Color(0.45, 0.16, 0.18), Color.WHITE, 13)
	close_btn.pressed.connect(_on_close_launcher)
	hdr.add_child(close_btn)

	var desc := Label.new()
	desc.text = "시나리오 파일(scenarios/default_full_scenario.json)을 기반으로 봇이 직접 캐릭터를 움직여\n3D 월드 이동 · NPC 대화 · 퀴즈 · 컴퓨터 접속 · 2D 미니게임 풀이를 화면에서 시연합니다."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.82, 0.88, 0.94))
	vb.add_child(desc)

	var btn_full := Button.new()
	btn_full.text = "▶ 전체 코스 자동 플레이 (3D 월드 이동 → NPC 대화 → 컴퓨터 접속 → 2D 미니게임)"
	btn_full.custom_minimum_size = Vector2(0, 42)
	_style_btn(btn_full, Color(0.09, 0.52, 0.42), Color(0.12, 0.64, 0.52), Color.WHITE, 14)
	btn_full.pressed.connect(_on_start_full_tour)
	vb.add_child(btn_full)

	var btn_cur := Button.new()
	btn_cur.text = "🎯 현재 열려 있는 화면(현재 섬 / 현재 2D 미니게임) 즉시 봇 플레이"
	btn_cur.custom_minimum_size = Vector2(0, 38)
	_style_btn(btn_cur, Color(0.14, 0.36, 0.58), Color(0.18, 0.46, 0.72), Color.WHITE, 14)
	btn_cur.pressed.connect(_on_start_current_scene_bot)
	vb.add_child(btn_cur)

	var sub_lbl := Label.new()
	sub_lbl.text = "🎮 섬 컴퓨터로 걸어가서 접속 후 미니게임 봇 플레이 보기:"
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	vb.add_child(sub_lbl)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)

	_add_stage_demo_btn(grid, "📦 [자료구조] ST01 배열 보관소", "ST01")
	_add_stage_demo_btn(grid, "📦 [자료구조] ST03 스택 복구실", "ST03")
	_add_stage_demo_btn(grid, "⚡ [알고리즘] ALG01 기본 정렬", "ALG01")
	_add_stage_demo_btn(grid, "🏛️ [SQL] SQL01 5x5 쿼리 서랍", "SQL01")
	_add_stage_demo_btn(grid, "🔭 [데이터] DATA01 데이터 정제", "DATA01")
	_add_stage_demo_btn(grid, "🌳 [자료구조] DS09 트리 조립", "DS09")

	# 2. Running Top-Center Live Banner
	running_bar = PanelContainer.new()
	running_bar.name = "BotRunningBar"
	running_bar.visible = false
	running_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	running_bar.offset_left = 180.0
	running_bar.offset_top = 12.0
	running_bar.offset_right = -180.0
	running_bar.offset_bottom = 82.0
	running_bar.add_theme_stylebox_override(
		"panel",
		_make_box_style(Color(0.05, 0.11, 0.16, 0.94), Color(0.20, 0.85, 0.65, 0.95), 14, 18, 10, 2)
	)
	add_child(running_bar)

	var r_hb := HBoxContainer.new()
	r_hb.add_theme_constant_override("separation", 14)
	running_bar.add_child(r_hb)

	var r_vb := VBoxContainer.new()
	r_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_vb.add_theme_constant_override("separation", 3)
	r_hb.add_child(r_vb)

	step_title_lbl = Label.new()
	step_title_lbl.text = "🤖 [테스트 봇 자동 플레이 중] 시나리오 준비 중..."
	step_title_lbl.add_theme_font_size_override("font_size", 16)
	step_title_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.82))
	r_vb.add_child(step_title_lbl)

	step_action_lbl = Label.new()
	step_action_lbl.text = "▶ 로봇 이동 및 상호작용 시뮬레이션"
	step_action_lbl.add_theme_font_size_override("font_size", 13)
	step_action_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.70))
	r_vb.add_child(step_action_lbl)

	var menu_btn := Button.new()
	menu_btn.text = "📋 코스 선택"
	menu_btn.custom_minimum_size = Vector2(104, 36)
	_style_btn(menu_btn, Color(0.16, 0.24, 0.34), Color(0.24, 0.36, 0.50), Color(0.88, 0.96, 1.0), 13)
	menu_btn.pressed.connect(toggle_course_menu)
	r_hb.add_child(menu_btn)

	speed_btn = Button.new()
	speed_btn.text = "⚡ 속도 1x"
	speed_btn.custom_minimum_size = Vector2(96, 36)
	_style_btn(speed_btn, Color(0.14, 0.26, 0.38), Color(0.20, 0.36, 0.52), Color(1.0, 0.92, 0.45), 13)
	speed_btn.pressed.connect(_cycle_speed)
	r_hb.add_child(speed_btn)

	stop_btn = Button.new()
	stop_btn.text = "⏹ 봇 중지 (F5)"
	stop_btn.custom_minimum_size = Vector2(126, 36)
	_style_btn(stop_btn, Color(0.65, 0.16, 0.18), Color(0.82, 0.22, 0.24), Color.WHITE, 13)
	stop_btn.pressed.connect(_on_stop_btn_pressed)
	r_hb.add_child(stop_btn)

	# 3. Completion Banner
	result_banner = PanelContainer.new()
	result_banner.name = "BotResultBanner"
	result_banner.visible = false
	result_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	result_banner.offset_left = 220.0
	result_banner.offset_top = 14.0
	result_banner.offset_right = -220.0
	result_banner.offset_bottom = 76.0
	result_banner.add_theme_stylebox_override(
		"panel",
		_make_box_style(Color(0.06, 0.18, 0.14, 0.95), Color(0.25, 0.92, 0.68, 0.95), 12, 16, 10, 2)
	)
	add_child(result_banner)

	var res_hb := HBoxContainer.new()
	res_hb.add_theme_constant_override("separation", 12)
	result_banner.add_child(res_hb)

	result_lbl = Label.new()
	result_lbl.text = "✅ 시나리오 테스트 봇 플레이 완료!"
	result_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_lbl.add_theme_font_size_override("font_size", 15)
	result_lbl.add_theme_color_override("font_color", Color(0.85, 1.0, 0.92))
	res_hb.add_child(result_lbl)

	var res_close := Button.new()
	res_close.text = "닫기"
	res_close.custom_minimum_size = Vector2(68, 32)
	_style_btn(res_close, Color(0.15, 0.38, 0.30), Color(0.22, 0.52, 0.40), Color.WHITE, 13)
	res_close.pressed.connect(_on_close_result_banner)
	res_hb.add_child(res_close)

func _add_stage_demo_btn(parent: Node, label_text: String, stage_id: String) -> void:
	var b := Button.new()
	b.text = label_text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(215, 34)
	_style_btn(b, Color(0.12, 0.20, 0.28), Color(0.18, 0.30, 0.42), Color(0.92, 0.96, 1.0), 13)
	b.pressed.connect(_on_stage_demo_selected.bind(stage_id))
	parent.add_child(b)

func _on_close_launcher() -> void:
	launcher_panel.visible = false

func _on_close_result_banner() -> void:
	result_banner.visible = false

func _on_stop_btn_pressed() -> void:
	stop_bot("사용자가 [⏹ 봇 중지] 버튼을 눌렀습니다.")

func stop_bot(reason: String = "") -> void:
	stop_requested = true
	is_running = false
	_run_token += 1
	_clear_player_bot_inputs()
	if running_bar != null:
		running_bar.visible = false
	if not reason.is_empty():
		_show_completion_banner("⏹ " + reason)

func _clear_player_bot_inputs() -> void:
	var sc := get_tree().current_scene
	if sc == null:
		return
	var p = sc.get("player")
	if p != null and is_instance_valid(p):
		if "bot_move_dir" in p:
			p.bot_move_dir = Vector2.ZERO
		if "bot_sprint" in p:
			p.bot_sprint = false
		if "can_move" in p:
			p.can_move = true
		if "active" in p:
			p.active = true

func _show_completion_banner(msg: String) -> void:
	if result_banner != null and result_lbl != null:
		result_lbl.text = msg
		result_banner.visible = true

# ============================================================================
# BOT RUNNERS (FULL TOUR / CURRENT SCENE / SPECIFIC STAGE)
# ============================================================================
func _begin_bot_session() -> int:
	_run_token += 1
	is_running = true
	stop_requested = false
	if launcher_panel != null:
		launcher_panel.visible = false
	if result_banner != null:
		result_banner.visible = false
	if running_bar != null:
		running_bar.visible = true
	return _run_token

func _on_start_full_tour() -> void:
	var token := _begin_bot_session()
	await _run_full_scenario_tour(token)

func _on_start_current_scene_bot() -> void:
	var token := _begin_bot_session()
	var sc := get_tree().current_scene
	if sc == null:
		stop_bot()
		return
	var spath: String = str(sc.get_script().resource_path) if sc.get_script() else ""
	if spath == "res://scripts/nodeverse_world.gd":
		await _run_full_scenario_tour(token)
	elif spath == "res://scripts/main_menu.gd":
		_set_live_status("컴퓨터 메뉴 자동 선택", "첫 번째 미니게임을 자동으로 시작합니다...")
		if not await _wait_sec(0.8, token):
			return
		var games: Array = Catalog.games_for(Catalog.selected_category)
		if not games.is_empty():
			sc._go(games[0][4])
			await get_tree().process_frame
			await get_tree().process_frame
			await _play_current_2d_stage(token, 1)
	else:
		await _play_current_2d_stage(token, 2)

	if not stop_requested and token == _run_token:
		is_running = false
		running_bar.visible = false
		_show_completion_banner("✅ 현재 화면 테스트 봇 자동 플레이가 완료되었습니다!")

func _find_terminal_for_category(world: Node, cat: String) -> Node3D:
	for term in world.computer_terminals:
		if is_instance_valid(term) and String(term.get_meta("quiz_zone", "DS")) == cat:
			return term
	if not world.computer_terminals.is_empty():
		return world.computer_terminals[0]
	return null

func _find_npc_for_island(world: Node, zone_key: String) -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	for npc in world.spawned_npcs:
		if is_instance_valid(npc) and String(world._zone_of(npc.global_position)) == zone_key:
			var d: float = world.player.global_position.distance_to(npc.global_position)
			if d < best_d:
				best_d = d
				best = npc
	return best

func _walk_to_terminal_and_enter_stage(world: Node, target_cat: String, stage_id: String, target_scene: String, target_title: String, token: int) -> bool:
	_ensure_world_playing(world)
	Catalog.selected_category = target_cat
	var cat_kor: String = str(Catalog.CATEGORIES.get(target_cat, target_cat))
	var target_term: Node3D = _find_terminal_for_category(world, target_cat)

	if is_instance_valid(target_term):
		var front_pos: Vector3 = target_term.global_position + target_term.global_basis.z * 1.5
		_set_live_status("[%s 섬] 다리와 길을 따라 컴퓨터로 걸어가는 중" % cat_kor, "3D 로봇이 순간이동 없이 [%s] 섬 컴퓨터 책상까지 직접 걸어갑니다..." % cat_kor)
		await _walk_3d_player_to(world, front_pos, 1.55, token)
		if stop_requested or token != _run_token:
			return false

		_set_live_status("[%s 섬] 컴퓨터 도착 · 모니터 접속(E)" % cat_kor, "💻 [E] 컴퓨터 접속 -> [%s] 화면으로 줌인합니다..." % target_title)
		if not await _wait_sec(0.55, token):
			return false
		await world._open_computer_game()
		_active_2d_category = target_cat
		await get_tree().process_frame
		await get_tree().process_frame

	return await _select_stage_from_2d_menu_and_enter(target_cat, stage_id, target_scene, target_title, token)

func _select_stage_from_2d_menu_and_enter(target_cat: String, stage_id: String, target_scene: String, target_title: String, token: int) -> bool:
	Catalog.selected_category = target_cat
	_active_2d_category = target_cat
	var cat_kor: String = str(Catalog.CATEGORIES.get(target_cat, target_cat))
	var menu_sc := get_tree().current_scene
	var menu_spath: String = str(menu_sc.get_script().resource_path) if (menu_sc != null and menu_sc.get_script() != null) else ""
	if menu_spath != "res://scripts/main_menu.gd":
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		await get_tree().process_frame
		await get_tree().process_frame
		menu_sc = get_tree().current_scene

	if menu_sc != null and menu_sc.get_script() != null and str(menu_sc.get_script().resource_path) == "res://scripts/main_menu.gd":
		var cat_games: Array = Catalog.games_for(target_cat)
		for idx in cat_games.size():
			if str(cat_games[idx][0]) == stage_id:
				menu_sc.page = int(idx / 6)
				menu_sc.queue_redraw()
				break
		_set_live_status("[%s 섬 컴퓨터 메뉴] %s 선택" % [cat_kor, target_title], "같은 섬 컴퓨터 메뉴에서 [%s] 카드를 선택합니다..." % target_title)
		if not await _wait_sec(0.85, token):
			return false

	_set_live_status("2D 미니게임 봇 자동 플레이: " + target_title, "스테이지 입장 완료 · 로봇 이동 및 자동 풀이 시작!")
	get_tree().change_scene_to_file("res://scenes/stages/%s.tscn" % target_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	return await _wait_sec(0.4, token)

func _on_stage_demo_selected(stage_id: String) -> void:
	var token := _begin_bot_session()
	var target_scene := ""
	var target_cat := "DS"
	var target_title := stage_id
	for g in Catalog.GAMES:
		if str(g[0]) == stage_id:
			target_title = "%s (%s)" % [str(g[1]), str(g[2])]
			target_cat = str(g[3])
			target_scene = str(g[4])
			break
	if target_scene.is_empty():
		stop_bot("스테이지를 찾을 수 없습니다: " + stage_id)
		return

	var sc := get_tree().current_scene
	var cur_spath: String = str(sc.get_script().resource_path) if (sc != null and sc.get_script() != null) else ""
	var is_in_2d: bool = (cur_spath != "res://scripts/nodeverse_world.gd")
	var cur_2d_cat: String = _active_2d_category if not _active_2d_category.is_empty() else str(Catalog.selected_category)

	# Same-island check: if we are ALREADY inside the 2D computer of the same island (target_cat == cur_2d_cat),
	# do NOT exit to 3D and walk to the same computer again — switch directly via this island's 2D computer menu!
	if is_in_2d and cur_2d_cat == target_cat:
		var ok_same := await _select_stage_from_2d_menu_and_enter(target_cat, stage_id, target_scene, target_title, token)
		if not ok_same or stop_requested or token != _run_token:
			return
	else:
		# Different island (or currently in 3D world): exit to 3D if in 2D, then physically walk across bridges to target_cat's computer!
		if is_in_2d:
			_set_live_status("다른 섬(%s)으로 걸어가기 위해 3D 월드 복귀" % str(Catalog.CATEGORIES.get(target_cat, target_cat)), "현재 컴퓨터에서 나와 다른 섬의 컴퓨터로 직접 걸어갑니다...")
			await _return_to_3d_world()
			if not await _wait_sec(0.35, token):
				return
			sc = get_tree().current_scene
			cur_spath = str(sc.get_script().resource_path) if (sc != null and sc.get_script() != null) else ""

		if sc != null and cur_spath == "res://scripts/nodeverse_world.gd":
			var entered := await _walk_to_terminal_and_enter_stage(sc, target_cat, stage_id, target_scene, target_title, token)
			if not entered or stop_requested or token != _run_token:
				return

	await _play_current_2d_stage(token, 2)
	if stop_requested or token != _run_token:
		return

	_set_live_status("미니게임 클리어 완료: " + target_title, "컴퓨터 메뉴로 돌아갑니다...")
	if not await _wait_sec(0.8, token):
		return
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	is_running = false
	running_bar.visible = false
	_show_completion_banner("✅ [%s] 테스트 봇 자동 플레이 완료! (같은 섬 다른 코스는 바로 전환됩니다)" % target_title)

# ============================================================================
# FULL SCENARIO VISUAL TOUR (3D WORLD -> NPC -> QUIZ -> TERMINAL -> 2D STAGES -> REPORT)
# ============================================================================
func _ensure_world_playing(world: Node) -> void:
	if world.game_state != world.GameState.PLAYING:
		if world.current_user == "":
			world._on_guest_pressed()
		world._set_game_state(world.GameState.PLAYING)

func _run_full_scenario_tour(token: int) -> void:
	# Ensure we start in 3D World
	var sc := get_tree().current_scene
	if sc == null or sc.get_script() == null or str(sc.get_script().resource_path) != "res://scripts/nodeverse_world.gd":
		await _return_to_3d_world()
		sc = get_tree().current_scene

	if sc == null or sc.get_script() == null or str(sc.get_script().resource_path) != "res://scripts/nodeverse_world.gd":
		stop_bot("3D 월드 씬을 찾을 수 없습니다.")
		return

	var world: Node = sc
	_ensure_world_playing(world)
	if not await _wait_sec(0.4, token):
		return

	# Build rotation of all 7 islands starting from the player's current island!
	var cur_zone: String = String(world._zone_name) if ("_zone_name" in world and not String(world._zone_name).is_empty()) else "MAIN"
	var start_idx: int = maxi(0, ISLAND_ORDER.find(cur_zone))
	var ordered_islands: Array[String] = []
	for i in ISLAND_ORDER.size():
		ordered_islands.append(ISLAND_ORDER[(start_idx + i) % ISLAND_ORDER.size()])

	# Visit each of the 7 islands one by one!
	for idx in ordered_islands.size():
		if stop_requested or token != _run_token:
			return
		var zkey: String = ordered_islands[idx]
		var ztitle: String = str(ISLAND_NAMES.get(zkey, zkey))
		var step_prefix := "[섬 %d/%d · %s]" % [idx + 1, ordered_islands.size(), ztitle]

		# Ensure we are in 3D world before starting this island
		sc = get_tree().current_scene
		if sc == null or sc.get_script() == null or str(sc.get_script().resource_path) != "res://scripts/nodeverse_world.gd":
			await _return_to_3d_world()
			sc = get_tree().current_scene
		world = sc

		# 1) Walk across bridges (NO teleportation!) to this island's NPC and talk
		var island_npc: Node3D = _find_npc_for_island(world, zkey)
		if is_instance_valid(island_npc):
			var npc_name_str := String(island_npc.get_meta("npc_name", "NPC"))
			_set_live_status("%s 다리를 건너 NPC에게 걸어가는 중" % step_prefix, "순간이동 없이 다리와 길을 따라 [%s] 앞으로 걸어갑니다..." % npc_name_str)
			await _walk_3d_player_to(world, island_npc.global_position, 1.85, token)
			if stop_requested or token != _run_token:
				return
			_set_live_status("%s NPC 대화 진행" % step_prefix, "[%s] 앞에서 [E] 키를 눌러 대화합니다..." % npc_name_str)
			world.active_npc = island_npc
			world._talk_to_npc(island_npc)
			if not await _wait_sec(1.0, token):
				return
			while world.npc_dialog_open():
				if stop_requested or token != _run_token:
					return
				world._advance_npc_dialog()
				if not await _wait_sec(0.85, token):
					return

		# 2) Trigger this island's 3D gimmick & solve 1 quiz question
		_set_live_status("%s 3D 기믹 및 퀴즈 풀이" % step_prefix, "%s의 3D 학습 장치와 퀴즈를 검증합니다..." % ztitle)
		world._on_interact()
		if not await _wait_sec(0.65, token):
			return
		world._open_quiz_for_zone(zkey)
		if not await _wait_sec(1.0, token):
			return
		if world.is_quiz_open and not world.current_quiz_item.is_empty():
			var ans_idx: int = int(world.current_quiz_item.get("a", 0))
			world._on_quiz_option_selected(ans_idx)
			if not await _wait_sec(1.1, token):
				return
			world._close_quiz()
			if not await _wait_sec(0.45, token):
				return

		# 3) If this island has a Computer Terminal (DS, ALGO, SQL, DATA), walk to the computer, zoom in, play its 2D minigame, and zoom back out to 3D!
		if ISLAND_DEFAULT_STAGE.has(zkey):
			var st_id: String = str(ISLAND_DEFAULT_STAGE[zkey])
			var st_scene := ""
			var st_title := st_id
			for g in (Catalog.GAMES + Catalog.CHALLENGE_GAMES):
				if str(g[0]) == st_id or str(g[4]) == st_id:
					st_title = "%s (%s)" % [str(g[1]), str(g[2])]
					st_scene = str(g[4])
					break
			if not st_scene.is_empty():
				var ok_enter := await _walk_to_terminal_and_enter_stage(world, zkey, st_id, st_scene, st_title, token)
				if not ok_enter or stop_requested or token != _run_token:
					return
				await _play_current_2d_stage(token, 1)
				if stop_requested or token != _run_token:
					return
				_set_live_status("%s 미니게임 클리어 -> 3D 월드 복귀" % step_prefix, "컴퓨터에서 나와 다음 섬으로 이동할 준비를 합니다...")
				if not await _wait_sec(0.65, token):
					return
				await _return_to_3d_world()
				if not await _wait_sec(0.45, token):
					return

	is_running = false
	running_bar.visible = false
	_show_completion_banner("✅ 7개 섬 전체 순회 및 컴퓨터 미니게임 테스트 봇 플레이가 완료되었습니다!")

func _return_to_3d_world() -> void:
	_active_2d_category = ""
	var world_script = load("res://scripts/nodeverse_world.gd")
	if world_script and world_script.return_from_2d(get_tree()):
		await get_tree().process_frame
		await get_tree().process_frame
		var w := get_tree().current_scene
		# Wait until the 1.0s monitor zoom-out camera tween finishes so the 3D player camera is active!
		var wait_guard := 0
		while w != null and is_instance_valid(w) and "_zoom_cam" in w and w._zoom_cam != null and wait_guard < 90:
			wait_guard += 1
			await get_tree().process_frame
		if w != null and is_instance_valid(w) and "player" in w and w.player != null:
			w.player.can_move = true
		return
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_tree().change_scene_to_file("res://scenes/NodeverseWorld.tscn")
	await get_tree().process_frame
	await get_tree().process_frame

# ============================================================================
# 3D ROBOT PHYSICAL WALK CONTROLLER (A* BRIDGE & PATH NAVIGATION - ZERO TELEPORT)
# ============================================================================
func _ensure_3d_astar(world: Node) -> void:
	if _nav_astar != null and _nav_astar.get_point_count() > 100:
		return
	_nav_astar = AStar2D.new()
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state

	# Exclude Ground and Bridge floor StaticBody3Ds from the 3D obstacle cylinder query
	var floor_rids: Array[RID] = []
	if world.player != null:
		floor_rids.append(world.player.get_rid())
	for n in world.find_children("*", "StaticBody3D", true, false):
		var sb := n as StaticBody3D
		if sb != null and (sb.name == "Ground" or "Bridge" in sb.name or (sb.get_parent() and "Bridge" in sb.get_parent().name)):
			floor_rids.append(sb.get_rid())

	var cyl := CylinderShape3D.new()
	cyl.radius = 0.36
	cyl.height = 0.96
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = cyl
	sq.exclude = floor_rids

	var step: float = 0.5
	var x_min: int = -66
	var x_max: int = 66
	var z_min: int = -74
	var z_max: int = 42
	var valid: Dictionary = {}
	var pos_map: Dictionary = {}

	for ix in range(x_min, x_max + 1):
		for iz in range(z_min, z_max + 1):
			var p := Vector3(float(ix) * step, 1.0, float(iz) * step)
			var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3.0, 0), p - Vector3(0, 1.0, 0))
			if world.player != null:
				q.exclude = [world.player.get_rid()]
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty():
				continue
			var hp: Vector3 = hit["position"]
			var hn: Vector3 = hit["normal"]
			# Walkable floor & bridge deck ONLY (0.85 .. 1.48), strictly excluding bridge railings (1.78+) and props
			if hp.y < 0.85 or hp.y > 1.48 or hn.y < 0.72:
				continue
			# Check ankle-to-head 3D cylinder (radius=0.36m, y=gy+0.14..gy+1.10) against ALL props/obstacles/pedestals/lamps
			sq.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, hp.y + 0.62, p.z))
			var col: Array = space.intersect_shape(sq, 1)
			if not col.is_empty():
				continue
			# Keep robot out of the narrow interior pocket between the 5 graph pedestals on ALGO island
			if p.z >= -18.8 and p.z <= -13.9 and p.x >= -2.7 and p.x <= 2.7:
				continue
			var pid: int = (ix - x_min) * 1000 + (iz - z_min)
			valid[Vector2i(ix, iz)] = pid
			pos_map[pid] = Vector2(p.x, p.z)

	# Build adjacency and flood-fill from Main Island spawn (0, 11) so disconnected pockets/traps are 100% removed
	var adj: Dictionary = {}
	for cell in valid.keys():
		var pid: int = valid[cell]
		adj[pid] = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cell + d
			if valid.has(nb):
				adj[pid].append(valid[nb])
		for d in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var nb: Vector2i = cell + d
			if valid.has(nb) and valid.has(cell + Vector2i(d.x, 0)) and valid.has(cell + Vector2i(0, d.y)):
				adj[pid].append(valid[nb])

	var seed_pid: int = -1
	var best_seed_d: float = INF
	for pid in pos_map.keys():
		var d: float = (pos_map[pid] as Vector2).distance_to(Vector2(0.0, 11.0))
		if d < best_seed_d:
			best_seed_d = d
			seed_pid = pid

	var reachable: Dictionary = {}
	if seed_pid != -1:
		var queue: Array[int] = [seed_pid]
		reachable[seed_pid] = true
		var head: int = 0
		while head < queue.size():
			var cur_pid: int = queue[head]
			head += 1
			for nb_pid in adj[cur_pid]:
				if not reachable.has(nb_pid):
					reachable[nb_pid] = true
					queue.append(nb_pid)

	# Add only flood-fill reachable nodes and penalize edge nodes so A* stays in the center of bridges and paths
	for cell in valid.keys():
		var pid: int = valid[cell]
		if not reachable.has(pid):
			continue
		_nav_astar.add_point(pid, pos_map[pid])
		var card_count: int = 0
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cell + d
			if valid.has(nb) and reachable.has(valid[nb]):
				card_count += 1
		var diag_count: int = 0
		for d in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var nb: Vector2i = cell + d
			if valid.has(nb) and reachable.has(valid[nb]):
				diag_count += 1
		var w_scale: float = 1.0
		if card_count < 4:
			w_scale = 6.0
		elif diag_count < 4:
			w_scale = 2.5
		_nav_astar.set_point_weight_scale(pid, w_scale)

	for pid in reachable.keys():
		for nb_pid in adj[pid]:
			if reachable.has(nb_pid):
				_nav_astar.connect_points(pid, nb_pid, false)

func _walk_3d_player_to(world: Node, target_pos: Vector3, stop_dist: float, token: int) -> void:
	if world == null or world.player == null:
		return
	_ensure_3d_astar(world)
	var p: CharacterBody3D = world.player
	p.can_move = true

	var start_v2 := Vector2(p.global_position.x, p.global_position.z)
	var goal_v2 := Vector2(target_pos.x, target_pos.z)
	var s_id: int = _nav_astar.get_closest_point(start_v2)
	var g_id: int = _nav_astar.get_closest_point(goal_v2)
	var raw_path: PackedVector2Array = _nav_astar.get_point_path(s_id, g_id)

	var waypoints: Array[Vector3] = []
	for pt in raw_path:
		waypoints.append(Vector3(pt.x, float(world.TOP) + 0.1, pt.y))
	if waypoints.is_empty():
		waypoints.append(target_pos)

	var wp_idx: int = 0
	var max_time: float = 40.0
	var elapsed: float = 0.0
	var stuck_timer: float = 0.0
	var prev_pos: Vector3 = p.global_position

	while elapsed < max_time and wp_idx < waypoints.size():
		if stop_requested or token != _run_token or not is_instance_valid(p):
			break
		var cur := p.global_position
		var dist_to_target := Vector2(target_pos.x - cur.x, target_pos.z - cur.z).length()
		if dist_to_target <= stop_dist:
			break

		var wp: Vector3 = waypoints[wp_idx]
		var diff := Vector3(wp.x - cur.x, 0.0, wp.z - cur.z)
		var reach_r: float = 0.35 if wp_idx == waypoints.size() - 1 else 0.42
		if diff.length() <= reach_r:
			wp_idx += 1
			stuck_timer = 0.0
			continue

		var dir3 := diff.normalized()
		var yaw_rad := deg_to_rad(p.cam_yaw)
		var fwd := Vector3(-sin(yaw_rad), 0.0, -cos(yaw_rad))
		var right := Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad))
		var ix := dir3.dot(right)
		var iy := dir3.dot(fwd)
		p.bot_move_dir = Vector2(ix, iy).normalized()
		if "bot_sprint" in p:
			p.bot_sprint = (dist_to_target > 3.5 or speed_mult > 1.0)

		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		elapsed += dt

		if p.global_position.distance_to(prev_pos) < 0.008:
			stuck_timer += dt
			if stuck_timer > 0.35:
				# Re-path from current position or advance waypoint
				if wp_idx < waypoints.size() - 1:
					wp_idx += 1
				stuck_timer = 0.0
		else:
			stuck_timer = 0.0
		prev_pos = p.global_position

	if is_instance_valid(p):
		p.bot_move_dir = Vector2.ZERO
		if "bot_sprint" in p:
			p.bot_sprint = false
		p.velocity = Vector3.ZERO

# ============================================================================
# 2D MINIGAME VISUAL BOT PLAYERS (ST01, WALK STAGES, LAB STAGES, SQL DRAWER)
# ============================================================================
func _play_current_2d_stage(token: int, max_levels: int = 2) -> void:
	var stage := get_tree().current_scene
	if stage == null:
		return
	var spath: String = str(stage.get_script().resource_path) if stage.get_script() else ""

	if spath == "res://scripts/play/st01_array_stage.gd":
		await _play_visual_st01(stage, token, max_levels)
	elif spath == "res://scripts/minigames/sql_drawer.gd":
		await _play_visual_sql_drawer(stage, token, max_levels)
	elif spath == "res://scripts/minigames/coding_test_challenge.gd":
		await _play_visual_coding_test(stage, token, max_levels)
	elif stage.has_method("on_button") and "activity" in stage:
		await _play_visual_lab_stage(stage, token, max_levels)
	elif stage is WalkStage:
		await _play_visual_walk_stage(stage, token, max_levels)

func _play_visual_coding_test(stage: Node, token: int, max_levels: int) -> void:
	var total_lv := mini(max_levels, stage.LEVELS.size())
	for lv in total_lv:
		if stop_requested or token != _run_token or not is_instance_valid(stage):
			return
		stage._load_level(lv)
		var lv_data: Dictionary = stage.LEVELS[lv]
		var ans: String = str(lv_data.answers[0])
		_set_live_status("판테온 코딩테스트 (%d/%d단계)" % [lv + 1, total_lv], "목표 결과에 맞춰 '%s' 타이핑 중..." % ans)
		if not await _wait_sec(0.35, token):
			return
		for ci in ans.length():
			if stop_requested or token != _run_token or not is_instance_valid(stage):
				return
			var ch := ans.substr(ci, 1)
			stage.typed_code += ch
			stage._trigger_robot_typing_hop(ch, false)
			stage.queue_redraw()
			if not await _wait_sec(0.08, token):
				return
		if not await _wait_sec(0.3, token):
			return
		stage._submit_code()
		if not await _wait_sec(0.55, token):
			return

func _skip_2d_dialogue_visually(stage: Node, token: int) -> void:
	if not ("hud" in stage) or stage.hud == null:
		return
	var guard := 0
	while stage.hud.dialogue_open() and guard < 20:
		if stop_requested or token != _run_token:
			return
		guard += 1
		_set_live_status("NPC 가이드 대화 확인 중 (%s)" % str(stage.get("stage_id")), "NPC 설명 대화를 읽고 넘깁니다...")
		if not await _wait_sec(0.35, token):
			return
		stage.hud.dialogue_skip()
		await get_tree().process_frame

func _walk_2d_player_to(player_2d: CharacterBody2D, target_pos: Vector2, token: int) -> void:
	if player_2d == null or not is_instance_valid(player_2d):
		return
	player_2d.active = true
	var orig_speed: float = float(player_2d.speed)
	player_2d.speed = 240.0 * maxf(1.0, speed_mult)
	var guard := 0
	var prev_pos := player_2d.position
	var stuck_frames := 0
	while guard < 180:
		if stop_requested or token != _run_token or not is_instance_valid(player_2d):
			break
		guard += 1
		var diff := target_pos - player_2d.position
		if diff.length() <= 14.0:
			break
		player_2d.bot_move_dir = diff.normalized()
		await get_tree().physics_frame
		if player_2d.position.distance_to(prev_pos) < 0.4:
			stuck_frames += 1
			if stuck_frames > 12:
				player_2d.position = player_2d.position.move_toward(target_pos, 8.0 * maxf(1.0, speed_mult))
		else:
			stuck_frames = 0
		prev_pos = player_2d.position
	if is_instance_valid(player_2d):
		player_2d.speed = orig_speed
		player_2d.bot_move_dir = Vector2.ZERO
		player_2d.velocity = Vector2.ZERO
		player_2d.position = target_pos
		for i in 3:
			await get_tree().physics_frame

func _find_st01_spot_pos(stage: Node, kind: String, idx: int) -> Vector2:
	var w: Node2D = stage.world
	for c in w.get_children():
		if c is Interactable and c.kind == kind and c.index == idx:
			return c.position + Vector2(0, 12)
	return stage.player.position

func _find_st01_spot_node(stage: Node, kind: String, idx: int) -> Interactable:
	var w: Node2D = stage.world
	for c in w.get_children():
		if c is Interactable and c.kind == kind and c.index == idx:
			return c
	return null

func _play_visual_st01(stage: Node, token: int, max_levels: int) -> void:
	var total_lv := mini(max_levels, stage.LEVELS.size())
	for lv in total_lv:
		if stop_requested or token != _run_token or not is_instance_valid(stage):
			return
		if stage.level != lv:
			stage.start_level(lv)
		await _skip_2d_dialogue_visually(stage, token)
		if not await _wait_sec(0.4, token):
			return

		# Demonstrate 1 intentional mistake on Level 0 so user sees validation toast
		if lv == 0:
			_set_live_status("ST01 배열 보관소 (레벨 1) - 오답 검증 시연", "의도적으로 0번 보관함으로 걸어가 오답 판정(실수+1)을 검증합니다...")
			var wrong_pos := _find_st01_spot_pos(stage, "slot", 0)
			await _walk_2d_player_to(stage.player, wrong_pos, token)
			if stop_requested or token != _run_token:
				return
			var wrong_spot := _find_st01_spot_node(stage, "slot", 0)
			if wrong_spot != null:
				stage._on_interact(wrong_spot)
			if not await _wait_sec(0.85, token):
				return

		var guard := 0
		while not stage.done and guard < 40:
			if stop_requested or token != _run_token or not is_instance_valid(stage):
				return
			guard += 1
			var a: Array = stage._next_action()
			var kind := str(a[0])
			var idx := int(a[1])
			var desc := str(a[2])
			if kind.is_empty():
				break
			_set_live_status("ST01 배열 보관소 (레벨 %d/%d) 자동 풀이 중" % [lv + 1, total_lv], "로봇 이동 및 조작: %s" % desc)
			var dest := _find_st01_spot_pos(stage, kind, idx)
			await _walk_2d_player_to(stage.player, dest, token)
			if stop_requested or token != _run_token:
				return
			var sp := _find_st01_spot_node(stage, kind, idx)
			if sp != null:
				stage._on_interact(sp)
			if not await _wait_sec(0.55, token):
				return

		_set_live_status("ST01 배열 보관소 (레벨 %d 클리어!)" % (lv + 1), "클리어 결과 및 생성된 배열 코드를 확인합니다...")
		if not await _wait_sec(1.1, token):
			return
		if lv < total_lv - 1 and is_instance_valid(stage):
			stage.start_level(lv + 1)

func _play_visual_walk_stage(stage: WalkStage, token: int, max_levels: int) -> void:
	var total_lv := mini(max_levels, stage.level_count)
	for lv in total_lv:
		if stop_requested or token != _run_token or not is_instance_valid(stage):
			return
		if stage.level != lv:
			stage.start_level(lv)
		await _skip_2d_dialogue_visually(stage, token)
		if not await _wait_sec(0.4, token):
			return

		var guard := 0
		while not stage.done and guard < 60:
			if stop_requested or token != _run_token or not is_instance_valid(stage):
				return
			guard += 1
			var na: Array = stage.next_action()
			var target_spot: Interactable = na[0]
			var hint_msg: String = str(na[1])
			if target_spot == null:
				break
			_set_live_status("%s %s (레벨 %d) 자동 풀이 중" % [stage.stage_id, stage.stage_title, lv + 1], "로봇 이동 -> %s ([E] 상호작용)" % (hint_msg if not hint_msg.is_empty() else target_spot.prompt))
			await _walk_2d_player_to(stage.player, target_spot.position + Vector2(0, 10), token)
			if stop_requested or token != _run_token:
				return
			stage._on_interact(target_spot)
			if not await _wait_sec(0.5, token):
				return

		_set_live_status("%s 레벨 %d 클리어 완료!" % [stage.stage_id, lv + 1], "클리어 판정 확인 완료")
		if not await _wait_sec(1.0, token):
			return
		if lv < total_lv - 1 and is_instance_valid(stage):
			stage.start_level(lv + 1)

func _play_visual_sql_drawer(stage: Node, token: int, max_levels: int) -> void:
	var sid := str(stage.get("id")) if "id" in stage else "SQL01"
	var total_lv := mini(max_levels, 2)
	for lv in total_lv:
		if stop_requested or token != _run_token or not is_instance_valid(stage):
			return
		stage._load_level(lv)
		stage.phase = "play"
		_set_live_status("%s 5x5 SQL 서랍 (레벨 %d) 자동 풀이" % [sid, lv + 1], "의뢰 조건을 분석하여 5x5 서랍에 도구를 색칠합니다...")
		if not await _wait_sec(0.6, token):
			return

		var steps: Array = []
		if sid == "SQL01":
			if lv == 0:
				steps = [
					["paint", "col", 0, 1, "SELECT name 열 색칠"],
					["submit_wrong", "누락된 score 열 없이 제출하여 오답 차단 확인"],
					["paint", "col", 2, 2, "SELECT score 열 추가 색칠"],
					["submit", "완성된 SELECT name, score 쿼리 제출"]
				]
			else:
				steps = [
					["paint", "col", 0, 1, "SELECT name 열 색칠"],
					["paint", "col", 0, 2, "SELECT score 열 색칠"],
					["cond", "cond", 0, 2, ">=", 80, "WHERE score >= 80 조건 색칠"],
					["submit", "완성된 WHERE 조건 쿼리 제출"]
				]
		elif sid == "SQL02":
			steps = [
				["paint", "group", 0, 3, "GROUP BY dept 부서별 묶기"],
				["paint", "count", 0, 3, "COUNT(*) 집계 도구 적용"],
				["submit", "GROUP BY 쿼리 제출"]
			]
		elif sid == "SQL03":
			steps = [
				["paint", "key", 0, 2, "왼쪽 테이블 dept_id 키 연결"],
				["paint", "key", 0, 5, "오른쪽 테이블 id 키 연결"],
				["submit", "INNER JOIN 쿼리 제출"]
			]
		else:
			steps = [
				["paint", "avg", 0, 2, "안쪽 서브쿼리 AVG(score) 계산"],
				["submit", "서브쿼리 제출"]
			]

		for st in steps:
			if stop_requested or token != _run_token or not is_instance_valid(stage):
				return
			var kind := str(st[0])
			if kind == "paint":
				_set_live_status("%s (레벨 %d) 봇 조작 중" % [sid, lv + 1], str(st[4]))
				stage.tool_id = str(st[1])
				stage.r = int(st[2])
				stage.c = int(st[3])
				stage.press_e()
			elif kind == "cond":
				_set_live_status("%s (레벨 %d) 봇 조작 중" % [sid, lv + 1], str(st[6]))
				stage.tool_id = str(st[1])
				stage.r = int(st[2])
				stage.c = int(st[3])
				stage.press_e()
				var ops: Array = stage.COMPARE_OPS if stage.palette.mode == "compare" else SqlModel.NUMERIC_OPS
				stage.palette.op = ops.find(str(st[4]))
				if stage.palette.has("val"):
					stage.palette.val = stage.WHERE_VALUES.find(int(st[5]))
				stage.confirm_palette()
			elif kind == "submit_wrong" or kind == "submit":
				_set_live_status("%s (레벨 %d) 결과 제출" % [sid, lv + 1], str(st[1]))
				stage.submit()
			if not await _wait_sec(0.75, token):
				return

		if not await _wait_sec(0.9, token):
			return

func _lab_walk_and_press(stage: Node, action_key: String, desc: String, token: int) -> void:
	_set_live_status("%s %s 자동 풀이 중" % [str(stage.stage_id), str(stage.stage_title)], desc)
	# If there is a station spot matching action_key, walk the 2D robot there first!
	if "_st" in stage and stage.has_method("spot"):
		var st_arr: Array = stage._st
		for i in st_arr.size():
			if st_arr[i] != null and str(st_arr[i][0]) == action_key:
				var sp: Interactable = stage.spot("st", i)
				if sp != null:
					await _walk_2d_player_to(stage.player, sp.position + Vector2(0, 10), token)
				break
	if is_instance_valid(stage):
		stage.on_button(action_key)

func _play_visual_lab_stage(stage: Node, token: int, _max_levels: int) -> void:
	await _skip_2d_dialogue_visually(stage, token)
	if not await _wait_sec(0.4, token):
		return
	var act := str(stage.get("activity"))

	if act == "sort": # ALG01_Sorting Level 1 (Bubble Sort)
		var guard := 0
		while not stage.level_done and guard < 25:
			if stop_requested or token != _run_token or not is_instance_valid(stage):
				return
			guard += 1
			if stage.problem == 0:
				var a: Array = []
				for c in stage.state.a:
					a.append(c[0])
				var j: int = stage.state.j
				var do_swap: bool = a[j] > a[j + 1]
				var key := "swap" if do_swap else "keep"
				await _lab_walk_and_press(stage, key, "버블 정렬 비교: (%d, %d) -> %s" % [a[j], a[j + 1], "교환(Swap)" if do_swap else "유지(Keep)"], token)
			else:
				await _lab_walk_and_press(stage, "keep", "정렬 완료 패스 확인 (Keep)", token)
			if not await _wait_sec(0.45, token):
				return
	elif act == "tree": # DS09_TreeStructure Level 1
		for item in [
			["A", "부모 노드 A 선택"],
			["B", "자식 노드 B 선택"],
			["left", "왼쪽 자식(Left)으로 연결"],
			["A", "부모 노드 A 선택"],
			["C", "자식 노드 C 선택"],
			["right", "오른쪽 자식(Right)으로 연결"],
			["check", "트리 구조 검증 제출"]
		]:
			if stop_requested or token != _run_token:
				return
			await _lab_walk_and_press(stage, item[0], item[1], token)
			if not await _wait_sec(0.5, token):
				return
	elif act == "clean": # DATA01_Explore Level 1
		for item in [
			["submit", "의도적 빈 파이프라인 제출 -> 오답 차단 확인"],
			["missing", "결측치(NULL) 행 제거 필터 적용"],
			["submit", "정제된 데이터셋 제출"]
		]:
			if stop_requested or token != _run_token:
				return
			await _lab_walk_and_press(stage, item[0], item[1], token)
			if not await _wait_sec(0.65, token):
				return
	else:
		# Generic solver using next_key() or stations
		var guard := 0
		while not stage.level_done and guard < 15:
			if stop_requested or token != _run_token or not is_instance_valid(stage):
				return
			guard += 1
			var nk := str(stage.next_key()) if stage.has_method("next_key") else ""
			if nk.is_empty():
				break
			await _lab_walk_and_press(stage, nk, "다음 단계 실행: " + nk, token)
			if not await _wait_sec(0.5, token):
				return

	if not await _wait_sec(1.0, token):
		return
