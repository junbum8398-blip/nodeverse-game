extends Node
## 검증용 자동 플레이: 각 스테이지를 끝까지 풀어 본다.
## 대화창을 넘기고, next_action() 이 가리키는 지점 바로 앞으로 로봇을 옮겨 실제 E 입력으로 상호작용한다.
## 실행: Godot.exe --path . --resolution 1280x720 res://scenes/AutoplayStages.tscn [-- ST03 ST04]

const SCENES := {"ST02": "ST02_LinkedList", "ST03": "ST03_Stack", "ST04": "ST04_QueueDeque", "ST05": "ST05_Hash", "ST06": "ST06_BinaryTree",
	"ST07": "ST07_Bst", "ST08": "ST08_Heap", "ST09": "ST09_Graph", "ST10": "ST10_Integrated"}
var fails := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://renders/stages"))
	var ig := FileAccess.open("res://renders/stages/.gdignore", FileAccess.WRITE)   # 캡처가 임포트되지 않게
	if ig:
		ig.close()
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		ids = SCENES.keys()
	for id in ids:
		await _play(id)
	print("AUTOPLAY RESULT: fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _play(id: String) -> void:
	var stage: WalkStage = load("res://scenes/stages/%s.tscn" % SCENES[id]).instantiate()
	add_child(stage)
	await _wait(1.2)
	await _shot("%s_1_dialogue" % id)
	await _walk_check(id, stage)
	for lv in stage.level_count:
		await _skip_dialogue(stage)
		await _wait(0.25)
		if lv == 0:
			await _shot("%s_2_start" % id)
		var guard := 0
		var shot_mid := false
		while not stage.done and guard < 60:
			guard += 1
			var a: Array = stage.next_action()
			var t: Interactable = a[0]
			if t == null:
				print("!! %s level %d: no next action (stuck)" % [id, lv + 1])
				fails += 1
				break
			var pl: StagePlayer = stage.player
			pl.position = t.position + Vector2(0, 8)
			for i in 3:
				await get_tree().physics_frame
			# 겹친 지점이 여러 개일 때 가장 가까운 것이 다른 지점이면 그 지점만 남긴다
			var others := []
			for s in stage._spots.values():
				if s != t and s.enabled:
					s.enabled = false
					others.append(s)
			await get_tree().physics_frame
			await get_tree().physics_frame
			if pl.focus != t:
				print("!! %s level %d: focus mismatch for %s" % [id, lv + 1, t.name])
				fails += 1
			await _press_interact()
			await get_tree().physics_frame
			await get_tree().process_frame
			for s in others:
				s.enabled = true
			await _wait(0.05)
			if guard == 3 and not shot_mid and lv == stage.level_count - 1:
				shot_mid = true
				await _wait(0.35)
				await _shot("%s_3_play" % id)
		print("%s level %d: done=%s moves=%d mistakes=%d" % [id, lv + 1, str(stage.done), stage.moves, stage.mistakes])
		if not stage.done:
			fails += 1
			break
		if stage.mistakes != 0:
			print("!! %s level %d: hint path caused mistakes" % [id, lv + 1])
			fails += 1
		await _wait(0.5)
		if lv == stage.level_count - 1:
			await _shot("%s_4_clear" % id)
			break
		stage._next_level()
		await _wait(0.2)
	stage.queue_free()
	await _wait(0.1)

## 실제 이동 입력으로 네 방향을 밀어 보고, 벽 안에 머무는지 확인한다.
func _walk_check(id: String, stage: WalkStage) -> void:
	stage.hud.dialogue_skip()
	await _wait(0.1)
	var pl: StagePlayer = stage.player
	pl.position = stage.mark("Spawn")
	var loops := []
	for c in stage.get_node("Field/Walls").get_children():
		loops.append((c as CollisionPolygon2D).polygon)
	var moved := 0.0
	for act in ["move_up", "move_right", "move_down", "move_left"]:
		var p0 := pl.position
		Input.action_press(act)
		await _wait(0.9)
		Input.action_release(act)
		await get_tree().physics_frame
		moved = maxf(moved, pl.position.distance_to(p0))
		var inside := 0
		for poly in loops:
			if Geometry2D.is_point_in_polygon(pl.position, poly):
				inside += 1
		if inside % 2 == 0:
			print("!! %s: walked out of bounds at %s" % [id, str(pl.position)])
			fails += 1
	if moved < 30.0:
		print("!! %s: robot could not move (max %.0f)" % [id, moved])
		fails += 1
	print("%s walk check ok, max move %.0f" % [id, moved])
	stage.player.position = stage.mark("Spawn")
	stage._talked_level = -1
	stage.start_level(0)
	await _wait(0.1)

func _skip_dialogue(stage: WalkStage) -> void:
	for i in 80:
		if not stage.hud.dialogue_open():
			break
		stage.hud.dialogue_skip()
		await _wait(0.03)

func _press_interact() -> void:
	await get_tree().process_frame
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.keycode = KEY_E
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.physical_keycode = KEY_E
	up.keycode = KEY_E
	up.pressed = false
	Input.parse_input_event(up)

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _shot(n: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://renders/stages/%s.png" % n))
