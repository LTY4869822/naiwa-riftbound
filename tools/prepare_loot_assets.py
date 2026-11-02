"""Copy original RGBA renders and measure atlas regions; never edit pixels."""
from pathlib import Path
from PIL import Image
import numpy as np
from scipy import ndimage
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1] / 'prototype/assets/loot-v3'
SOURCE = Path.home() / '.codex/generated_images/01a180ef-7ca6-7bb3-95a5-32cb97522799'
production = json.loads((ROOT / 'production.json').read_text(encoding='utf-8'))
manifest = {}
for entry in production['sources']:
    target = ROOT / (entry['id'] + '.png')
    shutil.copy2(SOURCE / entry['source'], target)
    im = Image.open(target)
    assert im.mode == 'RGBA'
    alpha = np.asarray(im.getchannel('A'))
    assert (alpha == 0).any() and (alpha > 0).any()
    frames = []
    labels, n = ndimage.label(alpha > 32)
    counts = np.bincount(labels.ravel())
    boxes = [box for i, box in enumerate(ndimage.find_objects(labels)) if box and counts[i+1] > 1000]
    assert len(boxes) == (8 if entry['id'] == 'coin' else 1)
    boxes.sort(key=lambda box: ((box[0].start+box[0].stop)//im.height, box[1].start))
    for box in boxes:
        l, r = max(0, box[1].start-4), min(im.width, box[1].stop+4)
        t, b = max(0, box[0].start-4), min(im.height, box[0].stop+4)
        assert l > 0 and r < im.width and t > 0 and b < im.height, 'clipped image'
        frames.append({'region': [l, t, r-l, b-t], 'pivot': [(r-l)/2, (b-t)/2]})
    manifest[entry['id']] = {
        'file': 'res://assets/loot-v3/' + target.name,
        'dimensions': list(im.size), 'frames': frames,
        'reference_height': max(f['region'][3] for f in frames),
        'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
    }
    print(entry['id'], im.size, 'frames', len(frames))
(ROOT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
