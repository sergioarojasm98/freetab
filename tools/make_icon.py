"""Placeholder app icon: a white receipt with a check on a green gradient (1024x1024, no alpha).

Run from the repo root with Pillow installed: python tools/make_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

S = 1024
OUT = Path(__file__).resolve().parent.parent / "Freetab/Assets.xcassets/AppIcon.appiconset/icon-1024.png"


def main() -> None:
    img = Image.new("RGB", (S, S))
    top, bottom = (52, 211, 141), (16, 128, 92)
    for y in range(S):
        t = y / (S - 1)
        color = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
        ImageDraw.Draw(img).line([(0, y), (S, y)], fill=color)

    d = ImageDraw.Draw(img)
    # receipt body with a zigzag bottom edge
    left, right, ytop, ybot = 262, 762, 196, 812
    teeth = 8
    w = (right - left) / teeth
    outline = [(left, ytop), (right, ytop), (right, ybot)]
    for i in range(teeth, 0, -1):
        outline.append((left + (i - 0.5) * w, ybot - 44))
        outline.append((left + (i - 1) * w, ybot))
    d.polygon(outline, fill=(255, 255, 255))
    d.rounded_rectangle([left, ytop, right, ytop + 80], radius=36, fill=(255, 255, 255))
    # text lines
    line = (186, 226, 207)
    for i, length in enumerate([300, 220, 260]):
        y = 300 + i * 90
        d.rounded_rectangle([left + 70, y, left + 70 + length, y + 34], radius=17, fill=line)
    # check badge
    cx, cy, r = 652, 640, 96
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(16, 128, 92))
    d.line([(cx - 44, cy + 2), (cx - 10, cy + 38), (cx + 50, cy - 36)], fill=(255, 255, 255), width=30, joint="curve")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, optimize=True)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
