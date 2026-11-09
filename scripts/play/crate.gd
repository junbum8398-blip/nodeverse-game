class_name StageCrate
extends Node2D
## 들고 옮기는 물건(상자, 토큰) 공통 스크립트: 스프라이트 + 글자 명판(Label). 이동은 Tween.

var value = 0
var base_scale := Vector2.ONE

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Node2D = get_node_or_null("Shadow")

func set_value(v) -> void:
	value = v
	if not is_node_ready():
		await ready
	label.text = str(v)

func set_base_scale(s: float) -> void:
	base_scale = Vector2(s, s)
	scale = base_scale

func set_tint(c: Color) -> void:
	if not is_node_ready():
		await ready
	sprite.modulate = c

func _process(_d: float) -> void:
	if shadow:
		shadow.visible = z_index == 0   # 로봇이 들고 있을 때(z_index 2)는 바닥 그림자 없음

func move_to(p: Vector2, dur := 0.22) -> Tween:  # p: 부모(World) 기준 좌표
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", p, dur)
	return tw

func pop() -> void:
	var tw := create_tween()
	scale = base_scale * Vector2(1.15, 0.85)
	tw.tween_property(self, "scale", base_scale, 0.18).set_trans(Tween.TRANS_BACK)

func vanish() -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position:y", position.y + 40, 0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(queue_free)
