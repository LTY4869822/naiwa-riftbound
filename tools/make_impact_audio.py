"""Original layered transient, body and debris sounds, with repeatable alternate takes."""
from pathlib import Path
import json
import wave
import numpy as np

OUT = Path(__file__).resolve().parents[1] / 'prototype/assets/pixelfx/audio'
OUT.mkdir(parents=True, exist_ok=True)
rate = 48000
report = {}
for kind, duration, bass, tail in [('light', .19, 150, .045), ('heavy', .36, 88, .095),
                                   ('break', .42, 215, .12), ('hurt', .25, 112, .06)]:
    for variant in range(3):
        rng = np.random.default_rng(710 + variant * 41 + len(kind))
        t = np.arange(round(duration * rate)) / rate
        noise = rng.uniform(-1, 1, len(t))
        low = np.convolve(noise, np.ones(14) / 14, mode='same')
        phase = 2 * np.pi * (bass * t + bass * .035 * (1 - np.exp(-t / .035)))
        body = np.sin(phase) * np.exp(-t / tail) * .72
        snap = (noise - low) * np.exp(-t / .008) * .26
        grit = low * np.exp(-t / (tail * 1.6)) * .75
        sound = body + snap + grit
        if kind == 'break':
            sound = snap * .8 + grit * .25
            for freq, weight in [(860, .20), (1379, .16), (2314, .10), (3710, .035)]:
                sound += np.sin(2 * np.pi * freq * (1 + variant * .014) * t) * np.exp(-t / .085) * weight
        if kind == 'heavy':
            sound += np.sin(2 * np.pi * 51 * t) * np.exp(-t / .075) * .24
            sound += noise * np.exp(-np.maximum(t - .018, 0) / .035) * (t > .018) * .055
        envelope = np.minimum(t / .0006, 1) * np.minimum((duration - t) / .02, 1)
        sound = np.tanh(sound * 1.1) * envelope
        sound *= .78 / max(np.max(np.abs(sound)), .001)
        path = OUT / f'{kind}-{variant + 1}.wav'
        with wave.open(str(path), 'wb') as f:
            f.setparams((1, 2, rate, len(sound), 'NONE', 'not compressed'))
            f.writeframes((sound * 32767).astype('<i2').tobytes())
        report[path.name] = {'seconds': duration, 'peak_dbfs': float(20 * np.log10(np.max(np.abs(sound))))}
(OUT / 'sources.json').write_text(json.dumps({'license': 'Original project-generated synthesized audio',
 'method': 'Seeded noise transient + frequency-dropping body + grit; three takes per role',
 'samples': report}, indent=2), encoding='utf-8')
print(f'{len(report)} original impact samples, 48 kHz mono, peak -2.16 dBFS')
