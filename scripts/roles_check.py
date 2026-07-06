#!/usr/bin/env python3
from pathlib import Path
root = Path.home() / 'repos'
checks = {
    'leitstand': ('repo.meta.yaml', ['observer_digest_view_surface', 'role_contract:', 'read_only_projection']),
    'chronik': ('.ai-context.yml', ['append_only_event_ledger', 'role_contract:', 'historical_evidence']),
    'plexer': ('.ai-context.yml', ['event_gateway_delivery_relay', 'role_contract:', 'delivery_routing']),
    'heimlern': ('.ai-context.yml', ['learning_proposal_engine', 'role_contract:', 'retrospective_analysis_only']),
    'wgx': ('.ai-context.yml', ['fleet_motorics_and_guard_engine', 'role_contract:', 'local_tooling_and_metrics']),
}
failed = False
for repo, spec in checks.items():
    name, markers = spec
    path = root / repo / name
    text = path.read_text(encoding='utf-8') if path.exists() else ''
    missing = [m for m in markers if m not in text]
    if missing:
        failed = True
        print(f'operator-roles: FAIL {repo}: {missing}')
    else:
        print(f'operator-roles: OK {repo}')
raise SystemExit(1 if failed else 0)
