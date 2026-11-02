"""Copy original generated art; measure atlas UVs/pivots without changing pixels."""
from pathlib import Path
import hashlib,json,shutil
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'prototype/assets/biomes-v5'
OUT.mkdir(parents=True,exist_ok=True)
manifest={}
records=json.loads((ROOT/'production/biomes-v5-sources.json').read_text(encoding='utf-8'))
for entry in records:
    target=OUT/(entry['id']+'.png')
    shutil.copy2(entry['source'],target)
    im=Image.open(target)
    assert im.mode=='RGBA'
    a=np.array(im.getchannel('A'))
    labels,n=ndimage.label(a>20)
    objects=ndimage.find_objects(labels)
    groups=[[] for _ in range(8)]
    for number,sl in enumerate(objects,1):
        if sl is None: continue
        yy,xx=np.where(labels[sl]==number)
        if len(xx)<6: continue
        cx=float(xx.mean()+sl[1].start); cy=float(yy.mean()+sl[0].start)
        row=min(1,max(0,int(cy/(im.height/2))))
        col=min(3,max(0,round(cx/(im.width/4)-.5)))
        groups[row*4+col].append((sl[1].start,sl[0].start,sl[1].stop,sl[0].stop,len(xx)))
    frames=[]
    for i,g in enumerate(groups):
        assert g and max(o[4] for o in g)>2500,(entry['id'],i,'missing pose')
        # Disconnected tiny alpha flecks are not part of the character silhouette.
        g=[o for o in g if o[4]>18]
        l=min(o[0] for o in g);t=min(o[1] for o in g)
        r=max(o[2] for o in g);b=max(o[3] for o in g)
        assert min(l,t,im.width-r,im.height-b)>3,(entry['id'],i,'canvas clipping')
        region=[max(0,l-3),max(0,t-3),r-l+6,b-t+6]
        solid=np.where(a[t:b,l:r]>100)
        bottom_y=int(np.quantile(solid[0],.998))+t
        lower=solid[1][solid[0]>(b-t)*.76]
        root_x=float(np.median(lower))+l if len(lower)>20 else (l+r)/2
        frames.append({'region':region,'pivot':[round(root_x-region[0],2),bottom_y-region[1]+1],
                       'opaque_bounds':[l,t,r-l,b-t],'canvas_margin':min(l,t,im.width-r,im.height-b)})
    manifest[entry['id']]={'file':'res://assets/biomes-v5/'+target.name,'dimensions':list(im.size),
       'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'frames':frames}
    print(entry['id'],len(frames),'complete measured poses')
for entry in json.loads((ROOT/'production/biomes-v5-cartoon-backgrounds.json').read_text(encoding='utf-8')):
    target=OUT/(entry['id']+'.png');shutil.copy2(entry['source'],target)
    manifest[entry['id']]={'file':'res://assets/biomes-v5/'+target.name,'dimensions':list(Image.open(target).size),
      'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
props=json.loads((ROOT/'production/biomes-v5-ledges.json').read_text(encoding='utf-8'))
target=OUT/'ledges.png';shutil.copy2(props['source'],target)
im=Image.open(target);a=np.array(im.getchannel('A'))
labels,n=ndimage.label(a>64)
objects=ndimage.find_objects(labels)
parts=[]
for k,sl in enumerate(objects,1):
    size=int(np.sum(labels[sl]==k))
    if size>20000: parts.append((sl,size))
assert len(parts)==4
parts.sort(key=lambda o:(round(o[0][0].start/(im.height/2)),o[0][1].start))
frames=[]
for sl,_ in parts:
    x0,x1=sl[1].start,sl[1].stop;y0,y1=sl[0].start,sl[0].stop
    xs=range(int(x0+(x1-x0)*.4),int(x0+(x1-x0)*.6))
    tops=[int(np.where(a[y0:y1,x]>128)[0][0])+y0 for x in xs if np.any(a[y0:y1,x]>128)]
    frames.append({'region':[x0-3,y0-3,x1-x0+6,y1-y0+6],'contact_y':float(np.median(tops))-y0+3})
manifest['ledges']={'file':'res://assets/biomes-v5/ledges.png','dimensions':list(im.size),'frames':frames,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
for target in OUT.glob('*.png.import'):
    target.write_text(target.read_text(encoding='utf-8').replace('mipmaps/generate=false','mipmaps/generate=true'),encoding='utf-8')
