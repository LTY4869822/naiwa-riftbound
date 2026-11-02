from pathlib import Path
import hashlib,json,re,subprocess
import numpy as np
import imageio_ffmpeg

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'prototype/artifacts'
def read(name): return json.loads((OUT/name).read_text(encoding='utf-8-sig'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
assert read('rift-checks.json')=={'checks':40,'failures':[]}
assert read('loop-checks.json')['failures']==[]
tests=[('rift-review.log',40,'RIFT_CHECKS 40 failures=0'),('rift-core-regression.log',122,'LOOP_CHECKS 122 failures=0'),('rift-hud.log',36,'HUD_CHECKS 36 failures=0'),('rift-loot-regression.log',17,'LOOT_CHECKS 17 failures=0'),('rift-shop.log',27,'SHOP_UI_CHECKS 27 failures=0')]
for name,count,marker in tests:
    text=(OUT/name).read_text(encoding='utf-8-sig')
    assert marker in text and 'ERROR:' not in text, name
resources=read('remediation-resources.json')
assert resources['checked']==157 and not resources['failed']
ai=read('rift-ai.json')
assert ai['all_six'] and len(ai['runs'])==8
assert len({tuple(r['history']) for r in ai['runs']})>3
render=(OUT/'rift-render.log').read_text(encoding='utf-8')
assert 'ERROR:' not in render
dimensions=re.search(r'recording movie in (\d+)×(\d+) @ 30 FPS',render)
assert dimensions
resolution=[int(dimensions.group(1)),int(dimensions.group(2))]
assert resolution[0]>=960 and resolution[1]>=600
film=read('rift-film.json')
film['resolution']=resolution
assert film['frames']==1055 and len(film['shots'])==11
video=OUT/'rift-v4-demo.mp4'
ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
decoded=subprocess.run([ffmpeg,'-v','error','-i',str(video),'-vn','-f','f32le','-ac','1','-ar','48000','-'],capture_output=True,check=True)
samples=np.frombuffer(decoded.stdout,dtype='<f4')
peak=float(np.max(np.abs(samples)))
assert len(samples)>48000*35 and .001<peak<.99
audio={'seconds':len(samples)/48000,'peak_dbfs':float(20*np.log10(peak)),'real_engine_movie_audio':True}
assets=ROOT/'prototype/assets/rift-v4'
manifest=json.loads((assets/'manifest.json').read_text(encoding='utf-8'))
assert len(manifest)==6 and all(len(d['frames'])==8 for d in manifest.values())
for key in manifest: assert sha(assets/(key+'.png'))==manifest[key]['sha256']
files=list((ROOT/'prototype/rift').glob('*.gd*'))+list(assets.glob('*.png'))+[assets/'production.json',assets/'manifest.json',ROOT/'prototype/v6/main.gd',ROOT/'prototype/v6/fighter.gd',ROOT/'prototype/v5/enemy.gd',ROOT/'prototype/loop/boss_brain.gd',ROOT/'prototype/loop/journey.gd',video]
data={'version':'rift-bosses-2026-10-30','entry':'prototype/v6/slice.tscn','launcher':'试玩裂界荒神.cmd','documentation':'docs/RIFT_2026-10-30.md','tests':[{'log':f,'passed':n} for f,n,m in tests],'assertions_passed':sum(n for f,n,m in tests),'resources':resources,'ai_observation':ai,'balance_observation':read('rift-balance.json'),'film':film,'audio':audio,'asset_sheets':6,'authored_frames':48,'formal_records_written_by_checks':False,'limits':['AI observation sets phase three and an invulnerable target; it proves repertoire and varied decisions, not difficulty balance.','Four unmodified-damage automated map attempts did not clear a whole map.','Movie deliberately stages phase thresholds, named actions and room clear; hero animation has seeded energy. Not a full playthrough.','Long-term human feel and hardware performance are not established by these checks.'],'sha256':{str(p.relative_to(ROOT)).replace('\\','/'):sha(p) for p in files}}
(OUT/'rift-delivery.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'passed':data['assertions_passed'],'resources':157,'ai_profiles_with_six_moves':8,'authored_frames':48,'video_seconds':film['seconds'],'audio_peak_dbfs':audio['peak_dbfs']},ensure_ascii=False))
