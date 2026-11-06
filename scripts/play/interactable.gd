class_name Interactable
extends Area2D
## 상호작용 지점(칸, 트레이, 반환 레버 등). 플레이어가 가까이 오면 말풍선이 뜨고 E 로 동작.

@export var kind := ""          # "slot", "tray", "bin" ...
@export var index := -1
@export var prompt := "상호작용"
@export var bubble_offset := Vector2(0, -70)
var enabled := true
