"""Build the Godot side-facing animation bank from inspected, complete drawings.

Read-only image measurements choose a rigid ground anchor. No image resizing,
warping, interpolation, recoloring or compositing occurs here.
"""
from pathlib import Path
import json
import numpy as np
import cv2
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'prototype/assets/v6/side'
# Hand landmarks are source coordinates. The support foot meets the platform;
# secondary foot shadows retain slight projection depth. Scale is uniform and fixed.
DEFS=[
 ('00-guard.png',[860,540],0),
 ('02-jab-half.png',[990,450],0),
 ('03-jab-hit.png',[1030,446],0),
 ('04-jab-recover.png',[900,492],0),
 ('05-changeover.png',[580,645],0),
 ('06-cross-half.png',[916,487],0),
 ('07-cross-hit.png',[1025,463],0),
 ('08-cross-recover.png',[740,480],0),
 ('10-contact-a.png',[740,690],0),
 ('11-down-a.png',[660,750],0),
 ('12-pass-a.png',[640,820],0),
 ('13-reach-a.png',[600,860],0),
 ('14-contact-b.png',[370,850],0),
 ('15-down-b.png',[440,850],0),
 ('16-pass-b.png',[560,820],0),
 ('17-reach-b.png',[680,760],0),
 ('20-hurt.png',[680,580],0),
 ('21-air.png',[690,560],None),
]
frames=[]
for name,hand,depth in DEFS:
    p=ASSETS/name
    assert p.is_file(),f'Missing complete frame: {name}'
    pixels=np.array(Image.open(p))
    assert pixels.shape[:2]==(1448,1086),f'Unexpected canvas in {name}'
    ys,xs=np.where(pixels[:,:,3]>128)
    assert xs.min()>8 and xs.max()<1078 and ys.min()>8 and ys.max()<1440,f'Clipped figure in {name}'
    sole=int(ys.max())
    anchor_y=1334 if depth is None else sole-depth
    mask=(pixels[1160:,:,3]>128).astype(np.uint8)
    count,labels,stats,_=cv2.connectedComponentsWithStats(mask)
    feet=[]
    for label in range(1,count):
        if stats[label,cv2.CC_STAT_AREA]<400: continue
        fy,fx=np.where(labels==label)
        foot_y=int(fy.max()+1160)
        bottom_x=fx[fy>=fy.max()-12]
        foot_x=float((bottom_x.min()+bottom_x.max())*.5)
        feet.append({'point':[foot_x,foot_y],
                     'depth':int(np.clip(foot_y-anchor_y,-27,0)),
                     'width':float(np.clip((bottom_x.max()-bottom_x.min())*.175*.5,12,28))})
    frames.append({'texture':'res://assets/v6/side/'+name,'anchor':[537,anchor_y],
        'hand':hand,'sole_y':sole,'support_depth':depth or 0,'grounded':depth is not None,'feet':feet})

def clip(ids,times,duration=None):
    total=round(sum(times),6)
    if duration is not None: assert abs(total-duration)<.0001,(total,duration)
    assert len(ids)==len(times) and all(0<=i<len(frames) for i in ids)
    return {'frames':ids,'times':times,'duration':total}

clips={
 'idle':clip([0],[1]),
 'run':clip(list(range(8,16)),[.12]*8),
 'settle_a':clip([8,0],[.07,.06]),
 'settle_b':clip([15,8,0],[.06,.05,.05]),
 'attack0':clip([3,0,1,2,1,3,0],[.05,.05,.04,.11,.035,.07,.125],.48),
 'attack1':clip([3,4,5,6,5,7,0],[.06,.07,.04,.12,.05,.09,.11],.54),
 'attack2':clip([0,4,5,6,5,7,0],[.07,.13,.05,.14,.07,.11,.15],.72),
 'skill':clip([0,4,5,6,5,7,0],[.08,.32,.08,.16,.06,.15,.20],1.05),
 'hurt':clip([16,7,0],[.17,.07,.08],.32),
 'dash':clip([10,17,14],[.06,.06,.06],.18),
 'air':clip([0,17,8],[.08,.74,.18],1),
}
manifest={'version':2,'source_facing':1,'scale':.175,'frames':frames,'clips':clips,
          'notes':'Entire authored frames only; fixed uniform scale; side profile throughout.'}
out=ROOT/'prototype/assets/v6/side-frames.json'
out.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'{len(frames)} side-facing frames, {len(clips)} clips; all durations checked.')
for i,f in enumerate(frames): print(i,Path(f['texture']).name,'anchor',f['anchor'],'support',f['support_depth'])
