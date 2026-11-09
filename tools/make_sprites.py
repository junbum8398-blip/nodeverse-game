# -*- coding: utf-8 -*-
"""걸어 다니는 스테이지가 쓰는 스프라이트를 코드로 그린다 (6배 슈퍼샘플 후 축소).

  textures/sprites/crate.png   파란 강철 상자. 진한 외곽선 + 밝은 테두리로 따뜻한 색 배경과 분리된다.
  textures/sprites/token.png   반짝이는 블록. 흰색 기준이라 Godot 에서 modulate 로 색을 입힌다.
  textures/npc_portraits/NPCxx_world.png   SD 원화에서 만든 맵 위 NPC (높이 150px)

실행: python tools/make_sprites.py
"""
import glob
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "textures", "sprites")
NPC_SRC = os.path.join(ROOT, "reference", "npc_v2_art")
NPC_OUT = os.path.join(ROOT, "textures", "npc_portraits")
SS = 6
INK = (29, 27, 42, 255)


def pts(lst):
    return [(x * SS, y * SS) for x, y in lst]


def finish(layer, w, h, halo=(255, 255, 255, 235), halo_px=3):
    """외곽선 바깥에 밝은 테두리를 둘러 어떤 배경에서도 형태가 또렷하게 한다."""
    img = layer.resize((w, h), Image.LANCZOS)
    a = img.getchannel("A")
    grown = a.filter(ImageFilter.MaxFilter(halo_px * 2 + 1)).filter(ImageFilter.GaussianBlur(0.7))
    out = Image.new("RGBA", (w, h), halo[:3] + (0,))
    out.putalpha(grown.point(lambda v: min(v, halo[3])))
    out.alpha_composite(img)
    return out


def crate():
    W, H = 240, 256
    im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # 면: 윗면, 앞면, 오른쪽 옆면
    top = [(40, 22), (190, 22), (222, 76), (14, 76)]
    front = [(14, 76), (196, 76), (196, 244), (14, 244)]
    side = [(196, 76), (222, 76), (226, 214), (196, 244)]
    sil = [(40, 22), (190, 22), (222, 76), (226, 214), (196, 244), (14, 244), (14, 76)]
    d.polygon(pts(sil), fill=INK, outline=INK)
    d.line(pts(sil + [sil[0]]), fill=INK, width=14 * SS // 2, joint="curve")
    d.polygon(pts(top), fill=(107, 170, 248, 255))
    d.polygon(pts(front), fill=(44, 106, 214, 255))
    d.polygon(pts(side), fill=(27, 67, 150, 255))
    # 윗면 판자
    for t in (0.34, 0.67):
        xa = 40 + (14 - 40) * t
        d.line(pts([(xa + 8, 22 + 54 * t), (190 + 32 * t - 8, 22 + 54 * t)]), fill=(70, 128, 214, 255), width=3 * SS)
    d.polygon(pts([(48, 26), (182, 26), (190, 38), (42, 38)]), fill=(170, 212, 255, 255))
    # 앞면 판자 줄무늬와 음영
    for y in (118, 160, 202):
        d.line(pts([(30, y), (182, y)]), fill=(29, 78, 170, 255), width=3 * SS)
    d.rectangle(pts([(14, 76), (196, 86)]), fill=(92, 152, 240, 255))
    # 금색 틀과 모서리 보강
    gold, gold_d, gold_l = (247, 196, 72, 255), (176, 118, 28, 255), (255, 232, 150, 255)
    for x0, x1 in ((14, 40), (170, 196)):
        d.rectangle(pts([(x0, 76), (x1, 244)]), fill=gold)
        d.rectangle(pts([(x0, 76), (x0 + 5, 244)]), fill=gold_l)
        d.rectangle(pts([(x1 - 4, 76), (x1, 244)]), fill=gold_d)
    for y0, y1 in ((76, 100), (220, 244)):
        d.rectangle(pts([(14, y0), (196, y1)]), fill=gold)
        d.rectangle(pts([(14, y0), (196, y0 + 5)]), fill=gold_l)
        d.rectangle(pts([(14, y1 - 4), (196, y1)]), fill=gold_d)
    d.polygon(pts([(196, 76), (222, 76), (223, 100), (196, 100)]), fill=gold_d)
    d.polygon(pts([(196, 220), (225, 192), (226, 214), (196, 244)]), fill=gold_d)
    d.polygon(pts([(40, 22), (190, 22), (196, 32), (34, 32)]), fill=gold)
    # 금속 리벳
    for cx, cy in ((27, 88), (183, 88), (27, 232), (183, 232)):
        d.ellipse(pts([(cx - 7, cy - 7), (cx + 7, cy + 7)]), fill=(120, 80, 22, 255))
        d.ellipse(pts([(cx - 5, cy - 6), (cx + 4, cy + 3)]), fill=(255, 240, 190, 255))
    # 숫자 명판
    plate = [(50, 110), (160, 110), (160, 210), (50, 210)]
    d.polygon(pts([(x + 3, y + 4) for x, y in plate]), fill=(16, 40, 96, 255))
    d.rectangle(pts([(50, 110), (160, 210)]), fill=INK)
    d.rectangle(pts([(56, 116), (154, 204)]), fill=(255, 246, 222, 255))
    d.rectangle(pts([(56, 192), (154, 204)]), fill=(233, 214, 174, 255))
    # 외곽선 다시 긋기
    d.line(pts(sil + [sil[0]]), fill=INK, width=8 * SS, joint="curve")
    d.line(pts([(14, 76), (222, 76)]), fill=INK, width=3 * SS)
    d.line(pts([(196, 76), (196, 244)]), fill=INK, width=3 * SS)
    # 위가 밝고 아래가 어두운 빛, 판자 결 노이즈 (명판은 깨끗하게 유지)
    arr = np.array(im, dtype=np.float32)
    h, w = arr.shape[:2]
    light = np.linspace(1.14, 0.84, h)[:, None]
    rng = np.random.default_rng(3)
    noise = (rng.random((h // 24, w // 12)) * 255).astype(np.uint8)
    grain = np.array(Image.fromarray(noise).resize((w, h), Image.BICUBIC), dtype=np.float32) / 255
    shade = light * (0.94 + grain * 0.12)
    plate = (arr[..., 0] > 215) & (arr[..., 2] > 150)
    arr[..., :3] = np.where(plate[..., None], arr[..., :3], arr[..., :3] * shade[..., None]).clip(0, 255)
    im = Image.fromarray(arr.astype(np.uint8), "RGBA")
    out = finish(im, W, H, halo=(255, 255, 255, 215), halo_px=2)
    out.save(os.path.join(OUT, "crate.png"))
    prev = Image.new("RGBA", (W, H), (214, 170, 120, 255))
    prev.alpha_composite(out)
    prev.save(os.path.join(OUT, "_crate_preview.png"))


def token():
    W, H = 200, 176
    im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    body = (16, 30, 184, 150)
    x0, y0, x1, y1 = [v * SS for v in body]
    r = 26 * SS
    d.rounded_rectangle((x0 - 4 * SS, y0 - 4 * SS, x1 + 4 * SS, y1 + 22 * SS), r + 4 * SS, fill=INK)
    d.rounded_rectangle((x0, y0 + 14 * SS, x1, y1 + 18 * SS), r, fill=(150, 150, 150, 255))
    d.rounded_rectangle((x0, y0, x1, y1), r, fill=(255, 255, 255, 255))
    d.rounded_rectangle((x0 + 14 * SS, y0 + 8 * SS, x1 - 14 * SS, y0 + 30 * SS), 11 * SS, fill=(255, 255, 255, 255))
    arr = np.array(im, dtype=np.float32)
    # 위쪽 밝고 아래쪽 약간 어두운 음영 (색은 modulate 로 입힌다)
    yy = np.linspace(1.0, 0.76, arr.shape[0])[:, None]
    mask = arr[..., 0] > 200
    arr[..., :3][mask] = (arr[..., :3] * yy[..., None])[mask]
    im = Image.fromarray(arr.astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((x0 + 16 * SS, y0 + 10 * SS, x1 - 16 * SS, y0 + 24 * SS), 7 * SS, fill=(255, 255, 255, 255))
    out = finish(im, W, H, halo=(255, 255, 255, 160), halo_px=2)
    out.save(os.path.join(OUT, "token.png"))


def npcs():
    for f in sorted(glob.glob(os.path.join(NPC_SRC, "NPC0*.png"))):
        nid = os.path.basename(f)[:5]
        if nid == "NPC01":
            continue   # ST01 이 쓰는 기존 스프라이트 유지
        im = Image.open(f).convert("RGBA")
        im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox())
        h = 150
        w = max(1, round(im.width * h / im.height))
        im.resize((w, h), Image.LANCZOS).save(os.path.join(NPC_OUT, f"{nid}_world.png"))
        print(nid, (w, h))


if __name__ == "__main__":
    crate()
    token()
    npcs()
