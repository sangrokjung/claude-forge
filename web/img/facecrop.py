#!/usr/bin/env python3
"""캐릭터의 눈(호박색 발광)을 찾아 그 주변을 정사각으로 크롭해 아바타를 만든다.

포즈마다 머리 위치가 달라서 고정 좌표로는 안 된다. 눈은 상반부에 있고
채도 높은 호박색이라 배경·갑옷과 확실히 구분된다.

usage: facecrop.py <in.png> <out.png> [size]
"""
import sys

from PIL import Image


def main():
    src, dst = sys.argv[1], sys.argv[2]
    out_size = int(sys.argv[3]) if len(sys.argv) > 3 else 128

    im = Image.open(src).convert("RGBA")
    w, h = im.size
    px = im.load()

    xs, ys, n = 0, 0, 0
    for y in range(0, int(h * 0.55), 2):          # 상반부만
        for x in range(0, w, 2):
            r, g, b, a = px[x, y]
            if a > 200 and r > 200 and 110 < g < 235 and b < 130:   # 호박색 발광
                xs += x
                ys += y
                n += 1

    if n < 20:
        cx, cy = w // 2, int(h * 0.18)
        print("  (눈 미검출 — 상단 중앙 폴백)")
    else:
        cx, cy = xs // n, ys // n

    side = int(w * 0.62)
    cy = int(cy + side * 0.06)                    # 눈보다 살짝 아래를 중심으로
    box = (cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2)

    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im.crop(box), (0, 0))
    canvas = canvas.resize((out_size, out_size), Image.LANCZOS)
    canvas.save(dst)
    print("%s → %s | 눈 픽셀 %d | 중심 (%d,%d) | %dpx" % (src, dst, n, cx, cy, out_size))


if __name__ == "__main__":
    main()
