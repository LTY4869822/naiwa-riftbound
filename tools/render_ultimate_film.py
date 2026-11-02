"""Capture the real game and mux its original ultimate sound cues."""
from pathlib import Path
import json, subprocess, wave
import imageio_ffmpeg
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT/'prototype'
OUT=PROJECT/'artifacts'
FRAMES=OUT/'ultimate-demo-frames'

def main():
    FRAMES.mkdir(exist_ok=True)
    assert FRAMES.resolve().parent==OUT.resolve()
    # Exact generated frame files only, never another capture's working directory.
    for p in FRAMES.glob('frame_?????.jpg'): p.unlink()
    startup=subprocess.STARTUPINFO()
    startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow=0
    command=[str(ROOT/'tools/Godot_v4.7.2-stable_win64.exe'),'--path',str(PROJECT),
             '--position','-32000,-32000','--fixed-fps','60',
             '--log-file',str(OUT/'ultimate-demo-engine.log'),
             '--','--bridge-check','--ultimate-film']
    with (OUT/'ultimate-demo-capture.log').open('w',encoding='utf-8') as log:
        subprocess.run(command,cwd=PROJECT,startupinfo=startup,
                       creationflags=subprocess.CREATE_NO_WINDOW,stdout=log,
                       stderr=subprocess.STDOUT,check=True,timeout=55)
    data=json.loads((OUT/'ultimate-demo-metadata.json').read_text(encoding='utf-8'))
    assert len(list(FRAMES.glob('frame_?????.jpg')))==data['frames']
    rate=44100
    audio=np.zeros(round(data['duration_seconds']*rate),np.float32)
    for cue in data['audio_events']:
        with wave.open(str(PROJECT/'assets/ultimate'/(cue['sound']+'.wav')),'rb') as source:
            assert source.getframerate()==rate
            samples=np.frombuffer(source.readframes(source.getnframes()),dtype='<i2').astype(np.float32)/32768
        start=round(cue['frame']/data['fps']*rate)
        count=min(len(audio)-start,len(samples))
        if cue['sound'].endswith('hit'):
            samples=np.interp(np.arange(0,len(samples),.95),np.arange(len(samples)),samples)
            count=min(len(audio)-start,len(samples))
        volume={'ultimate_charge':-16,'ultimate_launch':-13,'ultimate_hit':-12}[cue['sound']]
        gain=10**(volume/20)
        audio[start:start+count]+=samples[:count]*gain
    with wave.open(str(OUT/'ultimate-demo-audio.wav'),'wb') as output:
        output.setparams((1,2,rate,0,'NONE','not compressed'))
        output.writeframes((np.clip(audio,-.95,.95)*32767).astype('<i2').tobytes())
    movie=OUT/'ultimate-demo.mp4'
    command=[imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-y','-framerate',str(data['fps']),
             '-i',str(FRAMES/'frame_%05d.jpg'),'-i',str(OUT/'ultimate-demo-audio.wav'),
             '-c:v','libx264','-preset','medium','-crf','18','-pix_fmt','yuv420p',
             '-c:a','aac','-b:a','128k','-movflags','+faststart','-shortest',str(movie)]
    with (OUT/'ultimate-demo-encode.log').open('w',encoding='utf-8') as log:
        subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=50,check=True)
    for p in FRAMES.glob('frame_?????.jpg'): p.unlink()
    if not any(FRAMES.iterdir()): FRAMES.rmdir()
    print(f'{movie}: {data["frames"]} frames / {data["duration_seconds"]} seconds / {movie.stat().st_size} bytes')

if __name__=='__main__': main()
