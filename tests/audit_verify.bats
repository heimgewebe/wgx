#!/usr/bin/env bats

load test_helper

setup() {
  WGX_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export WGX_DIR="$WGX_ROOT"
  export PATH="$WGX_ROOT/cli:$PATH"
  TEST_DIR="$(mktemp -d)"
  export WGX_AUDIT_LOG="$TEST_DIR/ledger.jsonl"
}

teardown() {
  rm -rf "$TEST_DIR"
  unset WGX_AUDIT_LOG
}

write_valid_ledger() {
  python3 - "$WGX_AUDIT_LOG" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

entry = {
    "timestamp": "2026-08-08T00:00:00Z",
    "event": "fixture",
    "git_sha": "0" * 40,
    "payload": {},
    "prev_hash": "0" * 64,
}
body = json.dumps(entry, sort_keys=True, separators=(",", ":"))
entry["hash"] = hashlib.sha256(body.encode("utf-8")).hexdigest()
Path(sys.argv[1]).write_text(
    json.dumps(entry, sort_keys=True, separators=(",", ":")) + "\n",
    encoding="utf-8",
)
PY
}

@test "audit verify: empty ledger is a read-only no-data success" {
  run wgx audit verify --strict
  assert_success
  assert_output --partial "ledger empty"
  [ ! -e "$WGX_AUDIT_LOG" ]
}

@test "audit verify: accepts a valid hash chain" {
  write_valid_ledger
  before="$(sha256sum "$WGX_AUDIT_LOG" | awk '{print $1}')"
  run wgx audit verify --strict
  assert_success
  assert_output "OK"
  after="$(sha256sum "$WGX_AUDIT_LOG" | awk '{print $1}')"
  [ "$before" = "$after" ]
}

@test "audit verify: strict mode fails on damaged evidence" {
  printf '%s\n' '{"prev_hash":"bad","hash":"bad"}' > "$WGX_AUDIT_LOG"
  run wgx audit verify --strict
  assert_failure
  assert_output --partial "prev_hash_mismatch"
}

@test "audit verify: non-strict mode reports damaged evidence as warning" {
  printf '%s\n' '{"prev_hash":"bad","hash":"bad"}' > "$WGX_AUDIT_LOG"
  run wgx audit verify
  assert_success
  assert_output --partial "non-strict mode"
}

@test "audit git is retired from the WGX command surface" {
  run wgx audit git --stdout-json
  assert_failure
  assert_output --partial "unknown subcommand git"
}
