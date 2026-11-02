"""Fetch official Effekseer authoring tools and the selected CC0 effect sources.
Never touches character art, native desktop-pet files or the user's save.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import hashlib,json,urllib.request,zipfile

ROOT=Path(__file__).resolve().parents[1]
jobs=[
 ('https://github.com/effekseer/Effekseer/releases/download/1807/Effekseer1.80.7Win.zip',ROOT/'tools/downloads/Effekseer1.80.7Win.zip',ROOT/'tools/effekseer-1.80.7'),
 ('https://effekseer.github.io/contributes/tktk02.zip',ROOT/'art-source/vfx/tktk02.zip',ROOT/'art-source/vfx/effekseer-tktk02'),
]
def fetch(job):
 url,archive,dest=job
 archive.parent.mkdir(parents=True,exist_ok=True)
 if not archive.exists():
  request=urllib.request.Request(url,headers={'User-Agent':'Naiwa-Game-Asset-Research'})
  with urllib.request.urlopen(request,timeout=90) as response,archive.open('wb') as out:
   while data:=response.read(1024*1024):out.write(data)
 print(archive.name,archive.stat().st_size,'bytes',flush=True)
 with zipfile.ZipFile(archive) as z:
  target=dest.resolve()
  for info in z.infolist():
   resolved=(target/info.filename).resolve()
   assert resolved.is_relative_to(target),'Archive path escapes destination'
  z.extractall(target)
  interesting=[n for n in z.namelist() if n.lower().endswith(('.exe','.efkproj','.efkefc','.txt','.md'))]
 digest=hashlib.sha256(archive.read_bytes()).hexdigest()
 return {'url':url,'archive':str(archive.relative_to(ROOT)),'sha256':digest,'destination':str(dest.relative_to(ROOT)),'files':interesting}

if __name__=='__main__':
 with ThreadPoolExecutor(max_workers=2) as pool:records=list(pool.map(fetch,jobs))
 report=ROOT/'research/ultimate-source-downloads.json'
 report.write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
 for r in records:
  print(r['destination'],'sha256',r['sha256'])
  print('\n'.join(r['files'][:65]))
