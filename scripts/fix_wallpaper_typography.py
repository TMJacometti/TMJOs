"""Patch the Nano Banana wallpaper output to remove the spurious 's' character.

Nano Banana renders the central word as "TMJOSs" (6 chars) instead of the
intended "TMJOs" (5 chars). Since the logo asset already reads "TMJOS"
(5 uppercase letters), we standardize on "TMJOS" by erasing the trailing
lowercase 's' from the wallpaper.

Strategy: copy a clean strip from immediately above the text region and
paste it over the location of the 's', then feather the edges so the
join blends with the surrounding background (dragons + hex grid).
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/wallpapers/tmjos_walpapper.png"
DST = ROOT / "assets/wallpapers/tmjos_wallpaper.png"


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    W, H = img.size
    print(f"Loaded {SRC.name}: {W}x{H}")

    # Manual coords (1344x768 wallpaper from Nano Banana). Visual inspection
    # places the central "TMJOSs" typography at roughly y=270–500.
    # The trailing lowercase 's' sits at the right end of "TMJOS",
    # smaller than the capitals, occupying ~75–95% width and the lower
    # half of the typography band.
    # Tighter box: only the actual lowercase 's' glyph area + glow halo.
    # The lowercase s is smaller than caps, so it doesn't span the full
    # cap-height — only the x-height range (~middle vertical zone).
    s_x1 = int(W * 0.760)   # ~1021 px — starts right after capital S
    s_x2 = int(W * 0.940)   # ~1263 px — well past the lowercase s
    s_y1 = int(H * 0.435)   # ~334 px — covers full glyph height + glow
    s_y2 = int(H * 0.680)   # ~522 px
    print(f"Patching 's' glyph at box ({s_x1},{s_y1})–({s_x2},{s_y2})")

    band_w = s_x2 - s_x1
    band_h = s_y2 - s_y1

    # Sample the actual canvas dark color from a clean spot (top-center
    # is below the floating windows but above the dragons), so the patch
    # blends with the genuine wallpaper tone instead of being pure black.
    sample_x = W // 2
    sample_y = int(H * 0.10)
    bg_pixel = img.getpixel((sample_x, sample_y))
    if isinstance(bg_pixel, int):
        bg_pixel = (bg_pixel, bg_pixel, bg_pixel, 255)
    print(f"Background sample at ({sample_x},{sample_y}): {bg_pixel}")

    # Solid fill matching ambient dark navy
    overlay = Image.new("RGBA", (band_w, band_h), bg_pixel)

    # Feather only on the LEFT edge (toward the legitimate "S") and TOP/BOTTOM
    # so the glow of the real capital S is preserved. Right edge can be hard
    # since there's nothing meaningful past the spurious lowercase s.
    mask = Image.new("L", (band_w, band_h), 255)
    # Fade the left side to preserve the S's right-side glow
    feather_x = max(8, band_w // 6)
    for x in range(feather_x):
        alpha = int(255 * (x / feather_x))
        for y in range(band_h):
            mask.putpixel((x, y), alpha)
    mask_blur = mask.filter(ImageFilter.GaussianBlur(radius=6))

    img.paste(overlay, (s_x1, s_y1), mask_blur)

    img.convert("RGB").save(DST, optimize=True)
    print(f"Wrote {DST.name}")


if __name__ == "__main__":
    main()
