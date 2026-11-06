# -*- coding: utf-8 -*-
"""스테이지 컨셉아트(stage/*.png) -> 배경 에셋 추출.

컨셉아트 위에 얹힌 HUD(제목/목표/정보 패널/조작 안내)와 플레이어 로봇을 지우고
주변과 가장 잘 이어지는 영역을 복사해 메우는 방식(패치 인페인팅)으로 순수 배경만 남긴다.

출력 (textures/stages/<STxx_name>/):
  bg_clean.png   원본 해상도(1672x941) HUD 제거 배경
  bg_pixel.png   427x240 도트(픽셀) 배경 (64색 팔레트) - 미니게임에서 x3 Nearest 확대 사용
  hud_mask.png   제거한 영역 마스크 (흰색)
  compare.png    원본 / 정리본 / 도트본 비교
"""
import glob, json, os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.signal import fftconvolve

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "reference", "stage_src")
OUT = os.path.join(ROOT, "textures/stages")

# 원본 좌표(1672x941) 기준 제거 영역: 제목, 목표, 정보 패널, 조작 안내, 로봇(+말풍선)
HUD = {
    "ST01": [(8, 6, 600, 86), (600, 6, 1040, 88), (1414, 106, 1666, 334), (8, 872, 594, 930), (800, 386, 898, 546)],
    "ST02": [(8, 4, 466, 92), (474, 10, 966, 90), (1426, 60, 1666, 340), (14, 860, 634, 928), (714, 500, 814, 672)],
    "ST03": [(8, 12, 440, 92), (560, 2, 1106, 90), (1380, 80, 1660, 326), (8, 872, 566, 934), (434, 134, 620, 340)],
    "ST04": [(8, 10, 446, 94), (566, 6, 1094, 94), (1366, 52, 1670, 660), (14, 872, 506, 934), (386, 506, 534, 640)],
    "ST05": [(8, 14, 674, 100), (1074, 14, 1660, 94), (14, 872, 540, 928), (894, 352, 1020, 534)],
    "ST06": [(8, 6, 440, 94), (446, 2, 966, 88), (14, 880, 594, 934), (740, 166, 828, 274)],
    "ST07": [(20, 14, 506, 98), (526, 10, 994, 90), (1366, 34, 1666, 300), (8, 866, 614, 928), (772, 400, 874, 568)],
    "ST08": [(8, 6, 494, 100), (614, 6, 1054, 88), (1326, 60, 1646, 274), (14, 880, 506, 934), (1012, 392, 1114, 534)],
    "ST09": [(8, 6, 406, 90), (534, 6, 1140, 84), (1334, 52, 1672, 748), (8, 872, 554, 928), (252, 540, 346, 654)],
    "ST10": [(8, 10, 434, 100), (554, 6, 1114, 88), (1434, 46, 1672, 588), (8, 872, 540, 928), (652, 412, 780, 554)],
}

TILE = 40
RING = 10
SEARCH = 360


def fill_tile(out, known, tile):
    """타일 주변 링(알려진 픽셀)과 가장 비슷한 이웃 패치를 FFT 기반 SSD 로 찾아 복사."""
    H, W = known.shape
    x0, y0, x1, y1 = tile
    rx0, ry0, rx1, ry1 = max(x0 - RING, 0), max(y0 - RING, 0), min(x1 + RING, W), min(y1 + RING, H)
    ph, pw = ry1 - ry0, rx1 - rx0
    M = known[ry0:ry1, rx0:rx1].astype(np.float32)
    T = out[ry0:ry1, rx0:rx1]
    wx0, wy0 = max(rx0 - SEARCH, 0), max(ry0 - SEARCH, 0)
    wx1, wy1 = min(rx1 + SEARCH, W), min(ry1 + SEARCH, H)
    S = out[wy0:wy1, wx0:wx1]
    ssd = 0
    Mf = M[::-1, ::-1]
    for c in range(3):
        t = T[..., c]
        ssd = ssd + fftconvolve(S[..., c] ** 2, Mf, "valid") - 2 * fftconvolve(S[..., c], (M * t)[::-1, ::-1], "valid") + (M * t * t).sum()
    unk = (~known[wy0:wy1, wx0:wx1]).astype(np.int64)
    sat = np.pad(unk.cumsum(0).cumsum(1), ((1, 0), (1, 0)))
    cnt = sat[ph:, pw:] - sat[:-ph, pw:] - sat[ph:, :-pw] + sat[:-ph, :-pw]
    ssd = np.where(cnt == 0, ssd, np.inf)
    if not np.isfinite(ssd).any():
        return False
    iy, ix = np.unravel_index(np.argmin(ssd), ssd.shape)
    sy, sx = wy0 + iy, wx0 + ix
    src = out[sy:sy + ph, sx:sx + pw]
    ty0, tx0 = y0 - ry0, x0 - rx0
    region = ~known[y0:y1, x0:x1]
    patch = src[ty0:ty0 + (y1 - y0), tx0:tx0 + (x1 - x0)]
    out[y0:y1, x0:x1][region] = patch[region]
    known[y0:y1, x0:x1] = True
    return True


def inpaint(img, rects):
    out = img.astype(np.float32)
    H, W = out.shape[:2]
    known = np.ones((H, W), bool)
    tiles = []
    for (x0, y0, x1, y1) in rects:
        known[y0:y1, x0:x1] = False
        for ty in range(y0, y1, TILE):
            for tx in range(x0, x1, TILE):
                tiles.append((tx, ty, min(tx + TILE, x1), min(ty + TILE, y1)))
    while tiles:
        # 주변이 가장 많이 알려진 타일부터 (바깥에서 안쪽으로)
        def score(t):
            x0, y0, x1, y1 = t
            return known[max(y0 - RING, 0):y1 + RING, max(x0 - RING, 0):x1 + RING].mean()
        tiles.sort(key=score)
        t = tiles.pop()
        fill_tile(out, known, t)
    return out.clip(0, 255).astype(np.uint8)

def pixelate(im, size=(427, 240), colors=64):
    small = im.resize(size, Image.Resampling.BOX)
    q = small.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return q.convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    meta = []
    for f in sorted(glob.glob(os.path.join(SRC, "ST*.png"))):
        base = os.path.splitext(os.path.basename(f))[0]
        sid = base[:4]
        od = os.path.join(OUT, sid)
        os.makedirs(od, exist_ok=True)
        im = Image.open(f).convert("RGB")
        rects = HUD[sid]
        clean = Image.fromarray(inpaint(np.array(im), rects))
        clean.save(os.path.join(od, "bg_clean.png"))
        pix = pixelate(clean)
        pix.save(os.path.join(od, "bg_pixel.png"))
        mask = Image.new("L", im.size, 0)
        d = ImageDraw.Draw(mask)
        for r in rects:
            d.rectangle(r, fill=255)
        mask.save(os.path.join(od, "hud_mask.png"))
        cw = 560
        ch = round(cw * im.height / im.width)
        comp = Image.new("RGB", (cw * 3 + 40, ch + 20), (30, 30, 36))
        comp.paste(im.resize((cw, ch)), (10, 10))
        comp.paste(clean.resize((cw, ch)), (cw + 20, 10))
        comp.paste(pix.resize((cw, ch), Image.Resampling.NEAREST), (cw * 2 + 30, 10))
        comp.save(os.path.join(od, "compare.png"))
        parts = base.split("_")
        meta.append({"id": sid, "source": os.path.basename(f), "title": parts[-1],
                     "topic": "_".join(parts[1:-1]), "removed_rects": rects})
        print(sid, "done")
    with open(os.path.join(OUT, "textures/stages.json"), "w", encoding="utf-8") as fp:
        json.dump(meta, fp, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
