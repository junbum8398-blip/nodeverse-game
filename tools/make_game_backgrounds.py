# -*- coding: utf-8 -*-
"""배경(bg_clean.png)에서 '게임이 직접 그릴 움직이는 물건'(상자, 노드 등)을 지워 게임판용 배경을 만든다.

bg_clean.png 은 순수 추출 배경으로 그대로 두고,
  bg_game.png   게임판용 원본 해상도 배경
  bg_pixel.png  bg_game.png 의 도트 버전 (게임에서 사용)
을 만든다. 실행: python tools/make_game_backgrounds.py [ST01 ...]
"""
import os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_stage_backgrounds import inpaint, pixelate, OUT  # noqa: E402

# ("copy", (x0, y0, x1, y1), dx, dy): 원본 좌표 영역을 (dx, dy) 만큼 옮긴 곳에 복사
# ("inpaint", (x0, y0, x1, y1)): 주변 패치로 메우기
PREP = {
    "ST01": [
        # 빈 칸(3번) 모습을 0~2번 칸에 복사해 고정 상자 10/30/40 제거
        ("copy", (896, 330, 1044, 506), -165, 0),
        ("copy", (896, 330, 1044, 506), -330, 0),
        ("copy", (896, 330, 1044, 506), -495, 0),
        # 입고 트레이 위 상자 20 제거
        ("inpaint", (606, 574, 724, 694)),
    ],
}


def main(ids):
    for sid in ids:
        src = os.path.join(OUT, sid, "bg_clean.png")
        img = np.array(Image.open(src).convert("RGB"))
        holes = []
        for op in PREP.get(sid, []):
            if op[0] == "copy":
                (x0, y0, x1, y1), dx, dy = op[1], op[2], op[3]
                img[y0 + dy:y1 + dy, x0 + dx:x1 + dx] = img[y0:y1, x0:x1].copy()
            elif op[0] == "inpaint":
                holes.append(op[1])
        if holes:
            img = inpaint(img, holes)
        game = Image.fromarray(img)
        game.save(os.path.join(OUT, sid, "bg_game.png"))
        pixelate(game).save(os.path.join(OUT, sid, "bg_pixel.png"))
        print(sid, "game background done")


if __name__ == "__main__":
    main(sys.argv[1:] or sorted(PREP.keys()))
