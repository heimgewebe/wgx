#!/usr/bin/env bats

load test_helper

@test "receipt redaction covers quoted values and credential headers" {
  run python3 - "$WGX_PROJECT_ROOT" <<'PY'
import sys

sys.path.insert(0, f"{sys.argv[1]}/modules")
from validate_receipt import redact

cases = {
    'echo API_TOKEN="hunter two"': 'echo API_TOKEN=[REDACTED]',
    "cmd --client-secret 'sword fish'": "cmd --client-secret [REDACTED]",
    'curl -H "Authorization: Bearer bearer secret"':
        'curl -H "Authorization: Bearer [REDACTED]"',
    "curl -H 'Authorization: Basic basic secret'":
        "curl -H 'Authorization: Basic [REDACTED]'",
    'curl -H "X-API-Key: key secret"':
        'curl -H "X-API-Key: [REDACTED]"',
    'echo PRIVATE_KEY="private material"': 'echo PRIVATE_KEY=[REDACTED]',
    'cmd --password=one': 'cmd --password=[REDACTED]',
    'echo public value': 'echo public value',
}

for raw, expected in cases.items():
    actual = redact(raw)
    assert actual == expected, (raw, actual, expected)

print("redaction-ok")
PY
  assert_success
  assert_output "redaction-ok"
}
