"""User-authorized alpha-only extraction; no RGB edits, cropping, resizing or redrawing.

Authorization 2026-10-28: '改用程序抠图，保留原人物（推荐）'.
Only nearly neutral background connected to the outside border is removed.
Enclosed bright regions (belly/eyes) stay opaque. The one-pixel silhouette edge
gets a small alpha ramp; all RGB bytes and the canvas dimensions remain exact.
"""
from pathlib import Path
import hashlib
import json
import argparse
import cv2
import numpy as np
from scipy.ndimage import distance_transform_edt
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art-source/character-standard'
DEST = ROOT / 'prototype/assets/v6/approved'

def extract(source: Path, target: Path):
    rgb = np.array(Image.open(source).convert('RGB'))
    values = rgb.astype(np.int16)
    neutral = (values.max(2)-values.min(2)<28) & (values.min(2)>140)
    connected = neutral.astype(np.uint8)
    cv2.floodFill(connected, None, (0, 0), 2)
    outside = connected == 2
    distance = distance_transform_edt(~outside)
    alpha = np.rint(np.clip((distance-0.35)/1.2, 0, 1)*255).astype(np.uint8)
    rgba = np.dstack([rgb, alpha])
    target.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba).save(target)
    saved = np.array(Image.open(target))
    assert np.array_equal(saved[:,:,:3], rgb), 'RGB changed'
    assert saved.shape[:2] == rgb.shape[:2], 'Canvas changed'
    assert saved[200,535,3] == 255, 'Head interior damaged'
    assert saved[700,535,3] == 255, 'Cream belly damaged'
    assert saved[0,0,3] == 0, 'Background opaque'
    return {'source':str(source.relative_to(ROOT)).replace('\\','/'),
            'output':str(target.relative_to(ROOT)).replace('\\','/'),
            'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
            'size':[rgb.shape[1],rgb.shape[0]],'rgb_identical':True,
            'transparent_pixels':int((alpha==0).sum()),'opaque_pixels':int((alpha==255).sum()),
            'edge_pixels':int(((alpha>0)&(alpha<255)).sum())}

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--set',choices=['front','side'],default='front')
    args=parser.parse_args()
    if args.set=='side':
        DEST=ROOT/'prototype/assets/v6/side'
        inputs=[(SOURCE/'side-guard-01/naiwa-side-guard-review-01.png','00-guard.png')]
        inputs += [(p,p.name) for p in sorted((SOURCE/'side-attack-01').glob('*.png'))]
        inputs += [(p,p.name) for p in sorted((SOURCE/'side-step-01').glob('*.png'))]
        inputs += [(p,p.name) for p in sorted((SOURCE/'side-reaction-01').glob('*.png'))]
    else:
        inputs=[(SOURCE/'naiwa-front-review-01.png','00-idle.png')]
        inputs += [(p,p.name) for p in sorted((SOURCE/'attack-01').glob('*.png'))]
        inputs += [(p,p.name) for p in sorted((SOURCE/'step-01').glob('*.png'))]
    records=[extract(src,DEST/name) for src,name in inputs]
    (DEST/'extraction-report.json').write_text(json.dumps({'method':'alpha only; external neutral flood fill; no RGB modifications','authorization':'2026-10-28 user explicitly requested programmatic extraction preserving the character','frames':records},ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'{len(records)} source frames extracted; RGB bytes identical in every output; no resizing or cropping.')
