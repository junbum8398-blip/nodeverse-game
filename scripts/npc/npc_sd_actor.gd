extends Node3D
## SD 블록 NPC 대기 애니메이션: 숨쉬기(몸 위아래), 고개 끄덕임·갸웃, 팔 흔들기. 플레이어가 가까우면 바라보기.

@export var npc_id := ""
@export var display_name := ""
@export var look_at_target: Node3D
@export var wave := false          # true 면 오른팔로 손 흔들기

var _t := 0.0
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _base_y := 0.0

func _ready() -> void:
	_t = randf() * TAU
	_hips = get_node_or_null("Model/Hips")
	_torso = get_node_or_null("Model/Hips/Torso")
	_head = get_node_or_null("Model/Hips/Torso/Head")
	_arm_l = get_node_or_null("Model/Hips/Torso/ArmL")
	_arm_r = get_node_or_null("Model/Hips/Torso/ArmR")
	if _hips:
		_base_y = _hips.position.y

func _process(delta: float) -> void:
	_t += delta
	if _hips:
		_hips.position.y = _base_y + absf(sin(_t * 2.2)) * 0.012
	if _torso:
		_torso.scale = Vector3(1.0 + sin(_t * 2.2) * 0.012, 1.0 - sin(_t * 2.2) * 0.012, 1.0)
	if _head:
		_head.rotation.x = sin(_t * 1.1) * 0.05
		_head.rotation.z = sin(_t * 0.7) * 0.06
	if _arm_l:
		_arm_l.rotation.x = sin(_t * 2.2) * 0.12
		_arm_l.rotation.z = -0.06
	if _arm_r:
		if wave:
			_arm_r.rotation.z = 2.5 + sin(_t * 8.0) * 0.35
			_arm_r.rotation.x = 0.0
		else:
			_arm_r.rotation.x = -sin(_t * 2.2) * 0.12
			_arm_r.rotation.z = 0.06
	if look_at_target:
		var to := look_at_target.global_position - global_position
		to.y = 0
		if to.length() > 0.1 and to.length() < 4.0:
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), delta * 4.0)
