"""Validate the double-jump / Zheng / relic UI delivery and index its evidence."""
from pathlib import Path
import hashlib
import json
import subprocess

import imageio_ffmpeg
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'prototype/artifacts'


def read(name):
    return json.loads((OUT / name).read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


checks = read('echo-checks.json')
assert checks['checks'] == 65 and not checks['failures']
for name in checks['images']:
    assert (OUT / name).is_file(), name
markers = {'echo-review.log': 'ECHO_CHECKS 65 failures=0',
           'echo-rift-regression.log': 'RIFT_CHECKS 40 failures=0',
           'echo-v6-regression.log': 'V6_CHECKS 38 failures=0',
           'echo-resources.log': 'REMEDIATION_RESOURCES 199 failures=0'}
for name in [*markers, 'echo-film.log']:
    log = (OUT / name).read_text(encoding='utf-8-sig')
    assert 'SCRIPT ERROR' not in log and '\nERROR:' not in log, name
    if name in markers:
        assert markers[name] in log, name
resources = read('remediation-resources.json')
assert resources == {'checked': 199, 'failed': []}
manifest = json.loads((ROOT / 'prototype/assets/echo-v6/manifest.json').read_text(encoding='utf-8'))
assert len(manifest) == 3
assert manifest['zheng-run']['scale'] == manifest['zheng-combat']['scale']
for key, count in [('zheng-run', 8), ('zheng-combat', 8), ('relic-emblems', 4)]:
    asset = manifest[key]
    path = ROOT / 'prototype' / asset['file'].removeprefix('res://')
    assert sha(path) == asset['sha256'], key
    assert len(asset['frames']) == count
    assert all(f['margin'] > 3 for f in asset['frames']), key
video = OUT / 'echo-v6-demo.mp4'
metadata = read('echo-video.json')
assert metadata['sha256'] == sha(video)
assert metadata['size'] == [1152, 720] and metadata['fps'] == 30
assert metadata['audio_codec'] == 'aac' and 13 < metadata['duration'] < 14
decoded = subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-v', 'error', '-i', str(video),
                          '-vn', '-f', 'f32le', '-ac', '1', '-ar', '48000', '-'],
                         capture_output=True, check=True)
audio = np.frombuffer(decoded.stdout, dtype='<f4')
peak = float(np.max(np.abs(audio)))
assert len(audio) > 13 * 48000 and .001 < peak < .99
source_files = [*list((ROOT / 'prototype/echo').glob('*.gd')),
                ROOT / 'prototype/echo/theme.json', ROOT / 'prototype/v6/main.gd',
                ROOT / 'prototype/v6/fighter.gd', ROOT / 'prototype/v6/effects.gd',
                ROOT / 'prototype/v5/battle_hud.gd', ROOT / 'prototype/v5/foe_visual.gd',
                ROOT / 'prototype/rift/director.gd', ROOT / 'prototype/rift/relic_menu.gd',
                ROOT / 'production/echo-v6-sources.json', video]
data = {
    'version': 'echo-v6', 'validated_on': '2026-10-31',
    'entry': 'prototype/v6/slice.tscn', 'launcher': '试玩二段跳与遗物.cmd',
    'documentation': 'docs/DOUBLE_JUMP_AND_ECHO_2026-10-30.md',
    'changes': ['Two jumps with landing recharge and momentum retention',
                'Dedicated eight-frame Zheng run cycle with shared uniform combat scale',
                'Ink ticket relic UI with original illustrations and native button interaction'],
    'assertions_passed': 143,
    'tests': {'echo_review': 65, 'rift_regression': 40, 'core_combat_regression': 38},
    'resources': resources,
    'assets': {'sheets': 3, 'run_frames': 8, 'combat_poses': 8, 'relic_illustrations': 4,
               'manifest': 'prototype/assets/echo-v6/manifest.json'},
    'screenshots': checks['images'], 'film': read('echo-film.json'),
    'video': metadata, 'encoded_movie_frames': 409,
    'audio': {'seconds': len(audio) / 48000, 'peak_dbfs': float(20 * np.log10(peak))},
    'formal_records_written_by_checks': False,
    'limits': ['Zheng uses full-frame 2D sprites, not skeletal animation.',
               'The movie stages two-direction tiger patrol with an invulnerable target; it is not a playthrough.',
               'The movie seeds one healing offer to show all four relic illustrations.',
               'Physical gamepad hardware was not tested.'],
    'sha256': {p.relative_to(ROOT).as_posix(): sha(p) for p in source_files},
}
(OUT / 'echo-delivery.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
intermediate = OUT / 'echo-v6-capture.avi'
if intermediate.exists():
    assert intermediate.resolve().parent == OUT.resolve()
    intermediate.unlink()
print(json.dumps({'assertions_passed': 143, 'resources': resources,
                  'video_seconds': metadata['duration'], 'audio_peak': peak}, ensure_ascii=False))
