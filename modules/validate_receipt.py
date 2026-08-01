#!/usr/bin/env python3
"""Build the stable JSON receipt for `wgx validate --profile`.

The receipt records what was invoked, not what the checks mean. It establishes
no repository correctness, no CI replacement and no merge readiness; those
boundaries are carried in the emitted `does_not_establish` list.

Records arrive as NUL-separated 6-tuples on a file so Bash never has to quote
JSON itself:

    check\0<name>\0<status>\0<exit_code>\0<duration_ms>\0<command>
    skip\0<name>\0<kind>\0<reason>\0\0
"""
from __future__ import annotations

import hashlib
import json
import os
import platform
import re
import sys
from typing import Any, Dict, List

RECORD_FIELDS = 6

# Environment names whose values never enter a receipt.
RE_SECRET_NAME = re.compile(
    r'(SECRET|TOKEN|PASSWORD|PASSWD|CREDENTIAL|PRIVATE_KEY|APIKEY|API_KEY|ACCESS_KEY)',
    re.IGNORECASE,
)
# Inline assignments and bearer-style literals inside a recorded command.
RE_SECRET_INLINE = re.compile(
    r'((?:[A-Za-z_][A-Za-z0-9_]*)?(?:SECRET|TOKEN|PASSWORD|PASSWD|CREDENTIAL|APIKEY|API_KEY|ACCESS_KEY)[A-Za-z0-9_]*)'
    r'(\s*[=:]\s*)(\S+)',
    re.IGNORECASE,
)
RE_SECRET_FLAG = re.compile(
    r'(--(?:token|password|secret|api-key|access-key)(?:=|\s+))(\S+)',
    re.IGNORECASE,
)
REDACTED = '[REDACTED]'


def redact(text: str) -> str:
    """Remove secret-looking values from a string that enters the receipt."""
    if not text:
        return text
    text = RE_SECRET_INLINE.sub(lambda m: f'{m.group(1)}{m.group(2)}{REDACTED}', text)
    text = RE_SECRET_FLAG.sub(lambda m: f'{m.group(1)}{REDACTED}', text)
    return text


def _int(value: str, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def read_records(path: str) -> List[List[str]]:
    if not path or not os.path.exists(path):
        return []
    with open(path, 'rb') as handle:
        raw = handle.read().decode('utf-8', 'replace')
    fields = raw.split('\0')
    if fields and fields[-1] == '':
        fields.pop()
    records: List[List[str]] = []
    for start in range(0, len(fields), RECORD_FIELDS):
        chunk = fields[start:start + RECORD_FIELDS]
        if len(chunk) == RECORD_FIELDS:
            records.append(chunk)
    return records


def environment_identity() -> Dict[str, Any]:
    """Identify the environment without exposing any secret value."""
    names = sorted(name for name in os.environ if RE_SECRET_NAME.search(name))
    identity = {
        'wgx_version': os.environ.get('WGX_VERSION') or 'unknown',
        'os': platform.system().lower(),
        'os_release': platform.release(),
        'machine': platform.machine(),
        'bash': os.environ.get('WGX_BASH_VERSION') or 'unknown',
        'python': platform.python_version(),
        'redacted_env_names': names,
    }
    identity['identity_sha256'] = hashlib.sha256(
        json.dumps(
            {key: value for key, value in identity.items() if key != 'redacted_env_names'},
            sort_keys=True,
            ensure_ascii=False,
        ).encode('utf-8')
    ).hexdigest()
    return identity


def build(argv: List[str]) -> Dict[str, Any]:
    (
        profile,
        repo_root,
        repo_name,
        commit,
        dirty,
        started_at,
        finished_at,
        manifest_ok,
        manifest_errors,
        manifest_missing,
        timeout_seconds,
        records_path,
    ) = argv

    checks: List[Dict[str, Any]] = []
    skipped: List[Dict[str, Any]] = []
    for kind, name, a, b, c, command in read_records(records_path):
        if kind == 'check':
            command_text = redact(command)
            checks.append({
                'name': name,
                'status': a,
                'exit_code': _int(b),
                'duration_ms': _int(c),
                'command': command_text,
                'command_sha256': hashlib.sha256(command.encode('utf-8')).hexdigest(),
            })
        elif kind == 'skip':
            skipped.append({'name': name, 'kind': a, 'reason': redact(b)})

    # A profile that names a task the manifest does not define breaks deterministic
    # discovery, so it fails the run rather than being silently skipped.
    failed = [item for item in checks if item['status'] != 'passed']
    undeclared = [item for item in skipped if item['kind'] == 'undeclared']
    result = 'passed' if manifest_ok == 'true' and not failed and not undeclared else 'failed'

    receipt: Dict[str, Any] = {
        'schema_version': 1,
        'kind': 'wgx.validate.receipt',
        'profile': profile,
        'repository': {
            'root': repo_root,
            'name': repo_name,
            'commit': commit or None,
            'dirty': dirty == 'true',
        },
        'manifest': {
            'ok': manifest_ok == 'true',
            'errors': [item for item in manifest_errors.split('\n') if item],
            'missing_capabilities': [item for item in manifest_missing.split('\n') if item],
        },
        'checks': checks,
        'skipped': skipped,
        'result': result,
        'started_at': started_at,
        'finished_at': finished_at,
        'timeout_seconds': _int(timeout_seconds),
        'environment': environment_identity(),
        'does_not_establish': [
            'repository_correctness',
            'ci_replacement',
            'merge_readiness_from_quick_profile',
            'test_sufficiency',
            'runtime_correctness',
        ],
    }
    receipt['receipt_sha256'] = hashlib.sha256(
        json.dumps(receipt, sort_keys=True, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    ).hexdigest()
    return receipt


def main() -> int:
    expected = 12
    if len(sys.argv) != expected + 1:
        sys.stderr.write(f'Usage: validate_receipt.py <{expected} fields>\n')
        return 2
    receipt = build(sys.argv[1:])
    json.dump(receipt, sys.stdout, ensure_ascii=False, indent=2, sort_keys=True)
    sys.stdout.write('\n')
    return 0 if receipt['result'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
