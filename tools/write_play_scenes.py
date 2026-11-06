# -*- coding: utf-8 -*-
"""걸어 다니는 스테이지용 Godot 씬(.tscn) 작성: Player, Crate, ST01_Array.
에디터에서 열어 위치·충돌 경계를 그대로 수정할 수 있다."""
import math, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
os.makedirs("scenes/play", exist_ok=True)
os.makedirs("scenes/stages", exist_ok=True)
S = 1281.0 / 1672.0


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def v2arr(pts):
    return "PackedVector2Array(" + ", ".join(f"{x:.1f}, {y:.1f}" for x, y in pts) + ")"


ellipse = [(30 * math.cos(a / 16 * 2 * math.pi), 9 * math.sin(a / 16 * 2 * math.pi)) for a in range(16)]

write("scenes/play/Player.tscn", f'''[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://scripts/play/player.gd" id="1"]
[ext_resource type="Texture2D" path="res://textures/sprites/robot.png" id="2"]

[sub_resource type="CircleShape2D" id="body"]
radius = 14.0

[sub_resource type="CircleShape2D" id="reach"]
radius = 72.0

[sub_resource type="StyleBoxFlat" id="bubble"]
bg_color = Color(0.184, 0.373, 0.702, 1)
border_width_left = 3
border_width_top = 3
border_width_right = 3
border_width_bottom = 3
border_color = Color(0.114, 0.106, 0.165, 1)
content_margin_left = 10.0
content_margin_top = 4.0
content_margin_right = 10.0
content_margin_bottom = 4.0

[sub_resource type="LabelSettings" id="bubble_text"]
font_size = 23
outline_size = 4
outline_color = Color(0.114, 0.106, 0.165, 1)

[node name="Player" type="CharacterBody2D"]
motion_mode = 1
script = ExtResource("1")

[node name="Shadow" type="Polygon2D" parent="."]
color = Color(0, 0, 0, 0.28)
polygon = {v2arr(ellipse)}

[node name="Sprite" type="Sprite2D" parent="."]
scale = Vector2(0.75, 0.75)
texture = ExtResource("2")
offset = Vector2(0, -71)

[node name="Collision" type="CollisionShape2D" parent="."]
shape = SubResource("body")

[node name="Reach" type="Area2D" parent="."]
position = Vector2(0, -10)

[node name="Shape" type="CollisionShape2D" parent="Reach"]
shape = SubResource("reach")

[node name="CarryPoint" type="Marker2D" parent="."]
position = Vector2(0, -104)

[node name="Bubble" type="PanelContainer" parent="."]
z_index = 6
offset_left = 30.0
offset_top = -150.0
offset_right = 140.0
offset_bottom = -116.0
theme_override_styles/panel = SubResource("bubble")

[node name="Label" type="Label" parent="Bubble"]
layout_mode = 2
text = "E"
label_settings = SubResource("bubble_text")
''')

write("scenes/play/Crate.tscn", '''[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/play/crate.gd" id="1"]
[ext_resource type="Texture2D" path="res://textures/sprites/crate.png" id="2"]

[sub_resource type="LabelSettings" id="num"]
font_size = 24
font_color = Color(0.2, 0.13, 0.08, 1)

[node name="Crate" type="Node2D"]
script = ExtResource("1")

[node name="Sprite" type="Sprite2D" parent="."]
scale = Vector2(0.72, 0.72)
texture = ExtResource("2")
offset = Vector2(0, -62)

[node name="Label" type="Label" parent="."]
offset_left = -31.0
offset_top = -48.0
offset_right = 25.0
offset_bottom = -16.0
text = "0"
label_settings = SubResource("num")
horizontal_alignment = 1
vertical_alignment = 1
''')

# ---------- ST01 ----------
SLOT_X = [477.0, 642.0, 807.0, 972.0, 1137.0]
walls = [(190, 392), (1010, 392), (1052, 468), (1030, 556), (900, 562), (620, 568), (330, 574), (196, 522), (176, 440)]
nodes = []
for i, x in enumerate(SLOT_X):
    nodes.append(f'''[node name="Slot{i}" type="Area2D" parent="Field/World"]
position = Vector2({x * S:.1f}, 405)
script = ExtResource("3")
kind = "slot"
index = {i}

[node name="Shape" type="CollisionShape2D" parent="Field/World/Slot{i}"]
shape = SubResource("slot")
''')
tri = [(-16, -22), (16, -22), (0, 0)]
write("scenes/stages/ST01_Array.tscn", f'''[gd_scene load_steps=15 format=3]

[ext_resource type="Script" path="res://scripts/play/st01_array_stage.gd" id="1"]
[ext_resource type="Texture2D" path="res://textures/stages/ST01/bg_game.png" id="2"]
[ext_resource type="Script" path="res://scripts/play/interactable.gd" id="3"]
[ext_resource type="PackedScene" path="res://scenes/play/Player.tscn" id="4"]
[ext_resource type="Script" path="res://scripts/play/stage_hud.gd" id="5"]
[ext_resource type="Texture2D" path="res://textures/npc_portraits/NPC01_world.png" id="6"]

[sub_resource type="CircleShape2D" id="slot"]
radius = 46.0

[sub_resource type="CircleShape2D" id="tray"]
radius = 62.0

[sub_resource type="CircleShape2D" id="npc_body"]
radius = 18.0

[sub_resource type="CircleShape2D" id="npc_talk"]
radius = 64.0

[sub_resource type="CircleShape2D" id="bin"]
radius = 52.0

[sub_resource type="LabelSettings" id="hint_text"]
font_size = 25
font_color = Color(1, 0.86, 0.35, 1)
outline_size = 7
outline_color = Color(0.114, 0.106, 0.165, 1)

[sub_resource type="LabelSettings" id="sign_text"]
font_size = 21
outline_size = 5
outline_color = Color(0.114, 0.106, 0.165, 1)

[node name="ST01_Array" type="Node2D"]
script = ExtResource("1")

[node name="Backdrop" type="ColorRect" parent="."]
offset_right = 1280.0
offset_bottom = 720.0
color = Color(0.1, 0.13, 0.2, 1)

[node name="FieldFrame" type="ColorRect" parent="."]
offset_left = -4.0
offset_top = 66.0
offset_right = 971.0
offset_bottom = 618.0
color = Color(0.114, 0.106, 0.165, 1)

[node name="Field" type="Node2D" parent="."]
position = Vector2(0, 70)
scale = Vector2(0.755, 0.755)

[node name="Background" type="Sprite2D" parent="Field"]
scale = Vector2({S:.6f}, {S:.6f})
texture = ExtResource("2")
centered = false

[node name="Walls" type="StaticBody2D" parent="Field"]

[node name="Boundary" type="CollisionPolygon2D" parent="Field/Walls"]
build_mode = 1
polygon = {v2arr(walls + [walls[0]])}

[node name="World" type="Node2D" parent="Field"]
y_sort_enabled = true

[node name="Player" parent="Field/World" instance=ExtResource("4")]
position = Vector2(560, 450)

{"".join(n + chr(10) for n in nodes)}[node name="Tray" type="Area2D" parent="Field/World"]
position = Vector2({665 * S:.1f}, 505)
script = ExtResource("3")
kind = "tray"

[node name="Shape" type="CollisionShape2D" parent="Field/World/Tray"]
shape = SubResource("tray")

[node name="Bin" type="Area2D" parent="Field/World"]
position = Vector2(904, 500)
script = ExtResource("3")
kind = "bin"

[node name="Shape" type="CollisionShape2D" parent="Field/World/Bin"]
shape = SubResource("bin")

[node name="Npc" type="StaticBody2D" parent="Field/World"]
position = Vector2(262, 470)

[node name="Shadow" type="Polygon2D" parent="Field/World/Npc"]
color = Color(0, 0, 0, 0.28)
polygon = {v2arr(ellipse)}

[node name="Sprite" type="Sprite2D" parent="Field/World/Npc"]
texture = ExtResource("6")
offset = Vector2(0, -75)

[node name="Body" type="CollisionShape2D" parent="Field/World/Npc"]
shape = SubResource("npc_body")

[node name="Talk" type="Area2D" parent="Field/World/Npc"]
script = ExtResource("3")
kind = "npc"

[node name="Shape" type="CollisionShape2D" parent="Field/World/Npc/Talk"]
shape = SubResource("npc_talk")

[node name="Name" type="Label" parent="Field/World/Npc"]
offset_left = -70.0
offset_top = -182.0
offset_right = 70.0
offset_bottom = -158.0
text = "보관소 관리인"
label_settings = SubResource("sign_text")
horizontal_alignment = 1
[node name="BinSign" type="Label" parent="Field/World"]
z_index = 4
offset_left = 856.0
offset_top = 536.0
offset_right = 956.0
offset_bottom = 560.0
text = "반환 레버"
label_settings = SubResource("sign_text")
horizontal_alignment = 1

[node name="HintArrow" type="Node2D" parent="Field/World"]
z_index = 5
position = Vector2(400, 250)

[node name="Arrow" type="Polygon2D" parent="Field/World/HintArrow"]
color = Color(1, 0.8, 0.25, 1)
polygon = {v2arr(tri)}

[node name="Label" type="Label" parent="Field/World/HintArrow"]
offset_left = -200.0
offset_top = -62.0
offset_right = 200.0
offset_bottom = -26.0
text = "다음 행동"
label_settings = SubResource("hint_text")
horizontal_alignment = 1

[node name="HUD" type="CanvasLayer" parent="."]
script = ExtResource("5")
''')
print("play scenes written")
