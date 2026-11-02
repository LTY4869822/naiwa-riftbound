"""Keep the independent comparison scene on the canonical v5 character rig."""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
source = (root / "prototype/v5/naiwa.gd").read_text(encoding="utf-8")
for old, new in {
    "res://assets/naiwa/idle.png": "res://assets/naiwa-original.png",
    "res://assets/v4/naiwa-underpaint.png": "res://assets/torso-underpaint.png",
    "res://v5/cutout.gdshader": "res://cutout.gdshader",
    "res://assets/naiwa/blink_": "res://assets/blink_",
    "const SIZE := 0.72": "const SIZE := 0.86",
}.items():
    source = source.replace(old, new)
(root / "animation-lab/rig.gd").write_text(source, encoding="utf-8")
for image in (root / "prototype/assets/naiwa").glob("blink_0_*.png"):
    shutil.copy2(image, root / "animation-lab/assets" / image.name)
print("Synced v5 rig and original blink textures to the independent animation lab.")
