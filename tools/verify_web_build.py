from pathlib import Path
import gzip
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / 'web/dist'
manifest = json.loads((DIST / 'game-manifest.json').read_text(encoding='utf-8'))
checked = []
for name, item in manifest['files'].items():
    digest = hashlib.sha256()
    total = 0
    for part in item['parts']:
        path = DIST / part['file']
        assert path.is_file() and path.stat().st_size == part['compressed_size']
        assert path.stat().st_size < 25 * 1024 * 1024
        data = gzip.decompress(path.read_bytes())
        assert len(data) == part['size']
        digest.update(data); total += len(data)
    assert total == item['size'] and digest.hexdigest() == item['sha256'], name
    checked.append({'file': name, 'bytes': total, 'sha256': item['sha256'], 'verified': True})
index = (DIST / 'index.html').read_text(encoding='utf-8')
for reference in re.findall(r'(?:src|href)="([^"]+)"', index):
    if not reference.startswith(('https:', 'http:', '#')):
        assert (DIST / reference.split('?')[0]).exists(), reference
for name in ['GODOT.txt', 'PIXELFX.txt', 'NOTO-OFL.txt']:
    assert (DIST / 'licenses' / name).is_file()
log = (ROOT / 'production/web-export.log').read_text(encoding='utf-8')
assert 'SCRIPT ERROR' not in log and '\nERROR:' not in log
main = (ROOT / 'production/web-project/v6/main.gd').read_text(encoding='utf-8')
assert '--punch-demo' not in main and 'call_deferred("run_checks")' not in main
assert 'ThemeDB.fallback_font=font' in main
report = {'edition': 'web-2026-10-31', 'export': 'Godot 4.7.2 official single-threaded release',
          'download_bytes': manifest['download_bytes'], 'files': checked,
          'native_game_modified': False, 'native_records_uploaded': False,
          'entry': 'normal main menu, no test mode', 'font': 'Bundled static Noto Sans SC 500 / 800, SIL OFL',
          'controls': 'Keyboard and engine-native multi-touch TouchScreenButton',
          'save': 'Browser-local user://; not shared across browsers or desktop',
          'limits': ['Native pet and recycle-bin integration remain Windows-only.',
                     'No full twelve-room playthrough or physical phone test is claimed.']}
(ROOT / 'production/web-build-checks.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'verified_streams': len(checked), 'download_MB': round(manifest['download_bytes'] / 1024**2, 2),
                  'normal_menu': True, 'export_errors': 0}))
