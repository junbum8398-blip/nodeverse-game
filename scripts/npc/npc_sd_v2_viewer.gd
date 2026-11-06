extends Node3D
## NPC 3D 뷰어: 10종 복셀 NPC 를 원형 무대에 배치.
## 조작: ←/→ NPC 선택, 마우스 드래그 회전, 휠 줌, Esc 메인 메뉴
## 캡처: -- --capture  => renders/npc_<id>.png (정면/3/4/후면) + renders/npc_lineup.png

const IDS := ["NPC00_hub_guide", "NPC01_array_keeper", "NPC02_link_engineer", "NPC03_restore_artisan",
	"NPC04_receptionist", "NPC05_registry_clerk", "NPC06_tree_archivist", "NPC07_bst_warden",
	"NPC08_priority_dispatcher", "NPC09_graph_surveyor"]

var npcs: Array[Node3D] = []
var current := 0
var yaw := 0.0
var pitch := -0.12
var dist := 2.6
var cam: Camera3D
var info: Label
var dragging := false

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.18, 0.21, 0.27)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.85)
	e.ambient_light_energy = 0.30
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 28, 0)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 200, 0)
	fill.light_energy = 0.20
	add_child(fill)
	var floor_mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 9.0
	cyl.bottom_radius = 9.0
	cyl.height = 0.2
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.36, 0.44)
	cyl.material = fm
	floor_mi.mesh = cyl
	floor_mi.position.y = -0.1
	add_child(floor_mi)
	for i in IDS.size():
		var n: Node3D = load("res://scenes/npc/%s.tscn" % IDS[i]).instantiate()
		var a := float(i) / IDS.size() * TAU
		n.position = Vector3(sin(a), 0, cos(a)) * 5.0
		n.rotation.y = a
		add_child(n)
		npcs.append(n)
	cam = Camera3D.new()
	cam.fov = 40
	add_child(cam)
	var ui := CanvasLayer.new()
	add_child(ui)
	info = Label.new()
	info.position = Vector2(20, 14)
	info.add_theme_font_size_override("font_size", 22)
	info.add_theme_constant_override("outline_size", 6)
	info.add_theme_color_override("font_outline_color", Color.BLACK)
	ui.add_child(info)
	_select(0)
	if "--capture" in OS.get_cmdline_user_args():
		_capture()

func _select(i: int) -> void:
	current = posmod(i, IDS.size())
	yaw = 0.0
	var n := npcs[current]
	info.text = "%s  %s   (%d/%d)\n←/→ 선택 · 드래그 회전 · 휠 줌 · Esc 메뉴" % [n.npc_id, n.display_name, current + 1, IDS.size()]

func _update_cam() -> void:
	var n := npcs[current]
	var facing := n.rotation.y + yaw
	var target := n.global_position + Vector3(0, 0.62, 0)
	var off := Vector3(sin(facing) * cos(pitch), -sin(pitch), cos(facing) * cos(pitch)) * dist
	cam.global_position = target + off
	cam.look_at(target)

func _process(_d: float) -> void:
	_update_cam()

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_right"):
		_select(current + 1)
	elif ev.is_action_pressed("ui_left"):
		_select(current - 1)
	elif ev.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	elif ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			dragging = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = max(1.6, dist - 0.2)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = min(8.0, dist + 0.2)
	elif ev is InputEventMouseMotion and dragging:
		yaw -= ev.relative.x * 0.01
		pitch = clamp(pitch - ev.relative.y * 0.01, -1.2, 0.5)

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://renders/sd_v2"))
	info.visible = false
	for i in IDS.size():
		_select(i)
		for j in IDS.size():
			npcs[j].visible = j == i
		var imgs: Array[Image] = []
		for y in [0.0, 0.8, PI]:
			yaw = y
			_update_cam()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			imgs.append(get_viewport().get_texture().get_image())
		var w := imgs[0].get_width()
		var h := imgs[0].get_height()
		var sheet := Image.create(w * 3, h, false, imgs[0].get_format())
		for k in 3:
			sheet.blit_rect(imgs[k], Rect2i(0, 0, w, h), Vector2i(w * k, 0))
		sheet.resize(w * 3 / 2, h / 2)
		sheet.save_png(ProjectSettings.globalize_path("res://renders/sd_v2/npc_%s.png" % IDS[i]))
	# 전체 라인업
	for i in IDS.size():
		npcs[i].position = Vector3((i - 4.5) * 1.05, 0, 0)
		npcs[i].rotation.y = 0
		npcs[i].visible = true
		pass
	cam.global_position = Vector3(0, 2.3, 9.5)
	cam.look_at(Vector3(0, 0.6, 0))
	set_process(false)
	await _shot("res://renders/sd_v2/npc_lineup.png")
	get_tree().quit()


