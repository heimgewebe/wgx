#!/usr/bin/env bats

load test_helper

@test "command digest is derived from redacted text" {
  run python3 - "$WGX_PROJECT_ROOT" "$BATS_TEST_TMPDIR" <<'PY'
import hashlib
import sys
from pathlib import Path

sys.path.insert(0, f"{sys.argv[1]}/modules")
from validate_receipt import build


def check(command, path):
    record = "\0".join(("check", "publish", "passed", "0", "1", command)) + "\0"
    Path(path).write_bytes(record.encode())
    receipt = build([
        "quick", "/tmp/repo", "repo", "a" * 40, "false",
        "2026-08-01T00:00:00Z", "2026-08-01T00:00:01Z",
        "true", "", "", "120", path,
    ])
    return receipt["checks"][0]

first = check('echo API_TOKEN="hunter two"', f"{sys.argv[2]}/first.records")
second = check('echo API_TOKEN="different value"', f"{sys.argv[2]}/second.records")

assert first["command"] == "echo API_TOKEN=[REDACTED]"
assert second["command"] == first["command"]
assert first["command_sha256"] == second["command_sha256"]
assert first["command_sha256"] == hashlib.sha256(first["command"].encode()).hexdigest()
print("digest-redaction-ok")
PY
  assert_success
  assert_output "digest-redaction-ok"
}
