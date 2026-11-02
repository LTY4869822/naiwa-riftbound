"""Encode current in-engine captures for README display, without generating artwork."""
from pathlib import Path
from PIL import Image
import json
ROOT=Path(__file__).resolve().parents[1]
media=ROOT/'docs/media'
record=json.loads((media/'capture-manifest.json').read_text(encoding='utf-8'))
for path in media.glob('*.png'):
    Image.open(path).convert('RGB').save(path.with_suffix('.jpg'),quality=91,optimize=True)
frames=[]
for name in record['shots']:
    if name.startswith('combat-frames/'):
        image=Image.open(media/(name+'.png')).convert('RGB')
        image.thumbnail((640,400));frames.append(image.copy())
palette_source=Image.new('RGB',(160*10,100))
for index,image in enumerate(frames[::5]):
    palette_source.paste(image.resize((160,100)),(index*160,0))
palette=palette_source.quantize(colors=128)
frames=[image.quantize(palette=palette,dither=Image.Dither.NONE) for image in frames]
frames[0].save(media/'combat.gif',save_all=True,append_images=frames[1:],duration=100,loop=0,optimize=True)
print(json.dumps({'frames':len(frames),'gif_bytes':(media/'combat.gif').stat().st_size}))
