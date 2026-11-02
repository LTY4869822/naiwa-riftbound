"""Kenney CC0 coin foley + original modal chimes / watery healing synthesis."""
from pathlib import Path
from zipfile import ZipFile
import hashlib
import json
import subprocess
import wave
import imageio_ffmpeg
import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'prototype/assets/loot-v3/audio'
OUT.mkdir(parents=True, exist_ok=True)
RAW = OUT / 'source'
RAW.mkdir(exist_ok=True)
RATE = 48000
rng = np.random.default_rng(301026)
sources = json.loads((ROOT/'research/loot-audio/SOURCES.json').read_text(encoding='utf-8'))
with ZipFile(ROOT/'research/loot-audio/rpg.zip') as archive:
    for name in ['handleCoins.ogg', 'handleCoins2.ogg']:
        (RAW/name).write_bytes(archive.read('Audio/'+name))
    (OUT/'KENNEY-CC0.txt').write_bytes(archive.read('License.txt'))

def decode(name):
    result = subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-v', 'error', '-i', str(RAW/name), '-f', 'f32le', '-ac', '1', '-ar', str(RATE), '-'], capture_output=True, check=True)
    x = np.frombuffer(result.stdout, dtype='<f4').astype(float)
    active = np.flatnonzero(np.abs(x) > .008)
    if active.size: x = x[max(0, active[0]-120):active[-1]+500]
    return x

def bell(t, at, freq, length=.30, level=1.):
    age = t-at
    a = np.maximum(age, 0)
    y = np.zeros_like(t)
    for ratio, volume, decay in [(1,1,15), (2.76,.27,24), (4.07,.12,34)]:
        y += volume*np.sin(2*np.pi*freq*ratio*a)*np.exp(-a*decay)
    return y*(age>=0)*(age<length)*(1-np.exp(-a*1300))*level

def save(name, x, details):
    fade = min(400, len(x)//10)
    x[-fade:] *= np.linspace(1,0,fade)
    x *= .68/max(np.max(np.abs(x)), .001)
    pcm = np.round(x*32767).astype('<i2')
    path = OUT/(name+'.wav')
    with wave.open(str(path), 'wb') as f:
        f.setparams((1,2,RATE,0,'NONE','not compressed'))
        f.writeframes(pcm.tobytes())
    return {'file': path.name, 'seconds': len(x)/RATE, 'peak_dbfs': float(20*np.log10(np.max(np.abs(x)))), 'rms_dbfs': float(20*np.log10(np.sqrt(np.mean(x*x)))), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'construction': details}

report = []
for i, source in enumerate(['handleCoins.ogg', 'handleCoins2.ogg']):
    t = np.arange(round(RATE*.52))/RATE
    x = np.zeros_like(t)
    raw = decode(source)[:round(RATE*.28)]
    raw = sosfilt(butter(2, [500,7000], btype='bandpass', fs=RATE, output='sos'), raw)
    raw *= .24/max(np.max(np.abs(raw)),.001)
    x[:len(raw)] += raw*np.exp(-np.arange(len(raw))/RATE*6)
    x += bell(t,.005,1320*(1+i*.025),level=.42)
    x += bell(t,.062,1980*(1+i*.025),level=.29)
    report.append(save('coin-'+str(i+1),x,'Kenney '+source+' trimmed and filtered; original two modal metallic pings.'))

for i in range(2):
    t = np.arange(round(RATE*.96))/RATE
    noise = sosfilt(butter(2, [600,3200], btype='bandpass', fs=RATE, output='sos'), rng.normal(size=len(t)))
    x = noise*np.exp(-t*90)*(1-np.exp(-t*1600))*.25
    for j, at in enumerate([.045,.125,.215]):
        age = t-at
        a = np.maximum(age,0)
        freq = (370+j*120+i*25)
        phase = 2*np.pi*(freq*a + 110*(1-np.exp(-a*25))/25)
        x += np.sin(phase)*np.exp(-a*32)*(1-np.exp(-a*900))*(age>=0)*.25
    for j, freq in enumerate([659.25,830.61,987.77,1318.51]):
        x += bell(t,.10+j*.105,freq*(1+i*.012),length=.48,level=.12 if j<3 else .075)
    report.append(save('heal-'+str(i+1),x,'Original cork pop, three liquid bubbles and rising E-major glass chimes; deterministic additive and filtered-noise synthesis.'))

manifest = {'sample_rate': RATE, 'channels': 1, 'format': 'PCM16', 'files': report, 'source_pack': {'page': sources['rpg']['page'], 'archive_sha256': sources['rpg']['sha256'], 'license': 'CC0-1.0', 'used': ['Audio/handleCoins.ogg','Audio/handleCoins2.ogg']}, 'unused_researched_pack': sources['casino']['page']}
(OUT/'SOURCES.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
