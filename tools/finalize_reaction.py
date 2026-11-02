from pathlib import Path
import json,re,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'prototype/artifacts'
suites=[('reaction-review-final.log','REACTION_CHECKS',112),('reaction-mechanics-release.log','REMEDIATION_REVIEW',83),('reaction-core.log','V6_CHECKS',38),('reaction-ultimate.log','ULTIMATE_CHECKS',40),('reaction-campaign.log','CAMPAIGN_CHECKS',78),('reaction-foe.log','FOE_VFX_CHECKS',160),('reaction-shop.log','SHOP_UI_CHECKS',26)]
def read(name):return json.loads((OUT/name).read_text(encoding='utf-8'))
def clean(name):
    s=(OUT/name).read_text(encoding='utf-8')
    assert not any(x in s for x in ['SCRIPT ERROR:','SHADER ERROR:','ERROR:','WARNING:','FAIL ']),name
    return s
verified=[]
for log,marker,count in suites:
    s=clean(log)
    m=re.search(re.escape(marker)+r'\s+(\d+) failures=0',s)
    assert m and int(m[1])==count,log
    verified.append({'log':log,'checks':count,'failures':0})
resources=read('remediation-resources.json');assert not resources['failed'] and resources['checked']>=97
clean('reaction-resources.log');clean('reaction-render.log')
film=read('reaction-film.json');assert film['frames']==660
assert (OUT/'reaction-demo.mp4').stat().st_size>1_000_000
for shot in film['shots']:assert (OUT/f'reaction-{shot}.png').exists()
asset=ROOT/'prototype/assets/sprint-v2/sprint-four-frames.png'
with Image.open(asset) as im:
    assert im.mode=='RGBA' and im.size==(1536,1024)
    assert im.getchannel('A').getextrema()[0]==0
source={'date':'2026-10-29','tool':'OpenAI built-in image generation','reference':'assets/v6/side/00-guard.png','file':asset.name,'generated_output':'exec-2b59d52f-4ed9-4aeb-952f-9d72f04ed1d3.png','sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'frames':4,'grid':[2,2],'pixel_edits':False,'uniform_scale':0.46,'sole_anchors':[491,461,468,449],'prompts':'PROMPTS.md','wind':'Code-rendered live wind and snapshot trails, separate from character art.'}
(asset.parent/'SOURCE.json').write_text(json.dumps(source,ensure_ascii=False,indent=2),encoding='utf-8')
campaign=read('campaign-balance.json')
new_player=read('campaign-new-player.json')
assert new_player['all_won'] and new_player['starting_level_each_map']==1
forge=read('reaction-forge-play.json')
assert forge['all_won'] and forge['starting_level_each_map']==5
clean('reaction-forge-growth.log')
data={'date':'2026-10-29','checks':sum(x['checks'] for x in verified),'failures':0,'suites':verified,'resources':resources,'film':film,'video_bytes':(OUT/'reaction-demo.mp4').stat().st_size,'new_player':new_player,'campaign_level3_diagnostic':campaign,'forge_level5_diagnostic':forge,'user_profile_modified':False,'real_files_recycled':False,'limits':['Seeded normal-damage automation and GPU capture do not replace human difficulty/feel testing.','The level-3 bot cleared the first three maps; forge was separately cleared at level 5.']}
(OUT/'reaction-delivery.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'checks':data['checks'],'failures':0,'resources':resources['checked'],'new_player_clear':new_player['all_won'],'level3_clears':sum(x['won'] for x in campaign['runs']),'forge_level5_clear':forge['all_won'],'video_seconds':film['duration']},ensure_ascii=False))
