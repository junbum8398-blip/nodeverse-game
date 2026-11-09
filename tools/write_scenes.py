# -*- coding: utf-8 -*-
"""스크립트 1개짜리 Godot 씬(.tscn)들을 생성하고, 스크립트 파일의 BOM 을 제거한다."""
import glob, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
GAMES = ["st01_array", "st02_linked_list", "st03_stack", "st04_queue_deque", "st05_hash",
         "st06_binary_tree", "st07_bst", "st08_heap", "st09_graph", "st10_integrated"]


def scene(name, typ, script):
    return ('[gd_scene load_steps=2 format=3]\n\n'
            f'[ext_resource type="Script" path="{script}" id="1"]\n\n'
            f'[node name="{name}" type="{typ}"]\n'
            'script = ExtResource("1")\n')


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


os.makedirs("scenes/minigames", exist_ok=True)
for g in GAMES:
    write(f"scenes/minigames/{g}.tscn", scene(g.upper(), "Node2D", f"res://scripts/minigames/{g}.gd"))
write("scenes/Main.tscn", scene("Main", "Node2D", "res://scripts/main_menu.gd"))
write("scenes/NPCViewer.tscn", scene("NPCViewer", "Node3D", "res://scripts/npc/npc_viewer.gd"))
write("scenes/Capture.tscn", scene("Capture", "Node", "res://scripts/tools/capture_minigames.gd"))
for f in glob.glob("scripts/**/*.gd", recursive=True) + glob.glob("tools/*.py"):
    b = open(f, "rb").read()
    if b.startswith(b"\xef\xbb\xbf"):
        open(f, "wb").write(b[3:])
        print("BOM 제거:", f)
print("scenes written")
