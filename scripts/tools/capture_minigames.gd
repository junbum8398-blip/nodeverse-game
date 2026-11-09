extends Node
## 검증용: 메뉴 + 미니게임 10종 각각 (1) 시작 화면 캡처 (2) 레벨 1 자동 풀이 후 클리어 여부 확인 + 캡처
## 실행: Godot.exe --path . --resolution 1280x720 res://scenes/Capture.tscn

const GAMES := ["st01_array", "st02_linked_list", "st03_stack", "st04_queue_deque", "st05_hash",
	"st06_binary_tree", "st07_bst", "st08_heap", "st09_graph", "st10_integrated"]

# 레벨 1 정답 입력 순서
const SOLVE := {
	"st01_array": [2, 3, 1, 2, "tray", 1],
	"st02_linked_list": ["B", "C", "A", "B"],
	"st03_stack": ["pick_C", "pick_B", "pick_A", "run"],
	"st04_queue_deque": ["pop_front", "pop_front"],
	"st05_hash": [2, 2, 3, 0, 2, "item_2_1", 2, "item_2_0"],
	"st06_binary_tree": ["A", "B", "D", "E", "C"],
	"st07_bst": ["L", "R", "F"],
	"st08_heap": [5, "up", "up"],
	"st09_graph": ["A", "B", "C", "D", "E"],
}

func _ready() -> void:
	await get_tree().process_frame
	var dir := ProjectSettings.globalize_path("res://renders")
	DirAccess.make_dir_recursive_absolute(dir)
	var report := []
	var menu: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(menu)
	await _shot(dir + "/menu.png")
	menu.queue_free()
	for g in GAMES:
		var n: Node = load("res://scenes/minigames/%s.tscn" % g).instantiate()
		add_child(n)
		await _shot(dir + "/game_%s_start.png" % g)
		if n.tut_open:
			n.tut_open = false
			await _shot(dir + "/game_%s_play.png" % g)
			if SOLVE.has(g):
				n._click(SOLVE[g][0])
				await _shot(dir + "/game_%s_step1.png" % g)
				n.start_level(0)
		if SOLVE.has(g):
			for step in SOLVE[g]:
				n._click(step)
				await get_tree().process_frame
			if g == "st03_stack":
				await get_tree().create_timer(5.0).timeout
			await _shot(dir + "/game_%s_solved.png" % g)
			report.append("%s level1 cleared=%s mistakes=%d moves=%d" % [g, str(n.level_done), n.mistakes, n.moves])
		else:
			var q = n.POOL[n.order[0]]
			n._click(q[1])
			report.append("%s first answer correct=%s score=%d" % [g, str(n.score > 0), n.score])
		n.queue_free()
		await get_tree().process_frame
	for r in report:
		print(r)
	var f := FileAccess.open("res://renders/selftest.txt", FileAccess.WRITE)
	f.store_string("\n".join(report))
	f.close()
	get_tree().quit()

func _shot(path: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
