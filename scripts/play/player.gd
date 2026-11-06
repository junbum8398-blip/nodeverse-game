class_name StagePlayer
extends CharacterBody2D
## 플레이어 로봇: WASD/방향키 이동, E 상호작용. 걷기 시 통통 튀는 애니메이션, 좌우 반전, 그림자.
## 주변 Interactable(Area2D) 중 가장 가까운 것을 focus 로 잡고 E 로 상호작용한다.

signal interacted(target: Interactable)
signal focus_changed(target: Interactable)

@export var speed := 230.0
var active := true
var focus: Interactable = null
var carried: Node2D = null
var _t := 0.0
var _moving := false

@onready var sprite: Sprite2D = $Sprite
@onready var reach: Area2D = $Reach
@onready var carry_point: Marker2D = $CarryPoint

func _ready() -> void:
	_ensure_actions()

static func _ensure_actions() -> void:
	var keys := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN], "interact": [KEY_E, KEY_SPACE]}
	for act in keys:
		if InputMap.has_action(act):
			continue
		InputMap.add_action(act)
		for k in keys[act]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(act, ev)

func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if active:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()
	_moving = dir.length() > 0.1
	if absf(dir.x) > 0.1:
		sprite.flip_h = dir.x < 0
	_t += delta * (12.0 if _moving else 3.0)
	if _moving:
		sprite.position.y = -absf(sin(_t)) * 7.0
		sprite.rotation = sin(_t) * 0.06
	else:
		sprite.position.y = sin(_t) * 1.5
		sprite.rotation = 0.0
	if carried:
		carried.global_position = carry_point.global_position + Vector2(0, sprite.position.y)
	_update_focus()

func _update_focus() -> void:
	var best: Interactable = null
	var best_d := INF
	for a in reach.get_overlapping_areas():
		if a is Interactable and a.enabled:
			var d := global_position.distance_to(a.global_position)
			if d < best_d:
				best_d = d
				best = a
	if best != focus:
		focus = best
		focus_changed.emit(focus)

func _unhandled_input(ev: InputEvent) -> void:
	if active and ev.is_action_pressed("interact") and focus:
		interacted.emit(focus)
		get_viewport().set_input_as_handled()
