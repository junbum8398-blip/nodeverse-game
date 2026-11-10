# -*- coding: utf-8 -*-
"""SQL 5x5 시안 4장에서 2D 에셋을 분리한다.

시안 속 글자·숫자·표는 지우고 틀만 남겨 textures/sql_drawer/ 에 저장한다. 실제 값은 게임에서 그린다.
실행: python tools/make_sql_drawer_assets.py <시안 폴더>
"""
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "textures", "sql_drawer")
NAMES = {"SQL01": "SQL01_5x5_Extract.png", "SQL02": "SQL02_5x5_Group.png", "SQL03": "SQL03_5x5_Join.png", "SQL04": "SQL04_5x5_Subquery.png"}


def erase(im, box):
    """box 안의 글자를 좌우 바깥 색으로 줄 단위 보간해 지운다."""
    a = np.array(im.convert("RGB"), float)
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        left = a[y, max(x0 - 4, 0):x0].mean(axis=0)
        right = a[y, x1:min(x1 + 4, a.shape[1])].mean(axis=0)
        for x in range(x0, x1):
            t = (x - x0) / max(x1 - x0 - 1, 1)
            a[y, x] = left * (1 - t) + right * t
    return Image.fromarray(a.astype("uint8"))


def round_alpha(im, radius):
    im = im.convert("RGBA")
    s = 4
    mask = Image.new("L", (im.width * s, im.height * s), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width * s - 1, im.height * s - 1), radius * s, fill=255)
    im.putalpha(mask.resize(im.size, Image.LANCZOS))
    return im


def crop_clean(src, box, boxes_erase, radius=0):
    x0, y0, x1, y1 = box
    im = src.crop(box)
    for b in boxes_erase:
        im = erase(im, (b[0] - x0, b[1] - y0, b[2] - x0, b[3] - y0))
    return round_alpha(im, radius) if radius else im.convert("RGBA")


def floor_texture(size, base):
    """시안 바닥색으로 돌바닥을 그린다. 게임판 틈으로만 보인다."""
    w, h = size
    im = Image.new("RGB", size, tuple(base))
    d = ImageDraw.Draw(im)
    rng = random.Random(7)
    bw, bh = 62, 42
    for j in range(h // bh + 2):
        off = (j % 2) * bw // 2
        for i in range(-1, w // bw + 2):
            shade = rng.randint(-9, 9)
            c = tuple(int(np.clip(v + shade, 0, 255)) for v in base)
            d.rectangle((i * bw + off + 2, j * bh + 2, i * bw + off + bw - 2, j * bh + bh - 2), fill=c)
            d.line((i * bw + off + 3, j * bh + 3, i * bw + off + bw - 3, j * bh + 3), fill=tuple(min(v + 16, 255) for v in c))
    return im


def floor_color(src, regions):
    """판 둘레 바닥의 분홍빛 돌색을 측정한다."""
    a = np.array(src.convert("RGB"))
    x0 = min(r[0] for r in regions[1:]) - 14
    x1 = max(r[2] for r in regions[1:]) + 14
    y0 = min(r[1] for r in regions[1:])
    y1 = max(r[3] for r in regions[1:]) + 14
    ring = np.concatenate([a[y0:y1, max(x0, 0):x0 + 14].reshape(-1, 3), a[y0:y1, x1 - 14:min(x1, a.shape[1])].reshape(-1, 3), a[y1 - 14:y1, x0:x1].reshape(-1, 3)])
    ok = ring[(ring[:, 0] > 165) & (ring[:, 0] < 240) & (ring[:, 0] > ring[:, 1]) & (ring[:, 1] > ring[:, 2]) & (ring[:, 2] > 110)]
    return tuple(int(v) for v in np.median(ok if len(ok) > 50 else ring, axis=0))


def clean_background(src, regions, floor_color):
    out = src.convert("RGB").copy()
    tile = floor_texture(src.size, floor_color)
    mask = Image.new("L", src.size, 0)
    d = ImageDraw.Draw(mask)
    for r in regions:
        d.rounded_rectangle(r, 14, fill=255)
    out.paste(tile, (0, 0), mask.filter(ImageFilter.GaussianBlur(9)))
    return out


def hatch(size, line, spacing):
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for x in range(-size[1], size[0], spacing):
        d.line((x, size[1], x + size[1], 0), fill=line, width=3)
    return im


def dots(size, color, spacing):
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for y in range(spacing // 2, size[1], spacing):
        for x in range(spacing // 2, size[0], spacing):
            d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=color)
    return im


def main(folder):
    os.makedirs(OUT, exist_ok=True)
    src = {k: Image.open(os.path.join(folder, v)).convert("RGBA") for k, v in NAMES.items()}
    a, b, c, d = src["SQL01"], src["SQL02"], src["SQL03"], src["SQL04"]
    save = lambda im, name: im.save(os.path.join(OUT, name + ".png"))

    # 서랍 칸: 색별로 시안에서 잘라 글자만 지운다
    cells = {
        "cell_plain": (a, (238, 374, 380, 480), (262, 396, 358, 450)),
        "cell_col": (a, (394, 742, 538, 846), (414, 762, 520, 816)),
        "cell_row": (a, (238, 254, 380, 360), (262, 276, 358, 330)),
        "cell_hit": (a, (394, 258, 538, 360), (414, 276, 520, 330)),
        "cell_g1": (b, (208, 194, 364, 278), (262, 206, 318, 248)),
        "cell_g2": (b, (208, 288, 364, 372), (262, 300, 318, 342)),
        "cell_g3": (b, (208, 580, 364, 670), (262, 592, 318, 638)),
    }
    for name, (im, box, text_box) in cells.items():
        save(crop_clean(im, box, [text_box], 10), name)

    # 머리글·행 번호·의뢰판
    save(crop_clean(a, (714, 170, 856, 232), [(738, 182, 836, 218)], 12), "header_plain")
    save(crop_clean(a, (394, 170, 534, 232), [(420, 182, 512, 218)], 12), "header_on")
    save(crop_clean(a, (154, 272, 226, 346), [(176, 286, 206, 328)], 10), "row_badge")
    save(crop_clean(a, (526, 30, 1148, 124), [(566, 50, 1120, 102)], 16), "mission_plate")

    # 도구 칸
    save(crop_clean(a, (1104, 744, 1234, 858), [], 14), "tool_blue_brush")
    save(crop_clean(a, (1252, 744, 1384, 858), [], 14), "tool_gold_brush")
    save(crop_clean(a, (1402, 744, 1532, 858), [], 14), "tool_eraser")
    save(crop_clean(a, (1402, 744, 1532, 858), [(1416, 754, 1520, 848)], 14), "tool_blank")
    save(crop_clean(b, (1110, 648, 1202, 738), [], 12), "tool_group_brush")
    save(crop_clean(b, (1222, 650, 1310, 738), [], 12), "tool_count")
    save(crop_clean(b, (1328, 650, 1416, 738), [], 12), "tool_sum")
    save(crop_clean(c, (450, 786, 524, 852), [], 12), "tool_key_brush")
    save(crop_clean(c, (844, 784, 936, 850), [], 12), "tool_funnel")
    save(crop_clean(d, (1152, 735, 1296, 822), [], 14), "tool_green_brush")
    save(crop_clean(d, (1332, 735, 1472, 822), [], 14), "tool_submit")

    # 오른쪽 패널: LIVE SQL + RESULT 틀, 도구함
    panel = a.crop((1078, 148, 1550, 712)).convert("RGB")
    ox, oy = 1078, 148
    pd = ImageDraw.Draw(panel)
    pd.rounded_rectangle((1096 - ox, 192 - oy, 1532 - ox, 414 - oy), 14, fill=(27, 33, 48))
    pd.rounded_rectangle((1146 - ox, 490 - oy, 1486 - ox, 648 - oy), 8, fill=(246, 234, 208))
    save(round_alpha(panel, 18), "panel_sql")
    tray = a.crop((1080, 724, 1550, 884)).convert("RGB")
    ImageDraw.Draw(tray).rounded_rectangle((16, 16, 454, 144), 12, fill=(184, 128, 76))
    save(round_alpha(tray, 18), "tool_tray")

    # 요약 서랍·계산 띠·토큰
    for i, (x0, x1) in enumerate([(194, 452), (484, 742), (774, 1032)]):
        box = (x0, 770, x1, 912)
        save(crop_clean(b, box, [(x0 + 42, 786, x1 - 42, 826)], 12), "summary_%d" % (i + 1))
    save(crop_clean(d, (228, 822, 322, 880), [(244, 832, 306, 868)], 12), "strip_cell")
    save(crop_clean(d, (534, 822, 630, 880), [(548, 832, 616, 868)], 12), "strip_null")
    save(crop_clean(d, (802, 814, 974, 886), [(828, 826, 950, 874)], 30), "token")

    # 색약 대응 무늬
    save(hatch((140, 100), (70, 70, 80, 120), 18), "pattern_null")
    save(hatch((140, 100), (255, 255, 255, 110), 26), "pattern_g2")
    save(dots((140, 100), (255, 255, 255, 120), 22), "pattern_g3")

    # 배경: 판·패널 자리를 비운 작업장
    regions = {
        "SQL01": [(95, 4, 1152, 134), (146, 134, 1558, 890)],
        "SQL02": [(430, 4, 1240, 96), (172, 96, 1562, 924)],
        "SQL03": [(568, 4, 1106, 132), (94, 132, 1654, 872)],
        "SQL04": [(590, 4, 1086, 112), (148, 112, 1568, 900)],
    }
    for k, im in src.items():
        clean_background(im, regions[k], floor_color(im, regions[k])).save(os.path.join(OUT, "bg_%s.png" % k.lower()))
    print("assets:", len(os.listdir(OUT)))


if __name__ == "__main__":
    main(sys.argv[1])
