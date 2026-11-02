from pathlib import Path
import subprocess,json,imageio_ffmpeg,hashlib
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'prototype/artifacts'
avi=OUT/'biomes-v5-capture.avi'
cmd=[str(ROOT/'tools/Godot_v4.7.2-stable_win64.exe'),'--path',str(ROOT/'prototype'),'--position','-32000,-32000','--write-movie',str(avi),'--fixed-fps','30','--disable-vsync','--','--slice-test','--biome-film']
with (OUT/'biomes-film.log').open('w',encoding='utf-8') as log:
 result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW,timeout=240)
text=(OUT/'biomes-film.log').read_text(encoding='utf-8',errors='replace')
print(text[-2500:])
assert result.returncode==0 and 'SCRIPT ERROR' not in text and '\nERROR:' not in text,'movie runtime failed'
ff=imageio_ffmpeg.get_ffmpeg_exe()
mp4=OUT/'biomes-v5-demo.mp4'
subprocess.run([ff,'-y','-loglevel','error','-i',str(avi),'-c:v','libx264','-crf','20','-preset','fast','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',str(mp4)],check=True)
reader=imageio_ffmpeg.read_frames(str(mp4));meta=next(reader);reader.close()
meta['sha256']=hashlib.sha256(mp4.read_bytes()).hexdigest()
(OUT/'biomes-video.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
print(json.dumps(meta))
