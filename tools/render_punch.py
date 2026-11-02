from pathlib import Path
import hashlib
import json
import subprocess
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'prototype/artifacts'
avi = OUT / 'punch-capture.avi'
command = [str(ROOT / 'tools/Godot_v4.7.2-stable_win64.exe'), '--path', str(ROOT / 'prototype'),
           '--position=-32000,-32000', '--write-movie', str(avi), '--fixed-fps', '30',
           '--disable-vsync', '--', '--slice-test', '--punch-film']
with (OUT / 'punch-film.log').open('w', encoding='utf-8') as log:
    result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                            creationflags=subprocess.CREATE_NO_WINDOW, timeout=180)
text = (OUT / 'punch-film.log').read_text(encoding='utf-8', errors='replace')
print(text[-2000:])
assert result.returncode == 0 and 'SCRIPT ERROR' not in text and '\nERROR:' not in text
mp4 = OUT / 'pixelfx-impact-demo.mp4'
subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-v', 'error', '-i', str(avi),
                '-c:v', 'libx264', '-crf', '18', '-preset', 'fast', '-pix_fmt', 'yuv420p',
                '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', str(mp4)], check=True)
reader = imageio_ffmpeg.read_frames(str(mp4)); metadata = next(reader); reader.close()
metadata['sha256'] = hashlib.sha256(mp4.read_bytes()).hexdigest()
(OUT / 'punch-video.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
print(json.dumps(metadata))
