"""Produce a host-independent ZIP with index.html at its root."""
import hashlib
import json
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / 'web/dist'
OUT = ROOT / 'production/naiwa-web-upload.zip'
files = [path for path in DIST.rglob('*') if path.is_file()]
assert (DIST / 'index.html').is_file()
with zipfile.ZipFile(OUT, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
    for path in sorted(files):
        bundle.write(path, path.relative_to(DIST).as_posix())
with zipfile.ZipFile(OUT) as bundle:
    assert bundle.testzip() is None
    assert 'index.html' in bundle.namelist()
    assert len(bundle.namelist()) == len(files)
    assert not any(name.startswith(('.git', '.openai')) for name in bundle.namelist())
record = {'archive':str(OUT), 'file_count':len(files), 'bytes':OUT.stat().st_size,
          'sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),
          'game_download_bytes':json.loads((DIST/'game-manifest.json').read_text(encoding='utf-8'))['download_bytes'],
          'new_domestic_url':'Requires user cloud account and custom domain; not deployed there yet.'}
(ROOT / 'production/web-portable-package.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'zip':OUT.name,'files':len(files),'MiB':round(OUT.stat().st_size/1048576,2)}))
