#!/usr/bin/env python3
"""Draws Linkstow's launcher icon: two bookmark ribbons on black.

Karakeep's own icon is their brand mark, so Linkstow uses its own design in the
same spirit (white on black, bookmark shapes). Re-run after changing it, then
`dart run flutter_launcher_icons`.

    python3 tool/generate_app_icon.py

Writes, relative to apps/flutter:
  assets/icon/app_icon.png             1024², black background (iOS, legacy)
  assets/icon/app_icon_foreground.png  1024², transparent, inside Android's
                                       adaptive-icon safe zone
"""

from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
SUPERSAMPLE = 4  # draw big, scale down: smooth edges
BLACK = (0, 0, 0, 255)
WHITE = (255, 255, 255, 255)
GREY = (72, 72, 78, 255)
BLUE = (3, 133, 255, 255)  # AppColors.primary

OUT = Path(__file__).resolve().parent.parent / "assets" / "icon"


def ribbon(draw, x, y, w, h, fill, radius, notch):
    """A bookmark: rounded top corners, V cut into the bottom edge."""
    draw.rounded_rectangle((x, y, x + w, y + h), radius=radius, fill=fill)
    # Square off the bottom corners, then cut the notch.
    draw.rectangle((x, y + h - radius, x + w, y + h), fill=fill)
    draw.polygon(
        [(x, y + h + 1), (x + w / 2, y + h - notch), (x + w, y + h + 1)],
        fill=(0, 0, 0, 0),
    )


def glyph(size, scale):
    """The two ribbons, scaled by [scale] around the centre."""
    s = size * SUPERSAMPLE
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = s * scale / 100 / 100  # glyph box = scale% of canvas, 100 units wide
    ox = (s - 100 * u) / 2
    oy = (s - 100 * u) / 2

    # Back ribbon: grey, up and to the right.
    ribbon(d, ox + 38 * u, oy + 4 * u, 44 * u, 76 * u, GREY, 9 * u, 15 * u)
    # Front ribbon: white, the main mark.
    ribbon(d, ox + 18 * u, oy + 18 * u, 46 * u, 78 * u, WHITE, 9 * u, 16 * u)
    # A blue dot: the app's accent, as a "saved" marker.
    r = 6 * u
    cx, cy = ox + 41 * u, oy + 42 * u
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=BLUE)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)

    # Full icon: glyph fills ~62% of a black square.
    full = Image.new("RGBA", (SIZE * SUPERSAMPLE,) * 2, BLACK)
    full.alpha_composite(glyph(SIZE, 62))
    full.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB").save(
        OUT / "app_icon.png"
    )

    # Adaptive foreground: launchers crop to the centre 66%, so keep the
    # glyph within ~56% of the canvas (its corners stay inside the circle).
    fg = glyph(SIZE, 56)
    fg.resize((SIZE, SIZE), Image.LANCZOS).save(OUT / "app_icon_foreground.png")
    print(f"wrote {OUT}/app_icon.png and app_icon_foreground.png")


if __name__ == "__main__":
    main()
