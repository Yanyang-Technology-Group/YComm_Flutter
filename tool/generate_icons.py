"""从 assets/app_icon.png 生成各平台图标（需要 Pillow）。

主图 assets/app_icon.png 是 256x256 的官方图标：圆角蓝底 + 白色标识。
本脚本把它作为唯一来源，不再从 assets/ycomm_logo.png 现拼图标。

大尺寸（iOS/macOS 的 1024、macOS/web 的 512、Android 自适应前景的 432）比主图还大，
直接放大会把细线拉虚，所以改成按主图里量出来的圆角半径与标识位置重建：
圆角用 Pillow 直接画（任意尺寸都锐利），标识用 2000x2000 的 assets/ycomm_logo.png
的轮廓按同一比例摆放。两者形状一致（宽高比 1.380 vs 1.384，256 尺寸下平均像素差 0.9%）。

用法：
    python3 tool/generate_icons.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / 'assets/app_icon.png'
LOGO = ROOT / 'assets/ycomm_logo.png'

master = Image.open(MASTER).convert('RGBA')
SIZE = master.width
assert master.height == SIZE, '主图必须是正方形'

# ---- 从主图量出配色与几何，避免把数值写死 ----
corners = [master.getpixel(p)[3] for p in ((0, 0), (SIZE - 1, 0), (0, SIZE - 1), (SIZE - 1, SIZE - 1))]
ROUNDED = max(corners) < 128  # 四角透明才说明是圆角图标

opaque = [master.getpixel((x, y)) for y in range(SIZE) for x in range(SIZE)
          if master.getpixel((x, y))[3] > 250]
BACKGROUND = max(set(opaque), key=opaque.count)
mark_pixels = [p for p in opaque if p[:3] != BACKGROUND[:3]]
MARK = max(set(mark_pixels), key=mark_pixels.count)

xs = [x for x in range(SIZE) for y in range(SIZE)
      if master.getpixel((x, y))[3] > 127 and master.getpixel((x, y))[:3] != BACKGROUND[:3]]
ys = [y for x in range(SIZE) for y in range(SIZE)
      if master.getpixel((x, y))[3] > 127 and master.getpixel((x, y))[:3] != BACKGROUND[:3]]
MARK_BOX = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)

radius = 0
if ROUNDED:
    while radius < SIZE and master.getpixel((radius, 0))[3] <= 127:
        radius += 1

logo = Image.open(LOGO).convert('RGBA')
logo_alpha = logo.getchannel('A').crop(logo.getbbox())

print(f'主图 {SIZE}x{SIZE}  底色 {BACKGROUND[:3]}  标识 {MARK[:3]}  圆角 {radius}  标识框 {MARK_BOX}')


def _mark(width):
    """白色标识，按给定宽度等比缩放（来自 2000px logo 的轮廓，任意尺寸都清晰）。"""
    height = max(1, round(width * logo_alpha.height / logo_alpha.width))
    alpha = logo_alpha.resize((max(1, round(width)), height), Image.Resampling.LANCZOS)
    layer = Image.new('RGBA', alpha.size, MARK)
    layer.putalpha(alpha)
    return layer


def icon(size):
    """应用图标：圆角底色 + 标识。不大于主图时直接缩放，更大时重建。"""
    if size <= SIZE:
        return master.resize((size, size), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    scale = size / SIZE
    ImageDraw.Draw(canvas).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=max(1, round(radius * scale)), fill=BACKGROUND)
    mark = _mark(round((MARK_BOX[2] - MARK_BOX[0]) * scale))
    canvas.alpha_composite(mark, (round(MARK_BOX[0] * scale), round(MARK_BOX[1] * scale)))
    return canvas


def mark_only(size, fraction):
    """只有标识、背景透明的图层：Android 自适应前景与 web maskable 用。"""
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    mark = _mark(round(size * fraction))
    canvas.alpha_composite(mark, ((size - mark.width) // 2, (size - mark.height) // 2))
    return canvas


def full_bleed(size, fraction):
    """满幅底色 + 标识：maskable 图标会被裁剪成各种形状，不能有透明圆角。"""
    canvas = Image.new('RGBA', (size, size), BACKGROUND)
    mark = _mark(round(size * fraction))
    canvas.alpha_composite(mark, ((size - mark.width) // 2, (size - mark.height) // 2))
    return canvas


# ---- Android ----
res = ROOT / 'android/app/src/main/res'
for density, size in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
    folder = res / f'mipmap-{density}'
    folder.mkdir(parents=True, exist_ok=True)
    icon(size).save(folder / 'ic_launcher.png')
    # 自适应图标的前景画布是 108dp，标识要落在中间的安全区里
    mark_only(round(size * 108 / 48), .60).save(folder / 'ic_launcher_foreground.png')

values = res / 'values'
values.mkdir(parents=True, exist_ok=True)
(values / 'colors.xml').write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    f'    <color name="ic_launcher_background">#{BACKGROUND[0]:02X}{BACKGROUND[1]:02X}{BACKGROUND[2]:02X}</color>\n'
    '</resources>\n')
adaptive = res / 'mipmap-anydpi-v26'
adaptive.mkdir(exist_ok=True)
(adaptive / 'ic_launcher.xml').write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/ic_launcher_background" />\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
    '</adaptive-icon>\n')

# ---- iOS / macOS ----
for platform in ('ios', 'macos'):
    folder = ROOT / platform / 'Runner/Assets.xcassets/AppIcon.appiconset'
    for item in json.loads((folder / 'Contents.json').read_text())['images']:
        if 'filename' not in item:
            continue
        px = round(float(item['size'].split('x')[0]) * float(item['scale'].removesuffix('x')))
        icon(px).save(folder / item['filename'])

# ---- Windows：多尺寸 .ico ----
# 显式用 BMP 帧（bitmap_format='bmp'）。Pillow 默认对大尺寸写 PNG 压缩帧，
# 虽然 Vista 之后也支持，但 BMP 与原来的图标一致，rc.exe 兼容性最稳。
icon(256).save(ROOT / 'windows/runner/resources/app_icon.ico',
               sizes=[(n, n) for n in (16, 24, 32, 48, 64, 72, 96, 128, 256)],
               bitmap_format='bmp')

# ---- Web ----
for path in (ROOT / 'web/icons').glob('*.png'):
    size = Image.open(path).width
    if 'maskable' in path.name:
        full_bleed(size, .60).save(path)
    else:
        icon(size).save(path)
icon(32).save(ROOT / 'web/favicon.png')

print('图标已更新：android / ios / macos / web / windows')
