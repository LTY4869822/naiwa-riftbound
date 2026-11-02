from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'prototype/artifacts'
cmd = [str(ROOT / 'tools/Godot_v4.7.2-stable_win64.exe'),
       '--path', str(ROOT / 'prototype'), '--', '--slice-test', '--echo-demo']
with (OUT / 'echo-live.log').open('w', encoding='utf-8') as log:
    process = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT,
                               creationflags=subprocess.CREATE_NO_WINDOW)
record = {'pid': process.pid, 'command': cmd, 'isolated': True,
          'entry': 'relic choice',
          'shortcuts': 'F1 tiger, F2 double jump, F3 relics, F4 normal maps'}
(OUT / 'echo-live.json').write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(record, ensure_ascii=False))
