from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'production/web-project'
DIST = ROOT / 'web/dist'
DIST.mkdir(parents=True, exist_ok=True)
command = [str(ROOT / 'tools/Godot_v4.7.2-stable_win64.exe'), '--headless', '--path', str(PROJECT),
           '--export-release', 'Web', str(DIST / 'naiwa.html')]
log_path = ROOT / 'production/web-export.log'
with log_path.open('w', encoding='utf-8') as log:
    result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=600,
                            creationflags=subprocess.CREATE_NO_WINDOW)
log = log_path.read_text(encoding='utf-8', errors='replace')
print(log[-7000:])
print(f'EXPORT_EXIT={result.returncode}')
sys.exit(result.returncode)
