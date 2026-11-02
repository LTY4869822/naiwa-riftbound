"""Validate current artifacts and write a truthful delivery index."""
from pathlib import Path
import json,re,hashlib,shutil,subprocess
import numpy as np
import imageio_ffmpeg
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'prototype/artifacts'
def read(name): return json.loads((OUT/name).read_text(encoding='utf-8-sig'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
checks=read('biome-checks.json')
assert checks['checks']>=385 and not checks['failures']
assert checks['boss_count']==12 and checks['disjoint_minions']==12 and checks['save_isolated']
assert len({r['scene'] for r in checks['rooms']})==12
for room in checks['rooms']: assert (OUT/room['screenshot']).exists()
logs=['biomes-review.log','biomes-loop-regression.log','biomes-rift-regression.log','biomes-ai.log','biomes-boss-ai.log','biomes-resources.log','biomes-film.log']
for name in logs:
 text=(OUT/name).read_text(encoding='utf-8-sig')
 assert 'SCRIPT ERROR' not in text and '\nERROR:' not in text,name
assert read('loop-checks.json')['failures']==[] and read('loop-checks.json')['checks']==162
assert read('rift-checks.json')=={'checks':40,'failures':[]}
ai=read('biome-ai.json');assert ai['passed'] and len(ai['runs'])==36
boss_ai=read('rift-ai.json');assert boss_ai['all_six'] and len(boss_ai['runs'])==12
shutil.copy2(OUT/'rift-ai.json',OUT/'biome-boss-ai.json')
resources=read('remediation-resources.json');assert resources['checked']==190 and not resources['failed']
manifest=json.loads((ROOT/'prototype/assets/biomes-v5/manifest.json').read_text(encoding='utf-8'))
assert len(manifest)==24
for key,asset in manifest.items():
 path=ROOT/'prototype'/asset['file'].removeprefix('res://')
 assert path.exists() and sha(path)==asset['sha256'],key
 if key not in ['ledges'] and 'frames' in asset:
  assert len(asset['frames'])==8 and all(f['canvas_margin']>3 for f in asset['frames'])
video=OUT/'biomes-v5-demo.mp4'
ff=imageio_ffmpeg.get_ffmpeg_exe()
decoded=subprocess.run([ff,'-v','error','-i',str(video),'-vn','-f','f32le','-ac','1','-ar','48000','-'],capture_output=True,check=True)
audio=np.frombuffer(decoded.stdout,dtype='<f4')
peak=float(np.max(np.abs(audio)));assert len(audio)>44*48000 and .001<peak<.99
film=read('biome-film.json');assert len(film['scenes'])==12
source_files=list((ROOT/'prototype/biomes').glob('*.gd'))+[ROOT/'prototype/v6/main.gd',ROOT/'prototype/v5/enemy.gd',ROOT/'prototype/v5/foe_visual.gd',ROOT/'prototype/campaign/levels.gd',ROOT/'prototype/campaign/scenery.gd',ROOT/'prototype/remediation/arena.gd',ROOT/'prototype/loop/boss_brain.gd',video]
data={'version':'biomes-v5-2026-10-30','style':'User-selected bright cartoon fantasy, option one','entry':'prototype/v6/slice.tscn','launcher':'试玩幻彩四境.cmd','documentation':'docs/BIOMES_2026-10-30.md',
 'rooms':checks['rooms'],'bosses':12,'disjoint_minion_types':12,'new_character_sheets':11,'new_character_poses':88,'new_backgrounds':12,'platform_sprites':4,
 'assertions_passed':checks['checks']+162+40,'tests':{'biome_review':checks['checks'],'loop_regression':162,'rift_regression':40},'resources':resources,
 'ai_observation':{'minion_cases':36,'boss_profiles_with_six_moves':12,'files':['biome-ai.json','biome-boss-ai.json'],'invulnerable_target':True,'forced_regular_move_selection':False},
 'film':film,'video':read('biomes-video.json'),'audio':{'seconds':len(audio)/48000,'peak_dbfs':float(20*np.log10(peak))},
 'formal_records_written_by_checks':False,'limits':['Natural AI observations use invulnerable targets and staged room/phase fixtures.','The movie stages the full biome roster and explicitly starts middle-boss ultimates; it is not a normal playthrough.','No claim of completing all twelve rooms naturally or establishing long-term difficulty balance.'],
 'sha256':{str(p.relative_to(ROOT)).replace('\\','/'):sha(p) for p in source_files}}
(OUT/'biomes-delivery.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
avi=OUT/'biomes-v5-capture.avi'
if avi.exists():
 assert avi.resolve().parent==OUT.resolve()
 avi.unlink() # Only our validated, newly-created intermediate movie.
print(json.dumps({k:data[k] for k in ['assertions_passed','resources','bosses','disjoint_minion_types','new_backgrounds','new_character_poses']},ensure_ascii=False))
