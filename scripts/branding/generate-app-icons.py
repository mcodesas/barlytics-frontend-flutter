"""Generate launcher icons from the original BarLytics artwork (not in-app logos)."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SIDE = 1024
NAVY = (6, 23, 35, 255)
SCALE = 0.8


def render(source, scale=SCALE, rounded=False):
    source = source.convert('RGBA')
    if source.size != (SIDE, SIDE):
        raise ValueError('Expected official 1024x1024 artwork')
    if source.getchannel('A').getextrema()[0] != 0:
        raise ValueError('Expected transparent official artwork')
    size = round(SIDE * scale)
    logo = source.resize((size, size), Image.Resampling.LANCZOS)
    tile = Image.new('RGBA', (SIDE, SIDE), NAVY)
    offset = (SIDE - size) // 2
    tile.alpha_composite(logo, (offset, offset))
    if rounded:
        mask = Image.new('L', (SIDE * 2, SIDE * 2))
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, SIDE * 2 - 1, SIDE * 2 - 1), radius=SIDE * 2 // 5, fill=255)
        tile.putalpha(mask.resize((SIDE, SIDE), Image.Resampling.LANCZOS))
    return tile


def save_png(root, path, tile, size, opaque=False):
    out = root / path
    out.parent.mkdir(parents=True, exist_ok=True)
    image = tile.resize((size, size), Image.Resampling.LANCZOS)
    if opaque:
        image = image.convert('RGB')
    image.save(out, optimize=True)
    with Image.open(out) as check:
        assert check.size == (size, size) and check.mode == image.mode, out
    print(f'{path}: {size}x{size}')


def generate(root, platform):
    with Image.open(root / 'assets/branding/barlytics_app_icon_1024.png') as source:
        standard = render(source, rounded=True)
        maskable = render(source, scale=0.65)
    if platform in ('android', 'all'):
        for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
            save_png(root, f'android/app/src/main/res/mipmap-{density}/ic_launcher.png', standard, size)
    if platform in ('macos', 'all'):
        for size in (16, 32, 64, 128, 256, 512, 1024):
            save_png(root, f'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png', standard, size)
    if platform in ('windows', 'all'):
        out = root / 'windows/runner/resources/app_icon.ico'
        out.parent.mkdir(parents=True, exist_ok=True)
        sizes = [(n, n) for n in (16, 24, 32, 48, 64, 128, 256)]
        standard.save(out, format='ICO', sizes=sizes, bitmap_format='bmp')
        with Image.open(out) as check:
            assert check.ico.sizes() == set(sizes), out
        print(f'{out}: ICO {sizes}')
    if platform == 'linux':
        save_png(root, 'web/icons/Icon-512.png', standard, 512)
    if platform in ('web', 'all'):
        save_png(root, 'web/favicon.png', standard, 64)
        for size in (192, 512):
            save_png(root, f'web/icons/Icon-{size}.png', standard, size)
            save_png(root, f'web/icons/Icon-maskable-{size}.png', maskable, size, opaque=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=('android', 'macos', 'windows', 'linux', 'web', 'all'), default='all')
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    generate(args.root, args.platform)
