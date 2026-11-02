from pathlib import Path
import subprocess,json,imageio_ffmpeg,re

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'prototype/artifacts'
AVI=OUT/'rift-v4-capture.avi'
cmd=[str(ROOT/'tools/Godot_v4.7.2-stable_win64.exe'),'--path',str(ROOT/'prototype'),'--resolution','1280x800','--position','-32000,-32000','--write-movie',str(AVI),'--fixed-fps','30','--disable-vsync','--','--slice-test','--rift-film']
with (OUT/'rift-render.log').open('w',encoding='utf-8') as log:
    subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=270,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
text=(OUT/'rift-render.log').read_text(encoding='utf-8')
assert 'ERROR:' not in text,text[-6000:]
meta=json.loads((OUT/'rift-film.json').read_text(encoding='utf-8'))
meta['last_process_frame']=meta['frames']
meta['frames']=int(re.search(r'(\d+) frames at 30 FPS',text).group(1))
meta['seconds']=meta['frames']/30
(OUT/'rift-film.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
with (OUT/'rift-encode.log').open('w',encoding='utf-8') as log:
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-y','-i',str(AVI),'-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart',str(OUT/'rift-v4-demo.mp4')],stdout=log,stderr=subprocess.STDOUT,timeout=100,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
assert AVI.resolve().parent==OUT.resolve() and AVI.name=='rift-v4-capture.avi'
AVI.unlink()
print(json.dumps(meta,ensure_ascii=False))
