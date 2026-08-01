#!/usr/bin/env bats
# wgx validate --profile: declared profiles, native front doors, JSON receipts.

load test_helper

setup() {
  REPO_ROOT="$(pwd)"
  WORKDIR="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$WORKDIR/.wgx"
  export WGX_DIR="$REPO_ROOT"
  export PATH="$WGX_DIR/cli:$PATH"
}

write_profile() {
  cat >"$WORKDIR/.wgx/profile.yml"
}

standard_profile() {
  write_profile <<'YAML'
wgx:
  apiVersion: v1
  validate:
    quick: [lint]
    full: [lint, test, integration, bench]
    unsupported:
      bench: "no benchmark harness"
    ciOnly:
      integration: "needs cloud credentials"
  tasks:
    lint: "echo linting"
    test: "echo testing"
YAML
}

# bats-assert in diesem Repo liefert kein refute_output; siehe tests/send.bats.
assert_not_output() {
  if [[ "$output" == *"$1"* ]]; then
    fail "Output should not contain: $1"
  fi
}

receipt_field() {
  python3 -c 'import json,sys;print(json.loads(sys.stdin.read())["'"$1"'"])'
}

@test "validate ohne --profile bleibt reine Manifest-Prüfung" {
  standard_profile
  cd "$WORKDIR"
  run wgx validate --json
  assert_success
  assert_output --partial '"ok":true'
  assert_not_output 'wgx.validate.receipt'
}

@test "quick-Profil ruft nur die deklarierten nativen Tasks auf" {
  standard_profile
  cd "$WORKDIR"
  run wgx validate --profile quick --json
  assert_success
  assert_output --partial '"kind": "wgx.validate.receipt"'
  assert_output --partial '"result": "passed"'
  assert_output --partial '"name": "lint"'
  assert_not_output '"name": "test"'
}

@test "dry-run zeigt deterministische Check-Reihenfolge ohne Ausführung" {
  standard_profile
  cd "$WORKDIR"
  run wgx validate --profile full --dry-run
  assert_success
  [ "${lines[0]}" = "run	lint" ]
  [ "${lines[1]}" = "run	test" ]
  [ "${lines[2]}" = "skip	integration" ]
  [ "${lines[3]}" = "skip	bench" ]

  # Wiederholung liefert exakt dieselbe Reihenfolge.
  local first="$output"
  run wgx validate --profile full --dry-run
  assert_success
  [ "$output" = "$first" ]
}

@test "unsupported und ci-only werden explizit als skipped ausgewiesen" {
  standard_profile
  cd "$WORKDIR"
  run wgx validate --profile full --json
  assert_success
  assert_output --partial '"kind": "ci-only"'
  assert_output --partial '"name": "integration"'
  assert_output --partial '"kind": "unsupported"'
  assert_output --partial '"reason": "no benchmark harness"'
}

@test "rotes Receipt bei fehlschlagendem nativem Check" {
  write_profile <<'YAML'
wgx:
  apiVersion: v1
  validate:
    quick: [lint]
  tasks:
    lint: "exit 3"
YAML
  cd "$WORKDIR"
  run wgx validate --profile quick --json
  [ "$status" -ne 0 ]
  assert_output --partial '"result": "failed"'
  assert_output --partial '"status": "failed"'
  assert_output --partial '"exit_code": 3'
}

@test "Timeout wird als eigener Status und nicht als Erfolg gewertet" {
  write_profile <<'YAML'
wgx:
  apiVersion: v1
  validate:
    quick: [slow]
  tasks:
    slow: "sleep 30"
YAML
  cd "$WORKDIR"
  run wgx validate --profile quick --timeout 1 --json
  [ "$status" -ne 0 ]
  assert_output --partial '"status": "timeout"'
  assert_output --partial '"result": "failed"'
}

@test "Profil das einen unbekannten Task nennt scheitert statt still zu überspringen" {
  write_profile <<'YAML'
wgx:
  apiVersion: v1
  validate:
    quick: [ghost]
  tasks:
    lint: "echo linting"
YAML
  cd "$WORKDIR"
  run wgx validate --profile quick --json
  [ "$status" -ne 0 ]
  assert_output --partial '"kind": "undeclared"'
  assert_output --partial '"result": "failed"'
}

@test "nicht deklariertes Profil meldet das explizit" {
  write_profile <<'YAML'
wgx:
  apiVersion: v1
  tasks:
    lint: "echo linting"
YAML
  cd "$WORKDIR"
  run wgx validate --profile full --json
  [ "$status" -eq 2 ]
  assert_output --partial 'validate_profile_not_declared:full'
}

@test "unbekannter Profilname wird abgelehnt" {
  standard_profile
  cd "$WORKDIR"
  run wgx validate --profile turbo
  [ "$status" -eq 2 ]
}

@test "Receipt enthält den vollständigen Vertrag inklusive Hash" {
  standard_profile
  cd "$WORKDIR"
  git init -q -b main
  git -c user.email=t@e.invalid -c user.name=T add -A
  git -c user.email=t@e.invalid -c user.name=T commit -qm init
  run wgx validate --profile quick --json
  assert_success

  python3 - "$output" <<'PY'
import hashlib, json, sys

receipt = json.loads(sys.argv[1])
for field in (
    "schema_version", "kind", "profile", "repository", "manifest",
    "checks", "skipped", "result", "started_at", "finished_at",
    "timeout_seconds", "environment", "receipt_sha256", "does_not_establish",
):
    assert field in receipt, f"missing receipt field: {field}"

for field in ("root", "name", "commit", "dirty"):
    assert field in receipt["repository"], f"missing repository field: {field}"
assert len(receipt["repository"]["commit"]) == 40
assert receipt["repository"]["dirty"] is False

check = receipt["checks"][0]
for field in ("name", "status", "exit_code", "duration_ms", "command", "command_sha256"):
    assert field in check, f"missing check field: {field}"
assert check["duration_ms"] >= 0

assert "identity_sha256" in receipt["environment"]

expected = dict(receipt)
del expected["receipt_sha256"]
digest = hashlib.sha256(
    json.dumps(expected, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()
).hexdigest()
assert digest == receipt["receipt_sha256"], "receipt hash does not cover the receipt body"
PY
}

@test "dirty state wird im Receipt geführt" {
  standard_profile
  cd "$WORKDIR"
  git init -q -b main
  git -c user.email=t@e.invalid -c user.name=T add -A
  git -c user.email=t@e.invalid -c user.name=T commit -qm init
  echo "uncommitted" >stray.txt
  run wgx validate --profile quick --json
  assert_success
  assert_output --partial '"dirty": true'
}

@test "Secrets werden aus Kommandos und Umgebungsidentität redigiert" {
  write_profile <<'YAML'
wgx:
  apiVersion: v1
  validate:
    quick: [publish]
  tasks:
    publish: "echo deploying API_TOKEN=hunter2 --password swordfish"
YAML
  cd "$WORKDIR"
  GITHUB_TOKEN=topsecretvalue run wgx validate --profile quick --json
  assert_success
  assert_not_output 'hunter2'
  assert_not_output 'swordfish'
  assert_not_output 'topsecretvalue'
  assert_output --partial '[REDACTED]'
  assert_output --partial 'GITHUB_TOKEN'
}

@test "--output schreibt das Receipt zusätzlich in eine Datei" {
  standard_profile
  cd "$WORKDIR"
  run wgx validate --profile quick --output "$BATS_TEST_TMPDIR/receipt.json"
  assert_success
  [ -f "$BATS_TEST_TMPDIR/receipt.json" ]
  run python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["result"])' "$BATS_TEST_TMPDIR/receipt.json"
  assert_output "passed"
}
