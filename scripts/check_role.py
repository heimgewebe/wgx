#!/usr/bin/env python3
from pathlib import Path
text = Path('.ai-context.yml').read_text(encoding='utf-8')
for item in [
    'repository_verification_adapter',
    'role_contract:',
    'repository_local_verification',
]:
    assert item in text, item
print('role-contract: OK wgx')
