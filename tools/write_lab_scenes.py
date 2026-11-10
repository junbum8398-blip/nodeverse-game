# -*- coding: utf-8 -*-
"""시안을 게임판으로 쓰는 걷기 실습 씬 14종을 만든다 (ST02~ST10 과 같은 씬 구조).

좌표는 게임 좌표(시안을 1280x720 으로 줄인 값)로 적는다. write_stage_scenes 가 원본 좌표를 받으므로 W() 로 바꾼다.
시안 PNG 는 다시 인코딩하지 않고 그대로 textures/stages/<ID>/bg_game.png 로 복사한다.
실행: python tools/write_lab_scenes.py  (WALK_PREVIEW_DIR 를 주면 걷는 영역 확인 그림 저장)
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import write_stage_scenes as ws  # noqa: E402

S = ws.S
NEW = "reference/minigame_spec_concepts"
OLD = "reference/new_minigame_concepts"
ART = {
    "ALG01": f"{OLD}/ALG01_sorting.png", "ALG02": f"{OLD}/ALG02_binary_search.png",
    "ALG03": f"{NEW}/ALGO_DIVIDE_SORT.png", "ALG04": f"{NEW}/ALGO_SHORTEST.png",
    "DATA01": f"{OLD}/DATA01_data_exploration.png", "DATA02": f"{NEW}/DATA_PROFILE.png",
    "DATA03": f"{NEW}/DATA_STATS.png", "DATA04": f"{NEW}/DATA_CHART.png",
}


def W(p):
    return (p[0] / S, p[1] / S)


def poly(pts):
    return [W(p) for p in pts]


def R(x0, y0, x1, y1):
    return poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])


def E(cx, cy, rx, ry):
    return ws.ellipse(cx / S, cy / S, rx / S, ry / S)


def spots(entries, r=46, hint=-110):
    out = []
    for i, p in enumerate(entries):
        out.append((f"St{i}", "st", i, W(p), p[2] if len(p) > 2 else r, hint))
    return out


def row(x0, dx, n, y):
    return [(x0 + i * dx, y) for i in range(n)]


FLOOR = [(170, 170), (1100, 170), (1200, 240), (1205, 500), (1060, 604), (220, 604), (100, 510), (110, 250)]

LABS = {
    "DS09": {"scene": "DS09_TreeStructure", "script_file": "structure_labs", "activity": "tree", "art": "ST06", "npc": ("NPC06", "자료실 사서"), "npc_pos": (800, 305), "spawn": (960, 290),
             "walk": ws.STAGES["ST06"]["walk"], "holes": [],
             "spots": [(f"St{i}", "st", i, p, 54, -130) for i, p in enumerate([(867, 262), (493, 494), (1062, 494), (344, 770), (687, 770)])] + [("St5", "st", 5, (1010, 262), 44, -130)]},
    "DS10": {"scene": "DS10_GraphBuild", "script_file": "structure_labs", "activity": "graph", "art": "ST09", "npc": ("NPC09", "연결망 측량사"), "npc_pos": (300, 652), "spawn": (480, 560),
             "walk": ws.STAGES["ST09"]["walk"], "holes": ws.STAGES["ST09"]["holes"],
             "spots": [(f"St{i}", "st", i, p, 60, -140) for i, p in enumerate([(253, 628), (344, 300), (713, 640), (867, 300), (1230, 420)])] + [("St5", "st", 5, (500, 640), 46, -120)]},
    "ALG01": {"scene": "ALG01_Sorting", "activity": "sort", "script_file": "algo_labs", "npc": ("NPC01", "작업대 관리인"), "npc_pos": W((640, 265)), "spawn": W((640, 500)),
              "walk": poly([(200, 245), (1040, 245), (1095, 430), (1015, 528), (300, 528), (180, 430)]), "holes": [R(260, 400, 1016, 448)],
              "spots": spots([(x, 478, 44) for x in (318, 444, 570, 698, 825, 953)] + [(232, 410, 44), (1050, 410, 44)])},
    "ALG02": {"scene": "ALG02_Search", "activity": "search", "script_file": "algo_labs", "npc": ("NPC07", "서고 감독관"), "npc_pos": W((1060, 470)), "spawn": W((640, 440)),
              "walk": poly([(190, 390), (1120, 390), (1130, 470), (960, 592), (330, 592), (165, 470)]), "holes": [E(640, 530, 90, 50)],
              "spots": spots([(x, 420, 50) for x in (262, 410, 525, 640, 755, 870, 1018)] + [(640, 462, 36), (300, 520, 44), (980, 520, 44)])},
    "ALG03": {"scene": "ALG03_DivideSort", "activity": "divide", "script_file": "algo_labs", "npc": ("NPC03", "공방 장인"), "npc_pos": W((640, 210)), "spawn": W((610, 445)),
              "walk": poly([(170, 170), (1110, 170), (1150, 300), (1150, 480), (1060, 592), (240, 592), (130, 470), (130, 300)]),
              "holes": [R(232, 185, 530, 282), R(720, 185, 1036, 282), R(195, 320, 362, 416), R(400, 320, 562, 416), R(645, 320, 792, 416), R(822, 320, 916, 416), R(947, 320, 1116, 416), R(232, 470, 525, 565), R(712, 470, 1034, 565)],
              "spots": spots([(278, 442, 52), (480, 442, 52), (720, 442, 52), (868, 442, 52), (1030, 442, 52)])},
    "ALG04": {"scene": "ALG04_ShortestPath", "activity": "shortest", "script_file": "algo_labs", "npc": ("NPC02", "배달 경로 담당자"), "npc_pos": W((640, 190)), "spawn": W((320, 565)),
              "walk": poly([(130, 180), (1120, 180), (1240, 250), (1250, 480), (1130, 604), (220, 604), (70, 480), (70, 260)]), "holes": [R(985, 250, 1228, 545), R(85, 305, 252, 530), R(535, 502, 695, 562)],
              "spots": spots([(322, 402, 52), (488, 292, 52), (485, 510, 52), (895, 402, 52), (740, 292, 52), (260, 578, 44), (440, 578, 44), (840, 578, 44)])},
    "DATA01": {"scene": "DATA01_Explore", "activity": "clean", "script_file": "data_labs", "npc": ("NPC08", "기록 수리 담당자"), "npc_pos": W((640, 250)), "spawn": W((640, 520)),
               "walk": poly([(150, 240), (1130, 240), (1170, 320), (1150, 520), (950, 562), (330, 562), (130, 510), (110, 330)]), "holes": [R(160, 290, 390, 465), R(405, 255, 548, 450), R(566, 255, 712, 450), R(730, 255, 876, 450), R(890, 205, 1125, 480)],
               "spots": spots([(275, 505, 44), (475, 485, 44), (637, 485, 44), (800, 485, 44), (400, 545, 38), (560, 545, 38), (720, 545, 38), (1000, 520, 46)])},
    "DATA02": {"scene": "DATA02_Profile", "activity": "profile", "script_file": "data_labs", "npc": ("NPC00", "데이터 관측 담당자"), "npc_pos": W((640, 175)), "spawn": W((560, 590)),
               "walk": poly(FLOOR), "holes": [R(130, 260, 340, 570), R(345, 190, 760, 545), R(765, 210, 870, 505), R(885, 190, 1115, 380), R(885, 415, 1160, 555)],
               "spots": spots(row(190, 165, 5, 578) + [(1060, 578, 46)], r=48)},
    "DATA03": {"scene": "DATA03_Stats", "activity": "stats", "script_file": "data_labs", "npc": ("NPC03", "통계 실험가"), "npc_pos": W((900, 190)), "spawn": W((1000, 560)),
               "walk": poly(FLOOR), "holes": [R(318, 198, 570, 295), R(600, 198, 850, 295), R(255, 320, 850, 395), R(222, 405, 400, 568), R(440, 405, 620, 568), R(655, 405, 835, 568), R(870, 285, 1205, 530)],
               "spots": spots(row(220, 125, 6, 586) + [(870, 262, 44), (1010, 575, 40), (1130, 565, 40)], r=46)},
    "DATA04": {"scene": "DATA04_Chart", "activity": "chart", "script_file": "data_labs", "npc": ("NPC07", "차트 관측 담당자"), "npc_pos": W((180, 345)), "spawn": W((430, 540)),
               "walk": poly([(150, 292), (1130, 292), (1170, 400), (1130, 530), (1000, 602), (260, 602), (130, 510), (110, 400)]),
               "holes": [R(440, 335, 840, 490), R(200, 390, 405, 525), R(880, 380, 1095, 535), E(630, 562, 55, 28)],
               "spots": spots([(365, 318, 44), (635, 312, 44), (915, 318, 44), (210, 575, 44), (340, 575, 44), (460, 575, 40), (790, 575, 44), (910, 575, 40), (630, 508, 40), (1140, 410, 44), (160, 430, 44), (1020, 562, 40), (1115, 530, 40)])},
}


def main():
    for folder, src in ART.items():
        dest = os.path.join("textures", "stages", folder)
        os.makedirs(dest, exist_ok=True)
        shutil.copyfile(src, os.path.join(dest, "bg_game.png"))
    for sid, cfg in LABS.items():
        cfg.setdefault("art", sid)
        if isinstance(cfg["walk"][0], tuple):
            cfg["walk"] = [cfg["walk"]]
        cfg["script_res"] = f"res://scripts/minigames/{cfg['script_file']}.gd"
        cfg["script"] = cfg["script_file"]
        cfg.setdefault("marks", {})
        cfg.setdefault("signs", [])
        ws.stage_scene(sid, cfg)


if __name__ == "__main__":
    main()
