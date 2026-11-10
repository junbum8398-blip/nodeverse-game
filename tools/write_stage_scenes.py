# -*- coding: utf-8 -*-
"""ST02~ST10 걸어 다니는 스테이지 씬(.tscn) 작성 + Crate/Token 씬.

좌표는 전부 원본 배경(1672x941) 픽셀 기준으로 적고, 씬에는 게임 좌표(S 배)로 저장한다.
walk: 로봇이 걸을 수 있는 영역(다각형들의 합), holes: 그 안에서 막는 영역.
합친 영역의 외곽선을 CollisionPolygon2D 로 저장하므로 에디터에서 점을 끌어 고칠 수 있다.
실행: python tools/write_stage_scenes.py  (환경변수 WALK_PREVIEW_DIR 를 주면 걷는 영역 확인 그림을 저장)
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
os.makedirs("scenes/play", exist_ok=True)
os.makedirs("scenes/stages", exist_ok=True)
S = 1281.0 / 1672.0
W, H = 1672, 941
CELL = 4
PLAYER_R = 14 / S
REACH_R = 72 / S


def ellipse(cx, cy, rx, ry, n=28):
    return [(cx + rx * math.cos(i / n * 2 * math.pi), cy + ry * math.sin(i / n * 2 * math.pi)) for i in range(n)]


def rect(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


STAGES = {
    "ST02": {
        "scene": "ST02_LinkedList", "script": "st02_linked_list_stage", "npc": ("NPC02", "운송로 정비사"), "npc_pos": (765, 668), "spawn": (470, 690),
        "walk": [ellipse(285, 325, 195, 88), rect(430, 276, 1020, 340), ellipse(1113, 318, 175, 82), rect(1215, 300, 1285, 362),
                 [(250, 385), (325, 385), (340, 455), (500, 610), (430, 680), (275, 470)],
                 ellipse(585, 655, 200, 95), [(740, 600), (940, 640), (1170, 515), (1385, 630), (1075, 750), (760, 720)]],
        "holes": [ellipse(292, 330, 92, 36), ellipse(1113, 322, 92, 36), ellipse(585, 668, 92, 36), rect(1010, 545, 1270, 665)],
        "spots": [("Head", "head", -1, (150, 300), 66, -120), ("NodeA", "node", 0, (292, 378), 62, -210), ("NodeB", "node", 1, (585, 716), 62, -210),
                  ("NodeC", "node", 2, (1113, 378), 62, -210), ("End", "null", -1, (1312, 348), 58, -120)],
        "marks": {"AnchorA": (292, 238), "AnchorB": (585, 588), "AnchorC": (1113, 238), "AnchorHead": (170, 196), "AnchorEnd": (1305, 262)},
        "signs": [("HEAD", (150, 142)), ("끝 (null)", (1310, 212))],
    },
    "ST03": {
        "scene": "ST03_Stack", "script": "st03_stack_stage", "npc": ("NPC03", "복구실 장인"), "npc_pos": (668, 480), "spawn": (820, 560),
        "walk": [[(640, 410), (1250, 410), (1296, 520), (1240, 610), (1060, 660), (880, 678), (700, 676), (470, 664), (352, 646), (336, 612), (480, 612), (640, 612)]],
        "holes": [rect(900, 490, 1282, 628)],
        "spots": [("Tower", "tower", -1, (392, 630), 60, -320), ("Intake", "intake", -1, (760, 602), 58, -110), ("Output", "output", -1, (1060, 446), 70, -60),
                  ("Lever", "lever", -1, (560, 650), 52, -110), ("Desk", "desk", -1, (930, 420), 58, -150)],
        "marks": {"Stack0": (388, 576), "Stack1": (388, 470), "Stack2": (388, 362), "Inbox": (720, 612), "Out0": (975, 545), "Out1": (1080, 545), "Out2": (1188, 545), "Board": (930, 240)},
        "signs": [("스택 탑", (392, 232)), ("입고 레일", (760, 650)), ("복구 작업대", (1085, 628))],
    },
    "ST04": {
        "scene": "ST04_QueueDeque", "script": "st04_queue_deque_stage", "npc": ("NPC04", "접수 담당자"), "npc_pos": (352, 640), "spawn": (800, 600),
        "walk": [[(312, 420), (480, 414), (492, 340), (1125, 340), (1190, 395), (1216, 430), (1205, 540), (1107, 640), (853, 672), (440, 680), (290, 645), (258, 540), (312, 520)]],
        "holes": [rect(412, 436, 1188, 528)],
        "spots": [("Counter", "counter", -1, (330, 412), 62, -130), ("Front", "front", -1, (312, 490), 58, -110), ("Rear", "rear", -1, (1218, 500), 62, -120), ("Arrive", "arrive", -1, (1100, 590), 62, -100)],
        "marks": {"Line0": (522, 494), "Line1": (731, 494), "Line2": (941, 494), "Line3": (1122, 488), "Arrive0": (1090, 612), "Arrive1": (1000, 640), "Arrive2": (920, 655), "Served0": (250, 340), "Served1": (330, 340), "Served2": (410, 340), "Served3": (290, 300), "Mode": (795, 382)},
        "signs": [("도착 대기", (1095, 660))],
    },
    "ST05": {
        "scene": "ST05_Hash", "script": "st05_hash_stage", "npc": ("NPC05", "물품대장 담당자"), "npc_pos": (880, 650), "spawn": (960, 540),
        "walk": [[(440, 505), (1290, 505), (1290, 556), (985, 556), (985, 700), (880, 760), (640, 792), (360, 722), (190, 702), (140, 682), (330, 622), (430, 562)]],
        "holes": [ellipse(680, 640, 145, 86)],
        "spots": [("Bucket0", "bucket", 0, (512, 500), 46, -220), ("Bucket1", "bucket", 1, (637, 500), 46, -220), ("Bucket2", "bucket", 2, (786, 500), 54, -220),
                  ("Bucket3", "bucket", 3, (937, 500), 46, -220), ("Bucket4", "bucket", 4, (1070, 500), 46, -220),
                  ("Intake", "intake", -1, (410, 590), 66, -90), ("Dup", "dup", -1, (1170, 520), 74, -70), ("Hash", "hash", -1, (680, 556), 62, -60)],
        "marks": {"Tag0": (512, 330), "Tag1": (637, 330), "Tag2": (786, 330), "Tag3": (937, 330), "Tag4": (1070, 330), "Inbox": (360, 548), "Panel": (1520, 225)},
        "signs": [("입고대", (312, 668)), ("중복 거절함", (1170, 668))],
    },
    "ST06": {
        "scene": "ST06_BinaryTree", "script": "st06_binary_tree_stage", "npc": ("NPC06", "자료실 사서"), "npc_pos": (800, 305), "spawn": (960, 290),
        "walk": [ellipse(833, 262, 215, 62), [(585, 262), (650, 262), (625, 380), (567, 372)], [(965, 262), (1035, 262), (985, 372), (925, 372)],
                 rect(567, 360, 627, 510), rect(925, 360, 985, 510), ellipse(487, 530, 180, 58), ellipse(1067, 530, 150, 58),
                 [(355, 545), (440, 555), (375, 660), (295, 640)], [(545, 545), (625, 540), (665, 640), (590, 655)],
                 ellipse(330, 800, 150, 54), ellipse(700, 800, 150, 54), rect(300, 640, 380, 760), rect(595, 640, 680, 760)],
        "holes": [],
        "spots": [("RoomA", "room", 0, (867, 262), 54, -130), ("RoomB", "room", 1, (493, 494), 54, -130), ("RoomC", "room", 2, (1062, 494), 54, -130),
                  ("RoomD", "room", 3, (344, 770), 54, -130), ("RoomE", "room", 4, (687, 770), 54, -130)],
        "marks": {"Log0": (1380, 570), "Log1": (1442, 570), "Log2": (1504, 570), "Log3": (1566, 570), "Log4": (1628, 570), "Order": (1465, 412)},
        "signs": [],
    },
    "ST07": {
        "scene": "ST07_Bst", "script": "st07_bst_stage", "npc": ("NPC07", "갈림길 감독관"), "npc_pos": (846, 536), "spawn": (925, 618),
        "walk": [[(780, 250), (1040, 250), (1090, 300), (1320, 430), (1490, 545), (1410, 640), (1000, 690), (700, 700), (345, 650), (372, 545), (540, 420), (700, 300)]],
        "holes": [ellipse(1000, 438, 52, 38), rect(575, 492, 690, 560), rect(1150, 488, 1265, 556)],
        "spots": [("Pad0", "pad", 0, (920, 285), 66, -210), ("Pad1", "pad", 1, (673, 430), 66, -210), ("Pad2", "pad", 2, (1164, 430), 66, -210), ("Pad3", "pad", 3, (489, 605), 62, -210),
                  ("Pad4", "pad", 4, (780, 640), 62, -210), ("Pad5", "pad", 5, (1060, 605), 62, -210), ("Pad6", "pad", 6, (1353, 628), 62, -210)],
        "marks": {"Plate0": (920, 212), "Plate1": (673, 358), "Plate2": (1164, 362), "Plate3": (489, 540), "Plate4": (817, 584), "Plate5": (1060, 540), "Plate6": (1353, 560)},
        "signs": [],
    },
    "ST08": {
        "scene": "ST08_Heap", "script": "st08_heap_stage", "npc": ("NPC08", "긴급 배정 담당자"), "npc_pos": (1040, 552), "spawn": (820, 410),
        "walk": [[(352, 392), (560, 235), (720, 178), (890, 178), (1120, 245), (1130, 345), (1375, 410), (1355, 520), (1120, 625), (1010, 590), (400, 582), (352, 486)]],
        "holes": [],
        "spots": [("Pad0", "pad", 0, (801, 230), 54, -170), ("Pad1", "pad", 1, (615, 372), 54, -170), ("Pad2", "pad", 2, (985, 372), 54, -170), ("Pad3", "pad", 3, (485, 540), 54, -170), ("Pad4", "pad", 4, (712, 540), 54, -170), ("Pad5", "pad", 5, (908, 535), 54, -170),
                  ("Lever1", "lever", 1, (692, 262), 40, -90), ("Lever2", "lever", 2, (905, 262), 40, -90), ("Lever3", "lever", 3, (525, 408), 40, -90), ("Lever4", "lever", 4, (695, 408), 40, -90), ("Lever5", "lever", 5, (913, 408), 40, -90),
                  ("Intake", "intake", -1, (1205, 500), 62, -110), ("Outbox", "outbox", -1, (372, 420), 60, -100)],
        "marks": {"Crate0": (801, 196), "Crate1": (615, 336), "Crate2": (985, 336), "Crate3": (485, 502), "Crate4": (712, 502), "Crate5": (908, 496), "Inbox": (1262, 494), "Out": (250, 470),
                  "Arr0": (540, 633), "Arr1": (617, 633), "Arr2": (687, 633), "Arr3": (762, 633), "Arr4": (840, 633), "Arr5": (917, 633)},
        "signs": [("입고", (1262, 545)), ("완료 접수", (372, 500))],
    },
    "ST09": {
        "scene": "ST09_Graph", "script": "st09_graph_stage", "npc": ("NPC09", "연결망 측량사"), "npc_pos": (300, 652), "spawn": (480, 560),
        "walk": [[(150, 622), (205, 676), (360, 684), (392, 668), (620, 668), (800, 642), (830, 602), (1010, 562), (1120, 522), (1150, 500), (1320, 500), (1320, 400), (1150, 396), (1150, 345), (1010, 345), (940, 292), (790, 290), (780, 232), (450, 232), (440, 290), (340, 290), (270, 292), (230, 332), (200, 432), (145, 442), (132, 602)]],
        "holes": [rect(150, 446, 332, 606), rect(633, 440, 800, 622), rect(528, 290, 660, 426)],
        "spots": [("HouseA", "house", 0, (253, 628), 60, -140), ("HouseB", "house", 1, (344, 300), 60, -140), ("HouseC", "house", 2, (713, 640), 60, -140), ("HouseD", "house", 3, (867, 300), 60, -140), ("HouseE", "house", 4, (1230, 420), 60, -140)],
        "marks": {"Q0": (512, 772), "Q1": (601, 772), "Q2": (698, 772), "Q3": (797, 772)},
        "signs": [],
    },
    "ST10": {
        "scene": "ST10_Integrated", "script": "st10_integrated_stage", "npc": ("NPC00", "학습 지원 안내원"), "npc_pos": (716, 548), "spawn": (820, 520),
        "walk": [[(300, 470), (330, 440), (1110, 440), (1135, 520), (1030, 540), (1040, 730), (950, 790), (620, 800), (360, 750), (310, 660), (375, 600), (375, 530), (310, 520)]],
        "holes": [rect(420, 545, 650, 640), ellipse(805, 640, 110, 76)],
        "spots": [("Dev0", "device", 0, (385, 440), 74, -150), ("Dev1", "device", 1, (372, 610), 66, -120), ("Dev2", "device", 2, (693, 440), 74, -180), ("Dev3", "device", 3, (540, 530), 66, -80),
                  ("Dev4", "device", 4, (985, 440), 74, -180), ("Dev5", "device", 5, (1120, 470), 72, -170), ("Dev6", "device", 6, (1032, 620), 66, -140), ("Dev7", "device", 7, (700, 790), 72, -90)],
        "marks": {"Arr0": (624, 790), "Arr1": (664, 790), "Arr2": (704, 790), "Arr3": (744, 790), "Arr4": (784, 790)},
        "signs": [("배열", (705, 720))],
    },
}


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def v2arr(pts):
    return "PackedVector2Array(" + ", ".join(f"{x:.1f}, {y:.1f}" for x, y in pts) + ")"


def trace_loops(mask):
    """True 영역의 경계선을 닫힌 고리들로 추적 (격자 꼭짓점 좌표)."""
    h, w = mask.shape
    m = np.zeros((h + 2, w + 2), bool)
    m[1:-1, 1:-1] = mask
    nxt = {}
    for y, x in np.argwhere(m):
        for (dx, dy, a, b) in ((0, -1, (x, y), (x + 1, y)), (1, 0, (x + 1, y), (x + 1, y + 1)), (0, 1, (x + 1, y + 1), (x, y + 1)), (-1, 0, (x, y + 1), (x, y))):
            if not m[y + dy, x + dx]:
                nxt.setdefault(a, []).append(b)
    loops = []
    while nxt:
        start = next(iter(nxt))
        cur = start
        loop = []
        while True:
            loop.append(cur)
            lst = nxt[cur]
            b = lst.pop()
            if not lst:
                del nxt[cur]
            cur = b
            if cur == start:
                break
        loops.append([(p[0] - 1, p[1] - 1) for p in loop])
    return loops


def simplify(pts, eps):
    """닫힌 고리 Douglas-Peucker."""
    def rdp(seq):
        if len(seq) < 3:
            return seq
        a, b = np.array(seq[0], float), np.array(seq[-1], float)
        d = b - a
        n = np.hypot(*d) or 1.0
        arr = np.array(seq[1:-1], float) - a
        dist = np.abs(arr[:, 0] * d[1] - arr[:, 1] * d[0]) / n
        i = int(np.argmax(dist))
        if dist[i] <= eps:
            return [seq[0], seq[-1]]
        return rdp(seq[:i + 2])[:-1] + rdp(seq[i + 1:])
    k = len(pts) // 2
    return rdp(pts[:k + 1])[:-1] + rdp(pts[k:] + [pts[0]])[:-1]


def build_walls(cfg, sid):
    gw, gh = W // CELL, H // CELL
    im = Image.new("L", (gw, gh), 0)
    d = ImageDraw.Draw(im)
    for p in cfg["walk"]:
        d.polygon([(x / CELL, y / CELL) for x, y in p], fill=255)
    for p in cfg["holes"]:
        d.polygon([(x / CELL, y / CELL) for x, y in p], fill=0)
    mask = ndimage.binary_opening(np.array(im) > 0, iterations=2)
    # 도달 가능 검사 (로봇 반지름만큼 줄인 영역에서 flood)
    er = ndimage.binary_erosion(mask, iterations=int(PLAYER_R / CELL))
    lab, _ = ndimage.label(er)
    sx, sy = cfg["spawn"]
    sid_lab = lab[int(sy / CELL), int(sx / CELL)]
    if sid_lab == 0:
        print(f"!! {sid}: spawn is not walkable")
    reach = (lab == sid_lab) if sid_lab > 0 else er
    ys, xs = np.where(reach)
    for sp in cfg["spots"]:
        px, py = sp[3]
        dist = np.hypot(xs * CELL - px, ys * CELL - py).min()
        limit = (REACH_R + sp[4] / S) * 0.92
        if dist > limit:
            print(f"!! {sid}: spot {sp[0]} unreachable ({dist:.0f} > {limit:.0f})")
    loops = [simplify(l, 1.4) for l in trace_loops(mask)]
    loops = [l for l in loops if len(l) >= 3]
    # 확인 그림
    prev = Image.open(f"textures/stages/{cfg.get('art', sid)}/bg_game.png").convert("RGB").copy()
    d = ImageDraw.Draw(prev, "RGBA")
    for l in loops:
        d.line([(x * CELL, y * CELL) for x, y in l + [l[0]]], fill=(255, 0, 255, 255), width=3)
    for sp in cfg["spots"]:
        x, y = sp[3]
        r = sp[4] / S
        d.ellipse((x - r, y - r, x + r, y + r), outline=(255, 255, 0, 255), width=2)
        d.text((x, y), sp[0], fill=(255, 255, 255))
    sx, sy = cfg["npc_pos"]
    d.ellipse((sx - 10, sy - 10, sx + 10, sy + 10), fill=(0, 255, 0, 255))
    sx, sy = cfg["spawn"]
    d.ellipse((sx - 10, sy - 10, sx + 10, sy + 10), fill=(255, 0, 0, 255))
    if os.environ.get("WALK_PREVIEW_DIR"):
        prev.convert("RGB").resize((1254, 706), Image.LANCZOS).save(os.path.join(os.environ["WALK_PREVIEW_DIR"], f"_walk_{sid}.jpg"), quality=85)
    return [[(x * CELL * S, y * CELL * S) for x, y in l] for l in loops]


ELL = [(30 * math.cos(a / 16 * 2 * math.pi), 9 * math.sin(a / 16 * 2 * math.pi)) for a in range(16)]
TRI = [(-16, -22), (16, -22), (0, 0)]


def stage_scene(sid, cfg):
    def fp(p):
        return f"Vector2({p[0] * S:.1f}, {p[1] * S:.1f})"
    loops = build_walls(cfg, sid)
    radii = sorted({sp[4] for sp in cfg["spots"]})
    subs = "\n".join(f'[sub_resource type="CircleShape2D" id="r{r}"]\nradius = {r}.0\n' for r in radii)
    wall_nodes = ""
    for i, l in enumerate(loops):
        wall_nodes += f'''[node name="Boundary{i}" type="CollisionPolygon2D" parent="Field/Walls"]
build_mode = 1
polygon = {v2arr(l + [l[0]])}

'''
    spots = ""
    for name, kind, index, pos, r, hint_y in cfg["spots"]:
        spots += f'''[node name="{name}" type="Area2D" parent="Field/World"]
position = {fp(pos)}
script = ExtResource("3")
kind = "{kind}"
index = {index}
bubble_offset = Vector2(0, {hint_y})

[node name="Shape" type="CollisionShape2D" parent="Field/World/{name}"]
shape = SubResource("r{r}")

'''
    marks = ""
    for name, pos in cfg["marks"].items():
        marks += f'[node name="{name}" type="Marker2D" parent="Field/World"]\nposition = {fp(pos)}\n\n'
    signs = ""
    for i, (t, pos) in enumerate(cfg["signs"]):
        x, y = pos[0] * S, pos[1] * S
        signs += f'''[node name="Sign{i}" type="Label" parent="Field/World"]
z_index = 4
offset_left = {x - 90:.1f}
offset_top = {y - 13:.1f}
offset_right = {x + 90:.1f}
offset_bottom = {y + 13:.1f}
text = "{t}"
label_settings = SubResource("sign_text")
horizontal_alignment = 1

'''
    npc_id, npc_name = cfg["npc"]
    write(f"scenes/stages/{cfg['scene']}.tscn", f'''[gd_scene format=3]

[ext_resource type="Script" path="{cfg.get('script_res', 'res://scripts/play/' + cfg['script'] + '.gd')}" id="1"]
[ext_resource type="Texture2D" path="res://textures/stages/{cfg.get('art', sid)}/bg_game.png" id="2"]
[ext_resource type="Script" path="res://scripts/play/interactable.gd" id="3"]
[ext_resource type="PackedScene" path="res://scenes/play/Player.tscn" id="4"]
[ext_resource type="Script" path="res://scripts/play/stage_hud.gd" id="5"]
[ext_resource type="Texture2D" path="res://textures/npc_portraits/{npc_id}_world.png" id="6"]

{subs}
[sub_resource type="CircleShape2D" id="npc_body"]
radius = 18.0

[sub_resource type="CircleShape2D" id="npc_talk"]
radius = 64.0

[sub_resource type="LabelSettings" id="hint_text"]
font_size = 25
font_color = Color(1, 0.86, 0.35, 1)
outline_size = 7
outline_color = Color(0.114, 0.106, 0.165, 1)

[sub_resource type="LabelSettings" id="sign_text"]
font_size = 21
outline_size = 5
outline_color = Color(0.114, 0.106, 0.165, 1)

[node name="{cfg['scene']}" type="Node2D"]
script = ExtResource("1"){chr(10) + 'activity = "' + cfg['activity'] + '"' if 'activity' in cfg else ''}

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

{wall_nodes}[node name="Links" type="Node2D" parent="Field"]

[node name="World" type="Node2D" parent="Field"]
y_sort_enabled = true

[node name="Overlay" type="Node2D" parent="Field"]
z_index = 3

[node name="Player" parent="Field/World" instance=ExtResource("4")]
position = {fp(cfg['spawn'])}

[node name="Spawn" type="Marker2D" parent="Field/World"]
position = {fp(cfg['spawn'])}

{spots}{marks}[node name="Npc" type="StaticBody2D" parent="Field/World"]
position = {fp(cfg['npc_pos'])}

[node name="Shadow" type="Polygon2D" parent="Field/World/Npc"]
color = Color(0, 0, 0, 0.28)
polygon = {v2arr(ELL)}

[node name="Sprite" type="Sprite2D" parent="Field/World/Npc"]
texture = ExtResource("6")
offset = Vector2(0, -75)

[node name="Body" type="CollisionShape2D" parent="Field/World/Npc"]
shape = SubResource("npc_body")

[node name="Talk" type="Area2D" parent="Field/World/Npc"]
script = ExtResource("3")
kind = "npc"
prompt = "{npc_name}과 대화"

[node name="Shape" type="CollisionShape2D" parent="Field/World/Npc/Talk"]
shape = SubResource("npc_talk")

[node name="Name" type="Label" parent="Field/World/Npc"]
offset_left = -90.0
offset_top = -182.0
offset_right = 90.0
offset_bottom = -158.0
text = "{npc_name}"
label_settings = SubResource("sign_text")
horizontal_alignment = 1

{signs}[node name="HintArrow" type="Node2D" parent="Field/World"]
z_index = 5
position = Vector2(400, 250)

[node name="Arrow" type="Polygon2D" parent="Field/World/HintArrow"]
color = Color(1, 0.8, 0.25, 1)
polygon = {v2arr(TRI)}

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
    print(sid, "scene written,", len(loops), "wall loops")


def crate_scenes():
    write("scenes/play/Crate.tscn", f'''[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/play/crate.gd" id="1"]
[ext_resource type="Texture2D" path="res://textures/sprites/crate.png" id="2"]

[sub_resource type="LabelSettings" id="num"]
font_size = 25
font_color = Color(0.11, 0.1, 0.16, 1)

[node name="Crate" type="Node2D"]
script = ExtResource("1")

[node name="Shadow" type="Polygon2D" parent="."]
position = Vector2(0, 2)
scale = Vector2(1.5, 1.2)
color = Color(0, 0, 0, 0.32)
polygon = {v2arr(ELL)}

[node name="Sprite" type="Sprite2D" parent="."]
scale = Vector2(0.36, 0.36)
texture = ExtResource("2")
offset = Vector2(0, -124)

[node name="Label" type="Label" parent="."]
offset_left = -33.0
offset_top = -49.0
offset_right = 22.0
offset_bottom = -17.0
text = "0"
label_settings = SubResource("num")
horizontal_alignment = 1
vertical_alignment = 1
''')
    write("scenes/play/Token.tscn", f'''[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/play/crate.gd" id="1"]
[ext_resource type="Texture2D" path="res://textures/sprites/token.png" id="2"]

[sub_resource type="LabelSettings" id="num"]
font_size = 30
outline_size = 6
outline_color = Color(0.114, 0.106, 0.165, 1)

[node name="Token" type="Node2D"]
script = ExtResource("1")

[node name="Shadow" type="Polygon2D" parent="."]
position = Vector2(0, 2)
scale = Vector2(1.25, 1.0)
color = Color(0, 0, 0, 0.3)
polygon = {v2arr(ELL)}

[node name="Sprite" type="Sprite2D" parent="."]
scale = Vector2(0.36, 0.36)
texture = ExtResource("2")
offset = Vector2(0, -88)

[node name="Label" type="Label" parent="."]
offset_left = -36.0
offset_top = -50.0
offset_right = 36.0
offset_bottom = -12.0
text = "A"
label_settings = SubResource("num")
horizontal_alignment = 1
vertical_alignment = 1
''')


if __name__ == "__main__":
    crate_scenes()
    for sid, cfg in STAGES.items():
        stage_scene(sid, cfg)
