"""Vendor byte-identical CC0 textures; synthesize the ultimate's original audio.

No character image is read or changed. Runtime coloring happens in Godot.
"""
from pathlib import Path
import hashlib, json, math, random, shutil, struct, wave

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'art-source/vfx/effekseer-tktk02/tktk02/Parts'
DEST = ROOT/'prototype/assets/ultimate'
DEST.mkdir(parents=True, exist_ok=True)
names = ['Burst01.png','ElectricBall.png','Shockwave.png',
         'LaserMain01.png','Shock_wave_ring001.png','actionlines.png']
records = []
for name in names:
    shutil.copyfile(SOURCE/name, DEST/name)
    digest = hashlib.sha256((DEST/name).read_bytes()).hexdigest()
    assert digest == hashlib.sha256((SOURCE/name).read_bytes()).hexdigest()
    records.append({'file':name,'sha256':digest,'modified':False})
(DEST/'SOURCES.json').write_text(json.dumps({
    'author':'tktk','collection':'Effekseer tktk vol.2','license':'CC0-1.0',
    'gallery':'https://effekseer.github.io/zh-cn/contributes/tktk02/index.html',
    'license_evidence':'https://effekseer.github.io/zh-cn/contribute.html',
    'archive':'https://effekseer.github.io/contributes/tktk02.zip',
    'use':'Original Godot composition using unmodified source texture parts; not a baked Effekseer effect.',
    'files':records},ensure_ascii=False,indent=2),encoding='utf-8')
rate=44100
for name,duration in [('ultimate_charge',.48),('ultimate_launch',.48),('ultimate_hit',.30)]:
    rng=random.Random(442+len(name))
    smooth=0.0
    phase=0.0
    samples=[]
    for i in range(round(duration*rate)):
        t=i/rate
        p=t/duration
        noise=rng.uniform(-1,1)
        smooth=.87*smooth+.13*noise
        if name.endswith('charge'):
            freq=115+470*p*p
            env=min(1,p*14)*(1-p)**.23
            phase+=math.tau*freq/rate
            value=env*(.18*math.sin(phase)+.06*math.sin(phase*2)+.11*smooth)
        elif name.endswith('launch'):
            env=min(1,p*80)*(1-p)**2.2
            phase+=math.tau*(65+155*math.exp(-p*12))/rate
            value=env*(.38*math.sin(phase)+.27*noise+.32*smooth)
        else:
            env=min(1,p*100)*(1-p)**3
            phase+=math.tau*(48+95*math.exp(-p*18))/rate
            value=env*(.48*math.sin(phase)+.34*noise+.18*smooth)
        samples.append(struct.pack('<h',round(max(-.95,min(.95,value))*32767)))
    with wave.open(str(DEST/(name+'.wav')),'wb') as output:
        output.setparams((1,2,rate,0,'NONE','not compressed'))
        output.writeframes(b''.join(samples))
print('Vendored 6 exact CC0 texture files and generated 3 original PCM sound layers.')
