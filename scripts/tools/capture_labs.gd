extends SceneTree
## 실습 화면 캡처 (창 모드). 실행: Godot --path . --resolution 1280x720 --script res://scripts/tools/capture_labs.gd -- <저장 폴더>

var out := ""

func _init() -> void:
	call_deferred("run")

func shot(n: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(n + ".png"))

func open(scene: String, keys: Array, lv := 0) -> void:
	var g = (load("res://scenes/stages/%s.tscn" % scene) as PackedScene).instantiate()
	root.add_child(g)
	if lv > 0:
		g.start_level(lv)
	await process_frame
	g.hud.dialogue_skip()
	for k in keys:
		g.on_button(k)
	await create_timer(0.1).timeout
	g.player.position = g.mark("Spawn")
	await create_timer(0.3).timeout
	await shot(scene)
	g.queue_free()
	await process_frame

func run() -> void:
	MiniGameBase.progress_saving = false
	out = OS.get_cmdline_user_args()[0]
	var nm = root.get_node_or_null("NetworkManager")
	if nm:
		nm.auto_send_enabled = false
	await open("DS09_TreeStructure", ["A", "B", "left", "A", "C"], 1)
	await open("DS10_GraphBuild", ["A", "B", "add", "B", "C", "add", "C", "B"], 2)
	await open("ALG02_Search", ["3"], 1)
	await open("ALG01_Sorting", ["1"], 2)
	await open("ALG03_DivideSort", ["lt", "gt"], 2)
	await open("ALG04_ShortestPath", ["A", "update"], 0)
	await open("DATA02_Profile", ["field:age_rate", "key:4", "key:0"], 2)
	await open("DATA01_Explore", ["trim", "number"], 2)
	await open("DATA03_Stats", ["field:mean", "key:3", "key:4", "toggle_ex"], 2)
	await open("DATA04_Chart", ["x", "y", "agg", "zero", "draw", "mark:1"], 0)
	var menu = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	for c in ["DS", "ALGO", "SQL", "DATA"]:
		menu.get_script().get_script_constant_map().Catalog.selected_category = c; menu.page = 0
		await create_timer(0.1).timeout
		await shot("menu_" + c)
	quit()
