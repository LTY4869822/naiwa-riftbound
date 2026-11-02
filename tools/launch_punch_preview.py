from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'prototype/artifacts'
command = [str(ROOT / 'tools/Godot_v4.7.2-stable_win64.exe'), '--path', str(ROOT / 'prototype'),
           '--', '--slice-test', '--punch-demo']
with (OUT / 'punch-live.log').open('w', encoding='utf-8') as log:
    process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                               creationflags=subprocess.CREATE_NO_WINDOW)
record = {'pid': process.pid, 'command': command, 'isolated': True,
          'entry': 'sparring target with normal visual recovery',
          'keys': 'J combo, K heavy, U ultimate; F1 practice, F2 Zheng, F3 Paoxiao, F4 normal maps'}
(OUT / 'punch-live.json').write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(record, ensure_ascii=False))
