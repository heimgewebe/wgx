#!/usr/bin/env bats

load test_helper

setup() {
  WGX_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
  git init
  git config user.email "t@t.com"
  git config user.name "T"
  git commit --allow-empty -m "init"
  export WGX_AUDIT_LOG="$TEST_DIR/ledger.jsonl"
}

teardown() {
  cd "$BATS_TEST_DIRNAME"
  rm -rf "$TEST_DIR"
  unset WGX_AUDIT_LOG
}

@test "audit::log: called with event only does not crash under set -u" {
  run bash -c "
    set -u
    source \"$WGX_ROOT/lib/audit.bash\"
    export WGX_AUDIT_LOG=\"$WGX_AUDIT_LOG\"
    audit::log \"test_event\"
  "
  assert_success
}

@test "audit::log: missing payload defaults to {}" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"
  source "$WGX_ROOT/lib/audit.bash"
  audit::log "test_event"
  [ -f "$WGX_AUDIT_LOG" ]
  run python3 -c "
import json
with open('$WGX_AUDIT_LOG') as f:
    entry = json.loads(f.read().strip())
assert entry['payload'] == {}, f'Expected empty payload, got {entry[\"payload\"]!r}'
print('OK')
"
  assert_success
  assert_output "OK"
}
