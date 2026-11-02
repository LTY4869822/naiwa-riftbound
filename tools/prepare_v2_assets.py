"""Normalize generated animation families without altering character artwork.

Largest connected alpha components remove isolated generation debris; frames are
kept at a common source scale and aligned to the same feet baseline.
"""
from pathlib import Path
import json
import shutil
from PIL import Image, ImageOps
import numpy as np
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[1]
GENERATED = Path.home() / '.codex/generated_images/01a17dea-0624-70c0-beea-77da29ab6689'
OUTPUT = ROOT / 'prototype/assets/v2'
SOURCE = ROOT / 'art-source/v2'
OUTPUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)

def components(path, count):
    image = Image.open(path).convert('RGBA')
    rgba = np.array(image)
    labels, n = ndi.label(rgba[:, :, 3] > 90)
    sizes = ndi.sum(rgba[:, :, 3] > 90, labels, range(1, n + 1))
    indices = np.argsort(sizes)[-count:] + 1
    parts = []
    for index in indices:
        mask = ndi.binary_dilation(labels == index, iterations=2)
        ys, xs = np.where(labels == index)
        box = (max(0, xs.min()-3), max(0, ys.min()-3), min(image.width, xs.max()+4), min(image.height, ys.max()+4))
        data = rgba.copy()
        data[:, :, 3] = np.where(mask, rgba[:, :, 3], 0)
        parts.append({'center':((xs.min()+xs.max())/2, (ys.min()+ys.max())/2), 'image':Image.fromarray(data).crop(box), 'box':[int(v) for v in box]})
    return parts

def save_aligned(part, name, canvas_size, scale):
    image = part['image']
    image = image.resize((round(image.width*scale), round(image.height*scale)), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', canvas_size)
    canvas.alpha_composite(image, ((canvas.width-image.width)//2, canvas.height-10-image.height))
    dest = OUTPUT / name
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest)

hero_source = GENERATED / 'exec-8235ddcd-07a0-4a3a-ae29-acb8fe1ed5bc.png'
enemy_source = GENERATED / 'exec-8e3f74a3-d4dc-4bab-b2f4-dc762d61cb10.png'
background = GENERATED / 'exec-935331ec-9ee9-43ef-bc2e-91fc7bb5ad32.png'
for source, name in [(hero_source,'naiwa-actions-source.png'),(enemy_source,'enemies-source.png'),(background,'archive-background-source.png')]:
    shutil.copy2(source, SOURCE / name)

hero = sorted(components(hero_source, 12), key=lambda p:p['center'][1])
manifest = {'tool':'built-in image_gen','hero':{}, 'enemies':{}, 'background':str(background), 'normalization':'Connected alpha components, equal source scale, baseline alignment; no redraw.'}
for row, animation in enumerate(['run','attack','hurt']):
    ordered = sorted(hero[row*4:row*4+4], key=lambda p:p['center'][0])
    manifest['hero'][animation] = [part['box'] for part in ordered]
    for i, part in enumerate(ordered):
        save_aligned(part, f'hero/{animation}_{i}.png', (384,448), 1.02)

idle_path = ROOT / 'prototype/assets/naiwa/idle.png'
idle = ImageOps.mirror(Image.open(idle_path).convert('RGBA'))
idle = idle.crop(idle.getbbox())
save_aligned({'image':idle}, 'hero/idle.png', (384,448), 1.0)

enemies = sorted(components(enemy_source,8), key=lambda p:p['center'][1])
for row, animation in enumerate(['hound','warden']):
    ordered = sorted(enemies[row*4:row*4+4], key=lambda p:p['center'][0])
    manifest['enemies'][animation] = [part['box'] for part in ordered]
    for i, part in enumerate(ordered):
        save_aligned(part, f'enemies/{animation}_{i}.png', (512,512), 0.95)

shutil.copy2(background, OUTPUT/'archive-background.png')
(SOURCE/'asset-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')

# A developer contact sheet for checking pose selection and baseline stability.
sheet = Image.new('RGB',(768,672),'#182d34')
for row, animation in enumerate(['run','attack','hurt']):
    for i in range(4):
        im = Image.open(OUTPUT/f'hero/{animation}_{i}.png').resize((192,224),Image.Resampling.LANCZOS)
        sheet.paste(im,(i*192,row*224),im)
sheet.save(SOURCE/'naiwa-actions-contact.png')
from scipy.spatial import ConvexHull
pet_union=np.zeros((368,288),dtype=bool)
for source in (ROOT/'prototype/assets/naiwa').glob('*.png'):
    alpha=np.array(Image.open(source).convert('RGBA'))[:,:,3]
    pet_union |= alpha>35
ys,xs=np.where(ndi.binary_dilation(pet_union,iterations=4))
points=np.column_stack((xs,ys))
hull=ConvexHull(points)
polygon=[[round(float(points[i,0])*240/288,2),round(float(points[i,1])*307/368+4,2)] for i in hull.vertices]
(OUTPUT/'pet-mask.json').write_text(json.dumps(polygon),encoding='utf8')
print('Prepared 12 Naiwa action frames, idle, 8 enemy frames and archive environment.')
