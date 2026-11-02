"""Capture and encode the actual Godot enemy attack presentation."""
from pathlib import Path
import json
import subprocess
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT/'prototype'
ARTIFACTS = PROJECT/'artifacts'
FRAMES = ARTIFACTS/'enemy-demo-frames'

def main():
    FRAMES.mkdir(parents=True, exist_ok=True)
    assert FRAMES.resolve().parent == ARTIFACTS.resolve()
    for frame in FRAMES.glob('frame_?????.jpg'): frame.unlink()
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    command = [str(ROOT/'tools/Godot_v4.7.2-stable_win64.exe'), '--path',str(PROJECT),
               '--position','-32000,-32000','--fixed-fps','30',
               '--log-file',str(ARTIFACTS/'enemy-demo-engine.log'),
               '--','--slice-test','--enemy-film']
    with (ARTIFACTS/'enemy-demo-capture.log').open('w',encoding='utf-8') as log:
        subprocess.run(command,cwd=PROJECT,startupinfo=startup,creationflags=subprocess.CREATE_NO_WINDOW,
                       stdout=log,stderr=subprocess.STDOUT,timeout=100,check=True)
    metadata=json.loads((ARTIFACTS/'enemy-demo-metadata.json').read_text(encoding='utf-8'))
    assert len(list(FRAMES.glob('frame_?????.jpg')))==metadata['frames']
    output=ARTIFACTS/'enemy-demo.mp4'
    command=[imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-y','-framerate','30',
             '-i',str(FRAMES/'frame_%05d.jpg'),'-c:v','libx264','-preset','medium',
             '-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(output)]
    with (ARTIFACTS/'enemy-demo-encode.log').open('w',encoding='utf-8') as log:
        subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=90,check=True)
    print(f"Saved {output}: {metadata['frames']} frames, {metadata['duration_seconds']} seconds, {output.stat().st_size} bytes")
    # Only our generated frames; retain the movie, key shots and metadata.
    for frame in FRAMES.glob('frame_?????.jpg'): frame.unlink()
    if not any(FRAMES.iterdir()): FRAMES.rmdir()

if __name__=='__main__': main()
