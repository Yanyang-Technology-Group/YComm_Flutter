"""Generate launcher icons from the original Yanyang logo (requires Pillow)."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
logo = Image.open(ROOT / 'assets/ycomm_logo.png').convert('RGBA')
logo = logo.crop(logo.getbbox())

def icon(size, fraction=.72, transparent=False):
    canvas = Image.new('RGBA', (size, size), (255, 255, 255, 0 if transparent else 255))
    mark = logo.copy()
    mark.thumbnail((round(size * fraction), round(size * fraction)), Image.Resampling.LANCZOS)
    canvas.alpha_composite(mark, ((size-mark.width)//2, (size-mark.height)//2))
    return canvas if transparent else canvas.convert('RGB')

res = ROOT / 'android/app/src/main/res'
for density, size in {'mdpi':48, 'hdpi':72, 'xhdpi':96, 'xxhdpi':144, 'xxxhdpi':192}.items():
    folder=res/f'mipmap-{density}'
    folder.mkdir(parents=True, exist_ok=True)
    icon(size).save(folder/'ic_launcher.png')
    icon(round(size*108/48), .60, True).save(folder/'ic_launcher_foreground.png')
folder=res/'mipmap-anydpi-v26'
folder.mkdir(exist_ok=True)
(folder/'ic_launcher.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@android:color/white" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
''')
for platform in ['ios', 'macos']:
    folder=ROOT/platform/'Runner/Assets.xcassets/AppIcon.appiconset'
    for item in json.loads((folder/'Contents.json').read_text())['images']:
        size=round(float(item['size'].split('x')[0])*float(item['scale'].removesuffix('x')))
        icon(size).save(folder/item['filename'])
icon(256).save(ROOT/'windows/runner/resources/app_icon.ico', sizes=[(n,n) for n in [16,24,32,48,64,128,256]])
for path in (ROOT/'web/icons').glob('*.png'):
    size=Image.open(path).width
    icon(size, .60 if 'maskable' in path.name else .72).save(path)
icon(32).save(ROOT/'web/favicon.png')
icon(256).save(ROOT/'assets/app_icon.png')
