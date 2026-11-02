from pathlib import Path
import subprocess,json
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'prototype/artifacts'
cmd=[str(ROOT/'tools/Godot_v4.7.2-stable_win64.exe'),'--path',str(ROOT/'prototype'),'--','--slice-test','--biome-demo']
with (OUT/'biomes-live.log').open('w',encoding='utf-8') as log:
 process=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
record={'pid':process.pid,'command':cmd,'isolated':True,'entry':'four-map selector','shortcuts':'F1-F12 preview corresponding room'}
(OUT/'biomes-live.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(record,ensure_ascii=False))
