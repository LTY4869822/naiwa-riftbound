"""Verify the current combat-presentation delivery, media, licenses and asset contract."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import wave

import imageio_ffmpeg
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'prototype'
OUT = PROJECT / 'artifacts'


def read(name):
    return json.loads((OUT / name).read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


checks = read('punch-checks.json')
assert checks['checks'] == 56 and not checks['failures']
expected = {'punch-review.log': ('PUNCH_CHECKS', 56),
            'punch-smoke.log': ('V6_CHECKS', 38),
            'punch-rift-regression.log': ('RIFT_CHECKS', 40),
            'punch-ultimate-regression.log': ('ULTIMATE_CHECKS', 40),
            'punch-loop-regression.log': ('LOOP_CHECKS', 162)}
for name, (marker, count) in expected.items():
    log = (OUT / name).read_text(encoding='utf-8-sig')
    assert f'{marker} {count} failures=0' in log, name
    assert 'SCRIPT ERROR' not in log and '\nERROR:' not in log, name
for name in ['punch-resources.log', 'punch-film.log']:
    log = (OUT / name).read_text(encoding='utf-8-sig')
    assert 'SCRIPT ERROR' not in log and '\nERROR:' not in log, name
resources = read('remediation-resources.json')
assert resources == {'checked': 232, 'failed': []}
manifest = json.loads((PROJECT / 'assets/pixelfx/manifest.json').read_text(encoding='utf-8'))
assert len(manifest) == 7
asset_checks = []
for key, asset in manifest.items():
    for layer, digest in [('file', 'sha256'), ('light', 'light_sha256')]:
        path = PROJECT / asset[layer].removeprefix('res://')
        assert sha(path) == asset[digest], path
        with Image.open(path) as img:
            assert img.mode == 'RGBA'
            for x, y, w, h in asset['frames']:
                assert 0 <= x < x + w <= img.width and 0 <= y < y + h <= img.height
            x, y, w, h = asset['frames'][-1]
            assert img.crop((x, y, x + w, y + h)).getchannel('A').getextrema() == (0, 0), (key, layer)
    assert asset['fps'] == 30
    asset_checks.append({'effect': key, 'frames': len(asset['frames']), 'last_frame_empty': True})
assert sum(x['frames'] for x in asset_checks) == 244
license_text = (PROJECT / 'assets/pixelfx/LICENSE.txt').read_text(encoding='utf-8')
assert '2026 Patch' in license_text and '2026 Hugo Duprez' in license_text
audio_sources = list((PROJECT / 'assets/pixelfx/audio').glob('*.wav'))
assert len(audio_sources) == 12
for path in audio_sources:
    with wave.open(str(path)) as f:
        assert f.getframerate() == 48000 and f.getnchannels() == 1
        raw = np.frombuffer(f.readframes(f.getnframes()), dtype='<i2') / 32768.0
        assert .01 < np.max(np.abs(raw)) < .80
video = OUT / 'pixelfx-impact-demo.mp4'
metadata = read('punch-video.json')
assert metadata['sha256'] == sha(video)
assert metadata['duration'] == 15 and metadata['audio_codec'] == 'aac' and metadata['fps'] == 30
decoded = subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-v', 'error', '-i', str(video),
                          '-vn', '-f', 'f32le', '-ac', '1', '-ar', '48000', '-'],
                         capture_output=True, check=True)
audio = np.frombuffer(decoded.stdout, dtype='<f4')
peak = float(np.max(np.abs(audio)))
assert len(audio) >= 15 * 48000 and .001 < peak < .99
historical = (OUT / 'punch-ascension-regression.log').read_text(encoding='utf-8-sig')
assert 'ASCENSION_CHECKS 134 failures=14' in historical
screenshots = sorted(p.name for p in OUT.glob('punch-film-*.png'))
assert len(screenshots) == 7
files = [*list((PROJECT / 'punch').glob('*.gd')), PROJECT / 'punch/flash.gdshader',
         PROJECT / 'v6/main.gd', PROJECT / 'v6/stage.gd', PROJECT / 'v6/effects.gd',
         PROJECT / 'v5/enemy.gd', PROJECT / 'rift/director.gd', PROJECT / 'foe_vfx/director.gd',
         PROJECT / 'combat/ultimate.gd', PROJECT / 'ascension/power.gd',
         PROJECT / 'campaign/boss_fields.gd', ROOT / 'tools/export_pixelfx.mjs',
         ROOT / 'tools/make_impact_audio.py', video]
data = {
    'version': 'pixelfx-impact-2026-10-31', 'entry': 'prototype/v6/slice.tscn',
    'launcher': '试玩打击感升级.cmd', 'documentation': 'docs/PIXELFX_IMPACT_2026-10-31.md',
    'assertions_passed': sum(count for _, count in expected.values()),
    'tests': {marker: count for marker, count in expected.values()}, 'resources': resources,
    'upstream': json.loads((ROOT / 'production/pixelfx/source.json').read_text(encoding='utf-8')),
    'upstream_contract': {'recipes': 5, 'failures': 0, 'warnings': 0,
                          'log': 'production/pixelfx/upstream-checks.log'},
    'assets': asset_checks, 'color_light_atlas_pairs': 7, 'audio_takes': 12,
    'video': metadata, 'film': read('punch-film.json'), 'screenshots': screenshots,
    'audio': {'seconds': len(audio) / 48000, 'peak_dbfs': float(20 * np.log10(peak))},
    'formal_records_written_by_checks': False,
    'historical_check': {'script': 'ascension/review.gd', 'checks': 134, 'failures': 14,
        'counted_as_passing': False,
        'reason': 'Obsolete early rules: six-kill awakening, free healing, old finisher multipliers and old route buttons. Current rules are covered by loop/review.gd and punch/review.gd.',
        'log': 'punch-ascension-regression.log'},
    'limits': ['Movie uses staged high-health sparring targets, a seeded field and direct evade hook.',
               'No full playthrough or multi-device performance claim.',
               'Visual and gain checks do not establish subjective audio quality on every speaker.'],
    'sha256': {p.relative_to(ROOT).as_posix(): sha(p) for p in files},
}
(OUT / 'punch-delivery.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
intermediate = OUT / 'punch-capture.avi'
if intermediate.exists():
    assert intermediate.resolve().parent == OUT.resolve()
    intermediate.unlink()
print(json.dumps({'assertions_passed': data['assertions_passed'], 'resources': resources,
                  'effect_frames': 244, 'movie_peak_dbfs': data['audio']['peak_dbfs']}, ensure_ascii=False))
