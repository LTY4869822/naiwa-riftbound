from pathlib import Path
import subprocess,json
import imageio_ffmpeg
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'prototype/artifacts'
FRAMES=OUT/'ultimate-v2-frames'
FRAMES.mkdir(exist_ok=True)
assert FRAMES.resolve().parent==OUT.resolve()
for p in FRAMES.glob('frame_?????.jpg'):p.unlink()
cmd=[str(ROOT/'tools/Godot_v4.7.2-stable_win64.exe'),'--path',str(ROOT/'prototype'),'--position','-32000,-32000','--fixed-fps','30','--','--slice-test','--remediation-film']
with (OUT/'ultimate-v2-render.log').open('w',encoding='utf-8') as log:
    subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=180,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
text=(OUT/'ultimate-v2-render.log').read_text(encoding='utf-8')
if any(token in text for token in ['SCRIPT ERROR:','SHADER ERROR:','ERROR:']):raise RuntimeError(text[-12000:])
meta=json.loads((OUT/'ultimate-v2-film.json').read_text(encoding='utf-8'))
assert meta['frames']==len(list(FRAMES.glob('frame_?????.jpg')))
with (OUT/'ultimate-v2-encode.log').open('w',encoding='utf-8') as log:
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-y','-framerate','30','-i',str(FRAMES/'frame_%05d.jpg'),'-vf','scale=1280:800','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/'ultimate-v2-demo.mp4')],stdout=log,stderr=subprocess.STDOUT,timeout=90,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
for p in FRAMES.glob('frame_?????.jpg'):p.unlink()
if not any(FRAMES.iterdir()):FRAMES.rmdir()
print(json.dumps(meta,ensure_ascii=False))
print('Saved',OUT/'ultimate-v2-demo.mp4')
