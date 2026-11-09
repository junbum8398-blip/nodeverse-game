# -*- coding: utf-8 -*-
"""배경(bg_clean.png)에서 '게임이 직접 그릴 움직이는 물건'(상자, 노드 등)을 지워 게임판용 배경을 만든다.

bg_clean.png 은 순수 추출 배경으로 그대로 두고,
  bg_game.png   게임판용 원본 해상도 배경
  bg_pixel.png  bg_game.png 의 도트 버전 (게임에서 사용)
을 만든다. 실행: python tools/make_game_backgrounds.py [ST01 ...]
"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_stage_backgrounds import inpaint, pixelate, OUT  # noqa: E402

# ("copy", (x0, y0, x1, y1), dx, dy): 원본 좌표 영역을 (dx, dy) 만큼 옮긴 곳에 복사
# ("copy_scaled", 원본 사각형, 대상 사각형): 크기를 맞춰 복사
# ("inpaint", (x0, y0, x1, y1)): 주변 패치로 메우기
# ("erase_dark" / "erase_light", 사각형, 밝기 기준): 글자처럼 어둡거나 밝은 픽셀만 주변 색으로 지우기
# ("erase_rect", 사각형): 사각형 전체를 테두리 색으로 부드럽게 메우기 (양피지 안쪽 등)
# ("socket", 사각형): 토큰이 빠진 자리에 어두운 빈 홈을 그리기
# ("niche", 다각형, 질감 사각형, 어둡기): 다각형을 질감으로 채우기 (선반 안쪽 벽 등)
# ("recolor", 사각형, RGB): 밝은 픽셀을 지정한 색 평균으로 맞추기
CRATES_ST08 = [(755, 100, 848, 196), (570, 240, 665, 336), (938, 240, 1032, 336), (438, 408, 532, 502), (664, 408, 760, 502)]


def _st08_ops():
    # 받침대의 상자는 게임 상자가 그대로 덮으므로 두고, 컨베이어 위 상자와 E 표시만 지운다.
    return [
        ("inpaint_keep", [(868, 395, 945, 462), (985, 425, 1125, 535), (1204, 400, 1316, 492)], CRATES_ST08),
    ] + [("erase_dark", (x - 27, 606, x + 27, 660), 105) for x in (540, 617, 687, 762, 840)]


PREP = {
    "ST01": [
        # 빈 칸(3번) 모습을 0~2번 칸에 복사해 고정 상자 10/30/40 제거
        ("copy", (896, 330, 1044, 506), -165, 0),
        ("copy", (896, 330, 1044, 506), -330, 0),
        ("copy", (896, 330, 1044, 506), -495, 0),
        # 입고 트레이 위 상자 20 제거
        ("inpaint", (606, 574, 724, 694)),
    ],
    "ST02": [("erase_dark", (118, 160, 186, 226), 95)],
    "ST03": [
        # 탑 안의 상자 A, B, C 를 지워 빈 선반으로 (상자는 게임이 그린다)
        ("niche", [(344, 262), (432, 258), (432, 346), (344, 368)], (446, 424, 490, 500), 0.5),
        ("niche", [(344, 374), (432, 366), (432, 456), (344, 474)], (446, 424, 490, 500), 0.5),
        ("niche", [(344, 478), (432, 470), (432, 574), (344, 590)], (446, 424, 490, 500), 0.5),
        ("niche", [(436, 262), (510, 262), (512, 334), (436, 346)], (446, 424, 490, 500), 0.5),
    ],
    "ST04": [
        ("socket", (482, 432, 562, 508)),
        ("socket", (690, 432, 770, 508)),
        ("socket", (900, 432, 980, 508)),
        ("socket", (1082, 430, 1162, 500)),
        ("inpaint", (424, 500, 482, 556)),
        ("erase_light", (640, 362, 950, 402), 150),
    ],
    "ST05": [
        ("copy", (580, 296, 700, 496), 295, 0),
        ("copy", (535, 296, 574, 496), 125, 0),
        ("copy_scaled", (582, 296, 694, 494), (696, 296, 876, 494)),
        ("copy", (560, 296, 592, 496), 430, 0),
        ("recolor", (748, 268, 824, 298), (243, 224, 182)),
        ("erase_rect", (1426, 226, 1616, 414)),
    ],
    "ST07": [
        ("inpaint", (772, 496, 880, 566)),
        ("erase_dark", (878, 176, 966, 250), 110),
        ("erase_dark", (632, 322, 716, 396), 110),
        ("erase_dark", (1122, 326, 1208, 400), 110),
        ("erase_dark", (448, 504, 532, 578), 110),
        ("erase_dark", (776, 546, 860, 620), 110),
        ("erase_dark", (1018, 504, 1104, 578), 110),
        ("erase_dark", (1306, 520, 1402, 600), 155),
        ("erase_light", (124, 556, 268, 590), 150),
    ],
    "ST06": [],
    "ST08": _st08_ops(),
    "ST09": [
        ("inpaint", (476, 702, 548, 736)),
        ("copy", (602, 734, 672, 782), -122, 0),
    ],
    "ST10": [],
}


def laplace_fill(img, mask, iters=900):
    """mask 영역을 주변 색으로 매끄럽게 메운다 (글자 지우기용)."""
    out = img.astype(np.float32)
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return img
    y0, y1, x0, x1 = max(ys.min() - 3, 0), ys.max() + 4, max(xs.min() - 3, 0), xs.max() + 4
    win = out[y0:y1, x0:x1]
    m = mask[y0:y1, x0:x1]
    # 시작값은 가장 가까운 알려진 픽셀
    idx = ndimage.distance_transform_edt(m, return_distances=False, return_indices=True)
    win[m] = win[idx[0][m], idx[1][m]]
    k = np.array([[0, 1, 0], [1, 0, 1], [0, 1, 0]], dtype=np.float32) / 4
    for _ in range(iters):
        for c in range(3):
            ch = win[..., c]
            ch[m] = ndimage.convolve(ch, k, mode="nearest")[m]
    win[m] += np.random.default_rng(7).normal(0, 1.2, (int(m.sum()), 3))
    out[y0:y1, x0:x1] = win
    return out.clip(0, 255).astype(np.uint8)


def luma(img):
    return img[..., 0] * 0.3 + img[..., 1] * 0.59 + img[..., 2] * 0.11


def rect_mask(shape, rect):
    m = np.zeros(shape[:2], bool)
    x0, y0, x1, y1 = rect
    m[y0:y1, x0:x1] = True
    return m


def paint_socket(img, rect):
    x0, y0, x1, y1 = rect
    S = 4
    w, h = x1 - x0, y1 - y0
    layer = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle((0, 0, w * S - 1, h * S - 1), 14 * S, fill=(150, 112, 44, 255))
    d.rounded_rectangle((5 * S, 5 * S, (w - 5) * S, (h - 5) * S), 10 * S, fill=(36, 42, 62, 255))
    d.rounded_rectangle((10 * S, 9 * S, (w - 10) * S, (h - 22) * S), 7 * S, fill=(54, 62, 88, 255))
    layer = layer.resize((w, h), Image.LANCZOS)
    base = Image.fromarray(img).convert("RGBA")
    base.alpha_composite(layer, (x0, y0))
    return np.array(base.convert("RGB"))


def paint_niche(img, poly, tex_rect, dark):
    tx0, ty0, tx1, ty1 = tex_rect
    h, w = img.shape[:2]
    mim = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mim).polygon(poly, fill=255)
    alpha = np.array(mim.filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32)[..., None] / 255
    tex = img[ty0:ty1, tx0:tx1].astype(np.float32)
    ry = np.arange(h) % (2 * tex.shape[0])
    ry = np.where(ry < tex.shape[0], ry, 2 * tex.shape[0] - 1 - ry)
    rx = np.arange(w) % (2 * tex.shape[1])
    rx = np.where(rx < tex.shape[1], rx, 2 * tex.shape[1] - 1 - rx)
    fill = tex[ry[:, None], rx[None, :]] * dark
    return (img * (1 - alpha) + fill * alpha).clip(0, 255).astype(np.uint8)


def apply_op(img, op):
    kind = op[0]
    if kind == "copy":
        (x0, y0, x1, y1), dx, dy = op[1], op[2], op[3]
        img[y0 + dy:y1 + dy, x0 + dx:x1 + dx] = img[y0:y1, x0:x1].copy()
    elif kind == "copy_scaled":
        x0, y0, x1, y1 = op[1]
        a0, b0, a1, b1 = op[2]
        patch = Image.fromarray(img[y0:y1, x0:x1]).resize((a1 - a0, b1 - b0), Image.LANCZOS)
        img[b0:b1, a0:a1] = np.array(patch)
    elif kind == "inpaint":
        img = inpaint(img, [op[1]])
    elif kind == "inpaint_keep":
        orig = img.copy()
        img = inpaint(img, list(op[1]) + list(op[2]))
        for x0, y0, x1, y1 in op[2]:
            img[y0:y1, x0:x1] = orig[y0:y1, x0:x1]
    elif kind in ("erase_dark", "erase_light"):
        rm = rect_mask(img.shape, op[1])
        hit = luma(img) < op[2] if kind == "erase_dark" else luma(img) > op[2]
        m = ndimage.binary_dilation(rm & hit, iterations=3) & rm
        img = laplace_fill(img, m)
    elif kind == "erase_rect":
        img = laplace_fill(img, rect_mask(img.shape, op[1]))
    elif kind == "socket":
        img = paint_socket(img, op[1])
    elif kind == "niche":
        img = paint_niche(img, op[1], op[2], op[3])
    elif kind == "recolor":
        x0, y0, x1, y1 = op[1]
        win = img[y0:y1, x0:x1].astype(np.float32)
        bright = luma(win) > 150
        ratio = np.array(op[2], dtype=np.float32) / np.maximum(win[bright].mean(axis=0), 1)
        win[bright] = (win[bright] * ratio).clip(0, 255)
        img[y0:y1, x0:x1] = win.astype(np.uint8)
    return img


def main(ids):
    for sid in ids:
        src = os.path.join(OUT, sid, "bg_clean.png")
        img = np.array(Image.open(src).convert("RGB"))
        for op in PREP.get(sid, []):
            img = apply_op(img, op)
        game = Image.fromarray(img)
        game.save(os.path.join(OUT, sid, "bg_game.png"))
        pixelate(game).save(os.path.join(OUT, sid, "bg_pixel.png"))
        print(sid, "game background done")


if __name__ == "__main__":
    main(sys.argv[1:] or sorted(PREP.keys()))
