from pathlib import Path
import subprocess,json,imageio_ffmpeg
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'prototype/artifacts';FRAMES=OUT/'loop-frames'
FRAMES.mkdir(exist_ok=True)
assert FRAMES.resolve().parent==OUT.resolve()
for p in FRAMES.glob('frame_?????.jpg'):p.unlink()
cmd=[str(ROOT/'tools/Godot_v4.7.2-stable_win64.exe'),'--path',str(ROOT/'prototype'),'--position','-32000,-32000','--fixed-fps','30','--','--slice-test','--loop-film']
with (OUT/'loop-render.log').open('w',encoding='utf-8') as log:
 subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=180,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
t=(OUT/'loop-render.log').read_text(encoding='utf-8');assert 'ERROR:' not in t,t[-5000:]
meta=json.loads((OUT/'loop-film.json').read_text(encoding='utf-8'));assert len(list(FRAMES.glob('frame_?????.jpg')))==meta['frames']
with (OUT/'loop-encode.log').open('w',encoding='utf-8') as log:
 subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-y','-framerate','30','-i',str(FRAMES/'frame_%05d.jpg'),'-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/'loop-demo.mp4')],stdout=log,stderr=subprocess.STDOUT,timeout=90,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
for p in FRAMES.glob('frame_?????.jpg'):p.unlink()
if not any(FRAMES.iterdir()):FRAMES.rmdir()
print(json.dumps(meta,ensure_ascii=False))
