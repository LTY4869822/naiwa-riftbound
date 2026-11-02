from pathlib import Path
from PIL import Image
from scipy import ndimage
import numpy as np
import json,shutil,hashlib
ROOT=Path(__file__).resolve().parents[1]/'prototype/assets/loop-v2'
SOURCE=Path.home()/'.codex/generated_images/01a180ef-7ca6-7bb3-95a5-32cb97522799'
d=json.loads((ROOT/'production.json').read_text(encoding='utf-8'))
manifest={}
for entry in d['sources']:
 target=ROOT/(entry['id']+'.png');shutil.copy2(SOURCE/entry['source'],target)
 im=Image.open(target);a=np.asarray(im.getchannel('A'))>=128
 labels,n=ndimage.label(a);counts=np.bincount(labels.ravel());boxes=ndimage.find_objects(labels)
 components=[(int(counts[i+1]),b) for i,b in enumerate(boxes) if b and counts[i+1]>3500]
 print(entry['id'],im.size,'components',[(c,[b[1].start,b[0].start,b[1].stop,b[0].stop]) for c,b in components])
 assert len(components)==8,(entry['id'],len(components))
 frames=[None]*8
 for _,b in components:
  l,t,r,bot=b[1].start,b[0].start,b[1].stop,b[0].stop
  col=min(3,int((l+r)/2/(im.width/4)));row=min(1,int((t+bot)/2/(im.height/2)))
  index=row*4+col;assert frames[index] is None
  left=max(0,l-3);top=max(0,t-3);right=min(im.width,r+3);bottom=min(im.height,bot+3)
  center=(round(col*im.width/4)+round((col+1)*im.width/4))/2
  if entry['id']!='run':
   foot=np.where(a[bot-max(4,int((bot-t)*.08)):bot,l:r])[1]+l
   if foot.size: center=(float(foot.min())+float(foot.max()))*.5
  frames[index]={'region':[left,top,right-left,bottom-top],'pivot':[center-left,bot-top],'height':bot-t}
 assert all(frames)
 manifest[entry['id']]={'file':'res://assets/loop-v2/'+entry['id']+'.png','frames':frames,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'dimensions':im.size}
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
