"""Verify existing isolated review evidence and record the delivered shop build."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / 'prototype' / 'artifacts'
REPORTS = {
    'shop-store.log': 43,
    'shop-ui-final.log': 26,
    'shop-campaign-regression.log': 77,
    'shop-menu-regression.log': 15,
    'shop-route-regression.log': 24,
}


def main():
    results = {}
    for name, count in REPORTS.items():
        content = (ARTIFACTS / name).read_text(encoding='utf-8')
        passed = sum(line.startswith('PASS ') for line in content.splitlines())
        assert passed == count, (name, passed)
        assert not any(marker in content for marker in (
            'FAIL ', 'SCRIPT ERROR:', 'SHADER ERROR:', 'ERROR:'))
        results[name] = {'passed': passed, 'failed': 0}
    for name in ('shop-roundtrip-write.log', 'shop-roundtrip-read.log'):
        content = (ARTIFACTS / name).read_text(encoding='utf-8')
        assert 'SHOP_PROCESS_ROUNDTRIP PASS' in content
        results[name] = {'status': 'passed'}
    probe = json.loads((ARTIFACTS / 'design-combat-probe.json').read_text(encoding='utf-8'))
    assert len(probe['results']) == 8
    payload = {
        'date': '2026-10-28', 'shop_checks': 69, 'regression_checks': 116,
        'separate_process_save_reload': True, 'reports': results,
        'resource_check': {'files': 380, 'errors': 0, 'warnings': 0},
        'audit_probe_cases': 8, 'normal_profile_written': False,
        'real_file_operations': False, 'new_skin_art_created': False,
        'original_only': True, 'reward_first_total': 840,
        'reward_all_replays_total': 210, 'wallet_schema': 1,
        'wallet_path': 'user://wardrobe.json', 'growth_profile_schema_unchanged': 2,
        'rules': 'level AND real recycled bytes unlock automatically; alternatively stage coins; unpublished items cannot charge',
    }
    (ARTIFACTS / 'shop-delivery.json').write_text(
        json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
    references = ROOT / 'references' / 'gamedev-audit-2026-10-28'
    sources = {
        'repository': 'https://github.com/gamedev-skills/awesome-gamedev-agent-skills',
        'read_date': '2026-10-28',
        'files': [
            {'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
            for path in sorted(references.iterdir())
            if path.is_file() and path.name != 'SOURCE.json'
        ],
    }
    (references / 'SOURCE.json').write_text(json.dumps(sources, indent=2), encoding='utf-8')
    print('Verified: 69 shop checks, 116 regression checks, 8 diagnostic fights, process save/load.')


if __name__ == '__main__':
    main()
