"""Record a real Godot HUD state presentation in an isolated, hidden GPU process."""
from pathlib import Path
import argparse
import json
import subprocess
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'prototype'
ARTIFACTS = PROJECT / 'artifacts'
FRAMES = ARTIFACTS / 'hud-demo-frames'
OUTPUT = ARTIFACTS / 'hud-demo.mp4'
ENGINE = ROOT / 'tools/Godot_v4.7.2-stable_win64.exe'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--encode-only', action='store_true')
    args = parser.parse_args()
    if not args.encode_only:
        FRAMES.mkdir(parents=True, exist_ok=True)
        assert FRAMES.resolve().parent == ARTIFACTS.resolve()
        for frame in FRAMES.glob('frame_?????.jpg'):
            frame.unlink()
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
        command = [str(ENGINE), '--path', str(PROJECT), '--fixed-fps', '30',
                   '--log-file', str(ARTIFACTS / 'hud-demo-engine.log'),
                   '--', '--slice-test', '--hud-film']
        print('Capturing real GPU HUD frames...', flush=True)
        with (ARTIFACTS / 'hud-demo-capture.log').open('w', encoding='utf-8') as log:
            subprocess.run(command, cwd=PROJECT, startupinfo=startup,
                           creationflags=subprocess.CREATE_NO_WINDOW,
                           stdout=log, stderr=subprocess.STDOUT,
                           timeout=120, check=True)
    metadata = json.loads((ARTIFACTS / 'hud-demo-metadata.json').read_text(encoding='utf-8'))
    frames = sorted(FRAMES.glob('frame_?????.jpg'))
    if len(frames) != metadata['frames']:
        raise RuntimeError(f"Expected {metadata['frames']} frames, found {len(frames)}")
    command = [imageio_ffmpeg.get_ffmpeg_exe(), '-hide_banner', '-y',
               '-framerate', str(metadata['fps']), '-i', str(FRAMES / 'frame_%05d.jpg'),
               '-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
               '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(OUTPUT)]
    print(f"Encoding {len(frames)} frames ({metadata['duration_seconds']:.3f} seconds)...", flush=True)
    with (ARTIFACTS / 'hud-demo-encode.log').open('w', encoding='utf-8') as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=90, check=True)
    print(f'Saved {OUTPUT} ({OUTPUT.stat().st_size:,} bytes)', flush=True)


if __name__ == '__main__':
    main()
