"""Read-only alpha QA; emit atlas metadata without changing any image pixels."""
from pathlib import Path
from PIL import Image
from scipy import ndimage
import numpy as np
import json
ROOT=Path(__file__).resolve().parents[1]/'prototype/assets/ascension'
d=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
for key in ['bosses/zheng.png','bosses/yinglong.png','bosses/paoxiao.png','bosses/zhuyin-clean.png']:
    a=np.asarray(Image.open(ROOT/key).getchannel('A'))>=128
    labels,n=ndimage.label(a)
    counts=np.bincount(labels.ravel())
    boxes=ndimage.find_objects(labels)
    comps=[(int(counts[i+1]),[b[1].start,b[0].start,b[1].stop,b[0].stop]) for i,b in enumerate(boxes) if b is not None and counts[i+1]>1500]
    asset=d['assets'][key]
    cols,rows=asset['grid'];width,height=asset['dimensions']
    assert len(comps)==cols*rows,(key,len(comps))
    measured=[None]*(cols*rows)
    for area,b in comps:
        col=min(cols-1,int((b[0]+b[2])*.5/(width/cols)))
        row=min(rows-1,int((b[1]+b[3])*.5/(height/rows)))
        index=row*cols+col
        assert measured[index] is None,(key,index)
        l=max(0,b[0]-3);top=max(0,b[1]-3);r=min(width,b[2]+3);bottom=min(height,b[3]+3)
        center=(round(col*width/cols)+round((col+1)*width/cols))*.5
        measured[index]={'region':[l,top,r-l,bottom-top],'pivot':[center-l,b[3]-top],'height':b[3]-b[1],'component_bounds':b,'opaque_component_pixels':area}
    asset.setdefault('nominal_frames',asset['frames'])
    asset['frames']=measured
    asset['qa']='Measured complete connected alpha silhouettes, including tips beyond nominal cells. Source pixels unchanged; no image processing or repainting.'
    print(key,[x['region'] for x in measured])
(ROOT/'manifest.json').write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
