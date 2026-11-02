from pathlib import Path
import subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
tag=sys.argv[1]
args=sys.argv[2:]
log=ROOT/'prototype/artifacts'/f'{tag}.log'
cmd=[str(ROOT/'tools/Godot_v4.7.2-stable_win64.exe'),'--path',str(ROOT/'prototype')]
cmd+=args
with log.open('w',encoding='utf-8') as out:
    try:
        result=subprocess.run(cmd,stdout=out,stderr=subprocess.STDOUT,timeout=180,creationflags=subprocess.CREATE_NO_WINDOW)
        code=result.returncode
    except subprocess.TimeoutExpired:code=124
text=log.read_text(encoding='utf-8',errors='replace')
print(text[-20000:])
print(f'EXIT={code} LOG={log}')
sys.exit(code)
