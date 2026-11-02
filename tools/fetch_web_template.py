"""Fetch only the matching Web template entries from the official release TPZ via HTTP Range."""
from pathlib import Path
import io
import json
import zipfile
import requests

ROOT = Path(__file__).resolve().parents[1]
URL = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
OUT = ROOT / 'tools/web-templates-4.7.2'
OUT.mkdir(exist_ok=True)


class RemoteZip(io.RawIOBase):
    def __init__(self, url):
        self.session = requests.Session()
        response = self.session.get(url, headers={'Range': 'bytes=0-0'}, stream=True, timeout=45)
        if response.status_code != 206:
            response.close()
            raise RuntimeError(f'Range unsupported: HTTP {response.status_code}')
        self.size = int(response.headers['Content-Range'].split('/')[-1])
        self.url = response.url
        self.position = 0
        response.close()

    def readable(self): return True
    def seekable(self): return True
    def tell(self): return self.position

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.size + offset
        return self.position

    def read(self, size=-1):
        if size < 0: size = self.size - self.position
        if size <= 0: return b''
        end = min(self.position + size, self.size) - 1
        pieces = []
        at = self.position
        while at <= end:
            block_end = min(end, at + 1024 * 1024 - 1)
            for attempt in range(4):
                try:
                    response = self.session.get(self.url, headers={'Range': f'bytes={at}-{block_end}'}, timeout=35)
                    response.raise_for_status()
                    if response.status_code != 206 or len(response.content) != block_end - at + 1:
                        raise RuntimeError('Server returned an unexpected range')
                    pieces.append(response.content)
                    break
                except (requests.RequestException, RuntimeError):
                    if attempt == 3: raise
            at = block_end + 1
        data = b''.join(pieces)
        self.position += len(data)
        return data


remote = RemoteZip(URL)
with zipfile.ZipFile(remote) as archive:
    entries = [i for i in archive.infolist() if i.filename.endswith('/web_nothreads_release.zip')]
    print(json.dumps([{'name': i.filename, 'bytes': i.file_size} for i in entries]))
    for entry in entries:
        target = OUT / Path(entry.filename).name
        if target.exists() and target.stat().st_size == entry.file_size: continue
        target.write_bytes(archive.read(entry))
        print(f'Fetched {target.name}: {target.stat().st_size} bytes')
(OUT / 'SOURCE.json').write_text(json.dumps({'url': URL, 'method': 'HTTP byte ranges, matching official 4.7.2 release',
                                           'files': [i.filename for i in entries]}, indent=2), encoding='utf-8')
