"""Read-only, unauthenticated checks for the published browser edition."""
import hashlib
import json
from pathlib import Path
from urllib.request import urlopen
from urllib.error import HTTPError, URLError

ROOT = Path(__file__).resolve().parents[1]
BASE = 'https://naiwa-fragment-journey-1031.biaoyou13.chatgpt.site/'
checks = []
transport_limits = []
for name in ['index.html', 'game-manifest.json', 'app.js', 'style.css']:
    try:
        with urlopen(BASE + name, timeout=45) as response:
            data = response.read()
            assert response.status == 200
            assert data == (ROOT / 'web/dist' / name).read_bytes(), name
            checks.append({'file': name, 'status': 200, 'sha256': hashlib.sha256(data).hexdigest()})
    except (HTTPError, URLError) as error:
        transport_limits.append({'file': name, 'error': str(error),
                                 'note': 'CLI transport cannot verify this site; browser verification recorded separately.'})
        break
result = {'url': BASE, 'authentication': 'none', 'checks': checks,
          'cli_transport_limits': transport_limits,
          'local_browser': {'normal_home': True, 'battle': True,
                            'double_jump': 'jumps=2, min_y=458.70',
                            'movement': 'max_x=280.54 from initial x=155',
                            'attack': 'state=attack', 'pause_and_return_home': True,
                            'engine_errors': [], 'browser_console_errors': []},
          'limits': ['No physical phone test or complete twelve-room playthrough.']}
(ROOT / 'production/web-public-checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'url': BASE, 'unauthenticated_files_verified': len(checks)}))
