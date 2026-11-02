"""Download the pinned official Godot runtime into this checkout only."""
from pathlib import Path
import hashlib,json,shutil,urllib.request,zipfile
ROOT=Path(__file__).resolve().parents[1]
meta=json.loads((ROOT/'tools/windows-runtime.json').read_text(encoding='utf-8'))
target=ROOT/'tools'/meta['exe']
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
if target.exists() and digest(target)==meta['exe_sha256']:
    print('Godot runtime already verified.');raise SystemExit(0)
cache=ROOT/'tools/downloads';cache.mkdir(exist_ok=True)
archive=cache/'godot-4.7.2-windows.zip'
if not archive.exists() or digest(archive)!=meta['zip_sha256']:
    temporary=archive.with_suffix('.partial')
    request=urllib.request.Request(meta['url'],headers={'User-Agent':'NaiwaRiftboundBuild'})
    with urllib.request.urlopen(request,timeout=120) as response, temporary.open('wb') as output:
        shutil.copyfileobj(response,output)
    if digest(temporary)!=meta['zip_sha256']: raise RuntimeError('Official download checksum mismatch')
    temporary.replace(archive)
with zipfile.ZipFile(archive) as bundle:
    data=bundle.read(meta['exe'])
if hashlib.sha256(data).hexdigest()!=meta['exe_sha256']: raise RuntimeError('Godot executable checksum mismatch')
target.write_bytes(data)
print('Prepared official Godot '+meta['version']+'. Import prototype/project.godot in the editor before source play.')
