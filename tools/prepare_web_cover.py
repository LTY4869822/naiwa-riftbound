"""Resize and encode existing game art for the browser cover; no new character art."""
import json
from pathlib import Path
from PIL import Image, ImageOps
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools import subset

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'web/dist/cover'
OUT.mkdir(exist_ok=True)
for realm in ['moss', 'cavern', 'storm', 'forge']:
    image = Image.open(ROOT / ('prototype/assets/biomes-v5/' + realm + '-1.png'))
    image.save(OUT / (realm + '.webp'), 'WEBP', quality=84, method=6)
    ImageOps.fit(image, (240, 152)).save(OUT / (realm + '-thumb.webp'), 'WEBP', quality=80, method=6)
image = Image.open(ROOT / 'prototype/assets/menu-v2/pet/front-idle.png')
image.thumbnail((700, 1050))
image.save(OUT / 'naiwa.webp', 'WEBP', quality=90, method=6)
font = TTFont(ROOT / 'tools/NotoSansSC-wght.ttf')
font = instantiateVariableFont(font, {'wght': 900}, inplace=True)
text = (ROOT / 'web/dist/index.html').read_text(encoding='utf-8') + (ROOT / 'web/dist/cover.js').read_text(encoding='utf-8')
options = subset.Options()
options.flavor = 'woff2'
subsetter = subset.Subsetter(options=options)
subsetter.populate(text=text)
subsetter.subset(font)
font.flavor = 'woff2'
font.save(OUT / 'cover-bold.woff2')
manifest = {'sources': {'scenes':'prototype/assets/biomes-v5/*-1.png',
                        'pet':'prototype/assets/menu-v2/pet/front-idle.png',
                        'font':'Noto Sans SC 900, SIL OFL; licenses/NOTO-OFL.txt'},
            'files': {path.name:path.stat().st_size for path in OUT.iterdir() if path.is_file()}}
(OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'cover_bytes':sum(manifest['files'].values()),'files':len(manifest['files'])}))
