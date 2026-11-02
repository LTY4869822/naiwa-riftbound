from pathlib import Path
import json,re,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'prototype/artifacts'
checks=[
 ('remediation-review-final.log','REMEDIATION_REVIEW',79),
 ('remediation-core-gpu-final.log','V6_CHECKS',38),
 ('remediation-core-legacy-gpu.log','V5_CHECKS',18),
 ('remediation-ult-gpu.log','ULTIMATE_CHECKS',40),
 ('remediation-campaign-review-final.log','CAMPAIGN_CHECKS',78),
 ('remediation-foe-gpu-final.log','FOE_VFX_CHECKS',160),
 ('remediation-hud-gpu-final.log','HUD_CHECKS',36),
 ('remediation-shop-gpu.log','SHOP_UI_CHECKS',26),
 ('remediation-shop-store.log','SHOP_STORE_CHECKS',43),
 ('remediation-route-gpu.log','ROUTE_JELLY_CHECKS',24),
]
verified=[]
def clean(name):
    s=(OUT/name).read_text(encoding='utf-8')
    assert not any(token in s for token in ['SCRIPT ERROR:','SHADER ERROR:','ERROR:','FAIL ','WARNING:']),name
    return s
for name,marker,count in checks:
    s=clean(name)
    match=re.search(re.escape(marker)+r'\s+(\d+) failures=0',s)
    assert match and int(match[1])==count,(name,match)
    verified.append({'log':name,'checks':count,'failures':0})
s=clean('remediation-menu-gpu.log')
assert s.count('PASS ')==15
verified.append({'log':'remediation-menu-gpu.log','checks':15,'failures':0})
resources=json.loads((OUT/'remediation-resources.json').read_text(encoding='utf-8'))
assert resources['checked']>=93 and not resources['failed']
clean('remediation-resources-final.log')
balance=json.loads((OUT/'campaign-balance.json').read_text(encoding='utf-8'))
new_player=json.loads((OUT/'campaign-new-player.json').read_text(encoding='utf-8'))
assert balance['all_won'] and len(balance['runs'])==4 and not balance['invulnerability_override']
assert new_player['all_won'] and new_player['starting_level_each_map']==1 and not new_player['invulnerability_override']
clean('remediation-balance-final.log');clean('remediation-new-player.log')
film=json.loads((OUT/'ultimate-v2-film.json').read_text(encoding='utf-8'))
clean('ultimate-v2-render.log')
assert film['frames']==782 and (OUT/'ultimate-v2-demo.mp4').stat().st_size>1_000_000
for shot in film['shots']:assert (OUT/f'ultimate-v2-{shot}.png').exists()
assets=ROOT/'prototype/assets/ultimates-v2'
files=[]
for name,source in [('star-fist.png','exec-7c84fbe5-4469-4d10-9a78-27c65b4efd9a.png'),('root-crown.png','exec-69f28d74-c432-4ffe-9011-ae250e7ce18f.png')]:
    path=assets/name
    with Image.open(path) as im:
        assert im.mode=='RGBA'
        dimensions=im.size
        assert im.getchannel('A').getextrema()[0]==0
    files.append({'file':name,'generated_source':source,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'dimensions':dimensions,'frames':8,'transparent':True,'pixel_edits':False})
source={'date':'2026-10-29','generator':'OpenAI built-in image generation','origin':'original commissioned game VFX; no franchise assets','prompts':'PROMPTS.md','files':files,'runtime_notes':'Root crown uses individual atlas rectangles. Cel shader feathers overflow at cell edges. PNG files are unmodified tool outputs.'}
(assets/'SOURCE.json').write_text(json.dumps(source,ensure_ascii=False,indent=2),encoding='utf-8')
before=json.loads((OUT/'design-combat-probe-before-remediation.json').read_text(encoding='utf-8'))
after=json.loads((OUT/'design-combat-probe-after-remediation.json').read_text(encoding='utf-8'))
assert len(before['results'])==8 and len(after['results'])==8
data={'date':'2026-10-29','functional_checks':sum(item['checks'] for item in verified),'failures':0,'suites':verified,'resources':resources,'campaign':balance,'new_player':new_player,'film':film,'video_bytes':(OUT/'ultimate-v2-demo.mp4').stat().st_size,'diagnostic_comparison':{'before':'design-combat-probe-before-remediation.json','after':'design-combat-probe-after-remediation.json','limits':'isolated normal-damage diagnostic; no jump/dash/ultimate; not a human playtest'},'user_profile_modified':False,'real_files_recycled':False,'physical_controller_tested':False,'remaining':['Specific new skins, art adapters and pricing await user materials.','Four wave arenas remain; no long exploration routes in this revision.','Human difficulty and physical-controller playtests remain.']}
(OUT/'remediation-delivery.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
p=ROOT/'README.md';s=p.read_text(encoding='utf-8').replace('共13场遭遇','共14场遭遇').replace('Lv.2后按U使用碎片冲击','Lv.2后按U使用星核巨拳')
s=s.replace('L/Shift闪避；','L/Shift闪避，E场地交互；')
p.write_text(s,encoding='utf-8')
print(json.dumps({'checks':data['functional_checks'],'failures':0,'resources':resources['checked'],'campaign_clears':len(balance['runs']),'level_one_clear':new_player['all_won'],'video_seconds':film['duration'],'video_bytes':data['video_bytes']},ensure_ascii=False))
