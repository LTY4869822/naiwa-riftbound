"""Record all nine enemy identities and thirteen attacks in the real game renderer."""
from pathlib import Path
import argparse,json,subprocess
import imageio_ffmpeg
ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT/'prototype'
OUT=PROJECT/'artifacts'
FRAMES=OUT/'foe-vfx-demo-frames'

def main():
    global FRAMES
    parser=argparse.ArgumentParser()
    parser.add_argument('--tag',choices=['foe-vfx','toon-vfx'],default='foe-vfx')
    tag=parser.parse_args().tag
    FRAMES=OUT/(tag+'-demo-frames')
    FRAMES.mkdir(exist_ok=True)
    assert FRAMES.resolve().parent==OUT.resolve()
    for frame in FRAMES.glob('frame_?????.jpg'):frame.unlink()
    startup=subprocess.STARTUPINFO()
    startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow=0
    cmd=[str(ROOT/'tools/Godot_v4.7.2-stable_win64.exe'),'--path',str(PROJECT),
         '--position','-32000,-32000','--fixed-fps','30','--log-file',str(OUT/(tag+'-demo-engine.log')),
         '--','--slice-test','--foe-vfx-film']
    if tag=='toon-vfx':cmd.append('--toon-film')
    with (OUT/(tag+'-demo-capture.log')).open('w',encoding='utf-8') as log:
        subprocess.run(cmd,cwd=PROJECT,startupinfo=startup,creationflags=subprocess.CREATE_NO_WINDOW,
                       stdout=log,stderr=subprocess.STDOUT,timeout=150,check=True)
    diagnostics=(OUT/(tag+'-demo-capture.log')).read_text(encoding='utf-8')
    if any(marker in diagnostics for marker in ('SCRIPT ERROR:','SHADER ERROR:','ERROR:')):
        raise RuntimeError('The GPU capture contains engine errors; inspect the capture log before delivery.')
    metadata=json.loads((OUT/(tag+'-demo-metadata.json')).read_text(encoding='utf-8'))
    assert len(list(FRAMES.glob('frame_?????.jpg')))==metadata['frames']
    output=OUT/(tag+'-demo.mp4')
    cmd=[imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-y','-framerate','30','-i',str(FRAMES/'frame_%05d.jpg'),
         '-c:v','libx264','-preset','medium','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(output)]
    with (OUT/(tag+'-demo-encode.log')).open('w',encoding='utf-8') as log:
        subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=90,check=True)
    for frame in FRAMES.glob('frame_?????.jpg'):frame.unlink()
    if not any(FRAMES.iterdir()):FRAMES.rmdir()
    print(f"Saved {output}: {metadata['frames']} frames, {metadata['duration_seconds']:.2f}s, {output.stat().st_size} bytes")

if __name__=='__main__':main()
