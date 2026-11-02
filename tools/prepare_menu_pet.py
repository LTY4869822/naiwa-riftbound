"""Preserve the complete original Naiwa laugh in the native-menu asset bank.

No character imagery is generated or repainted here. The original PNG bytes stay
inside the original archive; menu_pet.gd decodes only the current frames.
"""
from pathlib import Path
from zipfile import ZipFile
import hashlib
import json
import shutil
import struct

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "prototype/assets/menu-v2/pet"
SOURCE = ROOT / "desktop/素材.nwp"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    with ZipFile(SOURCE) as archive:
        metadata = json.loads(archive.read("metadata.json"))
        frames = int(metadata["frames"])
        size = (int(metadata["width"]), int(metadata["height"]))
        for index in range(frames):
            encoded = archive.read(f"laugh/{index:04d}.png")
            assert encoded[:8] == b"\x89PNG\r\n\x1a\n"
            assert struct.unpack(">II", encoded[16:24]) == size
        assert frames == 422 and float(metadata["fps"]) == 30
    shutil.copy2(SOURCE, DEST / "original-laugh.nwp")
    shutil.copy2(ROOT / "desktop/原版笑声.wav", DEST / "original-laugh.wav")
    shutil.copy2(ROOT / "desktop/LICENCE", DEST / "NAIWA-LICENCE.txt")
    manifest = {
        "source": "https://github.com/yugh6/Naiwa",
        "archive_source": "desktop/素材.nwp",
        "archive_sha256": sha256(SOURCE),
        "copied_archive_sha256": sha256(DEST / "original-laugh.nwp"),
        "audio_source": "desktop/原版笑声.wav",
        "audio_sha256": sha256(DEST / "original-laugh.wav"),
        "metadata": metadata,
        "complete_laugh_frames": frames,
        "complete_laugh_duration_seconds": frames / float(metadata["fps"]),
        "runtime_cache_limit_frames": 16,
        "orientation": "Original clip begins in a left-facing three-quarter stance, turns toward the camera while belly-laughing, then falls sideways. It is not an all-frontal animation.",
        "new_front_assets": ["front-idle.png", "front-laugh.png"],
        "new_front_assets_note": "Separate generated assets based on the user's turnaround; neither is represented as a complete frame sequence.",
        "playback": "Optional 0.48-second front-pose introduction, all 422 original frames at 30 FPS with the original audio, 0.8-second resting pose, then 0.5-second crossfade to frontal idle.",
    }
    (DEST / "original-motion.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Verified and preserved {frames} original PNG frames, {frames / 30:.6f} seconds at 30 FPS.")


if __name__ == "__main__":
    main()
