from pathlib import Path
import subprocess
import json
import imageio_ffmpeg
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'prototype/artifacts'
AVI = OUT/'loot-v3-capture.avi'
MP4 = OUT/'loot-v3-demo.mp4'
engine = ROOT/'tools/Godot_v4.7.2-stable_win64.exe'
cmd = [str(engine), '--path', str(ROOT/'prototype'), '--position', '-32000,-32000', '--write-movie', str(AVI), '--fixed-fps', '30', '--disable-vsync', '--', '--slice-test', '--loot-film']
with (OUT/'loot-v3-render.log').open('w', encoding='utf-8') as log:
    subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, timeout=180, check=True, creationflags=subprocess.CREATE_NO_WINDOW)
text = (OUT/'loot-v3-render.log').read_text(encoding='utf-8')
assert 'ERROR:' not in text, text[-5000:]
metadata = json.loads((OUT/'loot-v3-film.json').read_text(encoding='utf-8'))
assert len(metadata['events']) == 4
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
with (OUT/'loot-v3-encode.log').open('w', encoding='utf-8') as log:
    subprocess.run([ffmpeg, '-hide_banner', '-y', '-i', str(AVI), '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', str(MP4)], stdout=log, stderr=subprocess.STDOUT, timeout=90, check=True, creationflags=subprocess.CREATE_NO_WINDOW)
# Decode the real captured audio: confirm four separate audible pickups and silence before them.
decoded = subprocess.run([ffmpeg, '-v', 'error', '-i', str(MP4), '-vn', '-f', 'f32le', '-ac', '1', '-ar', '48000', '-'], capture_output=True, check=True)
samples = np.frombuffer(decoded.stdout, dtype='<f4')
assert len(samples)>48000*8 and np.isfinite(samples).all()
peak = float(np.max(np.abs(samples)))
assert .01 < peak < .96, peak
bins = np.array([np.sqrt(np.mean(part**2)) for part in np.array_split(samples,len(samples)//2400)])
active = bins > .001
onsets = np.flatnonzero(active & ~np.r_[False,active[:-1]])*.05
analysis = {'seconds': len(samples)/48000, 'peak_dbfs': float(20*np.log10(peak)), 'rms_dbfs': float(20*np.log10(np.sqrt(np.mean(samples*samples)))), 'audible_onsets_seconds': onsets.tolist(), 'engine_movie_audio': True, 'audio_not_post_dubbed': True}
assert len(onsets)>=4, analysis
(OUT/'loot-v3-audio-check.json').write_text(json.dumps(analysis,indent=2),encoding='utf-8')
assert AVI.resolve().parent==OUT.resolve() and AVI.name=='loot-v3-capture.avi'
AVI.unlink() # Remove only this tool's large intermediate movie after successful encoding/validation.
print(json.dumps({'film': metadata, 'audio': analysis}, ensure_ascii=False))
