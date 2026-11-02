from pathlib import Path
import hashlib
import json

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'prototype/artifacts'
def read(name): return json.loads((OUT/name).read_text(encoding='utf-8-sig'))
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
checks=read('loot-v3-checks.json')
core=read('loop-checks.json')
resources=read('remediation-resources.json')
film=read('loot-v3-film.json')
sound=read('loot-v3-audio-check.json')
assert checks['checks']==17 and not checks['failures']
assert core['checks']==122 and not core['failures']
assert resources['checked']==142 and not resources['failed']
for name in ['loot-v3-review.log','loot-v3-loop-regression.log','loot-v3-render.log','loot-v3-resources.log']:
    text=(OUT/name).read_text(encoding='utf-8-sig')
    assert 'ERROR:' not in text and 'SCRIPT ERROR:' not in text, name
assert film['coins_picked']==58 and film['heals_picked']==1 and film['hp']==101
assert [e['kind'] for e in film['events']]==['coin','coin','coin','heal']
assert len(sound['audible_onsets_seconds'])==4 and sound['peak_dbfs']<0
assets=ROOT/'prototype/assets/loot-v3'
manifest=json.loads((assets/'manifest.json').read_text(encoding='utf-8'))
assert len(manifest['coin']['frames'])==8 and len(manifest['potion']['frames'])==1
for key in manifest:
    assert digest(assets/(key+'.png'))==manifest[key]['sha256']
files=list((ROOT/'prototype/loot').glob('*.gd'))
files += [ROOT/'prototype/loop/journey.gd',ROOT/'prototype/v6/main.gd',OUT/'loot-v3-demo.mp4',assets/'production.json',assets/'manifest.json',assets/'audio/SOURCES.json']
data={
    'version':'loot-presentation-2026-10-30',
    'entry':'prototype/v6/slice.tscn',
    'launcher':'试玩拾取新版.cmd',
    'documentation':'docs/LOOT_PRESENTATION_2026-10-30.md',
    'checks':checks,'loop_regression':core,'resource_loads':resources,
    'film':film,'captured_audio_analysis':sound,
    'image_source':'Built-in image_gen, originals copied without pixel edits. Full prompts in assets/loot-v3/production.json.',
    'audio_source':'Kenney RPG Audio CC0 handleCoins / handleCoins2 + original synthesis. Full source/license and processing in assets/loot-v3/audio/.',
    'formal_records_written':False,
    'limits':['Demonstration field seeds collectibles; it is not a combat playthrough.','Audio was verified through real engine movie output and waveform checks; different hardware subjective mix remains a playtest matter.'],
    'sha256':{str(p.relative_to(ROOT)).replace('\\','/'):digest(p) for p in files}
}
(OUT/'loot-v3-delivery.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'pickup_checks':17,'core_regressions':122,'resources':142,'audible_pickups':4,'video_seconds':sound['seconds']}))
