extends Node
## 검증용 자동 플레이: 실제 입력(WASD, E)을 흉내 내 로봇을 걸려서 ST01 레벨 1을 푼다.
## 실행: Godot.exe --path . --resolution 1280x720 res://scenes/AutoplayST01.tscn

const S := 1281.0 / 1672.0
const SLOT_X := [477.0, 642.0, 807.0, 972.0, 1137.0]
var stage: Node
var dir := ""

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://renders"))
	stage = load("res://scenes/stages/ST01_Array.tscn").instantiate()
	add_child(stage)
	await _wait(3.5)
	await _shot("st01_walk_0_dialogue1")
	_key(KEY_SPACE)
	await _wait(0.2)
	_key(KEY_SPACE)
	await _wait(4.0)
	await _shot("st01_walk_0_dialogue2")
	for i in 40:
		if not stage.hud.dialogue_open():
			break
		_key(KEY_SPACE)
		await _wait(0.15)
	print("dialogue closed=", not stage.hud.dialogue_open(), " player active=", stage.player.active)
	await _wait(0.4)
	await _shot("st01_walk_1_start")
	var plan := [["slot", 2], ["slot", 3], ["slot", 1], ["slot", 2], ["tray", 0], ["slot", 1]]
	var k := 0
	for step in plan:
		var p: Vector2 = Vector2(SLOT_X[step[1]] * S, 420) if step[0] == "slot" else Vector2(509, 470)
		await _walk_to(p)
		_press_interact()
		await _wait(0.35)
		k += 1
		if k == 1:
			await _shot("st01_walk_2_carry")
		if k == 5:
			await _shot("st01_walk_3_newcrate")
	await _wait(0.6)
	await _shot("st01_walk_4_clear")
	print("ST01 walk test: done=%s moves=%d mistakes=%d" % [str(stage.done), stage.moves, stage.mistakes])
	get_tree().quit()

func _walk_to(p: Vector2) -> void:
	var pl: CharacterBody2D = stage.player
	for i in 400:
		var d := p - pl.position
		if d.length() < 10:
			break
		_set_dir(d)
		await get_tree().physics_frame
	_set_dir(Vector2.ZERO)
	await get_tree().physics_frame

func _set_dir(d: Vector2) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if d.length() < 1:
		return
	var n := d.normalized()
	if n.x < -0.3: Input.action_press("move_left")
	if n.x > 0.3: Input.action_press("move_right")
	if n.y < -0.3: Input.action_press("move_up")
	if n.y > 0.3: Input.action_press("move_down")

func _press_interact() -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)

func _key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://renders/%s.png" % name))
