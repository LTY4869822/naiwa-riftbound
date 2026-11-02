"""Build an isolated browser edition from the current native game; do not touch native saves/code."""
from pathlib import Path
import json
import re
import shutil
import urllib.request
from fontTools import subset
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'prototype'
OUT = ROOT / 'production/web-project'
OUT.mkdir(parents=True, exist_ok=True)
ignored = {'.godot', 'artifacts', 'tests', 'web_assets'}
for path in SOURCE.iterdir():
    if path.name in ignored or path.name.startswith('.') or path.name == 'export_presets.cfg': continue
    target = OUT / path.name
    if path.is_dir(): shutil.copytree(path, target, dirs_exist_ok=True)
    elif path.is_file(): shutil.copy2(path, target)
assets = OUT / 'web_assets'
assets.mkdir(exist_ok=True)
font_source = ROOT / 'tools/NotoSansSC-wght.ttf'
if not font_source.exists():
    urllib.request.urlretrieve('https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf', font_source)
font_license = assets / 'OFL.txt'
if not font_license.exists():
    urllib.request.urlretrieve('https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/OFL.txt', font_license)
glyphs = set(chr(i) for i in range(32, 127))
for path in OUT.rglob('*'):
    if path.suffix in ['.gd', '.json', '.tres']:
        glyphs.update(path.read_text(encoding='utf-8-sig'))
glyphs.update('网页版返回首页存档已保存继续巡游首次加载战斗中请点击画面操作手机暂不支持')
glyphs.update('左右跳攻重闪觉奥首页')
options = subset.Options()
options.flavor = None
font = subset.load_font(str(font_source), options)
subsetter = subset.Subsetter(options=options)
subsetter.populate(text=''.join(sorted(glyphs)))
subsetter.subset(font)
subset.save_font(font, str(assets / 'NaiwaSC.ttf'), options)
for name, weight in [('regular', 500), ('bold', 800)]:
    static = instantiateVariableFont(font, {'wght': weight}, inplace=False)
    static.save(str(assets / f'NaiwaSC-{name}.ttf'))
    (assets / f'{name}.tres').write_text(
        '[gd_resource type="FontVariation" load_steps=2 format=3]\n'
        f'[ext_resource type="FontFile" path="res://web_assets/NaiwaSC-{name}.ttf" id="1"]\n'
        '[resource]\nbase_font = ExtResource("1")\n'
        'variation_embolden = 0.0\n', encoding='utf-8')
for path in OUT.rglob('*.gd'):
    text = path.read_text(encoding='utf-8-sig')
    if 'SystemFont' in text:
        text = re.sub(r'(\w+)\s*=\s*SystemFont\.new\(\)',
            lambda m: f'{m[1]}=preload("res://web_assets/{"bold" if m[1] == "bold" else "regular"}.tres")', text)
        text = text.replace('SystemFont.new()', 'preload("res://web_assets/bold.tres")')
        text = text.replace(': SystemFont', ': Font').replace(':SystemFont', ':Font')
        text = re.sub(r'^.*\.font_(?:names|weight)\s*=.*\n', '', text, flags=re.M)
    path.write_text(text, encoding='utf-8')
main = OUT / 'v6/main.gd'
text = main.read_text(encoding='utf-8')
start = text.index('\tif "--punch-review" in args')
end = text.index('\nfunc run_punch_review()', start)
text = text[:start] + text[end:]
# Debug capture/demo functions are not shipped as runtime entry points.
text = re.sub(r'^func (?:run_\w+|capture|visual_check)\([^\n]*\n.*?(?=^func |\Z)', '', text, flags=re.M | re.S)
# Keep normal gameplay input; remove only demo hotkey branches.
text = re.sub(r'^\tif test_mode and .*\n(?:\t\t.*\n|\n)*', '', text, flags=re.M)
text = text.replace('func return_pet() -> void:\n',
    'func return_pet() -> void:\n\tif OS.has_feature("web"):\n\t\tcamp()\n\t\ttoast("网页版进度已保存 · 欢迎继续巡游")\n\t\treturn\n')
text = text.replace('get_window().title = "奶蛙 · 碎片巡游"',
    'get_window().title = "奶蛙 · 碎片巡游 · 网页版"')
text = text.replace('\tsetup_input()\n', '\tThemeDB.fallback_font=font\n\tsetup_input()\n', 1)
text = text.replace('\twrite_bridge("active")\n', '\tvar touch_pad:=preload("res://web_assets/touch.gd").new()\n\ttouch_pad.host=self\n\tadd_child(touch_pad)\n\twrite_bridge("active")\n', 1)
main.write_text(text, encoding='utf-8')
shutil.copy2(ROOT / 'tools/web_touch_controls.gd', assets / 'touch.gd')
for path in [OUT / 'v5/menu.gd', OUT / 'v5/ui.gd']:
    text = path.read_text(encoding='utf-8').replace('返回桌宠', '返回首页')
    path.write_text(text, encoding='utf-8')
for path in [OUT / 'v5/menu.gd', OUT / 'v5/ui.gd', OUT / 'v5/battle_hud.gd']:
    text = path.read_text(encoding='utf-8').replace('"桌宠"', '"首页"').replace('P 桌宠', 'P 首页')
    path.write_text(text, encoding='utf-8')
project = OUT / 'project.godot'
text = project.read_text(encoding='utf-8')
text = text.replace('NaiwaFragmentPrototype', 'NaiwaBrowserEdition')
text = text.replace('window/size/window_width_override=1152', 'window/size/window_width_override=1280')
text = text.replace('window/size/window_height_override=720', 'window/size/window_height_override=800')
project.write_text(text, encoding='utf-8')
# Compress only the isolated browser edition's large illustrations, preserving pixel VFX.
for path in (OUT / 'assets').rglob('*.png.import'):
    if any(part in ['pixelfx', 'loot-v3', 'foe-vfx-toon'] for part in path.parts): continue
    text = path.read_text(encoding='utf-8')
    text = text.replace('compress/mode=0', 'compress/mode=1')
    text = re.sub(r'compress/lossy_quality=[0-9.]+', 'compress/lossy_quality=0.82', text)
    path.write_text(text, encoding='utf-8')
(assets / 'build.json').write_text(json.dumps({'edition': 'web', 'native_unchanged': True,
 'font': 'Noto Sans SC, SIL OFL, subset of game text',
 'save': 'Browser-local user://, distinct from native profile',
 'excluded': ['Native desktop pet / recycling integration', 'Debug entry points and capture artifacts']}, indent=2), encoding='utf-8')
print(json.dumps({'project': str(OUT), 'font_bytes': (assets / 'NaiwaSC.ttf').stat().st_size, 'glyphs': len(glyphs)}))
