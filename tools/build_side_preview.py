"""Package complete alpha-only frames and shared timings for offline/browser review."""
from pathlib import Path
import json
import shutil

ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'art-source/character-standard/side-attack-01'
assets=ROOT/'prototype/assets/v6/side'
frames=[
    ('00-guard.png','备战',[860,540]),
    ('02-jab-half.png','前手前送',[990,450]),
    ('03-jab-hit.png','前手击出',[1030,446]),
    ('04-jab-recover.png','前手回收',[900,492]),
    ('05-changeover.png','换手蓄力',[580,645]),
    ('06-cross-half.png','后手前送',[916,487]),
    ('07-cross-hit.png','后手击出',[1025,463]),
    ('08-cross-recover.png','后手回收',[740,480]),
]
def pose(f,ms,name,hit=0):
    return {'f':f,'ms':ms,'name':name,**({'hit':hit} if hit else {})}

combo=[pose(0,350,'侧身备战'),pose(1,40,'前手前送'),pose(2,75,'前手击出',1),
       pose(1,35,'前手回收'),pose(3,65,'回收换手'),pose(4,90,'后手蓄力'),
       pose(5,40,'后手前送'),pose(6,85,'后手击出',2),pose(5,40,'后手回收'),
       pose(7,85,'恢复护手'),pose(0,180,'收势')]
jab=[pose(0,400,'侧身备战'),pose(1,40,'前手前送'),pose(2,75,'前手击出',1),
     pose(1,45,'前手回收'),pose(3,90,'恢复护手'),pose(0,200,'收势')]
cross=[pose(0,200,'侧身备战'),pose(4,120,'后手蓄力'),pose(5,40,'后手前送'),
       pose(6,95,'后手击出',2),pose(5,45,'后手回收'),pose(7,100,'恢复护手'),pose(0,200,'收势')]

(folder/'frames').mkdir(exist_ok=True)
data={'version':1,'source_facing':'right','anchor_note':'One common rigid anchor. No per-frame rescale, crop, warp or blending.',
      'headY':146,'eyeY':239,'feet':[[330,1334],[800,1307]],'frames':[],
      'clips':{'combo':combo,'jab':jab,'cross':cross}}
for name,label,hand in frames:
    source=assets/name
    assert source.is_file(),f'Missing frame {source}'
    shutil.copy2(source,folder/'frames'/name)
    data['frames'].append({'src':'frames/'+name,'name':label,'anchor':[537,1334],'hand':hand})
for clip in data['clips'].values():
    assert all(0<=p['f']<len(frames) and p['ms']>0 for p in clip)
assert {p['f'] for p in combo}==set(range(len(frames)))
(folder/'animation.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
(folder/'data.js').write_text('window.NAIWA_SIDE = '+json.dumps(data,ensure_ascii=False)+';\n',encoding='utf-8')
print(f'{len(frames)} whole-character frames; combo {sum(p["ms"] for p in combo)} ms; no image transforms applied during packaging.')
