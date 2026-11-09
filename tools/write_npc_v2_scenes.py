# -*- coding: utf-8 -*-
"""models/npc/merged/<id>.scn (부품을 미리 합친 NPC; scripts/tools/merge_npc_parts.gd 로 생성) -> scenes/npc/<id>.tscn 게임용 NPC 씬 재생성.
GLB 를 씬 루트로 상속하고 대기 애니메이션 스크립트·충돌·대화 범위·이름표를 붙인다.
월드(nodeverse_world.gd 의 NPC_DEFS)와 NPC 뷰어는 scenes/npc/<id>.tscn 을 그대로 쓰므로 재배치가 자동 반영된다."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
names = {m["id"]: m["name"] for m in json.load(open("data/npc_list.json", encoding="utf-8"))}
HEIGHT = 1.22

for f in sorted(os.listdir("models/npc")):
    if not f.endswith(".glb"):
        continue
    nid = f[:-4]
    tscn = f'''[gd_scene load_steps=7 format=3]

[ext_resource type="PackedScene" path="res://models/npc/merged/{nid}.scn" id="1"]
[ext_resource type="Script" path="res://scripts/npc/npc_sd_actor.gd" id="2"]
[ext_resource type="FontVariation" path="res://fonts/NotoSansKR_Bold.tres" id="3"]

[sub_resource type="CapsuleShape3D" id="body"]
radius = 0.32
height = {HEIGHT}

[sub_resource type="SphereShape3D" id="talk"]
radius = 1.4

[node name="{nid}" instance=ExtResource("1")]
script = ExtResource("2")
npc_id = "{nid}"
display_name = "{names.get(nid, nid)}"

[node name="Collider" type="StaticBody3D" parent="."]

[node name="Shape" type="CollisionShape3D" parent="Collider"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {HEIGHT / 2:.3f}, 0)
shape = SubResource("body")

[node name="TalkArea" type="Area3D" parent="."]

[node name="Shape" type="CollisionShape3D" parent="TalkArea"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.7, 0)
shape = SubResource("talk")

[node name="NameTag" type="Label3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {HEIGHT + 0.2:.2f}, 0)
billboard = 1
pixel_size = 0.004
text = "{names.get(nid, nid)}"
font = ExtResource("3")
font_size = 44
outline_size = 10
'''
    with open(f"scenes/npc/{nid}.tscn", "w", encoding="utf-8", newline="\n") as fp:
        fp.write(tscn)
    print("scene:", nid)
