"""Capture the real Godot menu at fixed 30 FPS and encode its native frames.

Usage: python file-feeder/tools/render_menu_film.py [--encode-only]
Only the newly created menu-v2-demo artifact family is written.
"""
from pathlib import Path
import argparse
import json
import subprocess
import sys

import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "prototype"
ARTIFACTS = PROJECT / "artifacts"
FRAMES = ARTIFACTS / "menu-v2-demo-frames"
ENGINE = ROOT / "tools/Godot_v4.7.2-stable_win64.exe"
METADATA = ARTIFACTS / "menu-v2-demo-metadata.json"
OUTPUT = ARTIFACTS / "menu-v2-demo.mp4"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--encode-only", action="store_true")
    args = parser.parse_args()
    if not args.encode_only:
        FRAMES.mkdir(parents=True, exist_ok=True)
        assert FRAMES.resolve().parent == ARTIFACTS.resolve()
        # These are this recorder's numbered intermediates, never user assets.
        for image in FRAMES.glob("frame_?????.jpg"):
            image.unlink()
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
        command = [
            str(ENGINE), "--path", str(PROJECT), "--fixed-fps", "30",
            "--log-file", str(ARTIFACTS / "menu-v2-demo-engine.log"),
            "--", "--slice-test", "--menu-film",
        ]
        print("Capturing real Godot viewport frames at 30 FPS…", flush=True)
        with (ARTIFACTS / "menu-v2-demo-capture.log").open("w", encoding="utf-8") as log:
            subprocess.run(command, cwd=PROJECT, startupinfo=startup,
                           creationflags=subprocess.CREATE_NO_WINDOW,
                           stdout=log, stderr=subprocess.STDOUT,
                           timeout=180, check=True)
    metadata = json.loads(METADATA.read_text(encoding="utf-8"))
    actual_frames = sorted(FRAMES.glob("frame_?????.jpg"))
    if len(actual_frames) != metadata["frames"]:
        raise RuntimeError(f"Expected {metadata['frames']} GPU frames; found {len(actual_frames)}")
    print(f"Encoding {len(actual_frames)} native frames ({metadata['duration_seconds']:.3f} s)…", flush=True)
    offset_ms = round(metadata["audio_offset_seconds"] * 1000)
    audio = PROJECT / "assets/menu-v2/pet/original-laugh.wav"
    command = [
        imageio_ffmpeg.get_ffmpeg_exe(), "-hide_banner", "-y",
        "-framerate", str(metadata["fps"]), "-i", str(FRAMES / "frame_%05d.jpg"),
        "-i", str(audio),
        "-filter_complex", f"[1:a]adelay={offset_ms}:all=1,apad[a]",
        "-map", "0:v:0", "-map", "[a]",
        "-vf", "scale=in_range=pc:out_range=tv:out_color_matrix=bt709,format=yuv420p",
        "-c:v", "libx264", "-preset", "medium", "-crf", "19",
        "-pix_fmt", "yuv420p", "-color_range", "tv", "-colorspace", "bt709",
        "-color_primaries", "bt709", "-color_trc", "bt709",
        "-c:a", "aac", "-b:a", "160k",
        "-shortest", "-movflags", "+faststart", str(OUTPUT),
    ]
    with (ARTIFACTS / "menu-v2-demo-encode.log").open("w", encoding="utf-8") as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=120, check=True)
    print(f"Saved {OUTPUT} ({OUTPUT.stat().st_size:,} bytes)", flush=True)
    print(f"Original laugh audio offset: {metadata['audio_offset_seconds']:.3f} s", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Menu film failed: {error}", file=sys.stderr)
        raise
