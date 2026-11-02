"""Build the current, evidence-backed delivery index; do not reuse old check totals."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'prototype/artifacts'
def read(name):
    return json.loads((OUT / name).read_text(encoding='utf-8-sig'))
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

checks = read('loop-checks.json')
economy = read('loop-economy-check.json')
resources = read('remediation-resources.json')
ai = read('loop-ai-check.json')
film = read('loop-film.json')
balance = read('loop-balance.json')
assert checks['checks'] == 122 and checks['failures'] == [] and not checks['formal_saves']
assert economy['checks'] == 12 and economy['failures'] == []
assert resources['checked'] == 131 and resources['failed'] == []
assert ai['all_four'] and len(ai['runs']) == 8
assert film['frames'] == 1201 and film['real_gpu']
tests = [
    ('core', 122, 'loop-review.log', 'LOOP_CHECKS 122 failures=0'),
    ('hud', 36, 'loop-hud.log', 'HUD_CHECKS 36 failures=0'),
    ('shop_ui', 27, 'loop-shop.log', 'SHOP_UI_CHECKS 27 failures=0'),
    ('wallet', 60, 'loop-wallet.log', 'SHOP_STORE_CHECKS 60 failures=0'),
    ('loot_equipment_save', 12, 'loop-economy.log', 'LOOT_ECONOMY_CHECKS 12 failures=0'),
    ('energy_save', 14, 'loop-energy.log', 'ASCENSION_STORE_CHECKS 14 failures=0'),
]
for name, count, log, marker in tests:
    data = (OUT / log).read_text(encoding='utf-8-sig')
    assert marker in data, (name, data[-1000:])
    assert 'ERROR:' not in data and 'SCRIPT ERROR:' not in data, log
render = (OUT / 'loop-render.log').read_text(encoding='utf-8-sig')
assert not any(bad in render for bad in ['ERROR:', 'SCRIPT ERROR:', 'TOON_INVALID'])
hash_files = [
    'prototype/v6/main.gd', 'prototype/v6/fighter.gd',
    'prototype/ascension/power.gd', 'prototype/ascension/poses.gd',
    'prototype/ascension/store.gd', 'prototype/wardrobe/store.gd',
    'prototype/assets/loop-v2/production.json', 'prototype/assets/loop-v2/manifest.json',
    'prototype/assets/loop-v2/run.png', 'prototype/assets/loop-v2/combat.png',
    'prototype/assets/loop-v2/morph.png', 'prototype/artifacts/loop-demo.mp4',
]
hash_files += [str(p.relative_to(ROOT)).replace('\\', '/') for p in sorted((ROOT / 'prototype/loop').glob('*.gd*'))]
result = {
    'version': 'combat-loop-2026-10-30',
    'entry': 'prototype/v6/slice.tscn',
    'launcher': '试玩连战新版.cmd',
    'documentation': 'docs/COMBAT_LOOP_2026-10-30.md',
    'checks': [{'suite': n, 'passed': c, 'log': f} for n, c, f, m in tests],
    'assertions_passed': sum(t[1] for t in tests),
    'resource_loads': resources,
    'ai_rotation': ai,
    'film': film,
    'balance_observation': balance,
    'limits': [
        'Four automated connected-map attempts failed in later rooms; not an all-maps-clear result.',
        'AI repertoire observation uses an invulnerable target and is not difficulty validation.',
        'Movie stages a room clear and seeds animation energy; it is not a full playthrough.',
        'Three rooms are linked with a short passage fade, not one scrolling wide map.',
        'Human feel and long-term gear progression still need playtesting.',
        'Historical ascension-delivery.json results describe the prior implementation only.',
    ],
    'formal_saves_touched_by_tests': False,
    'sha256': {p: sha(ROOT / p) for p in hash_files},
}
(OUT / 'loop-delivery.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'assertions': result['assertions_passed'], 'resources': resources['checked'], 'video_seconds': film['seconds']}, ensure_ascii=False))
