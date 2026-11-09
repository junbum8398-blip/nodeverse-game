# -*- coding: utf-8 -*-
"""컨셉아트에서 게임용 스프라이트 잘라내기.

- 플레이어 로봇 (ST02 원화의 로봇): 무채색(흰/회색) 영역 + 내부 구멍 채우기로 배경 분리
- 걷기/대기 프레임은 Godot 에서 AnimationPlayer(기울기·통통 튀기)로 만든다.
출력: textures/sprites/robot.png
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "textures", "sprites")


def cut_robot():
    src = os.path.join(ROOT, "reference", "stage_src", "ST02_linked_list_끊어진 운송로.png")
    im = Image.open(src).convert("RGB").crop((716, 528, 816, 690))
    a = np.asarray(im).astype(np.float32) / 255.0
    mx, mn = a.max(axis=2), a.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    g = a[..., 1]
    white = (sat < 0.16) & (mx > 0.36)
    green = (g > 0.55) & (a[..., 0] < 0.5) & (a[..., 2] < 0.5)
    dark = mx < 0.22
    m = white
    m = ndimage.binary_closing(m, iterations=3)
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    m = lab == (1 + int(np.argmax(sizes)))
    m = ndimage.binary_fill_holes(m)
    # 몸 경계에 붙은 검은 관절(손·발)
    near = ndimage.binary_dilation(m, iterations=4)
    m = m | (dark & near)
    m = ndimage.binary_fill_holes(ndimage.binary_closing(m, iterations=1))
    m = ndimage.binary_opening(m, iterations=1)
    rgba = np.dstack([np.asarray(im), (m * 255).astype(np.uint8)])
    out = Image.fromarray(rgba, "RGBA")
    out = out.crop(out.getbbox())
    # 오른쪽 아래 바닥 돌 조각 제거
    arr = np.array(out)
    arr[112:, 68:, 3] = 0
    out = Image.fromarray(arr, "RGBA")
    out = out.crop(out.getbbox())
    os.makedirs(OUT, exist_ok=True)
    out.save(os.path.join(OUT, "robot.png"))
    prev = Image.new("RGBA", out.size, (255, 0, 255, 255))
    prev.alpha_composite(out)
    return prev


def cut_crate():
    """ST01 원화의 '10' 상자 -> 숫자를 지운 빈 상자 (숫자는 Godot Label 로 표시)."""
    src = os.path.join(ROOT, "reference", "stage_src", "ST01_array_순서가 있는 보관소.png")
    im = Image.open(src).convert("RGB").crop((416, 352, 536, 480))
    a = np.asarray(im).astype(np.float32) / 255.0
    mx, mn = a.max(axis=2), a.min(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    wood = (sat > 0.32) & (mx > 0.25) & (a[..., 0] > a[..., 2])
    m = ndimage.binary_closing(wood, iterations=2)
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    m = lab == (1 + int(np.argmax(sizes)))
    m = ndimage.binary_fill_holes(m)
    m = ndimage.binary_opening(m, iterations=2)
    arr = np.asarray(im).copy()
    # 명판 안 숫자 지우기: 명판 테두리 안쪽 색의 중앙값으로 칠하고 약간의 질감
    plate = arr[60:102, 26:86].reshape(-1, 3)
    light = plate[plate.mean(axis=1) > 170]
    base = np.median(light, axis=0)
    yy, xx = np.mgrid[64:98, 30:82]
    shade = 1.0 - (yy - 64) / 34.0 * 0.06
    arr[64:98, 30:82] = (base[None, None, :] * shade[..., None]).clip(0, 255).astype(np.uint8)
    rgba = np.dstack([arr, (m * 255).astype(np.uint8)])
    out = Image.fromarray(rgba, "RGBA")
    out = out.crop(out.getbbox())
    out.save(os.path.join(OUT, "crate.png"))
    prev = Image.new("RGBA", out.size, (255, 0, 255, 255))
    prev.alpha_composite(out)
    prev.resize((out.width * 4, out.height * 4), Image.NEAREST).save(os.path.join(OUT, "_crate_preview.png"))
    print("crate", out.size)


if __name__ == "__main__":
    cut_crate()
    p = cut_robot()
    p.resize((p.width * 4, p.height * 4), Image.NEAREST).save(os.path.join(OUT, "_robot_preview.png"))
    print("robot", p.size)
