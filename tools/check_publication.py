"""Check published files without depending on private caches, logs or a Godot install."""
from pathlib import Path
import gzip,hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]
DIST=ROOT/'web/dist'
manifest=json.loads((DIST/'game-manifest.json').read_text(encoding='utf-8'))
for name,item in manifest['files'].items():
    h=hashlib.sha256();total=0
    for part in item['parts']:
        path=DIST/part['file']
        data=path.read_bytes()
        assert len(data)==part['compressed_size']
        assert hashlib.sha256(data).hexdigest()[:12] in path.name
        block=gzip.decompress(data); assert len(block)==part['size']
        h.update(block);total+=len(block)
    assert h.hexdigest()==item['sha256'] and total==item['size'], name
html=(DIST/'index.html').read_text(encoding='utf-8')
for ref in re.findall(r'(?:src|href)="([^"]+)"',html):
    if not ref.startswith(('https:','http:','#','data:')):
        assert (DIST/ref.split('?')[0]).exists(),ref
documents=[ROOT/'README.md',ROOT/'LICENSE.md',ROOT/'THIRD_PARTY_NOTICES.md',ROOT/'CONTRIBUTING.md']+list((ROOT/'docs').glob('*.md'))
for document in documents:
    text=document.read_text(encoding='utf-8')
    for ref in re.findall(r'\]\(([^)]+)\)',text):
        if ref.startswith(('https:','http:','#','mailto:')):continue
        local=ref.split('#')[0]
        if local: assert (document.parent/local).exists(),(document.name,ref)
assert 'res://v6/slice.tscn' in (ROOT/'prototype/project.godot').read_text(encoding='utf-8')
version=json.loads((ROOT/'docs/validation/source-version.json').read_text())
assert hashlib.sha256((ROOT/'prototype/v6/main.gd').read_bytes().replace(b'\r\n',b'\n')).hexdigest()==version['main_sha256']
for required in ['relics-current.jpg','realm-storm.jpg','combat.gif','awakened-current.jpg']:
    assert (ROOT/'docs/media'/required).is_file(),required
print(json.dumps({'verified_game_streams':len(manifest['files']),'documents':len(documents),'source_matches_current_capture':True}))
