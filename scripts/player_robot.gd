extends CharacterBody3D

## Playable NODEVERSE robot: WASD/arrows (camera-relative), Space jump, Shift sprint,
## E / Q interact, R respawn, V camera mode, right-drag orbit, wheel zoom.

signal interact_pressed
signal secondary_pressed
signal fell_in_water(pos: Vector3)

const WALK_SPEED: float = 4.2
const SPRINT_SPEED: float = 7.0
const ACCEL: float = 30.0
const AIR_ACCEL: float = 12.0
const GRAVITY: float = 24.0
const JUMP_VELOCITY: float = 7.4
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER: float = 0.12
const FALL_Y: float = 0.25
const ROBOT_SCALE: float = 1.3

var spawn_point: Vector3 = Vector3(0.0, 0.6, 0.0)
var last_safe: Vector3 = Vector3(0.0, 0.6, 0.0)

var cam: Camera3D
var cam_yaw: float = 20.0
var cam_pitch: float = 36.0
var cam_dist: float = 14.0
var cam_focus: Vector3 = Vector3.ZERO
var follow_mode: bool = false
var overview_mode: bool = false
var tour_mode: bool = false
var can_move: bool = true
var is_camera_locked: bool = false
var cam_height_offset: float = 0.6
var _orbiting: bool = false

var _pivot: Node3D
var _visual: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _boot_l: Node3D
var _boot_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _head: Node3D
var _base_pos: Dictionary = {}

var _coyote: float = 0.0
var _jump_buf: float = 0.0
var _phase: float = 0.0
var _squash: float = 0.0
var _was_on_floor: bool = false
var _prev_vy: float = 0.0
var _safe_timer: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	floor_snap_length = 0.50
	floor_max_angle = deg_to_rad(55.0)
	floor_constant_speed = true
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.26
	cap.height = 1.1
	cs.shape = cap
	cs.position = Vector3(0.0, 0.56, 0.0)
	add_child(cs)

	_pivot = Node3D.new()
	_pivot.name = "VisualPivot"
	add_child(_pivot)
	var ps: PackedScene = load("res://scenes/assets/01_robot.tscn") as PackedScene
	if ps != null:
		_visual = ps.instantiate() as Node3D
		_pivot.add_child(_visual)
	_pivot.scale = Vector3.ONE * ROBOT_SCALE
	_leg_l = _find_part("Leg_L")
	_leg_r = _find_part("Leg_R")
	_boot_l = _find_part("BootSole_L")
	_boot_r = _find_part("BootSole_R")
	_arm_l = _find_part("ArmPivot_L")
	_arm_r = _find_part("ArmPivot_R")
	_head = _find_part("Head")

	cam = Camera3D.new()
	cam.name = "FollowCamera"
	cam.top_level = true
	cam.fov = 38.0
	cam.far = 300.0
	add_child(cam)
	cam.current = true
	cam_focus = global_position
	_update_camera(1.0)

func _find_part(part_name: String) -> Node3D:
	if _visual == null:
		return null
	var n: Node = _visual.find_child(part_name, true, false)
	var n3: Node3D = n as Node3D
	if n3 != null:
		_base_pos[part_name] = n3.position
	return n3

func teleport_to(p: Vector3) -> void:
	global_position = p
	velocity = Vector3.ZERO
	cam_focus = p

func _unhandled_input(event: InputEvent) -> void:
	if not can_move:
		return
	if event is InputEventKey:
		var ek: InputEventKey = event as InputEventKey
		if ek.pressed and not ek.echo:
			if ek.keycode == KEY_SPACE:
				_jump_buf = JUMP_BUFFER
			elif ek.keycode == KEY_E:
				interact_pressed.emit()
			elif ek.keycode == KEY_Q:
				secondary_pressed.emit()
			elif ek.keycode == KEY_R:
				teleport_to(spawn_point)
			elif ek.keycode == KEY_V:
				overview_mode = false
				follow_mode = not follow_mode
				if follow_mode:
					cam_pitch = 24.0
					cam_dist = 7.0
				else:
					cam_pitch = 36.0
					cam_dist = 14.0
			elif ek.keycode == KEY_M:
				overview_mode = not overview_mode
				if overview_mode:
					cam_yaw = 18.0
					cam_pitch = 44.0
					cam_dist = 82.0
				else:
					cam_pitch = 36.0
					cam_dist = 14.0
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = mb.pressed and not is_camera_locked
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			if not is_camera_locked:
				cam_dist = maxf(3.0, cam_dist * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			if not is_camera_locked:
				cam_dist = minf(130.0, cam_dist * 1.1)
	elif event is InputEventMouseMotion and _orbiting and not is_camera_locked:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		cam_yaw -= mm.relative.x * 0.3
		cam_pitch = clampf(cam_pitch + mm.relative.y * 0.25, 10.0, 80.0)

func _physics_process(delta: float) -> void:
	_time += delta
	var input_vec: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vec.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vec.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vec.x -= 1.0

	var yaw: float = deg_to_rad(cam_yaw)
	var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var wish: Vector3 = right * input_vec.x + fwd * input_vec.y
	if not can_move:
		wish = Vector3.ZERO
		_jump_buf = 0.0
	if wish.length() > 0.01:
		wish = wish.normalized()
	var speed: float = SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	var target: Vector3 = wish * speed
	var on_floor: bool = is_on_floor()
	var acc: float = ACCEL if on_floor else AIR_ACCEL
	velocity.x = move_toward(velocity.x, target.x, acc * delta)
	velocity.z = move_toward(velocity.z, target.z, acc * delta)

	if on_floor:
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(_coyote - delta, 0.0)
		velocity.y -= GRAVITY * delta
	_jump_buf = maxf(_jump_buf - delta, 0.0)
	if _jump_buf > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buf = 0.0
		_coyote = 0.0
		_squash = -0.12

	_prev_vy = velocity.y

	# 다리 이음새 및 턱 걸림 방지 (Smooth step-climb assist)
	if on_floor and wish.length_squared() > 0.01:
		var horiz := wish * (speed * delta)
		var step_test := move_and_collide(horiz, true)
		if step_test != null:
			var n: Vector3 = step_test.get_normal()
			if n.y < 0.7: # 수직 턱이나 계단/테라스 모서리에 부딪힘
				for h in [0.12, 0.22, 0.32, 0.42, 0.48]:
					var step_up := Vector3(0.0, h, 0.0)
					if not test_move(global_transform, step_up):
						var stepped_xform := global_transform.translated(step_up)
						if not test_move(stepped_xform, horiz):
							global_position += step_up + wish * (speed * delta * 0.4)
							velocity.y = 0.0
							break

	_guard_edges()
	move_and_slide()

	if is_on_floor() and not _was_on_floor and _prev_vy < -5.0:
		_squash = 0.18
	_was_on_floor = is_on_floor()

	if is_on_floor() and global_position.y >= 0.35:
		_safe_timer += delta
		if _safe_timer > 0.35:
			_safe_timer = 0.0
			last_safe = global_position + Vector3(0.0, 0.1, 0.0)
	if global_position.y < FALL_Y:
		fell_in_water.emit(global_position)
		var target_safe: Vector3 = last_safe if last_safe.y >= 0.35 else spawn_point
		teleport_to(target_safe)

	_animate(delta)

## 물 추락 방지: 진행 방향 앞쪽 발밑에 땅(물보다 높은 지면)이 없으면 그 방향 이동을 막는다.
## 섬 가장자리에서는 가장자리를 따라 미끄러지듯 이동(x/z 축 분리 검사).
const EDGE_LOOKAHEAD: float = 0.45
const GROUND_MIN_Y: float = 0.35

func _ground_ok(p: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 0.8, 0.0), p - Vector3(0.0, 4.0, 0.0))
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and (hit["position"] as Vector3).y >= GROUND_MIN_Y

func _guard_edges() -> void:
	var h := Vector3(velocity.x, 0.0, velocity.z)
	if h.length() < 0.05:
		return
	var p := global_position
	if _ground_ok(p + h.normalized() * EDGE_LOOKAHEAD):
		return
	var ok_x := absf(velocity.x) > 0.05 and _ground_ok(p + Vector3(signf(velocity.x), 0.0, 0.0) * EDGE_LOOKAHEAD)
	var ok_z := absf(velocity.z) > 0.05 and _ground_ok(p + Vector3(0.0, 0.0, signf(velocity.z)) * EDGE_LOOKAHEAD)
	if not ok_x:
		velocity.x = 0.0
	if not ok_z:
		velocity.z = 0.0

func _animate(delta: float) -> void:
	var hs: float = Vector2(velocity.x, velocity.z).length()
	if hs > 0.3:
		var target_yaw: float = atan2(velocity.x, velocity.z)
		_pivot.rotation.y = lerp_angle(_pivot.rotation.y, target_yaw, 1.0 - exp(-14.0 * delta))
	var amp: float = clampf(hs / 4.2, 0.0, 1.5)
	if not is_on_floor():
		amp = 0.25
	_phase += delta * (4.0 + hs * 1.7)
	var s: float = sin(_phase)
	var swing: float = s * amp
	_set_z(_leg_l, "Leg_L", swing * 0.05)
	_set_z(_boot_l, "BootSole_L", swing * 0.05)
	_set_z(_leg_r, "Leg_R", -swing * 0.05)
	_set_z(_boot_r, "BootSole_R", -swing * 0.05)
	var arm_air: float = -70.0 if not is_on_floor() else 0.0
	if _arm_l != null:
		_arm_l.rotation_degrees.x = lerpf(_arm_l.rotation_degrees.x, -swing * 38.0 + arm_air, 1.0 - exp(-16.0 * delta))
	if _arm_r != null:
		_arm_r.rotation_degrees.x = lerpf(_arm_r.rotation_degrees.x, swing * 38.0 + arm_air, 1.0 - exp(-16.0 * delta))
	if _head != null and _base_pos.has("Head"):
		var hb: Vector3 = _base_pos["Head"]
		_head.position = Vector3(hb.x, hb.y + absf(s) * 0.014 * amp + sin(_time * 2.0) * 0.004, hb.z)
	_squash = lerpf(_squash, 0.0, 1.0 - exp(-9.0 * delta))
	_pivot.scale = Vector3(1.0 + _squash, 1.0 - _squash, 1.0 + _squash) * ROBOT_SCALE

func _set_z(n: Node3D, key: String, dz: float) -> void:
	if n == null or not _base_pos.has(key):
		return
	var b: Vector3 = _base_pos[key]
	n.position = Vector3(b.x, b.y, b.z + dz)

func _process(delta: float) -> void:
	_update_camera(delta)

func _update_camera(delta: float) -> void:
	var goal: Vector3 = Vector3(0.0, 1.2, -12.0) if overview_mode else (global_position + Vector3(0.0, cam_height_offset, 0.0))
	if not tour_mode:
		cam_focus = cam_focus.lerp(goal, 1.0 - exp(-10.0 * delta))
	var yr: float = deg_to_rad(cam_yaw)
	var pr: float = deg_to_rad(cam_pitch)
	var offset: Vector3 = Vector3(sin(yr) * cos(pr), sin(pr), cos(yr) * cos(pr)) * cam_dist
	cam.look_at_from_position(cam_focus + offset, cam_focus, Vector3.UP)

func save_camera_settings() -> Dictionary:
	var data := {
		"pitch": cam_pitch,
		"yaw": cam_yaw,
		"dist": cam_dist,
		"fov": cam.fov if cam != null else 38.0,
		"height_offset": cam_height_offset,
		"locked": is_camera_locked
	}
	var f := FileAccess.open("user://camera_settings.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
	var f2 := FileAccess.open("res://data/camera_settings.json", FileAccess.WRITE)
	if f2 != null:
		f2.store_string(JSON.stringify(data, "\t"))
		f2.close()
	return data

func load_camera_settings() -> bool:
	var path := "user://camera_settings.json"
	if not FileAccess.file_exists(path):
		path = "res://data/camera_settings.json"
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var json_str := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(json_str)
	if parsed is Dictionary:
		apply_camera_settings(parsed)
		return true
	return false

func apply_camera_settings(d: Dictionary) -> void:
	if d.has("pitch"): cam_pitch = float(d["pitch"])
	if d.has("yaw"): cam_yaw = float(d["yaw"])
	if d.has("dist"): cam_dist = float(d["dist"])
	if d.has("height_offset"): cam_height_offset = float(d["height_offset"])
	if d.has("locked"): is_camera_locked = bool(d["locked"])
	if d.has("fov") and cam != null:
		cam.fov = float(d["fov"])
