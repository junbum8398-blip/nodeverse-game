class_name StageCrate
extends Node2D
## 원화에서 잘라낸 상자 스프라이트 + 숫자 명판(Label). 이동은 Tween.

var value := 0

@onready var label: Label = $Label

func set_value(v: int) -> void:
	value = v
	if not is_node_ready():
		await ready
	label.text = str(v)

func move_to(p: Vector2, dur := 0.22) -> Tween:  # p: 부모(World) 기준 좌표
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", p, dur)
	return tw

func pop() -> void:
	var tw := create_tween()
	scale = Vector2(1.15, 0.85)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)

func vanish() -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position:y", position.y + 40, 0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(queue_free)
