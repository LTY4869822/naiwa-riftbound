"""Package the exact runtime drawings for an offline animation review page."""
from pathlib import Path
import json
import shutil

ROOT=Path(__file__).resolve().parents[1]
runtime=json.loads((ROOT/'prototype/assets/v6/side-frames.json').read_text(encoding='utf-8'))
base=ROOT/'art-source/character-standard'
out=base/'side-motion-01'
(out/'frames').mkdir(parents=True,exist_ok=True)
labels=['备战','前手前送','前手击出','前手回收','换手蓄力','后手前送','后手击出','后手回收',
        '远腿落脚','远腿承重','近腿经过','近腿前伸','近腿落脚','近腿承重','远腿经过','远腿前伸','受击','腾空']
frames=[]
for i,f in enumerate(runtime['frames']):
    name=Path(f['texture']).name
    shutil.copy2(ROOT/'prototype'/f['texture'].removeprefix('res://'),out/'frames'/name)
    frames.append({'src':'frames/'+name,'name':labels[i],'anchor':f['anchor'],
                   'hand':f['hand'],'feet':f['feet']})

def converted(key):
    clip=runtime['clips'][key]
    return [{'f':i,'ms':round(t*1000),'name':labels[i],**({'hit':1 if i==2 else 2} if i in [2,6] else {})}
            for i,t in zip(clip['frames'],clip['times'])]

combo=converted('run')+[{'f':0,'ms':220,'name':'停步备战'}]+converted('attack0')+converted('attack1')
combo+=converted('hurt')+[{'f':0,'ms':300,'name':'收势'}]
data={'motion_review':True,'headY':146,'eyeY':239,'feet':[[330,1334],[800,1307]],'frames':frames,
      'clips':{'combo':combo,'move':converted('run'),'jab':converted('attack0'),
               'cross':converted('attack1'),'hurt':converted('hurt')+[{'f':0,'ms':300,'name':'收势'}],
               'air':[{'f':17,'ms':600,'name':'腾空姿势'},{'f':0,'ms':400,'name':'备战'}]}}
(out/'data.js').write_text('window.NAIWA_SIDE = '+json.dumps(data,ensure_ascii=False)+';\n',encoding='utf-8')
(out/'animation.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
html=(base/'side-attack-01/index.html').read_text(encoding='utf-8')
html=html.replace('奶娃 · 侧身双拳','奶娃 · 侧身移动与战斗').replace('前手直拳 → 后手直拳 → 收势','侧向移动 → 双拳 → 受击')
html=html.replace('两只拳头朝同一方向出击，保持侧身与完整人物换帧。','逐帧检查步态与战斗姿势；实战中由角色移动和跳跃物理驱动位置。')
html=html.replace('奶娃侧身双拳动画，两拳均朝同一个敌人方向','奶娃侧身移动、双拳、受击和腾空姿势')
html=html.replace('<strong>侧身双拳</strong>','<strong>移动与战斗动作</strong>')
html=html.replace('<option value="combo">连续双拳</option>','<option value="combo">完整流程</option><option value="move">移动步态</option>')
html=html.replace('</select><select id="speed"','<option value="hurt">受击恢复</option><option value="air">腾空姿势</option></select><select id="speed"',1)
html=html.replace('<script src="player.js"></script>','<script src="../side-attack-01/player.js"></script>')
html=html.replace('href="generation-record.json"','href="../side-step-01/generation-record.json"')
(out/'index.html').write_text(html,encoding='utf-8')
print(f'{len(frames)} runtime frames packaged for motion review.')
