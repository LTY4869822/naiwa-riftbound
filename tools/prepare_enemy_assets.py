"""Copy original generated sheets and CC0 textures; inspect alpha without repainting."""
from pathlib import Path
from PIL import Image
import hashlib
import json
import shutil
import zipfile
import numpy as np
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'prototype/assets/enemies-expansion'
SOURCE = Path.home() / '.codex/generated_images/01a180ef-7ca6-7bb3-95a5-32cb97522799'
SHEETS = {
    'beetle': ('exec-c30d539b-6596-4e79-8f8b-26ea6db4a7e1.png', 'thornback-beetle.png'),
    'shaman': ('exec-9f382274-51e2-4cf9-abdd-3ff777a55e69.png', 'sporelamp-shaman.png'),
    'raven': ('exec-095633a4-c11c-4abb-b06f-167ba80e8a70.png', 'nightplume-raven.png'),
}
MASKS = ['dirt_02.png', 'smoke_05.png', 'magic_03.png', 'circle_05.png',
         'slash_02.png', 'spark_04.png', 'star_07.png']

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    metadata = {}
    for kind, (original, target) in SHEETS.items():
        shutil.copy2(SOURCE / original, OUT / target)
        image = Image.open(OUT / target).convert('RGBA')
        width, height = image.size
        # Locate whole connected silhouettes; authored tips may cross a grid line.
        # This is read-only analysis. Original PNG bytes remain unchanged.
        labels, _ = ndimage.label(np.array(image.getchannel('A')) >= 64)
        slices = ndimage.find_objects(labels)
        sizes = np.bincount(labels.ravel())
        ids = np.argsort(sizes[1:])[::-1][:8] + 1
        components = [(slices[j-1][1].start, slices[j-1][0].start,
                       slices[j-1][1].stop, slices[j-1][0].stop) for j in ids]
        components.sort(key=lambda b: ((b[1]+b[3])/2 > height/2, b[0]))
        if kind == 'beetle':
            # Adjacent charge drawings extend across the same column boundary.
            # Restrict runtime UVs to avoid sampling a neighbour's horn/foot.
            x0,y0,x1,y1=components[5]
            components[5]=(x0,y0,min(x1,887),y1)
            x0,y0,x1,y1=components[6]
            components[6]=(max(x0,900),y0,min(x1,1352),y1)
        frames = []
        for i in range(8):
            col, row = i % 4, i // 4
            cell = (col * width // 4, row * height // 2,
                    (col + 1) * width // 4, (row + 1) * height // 2)
            component = components[i]
            bounds = (component[0]-cell[0], component[1]-cell[1],
                      component[2]-cell[0], component[3]-cell[1])
            assert bounds and bounds[2] > bounds[0] + 30 and bounds[3] > bounds[1] + 30
            anchor_x = (cell[2] - cell[0]) * .56
            anchor_y = bounds[3]
            if kind == 'shaman':
                anchor_x = [255, 240, 240, 250, 270, 250, 295, 305][i] * (cell[2] - cell[0]) / 443.5
            elif kind == 'raven':
                eye = [(100,265),(107,270),(108,225),(100,280),
                       (105,267),(147,242),(103,297),(120,232)][i]
                anchor_x = (eye[0]+110)*(cell[2]-cell[0])/443.5
                anchor_y = (eye[1]+280)*(cell[3]-cell[1])/443.5
            frames.append({'region':[cell[0]+bounds[0],cell[1]+bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]],
                           'pivot':[round(anchor_x-bounds[0],3),round(anchor_y-bounds[1],3)],
                           'alpha_bounds':list(bounds)})
        metadata[kind] = {'file':target,'size':[width,height],'frames':frames,
                          'sha256':hashlib.sha256((OUT/target).read_bytes()).hexdigest(),
                          'source':str(SOURCE/original),'alpha_threshold':64}
    (OUT/'sprites.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')
    archive = ROOT/'references/vfx/kenney-particle-pack.zip'
    vfx = OUT/'vfx'
    vfx.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive) as pack:
        for name in MASKS:
            (vfx/name).write_bytes(pack.read('PNG (Transparent)/'+name))
        (vfx/'KENNEY-LICENSE.txt').write_bytes(pack.read('License.txt'))
    (vfx/'sources.json').write_text(json.dumps({
        'author':'Kenney','pack':'Particle Pack','license':'CC0 1.0',
        'url':'https://kenney.nl/assets/particle-pack',
        'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),
        'files':{name:hashlib.sha256((vfx/name).read_bytes()).hexdigest() for name in MASKS},
        'technique_reference':'https://www.gdquest.com/news/2020/05/godot-vfx-secrets-out/',
        'note':'Original CC0 PNG bytes; runtime tint/rotation/scale only. GDQuest used as technique reference, no source code copied.'
    },ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k: {'size':v['size'],'frames':len(v['frames'])} for k,v in metadata.items()}))
    print((vfx/'KENNEY-LICENSE.txt').read_text(encoding='utf-8'))

if __name__ == '__main__': main()
