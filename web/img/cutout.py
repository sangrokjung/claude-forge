#!/usr/bin/env python3
"""생성 이미지의 가짜 '투명' 체커보드 배경을 실제 알파로 바꾼다.

gpt-image-2는 투명 배경을 지원하지 않아서, 요청하면 체커보드 무늬를 그림으로 그려 넣는다.
그 무늬는 밝고 무채색인 두 회색뿐이고 캐릭터는 어둡거나 채도가 높으므로,
가장자리에서 flood fill로 이어진 영역만 지우면 캐릭터 내부의 밝은 하이라이트는 살아남는다.

usage: cutout.py <in.png> <out.png> [--trim] [--pad N]
"""
import sys
from collections import deque

from PIL import Image, ImageFilter

LIGHT_MIN = 222      # 배경으로 볼 최소 밝기
NEUTRAL_MAX = 12     # 채널 간 최대 편차 (무채색 판정)


def is_bg(p):
    r, g, b = p[0], p[1], p[2]
    return min(r, g, b) >= LIGHT_MIN and (max(r, g, b) - min(r, g, b)) <= NEUTRAL_MAX


def main():
    src, dst = sys.argv[1], sys.argv[2]
    trim = "--trim" in sys.argv
    pad = 0
    if "--pad" in sys.argv:
        pad = int(sys.argv[sys.argv.index("--pad") + 1])

    im = Image.open(src).convert("RGB")
    w, h = im.size
    px = im.load()

    bg = bytearray(w * h)          # 1 = 배경
    seen = bytearray(w * h)
    q = deque()

    for x in range(w):
        for y in (0, h - 1):
            i = y * w + x
            if not seen[i] and is_bg(px[x, y]):
                seen[i] = 1
                bg[i] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            i = y * w + x
            if not seen[i] and is_bg(px[x, y]):
                seen[i] = 1
                bg[i] = 1
                q.append((x, y))

    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                j = ny * w + nx
                if not seen[j]:
                    seen[j] = 1
                    if is_bg(px[nx, ny]):
                        bg[j] = 1
                        q.append((nx, ny))

    alpha = Image.frombytes("L", (w, h), bytes(255 if not v else 0 for v in bg))
    # 계단현상 완화: 알파만 살짝 흐린 뒤 재대비
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.7)).point(
        lambda v: 0 if v < 60 else (255 if v > 200 else int((v - 60) * 255 / 140)))

    out = im.convert("RGBA")
    out.putalpha(alpha)

    if trim:
        box = out.getbbox()
        if box:
            if pad:
                box = (max(0, box[0] - pad), max(0, box[1] - pad),
                       min(w, box[2] + pad), min(h, box[3] + pad))
            out = out.crop(box)

    out.save(dst)
    removed = sum(bg)
    print("%s → %s | %dx%d | 배경 제거 %.1f%%" %
          (src, dst, out.size[0], out.size[1], removed / (w * h) * 100))


if __name__ == "__main__":
    main()
