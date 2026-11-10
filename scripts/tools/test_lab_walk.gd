extends SceneTree
## 시안 위 걷기 실습 검사: 모든 장치에 로봇이 닿는지, 노란 화살표만 따라가도 레벨이 끝나는지 본다.
## 실행: Godot --headless --path . --script res://scripts/tools/test_lab_walk.gd

const SCENES := ["DS09_TreeStructure", "DS10_GraphBuild", "ALG01_Sorting", "ALG02_Search", "ALG03_DivideSort", "ALG04_ShortestPath", "DATA01_Explore", "DATA02_Profile", "DATA03_Stats", "DATA04_Chart"]
const HINT_PLAY := ["ALG01_Sorting", "ALG02_Search", "ALG03_DivideSort", "ALG04_ShortestPath"]
var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL ", message)

func _init() -> void:
	call_deferred("run")

func frames(n := 3) -> void:
	for i in n:
		await physics_frame

func run() -> void:
	MiniGameBase.progress_saving = false
	var nm = root.get_node_or_null("NetworkManager")
	if nm:
		nm.auto_send_enabled = false
	create_timer(280).timeout.connect(func(): print("TIMEOUT"); quit(1))
	for scene in SCENES:
		await test_scene(scene)
	print("LAB_WALK_TEST_DONE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func test_scene(scene: String) -> void:
	var g = (load("res://scenes/stages/%s.tscn" % scene) as PackedScene).instantiate()
	root.add_child(g)
	await frames()
	g.hud.dialogue_skip()
	await frames()
	check(g.player.active, scene + " 대화 뒤 로봇 활성")
	for lv in g.level_count:
		g.start_level(lv)
		g.hud.dialogue_skip()
		await frames()
		var i := 0
		while g.spot("st", i) != null:
			var sp = g.spot("st", i)
			if sp.enabled:
				g.player.position = sp.position + Vector2(0, 8)
				await frames()
				check(g.player.focus == sp, "%s L%d St%d 장치에 닿음" % [scene, lv + 1, i])
			i += 1
	if scene in HINT_PLAY:
		for lv in g.level_count:
			g.start_level(lv)
			g.hud.dialogue_skip()
			await frames()
			var guard := 0
			while not g.done and guard < 300:
				guard += 1
				var t = g.next_action()[0]
				if t == null:
					break
				g._on_interact(t)
			check(g.done and g.mistakes == 0, "%s L%d 화살표 경로로 완료" % [scene, lv + 1])
	g.free()
	await process_frame
	print("WALK ok ", scene)
