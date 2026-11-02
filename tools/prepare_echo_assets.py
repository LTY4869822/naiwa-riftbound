"""Read alpha and write UV/contact metadata; original PNG pixels remain unchanged."""
from pathlib import Path
from PIL import Image
import numpy as np
from scipy import ndimage
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'prototype/assets/echo-v6';OUT.mkdir(parents=True,exist_ok=True)
manifest={}
records=json.loads((ROOT/'production/echo-v6-sources.json').read_text(encoding='utf-8'))
for rec in records:
    target=OUT/(rec['id']+'.png');shutil.copy2(rec['source'],target)
    im=Image.open(target);assert im.mode=='RGBA'
    a=np.array(im.getchannel('A'))
    cols=2 if rec['id']=='relic-emblems' else 4
    labels,n=ndimage.label(a>80)
    groups=[[] for _ in range(cols*2)]
    for k,sl in enumerate(ndimage.find_objects(labels),1):
        if sl is None: continue
        yy,xx=np.where(labels[sl]==k)
        if len(xx)<15: continue
        cx=xx.mean()+sl[1].start;cy=yy.mean()+sl[0].start
        col=min(cols-1,max(0,round(cx/(im.width/cols)-.5)))
        row=min(1,max(0,int(cy/(im.height/2))))
        groups[row*cols+col].append((sl,len(xx)))
    frames=[]
    for i,g in enumerate(groups):
        g=[o for o in g if o[1]>35]
        assert g and max(o[1] for o in g)>2000
        l=min(s[1].start for s,_ in g);r=max(s[1].stop for s,_ in g)
        t=min(s[0].start for s,_ in g);b=max(s[0].stop for s,_ in g)
        assert min(l,t,im.width-r,im.height-b)>3,(rec['id'],i,'clipped')
        pad=4
        region=[l-pad,t-pad,r-l+pad*2,b-t+pad*2]
        # Root X follows the torso, not the broad moving five-tail fan.
        pivot=[(r-l)*.40+pad,b-t+pad-1]
        frames.append({'region':region,'pivot':pivot,'height':b-t,'margin':min(l,t,im.width-r,im.height-b)})
    manifest[rec['id']]={'file':'res://assets/echo-v6/'+target.name,'dimensions':list(im.size),'frames':frames,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
    print(rec['id'],[(f['region'][2],f['region'][3]) for f in frames])
manifest['zheng-combat']['scale']=315.0/manifest['zheng-combat']['frames'][0]['height']
manifest['zheng-run']['scale']=manifest['zheng-combat']['scale']
manifest['relic-emblems']['ids']=['edge','wind','spring','echo']
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
for target in OUT.glob('*.png.import'):
    target.write_text(target.read_text(encoding='utf-8').replace('mipmaps/generate=false','mipmaps/generate=true'),encoding='utf-8')
