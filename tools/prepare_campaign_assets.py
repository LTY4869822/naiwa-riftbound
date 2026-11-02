"""Copy generated originals and inspect whole silhouettes for runtime atlas UVs."""
from pathlib import Path
from PIL import Image
from scipy import ndimage
import numpy as np
import json,shutil,hashlib

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'prototype/assets/campaign'

def main():
    provenance=json.loads((ROOT/'references/campaign-generation.json').read_text(encoding='utf-8'))
    OUT.mkdir(parents=True,exist_ok=True)
    bosses=OUT/'bosses'
    bosses.mkdir(exist_ok=True)
    metadata={}
    for key,entry in provenance['assets'].items():
        target=(bosses if entry['type']=='sprite' else OUT)/(key+'.png')
        shutil.copy2(entry['source'],target)
        image=Image.open(target).convert('RGBA')
        width,height=image.size
        if entry['type']!='sprite': continue
        alpha=np.array(image.getchannel('A'))>=64
        assert alpha.any() and not alpha.all()
        labels,_=ndimage.label(alpha)
        slices=ndimage.find_objects(labels)
        sizes=np.bincount(labels.ravel())
        ids=np.argsort(sizes[1:])[::-1][:8]+1
        boxes=[(slices[i-1][1].start,slices[i-1][0].start,slices[i-1][1].stop,slices[i-1][0].stop) for i in ids]
        boxes.sort(key=lambda b:((b[1]+b[3])/2>height/2,b[0]))
        frames=[]
        for i,(x0,y0,x1,y1) in enumerate(boxes):
            col,row=i%4,i//4
            assert (x0+x1)/2 >= col*width/4 and (x0+x1)/2 < (col+1)*width/4
            # Pivot follows the same central mass; bottom anchors every grounded pose.
            pivot_x=(col+0.5)*width/4-x0
            frames.append({'region':[x0,y0,x1-x0,y1-y0],'pivot':[pivot_x,y1-y0]})
        metadata[key]={'file':key+'.png','size':[width,height],'frames':frames,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
    (bosses/'sprites.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'generation.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:{'size':v['size'],'frames':len(v['frames'])} for k,v in metadata.items()}))

if __name__=='__main__':main()
