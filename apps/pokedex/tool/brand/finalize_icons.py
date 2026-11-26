"""Post-processes the icons rendered by tool/brand/generate_icons_test.dart.

- Packs the Windows sizes into windows/runner/resources/app_icon.ico.
- Removes the alpha channel of the iOS app icons (the App Store rejects
  icons with an alpha channel, even fully opaque ones).

Run from apps/pokedex after the generator; needs Pillow.
"""
from pathlib import Path

from PIL import Image

SIZES = [16, 20, 24, 32, 40, 48, 64, 128, 256]
out = Path("tool/brand/out")
images = [Image.open(out / f"windows_{s}.png").convert("RGBA") for s in SIZES]
ico = Path("windows/runner/resources/app_icon.ico")
# Each size is drawn natively (crisp small sizes) instead of downscaled.
images[-1].save(ico, format="ICO", sizes=[(s, s) for s in SIZES], append_images=images[:-1])
print(f"wrote {ico}")

for icon in sorted(Path("ios/Runner/Assets.xcassets/AppIcon.appiconset").glob("*.png")):
    Image.open(icon).convert("RGB").save(icon, optimize=True)
print("iOS icons without alpha channel")
