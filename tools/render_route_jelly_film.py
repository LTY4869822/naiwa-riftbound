"""Record the real level-map animations in the Compatibility renderer."""
from pathlib import Path
import json, subprocess
import imageio_ffmpeg

ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT/'prototype'
OUT=PROJECT/'artifacts'
FRAMES=OUT/'route-jelly-demo-frames'

def main():
    FRAMES.mkdir(exist_ok=True)
    assert FRAMES.resolve().parent==OUT.resolve()
    for path in FRAMES.glob('frame_?????.jpg'): path.unlink()
    startup=subprocess.STARTUPINFO()
    startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow=0
    command=[str(ROOT/'tools/Godot_v4.7.2-stable_win64.exe'),'--path',str(PROJECT),
        '--position','-32000,-32000','--fixed-fps','60',
        '--log-file',str(OUT/'route-jelly-demo-engine.log'),
        '--','--bridge-check','--route-jelly-film']
    with (OUT/'route-jelly-demo-capture.log').open('w',encoding='utf-8') as log:
        subprocess.run(command,cwd=PROJECT,startupinfo=startup,
            creationflags=subprocess.CREATE_NO_WINDOW,stdout=log,
            stderr=subprocess.STDOUT,timeout=55,check=True)
    metadata=json.loads((OUT/'route-jelly-demo-metadata.json').read_text(encoding='utf-8'))
    assert len(list(FRAMES.glob('frame_?????.jpg')))==metadata['frames']
    movie=OUT/'route-jelly-demo.mp4'
    command=[imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-y','-framerate','60',
        '-i',str(FRAMES/'frame_%05d.jpg'),'-c:v','libx264','-preset','medium','-crf','18',
        '-pix_fmt','yuv420p','-movflags','+faststart',str(movie)]
    with (OUT/'route-jelly-demo-encode.log').open('w',encoding='utf-8') as log:
        subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=45,check=True)
    for path in FRAMES.glob('frame_?????.jpg'): path.unlink()
    if not any(FRAMES.iterdir()): FRAMES.rmdir()
    print(f'{movie}: {metadata["frames"]} frames / {metadata["duration_seconds"]} seconds / {movie.stat().st_size} bytes')

if __name__=='__main__': main()
