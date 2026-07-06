#!/usr/bin/env python3
from pathlib import Path
text = Path('.ai-context.yml').read_text(encoding='utf-8')
for item in ['fleet_motorics_and_guard_engine', 'role_contract:', 'local_tooling_and_metrics']:
    assert item in text, item
print('role-contract: OK wgx')
