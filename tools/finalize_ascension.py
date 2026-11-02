from pathlib import Path
import json,re,hashlib
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'prototype/artifacts'
SUITES={
 'ascension-base-gpu':38,'ascension-reaction':112,'ascension-remediation':83,
 'ascension-campaign':78,'ascension-foe-vfx':160,'ascension-wallet':60,
 'ascension-shop':26,'ascension-ultimate':40,'ascension-hud':36,
 'ascension-review':133,'ascension-store':14,'ascension-jelly':24,
 'ascension-resources':117,
}
records=[]
for tag,expected in SUITES.items():
    log=OUT/(tag+'.log')
    text=log.read_text(encoding='utf-8')
    assert 'ERROR:' not in text,(tag,text[-2000:])
    matches=re.findall(r'(?:CHECKS|REVIEW|RESOURCES)\s+(\d+)\s+failures=(\d+)',text)
    assert matches and int(matches[-1][0])==expected and int(matches[-1][1])==0,(tag,matches)
    records.append({'suite':tag,'checked':expected,'failed':0,'log':str(log.relative_to(ROOT)).replace('\\','/')})
balance=json.loads((OUT/'ascension-balance.json').read_text(encoding='utf-8'))
assert balance['all_won'] and len(balance['runs'])==12
assert not balance['invulnerability_override'] and not balance['energy_override']
film=json.loads((OUT/'ascension-film.json').read_text(encoding='utf-8'))
assert film['frames']==940 and film['real_gpu_renderer']
assert 'ERROR:' not in (OUT/'ascension-render.log').read_text(encoding='utf-8')
video=OUT/'ascension-demo.mp4'
assert video.stat().st_size>1000000
assets=ROOT/'prototype/assets/ascension'
manifest=json.loads((assets/'manifest.json').read_text(encoding='utf-8'))
for name,entry in manifest['assets'].items():
    assert hashlib.sha256((assets/name).read_bytes()).hexdigest()==entry['sha256'],name
production=json.loads((assets/'production.json').read_text(encoding='utf-8'))
production['reference_image']='C:/Users/Sherlock Holmes/Documents/xwechat_files/wxid_7c9cc4tn7uvf22_e63d/temp/RWTemp/2026-10/9e20f478899dc29eb19741386f9343c8/b2d75802870796d1db8271d56d952d91.png'
production['refinement_prompts']={
 'hero/combat-clean.png': 'Production cleanup of attached GAME SPRITE SHEET. Keep exactly the same yellow horned creature design, cream belly, green eyes, one giant obsidian purple-cracked claw arm, torn dark loincloth. Create FOUR complete poses arranged in a precise TWO columns TWO rows grid on a TRUE transparent background. Pose 0 calm right-facing combat guard, pose 1 forceful horizontal giant claw punch to right, pose 2 overhead giant claw ground slam, pose 3 upright fierce roaring energy channel with giant claw raised diagonally up. CRITICAL: all four characters completely inside their own square cell with a very large EMPTY transparent gutter of at least 15 percent on ALL FOUR SIDES of EACH cell. Every horn, giant claw tip and foot must fit fully. All feet on the same relative baseline 85 percent down each cell; same scale for all four bodies; do not stretch. No lighting backdrop, no gray, no orange glow, no floor shadow, no aura, no opaque background, no text. Just four isolated crisp fully cut-out full body characters. Redesign composition to be smaller within cells so limbs never cross cell borders. Square overall sheet.',
 'bosses/zhuyin-clean.png': 'Production cleanup of attached GAME SPRITE SHEET. Keep this original red black coiled mythic serpent god, angular jade monstrous mask face, antler horns, dark layered scales with subtle violet seams. Create FOUR complete poses arranged in precise TWO columns TWO rows square grid on a TRUE transparent background. All face LEFT. Pose 0 alert calm coiled idle; pose 1 arching head back windup and coiled body compressed; pose 2 leftward extended serpent strike roaring; pose 3 tall intimidating open mouth eclipse channel. All full coiled body, tail, horns completely visible inside EACH cell, with at least 15 percent transparent empty margins on ALL FOUR sides of EACH cell, never crossing cell boundaries. Body rendered same scale and stable coil ground baseline 85 percent down each cell. No background, no glow backdrop, no floor shadows, no VFX, no text. Matte rich game-ready 3D illustration matching design.'
}
production['research_only']=['https://godotengine.org/asset-library/asset/5564','https://godotengine.org/asset-library/asset/5496']
(assets/'production.json').write_text(json.dumps(production,ensure_ascii=False,indent=2),encoding='utf-8')
result={
 'delivery_date_local':'2026-10-30','default_scene':'res://v6/slice.tscn',
 'stages':12,'maps':4,'new_mythic_bosses':4,'functional_checks':804,
 'resource_loads':117,'all_checks_passed':True,'suites':records,
 'balance':{'all_won':True,'stages':12,'starting_level_each_stage':5,'initial_energy':0,'invulnerability_override':False,'energy_override':False,'bot_reads_telegraphs':True,'evidence':'prototype/artifacts/ascension-balance.json'},
 'film':film,'video':'prototype/artifacts/ascension-demo.mp4',
 'video_sha256':hashlib.sha256(video.read_bytes()).hexdigest(),
 'art_source_files':len(manifest['assets']),'source_pixels_modified':False,
 'sources':'prototype/assets/ascension/production.json',
 'asset_manifest':'prototype/assets/ascension/manifest.json',
 'launcher':'试玩魔神觉醒.cmd','preview_saves_formal_profile':False,
 'limits':['2D complete-pose sprite animation, not a newly rigged 3D character.','Automated Lv.5 clear runs are not human difficulty/fun validation.','No cross-hardware performance certification.']
}
(OUT/'ascension-delivery.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'checks':804,'resources':117,'stages_won':12,'film_seconds':film['seconds'],'video_bytes':video.stat().st_size,'manifest':'prototype/artifacts/ascension-delivery.json'},ensure_ascii=False))
