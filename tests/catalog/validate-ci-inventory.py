#!/usr/bin/env python3
"""Ensure every Nim test file is inventoried and mapped or explicitly pending."""
from pathlib import Path
import sys
import yaml

root = Path(__file__).resolve().parent.parent.parent
inventory = yaml.safe_load((root / 'tests/cases/ci-inventory.yaml').read_text())
cases = {x['id'] for x in yaml.safe_load((root / 'tests/cases/catalog.yaml').read_text())['cases']}
tests = inventory.get('tests', [])
seen = set(); errors = []
for item in tests:
    name = item.get('test')
    if not name: errors.append('test entry without name'); continue
    if name in seen: errors.append(f'duplicate {name}')
    seen.add(name)
    if not (root.parent / 'avelra/tests' / name).is_file() and not (root.parent / 'avelra/tests' / name).is_dir():
        # root.parent is workspace; tests live in avelra/tests
        pass
    if item.get('case') and item['case'] not in cases:
        errors.append(f'{name}: unknown case {item["case"]}')
tests_dir = root.parent / 'avelra/tests'
if tests_dir.is_dir():
    files = {p.name for p in tests_dir.glob('test_*')}
    for name in sorted(files - seen): errors.append(f'not inventoried: {name}')
else:
    print('source absent: inventory-only validation')
for item in tests:
    if item.get('case') is None:
        print(f'PENDING {item["test"]}')
for e in errors: print(f'ERROR {e}')
print(f'tests={len(tests)} mapped={sum(bool(x.get("case")) for x in tests)} errors={len(errors)}')
sys.exit(1 if errors else 0)
