from pathlib import Path
import wave
import numpy as np

out=Path(__file__).resolve().parents[1]/'prototype/assets/v2/audio'
out.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(2207)
rate=44100
for name,duration in [('attack',.19),('hit',.16),('heavy',.30),('hurt',.24),('dash',.22),('feed',.55)]:
    t=np.arange(round(rate*duration))/rate
    noise=np.convolve(rng.uniform(-1,1,len(t)),np.ones(4)/4,mode='same')
    if name in ('attack','dash'):
        env=np.sin(np.pi*t/duration)**1.8
        signal=noise*env*.8 + np.sin(2*np.pi*(210*t+600*t*t))*env*.08
    elif name=='feed':
        signal=np.zeros_like(t)
        for i,freq in enumerate((523.25,659.25,783.99)):
            age=t-i*.08
            signal+=np.where(age>=0,np.sin(2*np.pi*freq*age)*np.exp(-np.maximum(age,0)*10),0)*.25
    else:
        heavy=name=='heavy'
        signal=noise*np.exp(-t*(37 if heavy else 60))*.9
        signal+=np.sin(2*np.pi*(110*t-110*t*t))*np.exp(-t*(12 if heavy else 24))*.7
        signal+=np.sin(2*np.pi*620*t)*np.exp(-t*70)*.15
        if name=='hurt': signal*=.75
    samples=np.int16(np.clip(signal,-1,1)*24000)
    with wave.open(str(out/(name+'.wav')),'wb') as f:
        f.setparams((1,2,rate,0,'NONE','not compressed'))
        f.writeframes(samples.tobytes())
print('Wrote layered whoosh / impact / heavy / hurt / dash / feed sounds.')
