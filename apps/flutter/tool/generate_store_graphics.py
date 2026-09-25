#!/usr/bin/env python3
"""Draws the store listing images from the app icon.

    python3 tool/generate_store_graphics.py

Run after tool/generate_app_icon.py. Writes, relative to the repo root:
  fastlane/metadata/android/en-US/images/icon.png            512², both stores
  fastlane/metadata/android/en-US/images/featureGraphic.png  1024x500, Google Play
"""

import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

APP = Path(__file__).resolve().parent.parent  # apps/flutter
ROOT = APP.parent.parent
ICON = APP / "assets" / "icon" / "app_icon.png"
OUT = ROOT / "fastlane" / "metadata" / "android" / "en-US" / "images"

WHITE = (255, 255, 255)
MUTED = (161, 161, 166)  # AppColors.mutedForeground


def font(bold, size):
    """Roboto from the Flutter SDK's cache, else Pillow's built-in font."""
    flutter = shutil.which("flutter")
    if flutter:
        fonts = Path(flutter).resolve().parent / "cache" / "artifacts" / "material_fonts"
        f = fonts / ("Roboto-Bold.ttf" if bold else "Roboto-Regular.ttf")
        if f.exists():
            return ImageFont.truetype(str(f), size)
    return ImageFont.load_default(size)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    icon = Image.open(ICON).convert("RGB")

    icon.resize((512, 512), Image.LANCZOS).save(OUT / "icon.png")

    # Feature graphic: icon on the left, name and tagline beside it, on black.
    fg = Image.new("RGB", (1024, 500), (0, 0, 0))
    fg.paste(icon.resize((360, 360), Image.LANCZOS), (70, 70))
    d = ImageDraw.Draw(fg)
    d.text((470, 175), "Linkstow", font=font(True, 96), fill=WHITE)
    d.text((474, 295), "a client for your Karakeep server", font=font(False, 34),
           fill=MUTED)
    fg.save(OUT / "featureGraphic.png")
    print(f"wrote {OUT}/icon.png and featureGraphic.png")


if __name__ == "__main__":
    main()
