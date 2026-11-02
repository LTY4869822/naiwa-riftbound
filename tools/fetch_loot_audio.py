from pathlib import Path
from urllib.request import urlopen, Request
from zipfile import ZipFile, is_zipfile
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / 'research/loot-audio'
CACHE.mkdir(parents=True, exist_ok=True)
PACKS = {
    'casino': 'https://kenney.nl/assets/casino-audio',
    'rpg': 'https://kenney.nl/assets/rpg-audio',
}
sources = {}
for key, page in PACKS.items():
    path = CACHE / (key + '.zip')
    if not path.exists() or not is_zipfile(path):
        headers = {'User-Agent': 'Mozilla/5.0', 'Referer': page}
        with urlopen(Request(page, headers=headers), timeout=30) as response:
            html = response.read().decode('utf-8')
        download_id = re.search(r"data-download-id=['\"]([a-f0-9]+)", html).group(1)
        # Same public fresh-link endpoint used by the official download button.
        with urlopen(Request('https://kenney.nl/download-link/' + download_id, headers=headers), timeout=30) as response:
            signed = json.load(response)['url']
        req = Request(signed, headers=headers)
        with urlopen(req, timeout=40) as response:
            path.write_bytes(response.read())
    with ZipFile(path) as archive:
        names = archive.namelist()
        print(key, json.dumps(names, ensure_ascii=False))
        sources[key] = {'page': page, 'download_method': 'Official public fresh-link endpoint used by the page download button. Expiring signed URLs are not persisted.', 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'files': names}
(CACHE / 'SOURCES.json').write_text(json.dumps(sources, ensure_ascii=False, indent=2), encoding='utf-8')
