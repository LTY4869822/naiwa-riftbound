from pathlib import Path
from PIL import Image
import json,shutil,hashlib,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'prototype/assets/ascension'
SOURCE=Path.home()/'.codex/generated_images/01a180ef-7ca6-7bb3-95a5-32cb97522799'
production=json.loads((ASSETS/'production.json').read_text(encoding='utf-8'))
manifest={'version':1,'pixel_edits':False,'assets':{}}
for target,source,cols,rows in production['sources']:
    out=ASSETS/target;out.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(SOURCE/source,out)
    with Image.open(out) as im:
        assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0,target
        frames=[];touch=[]
        for i in range(cols*rows):
            x0=round((i%cols)*im.width/cols);x1=round((i%cols+1)*im.width/cols)
            y0=round((i//cols)*im.height/rows);y1=round((i//cols+1)*im.height/rows)
            a=im.getchannel('A').crop((x0,y0,x1,y1))
            b=a.point(lambda v:255 if v>=128 else 0).getbbox();assert b,target
            l,t,r,bottom=b
            frames.append({'region':[x0+l,y0+t,r-l,bottom-t],'pivot':[(x1-x0)*0.5-l,bottom-t],'height':bottom-t,'bounds':list(b)})
            if l<=1 or r>=x1-x0-1 or t<=1 or bottom>=y1-y0-1:touch.append(i)
        manifest['assets'][target]={'file':'res://assets/ascension/'+target,'dimensions':im.size,'grid':[cols,rows],'frames':frames,'touching_cells':touch,'source':source,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}
    print(target,im.size,'edge_frames=',touch)
(ASSETS/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
subprocess.run([sys.executable,str(Path(__file__).with_name('measure_ascension_silhouettes.py'))],check=True)
