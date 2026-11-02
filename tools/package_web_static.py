from pathlib import Path
import gzip
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / 'web/dist'
CACHE = ROOT / 'production/web-export'
CACHE.mkdir(exist_ok=True)
CHUNKS = DIST / 'assets'
CHUNKS.mkdir(exist_ok=True)
manifest = {'version': 'naiwa-web-2026-10-31', 'files': {}, 'download_bytes': 0}
for filename, mime in [('naiwa.wasm', 'application/wasm'), ('naiwa.pck', 'application/octet-stream')]:
    source = DIST / filename
    if source.exists(): shutil.copy2(source, CACHE / filename)
    data = (CACHE / filename).read_bytes()
    record = {'size': len(data), 'mime': mime, 'parts': [], 'sha256': hashlib.sha256(data).hexdigest()}
    for i, at in enumerate(range(0, len(data), 8 * 1024 * 1024)):
        block = data[at:at + 8 * 1024 * 1024]
        compressed = gzip.compress(block, compresslevel=9, mtime=0)
        name = f'{filename}-{i:02d}-{hashlib.sha256(compressed).hexdigest()[:12]}.gz'
        (CHUNKS / name).write_bytes(compressed)
        record['parts'].append({'file': f'assets/{name}', 'size': len(block), 'compressed_size': len(compressed)})
        manifest['download_bytes'] += len(compressed)
    manifest['files'][filename] = record
    if source.exists():
        assert source.resolve().parent == DIST.resolve()
        source.unlink()
(DIST / 'game-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
current_parts = {Path(part['file']).name for item in manifest['files'].values() for part in item['parts']}
for path in CHUNKS.glob('naiwa.*.gz'):
    if path.name not in current_parts:
        assert path.resolve().parent == CHUNKS.resolve()
        path.unlink()
unused_html = DIST / 'naiwa.html'
if unused_html.exists():
    assert unused_html.resolve().parent == DIST.resolve()
    unused_html.unlink()
shutil.copy2(ROOT / 'prototype/CREDITS.md', DIST / 'CREDITS.txt')
licenses = DIST / 'licenses'
licenses.mkdir(exist_ok=True)
for name, source in [('GODOT.txt', ROOT / 'tools/GODOT-LICENSE.txt'),
                     ('PIXELFX.txt', ROOT / 'prototype/assets/pixelfx/LICENSE.txt'),
                     ('NOTO-OFL.txt', ROOT / 'production/web-project/web_assets/OFL.txt')]:
    shutil.copy2(source, licenses / name)
print(json.dumps({'download_MB': round(manifest['download_bytes'] / 1024**2, 2),
                  'parts': sum(len(f['parts']) for f in manifest['files'].values())}))
