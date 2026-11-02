from pathlib import Path
from PIL import Image
import numpy as np
import json, hashlib, shutil

OUT=Path(__file__).resolve().parents[1]/'prototype/assets/rift-v4'
SOURCE=Path.home()/'.codex/generated_images/01a180ef-7ca6-7bb3-95a5-32cb97522799'
production=json.loads((OUT/'production.json').read_text(encoding='utf-8'))
manifest={}
for entry in production['sources']:
    target=OUT/(entry['id']+'.png')
    shutil.copy2(SOURCE/entry['source'],target)
    im=Image.open(target)
    assert im.mode=='RGBA'
    alpha=np.asarray(im.getchannel('A'))
    frames=[]
    for row in range(2):
        for col in range(4):
            x0,x1=round(col*im.width/4),round((col+1)*im.width/4)
            y0,y1=round(row*im.height/2),round((row+1)*im.height/2)
            yy,xx=np.where(alpha[y0:y1,x0:x1]>24)
            assert len(xx)>100
            l,r=x0+int(xx.min())-4,x0+int(xx.max())+5
            t,b=y0+int(yy.min())-4,y0+int(yy.max())+5
            assert l>x0 and r<x1 and t>y0 and b<y1,(entry['id'],row,col,'clipped sprite')
            pivot=[(r-l)/2,(b-t)/2] if entry['id'] in ['portal','eclipse'] else [(r-l)/2,b-t-5]
            frames.append({'region':[l,t,r-l,b-t],'pivot':pivot})
    manifest[entry['id']]={'file':'res://assets/rift-v4/'+target.name,'dimensions':list(im.size),'frames':frames,'reference':[max(f['region'][2] for f in frames),max(f['region'][3] for f in frames)],'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
    print(entry['id'],im.size,'eight unclipped RGBA frames')
    import_file=target.with_suffix('.png.import')
    if import_file.exists():
        text=import_file.read_text(encoding='utf-8').replace('mipmaps/generate=false','mipmaps/generate=true')
        import_file.write_text(text,encoding='utf-8')
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
