#!/usr/bin/env bats

load test_helper

setup() {
  WORKDIR="$(mktemp -d)"
  METAREPO_VERIFY_COMMIT="fe6950616b2d06343e284a56a8944e0a36f1f972"
}

teardown() {
  rm -rf "$WORKDIR"
}

@test "repository WGX guard pins every external action to a full commit" {
  run python3 "$WGX_PROJECT_ROOT/scripts/check_wgx_guard_action_pins.py" \
    "$WGX_PROJECT_ROOT/.github/workflows/wgx-guard.yml"
  assert_success
  assert_output --partial "PASS: all external uses references"
}

@test "repository WGX smoke pins every external action to a full commit" {
  run python3 "$WGX_PROJECT_ROOT/scripts/check_wgx_guard_action_pins.py" \
    "$WGX_PROJECT_ROOT/.github/workflows/wgx-smoke.yml"
  assert_success
  assert_output --partial "PASS: all external uses references"
}

@test "repository WGX guard is only a pinned Metarepo compatibility shim" {
  workflow="$(cat "$WGX_PROJECT_ROOT/.github/workflows/wgx-guard.yml")"
  [[ "$workflow" == *"uses: heimgewebe/metarepo/.github/workflows/reusable-repo-verify.yml@$METAREPO_VERIFY_COMMIT"* ]]
  [[ "$workflow" == *"mode: guard"* ]]
  [[ "$workflow" != *"runs-on:"* ]]
  [[ "$workflow" != *"actions/checkout@"* ]]
  [[ "$workflow" != *"wgx task guard"* ]]
}

@test "repository WGX smoke is only a pinned Metarepo compatibility shim" {
  run python3 "$WGX_PROJECT_ROOT/scripts/check_wgx_smoke_contract.py" \
    "$WGX_PROJECT_ROOT/.github/workflows/wgx-smoke.yml"
  assert_success
  assert_output --partial "pinned Metarepo smoke compatibility shim"
}

@test "WGX example profile declares deterministic local guard and smoke tasks" {
  run env WGX_TARGET_ROOT="$WGX_PROJECT_ROOT" \
    "$WGX_PROJECT_ROOT/wgx" tasks --json
  assert_success
  assert_output --partial '"name":"guard"'
  assert_output --partial '"name":"smoke"'

  run env WGX_TARGET_ROOT="$WGX_PROJECT_ROOT" DRYRUN=1 \
    "$WGX_PROJECT_ROOT/wgx" task guard
  assert_success
  assert_output --partial "[DRY-RUN]"
  assert_output --partial "scripts/check_wgx_guard_action_pins.py"
  assert_output --partial "scripts/check_wgx_smoke_contract.py"
  assert_output --partial "scripts/validate_workflow.py .github/workflows/wgx-guard.yml"
  assert_output --partial "scripts/validate_workflow.py .github/workflows/wgx-smoke.yml"
  [[ "$output" != *"scripts/validate_operator_capabilities.py"* ]]

  run env WGX_TARGET_ROOT="$WGX_PROJECT_ROOT" DRYRUN=1 \
    "$WGX_PROJECT_ROOT/wgx" task smoke
  assert_success
  assert_output --partial "[DRY-RUN]"
  assert_output --partial "scripts/validate_workflow.py .github/workflows/wgx-smoke.yml"
}

@test "WGX guard pin checker rejects mutable major tags" {
  cat >"$WORKDIR/workflow.yml" <<'YAML'
jobs:
  guard:
    steps:
      - uses: actions/checkout@v4
YAML

  run python3 "$WGX_PROJECT_ROOT/scripts/check_wgx_guard_action_pins.py" \
    "$WORKDIR/workflow.yml"
  assert_failure
  assert_output --partial "actions/checkout@v4 is not pinned"
}

@test "WGX guard pin checker rejects abbreviated SHAs" {
  cat >"$WORKDIR/workflow.yml" <<'YAML'
jobs:
  guard:
    steps:
      - uses: actions/setup-python@a26af69
YAML

  run python3 "$WGX_PROJECT_ROOT/scripts/check_wgx_guard_action_pins.py" \
    "$WORKDIR/workflow.yml"
  assert_failure
  assert_output --partial "actions/setup-python@a26af69 is not pinned"
}

@test "WGX guard pin checker permits repository-local actions" {
  cat >"$WORKDIR/workflow.yml" <<'YAML'
jobs:
  guard:
    steps:
      - uses: "./local-action"
      - uses: "actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5"
YAML

  run python3 "$WGX_PROJECT_ROOT/scripts/check_wgx_guard_action_pins.py" \
    "$WORKDIR/workflow.yml"
  assert_success
}

@test "WGX smoke contract rejects local implementation logic" {
  cp "$WGX_PROJECT_ROOT/.github/workflows/wgx-smoke.yml" "$WORKDIR/smoke-local.yml"
  python3 - "$WORKDIR/smoke-local.yml" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("  smoke:\n", "  smoke:\n    runs-on: ubuntu-latest\n", 1)
path.write_text(text, encoding="utf-8")
PY

  run python3 "$WGX_PROJECT_ROOT/scripts/check_wgx_smoke_contract.py" \
    "$WORKDIR/smoke-local.yml"
  assert_failure
  assert_output --partial "contains implementation detail: runs-on:"
}

@test "WGX smoke contract rejects mutable Metarepo ref" {
  cp "$WGX_PROJECT_ROOT/.github/workflows/wgx-smoke.yml" "$WORKDIR/smoke-main.yml"
  python3 - "$WORKDIR/smoke-main.yml" "$METAREPO_VERIFY_COMMIT" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
commit = sys.argv[2]
text = path.read_text(encoding="utf-8").replace(
    f"reusable-repo-verify.yml@{commit}",
    "reusable-repo-verify.yml@main",
)
path.write_text(text, encoding="utf-8")
PY

  run python3 "$WGX_PROJECT_ROOT/scripts/check_wgx_smoke_contract.py" \
    "$WORKDIR/smoke-main.yml"
  assert_failure
  assert_output --partial "missing pinned Metarepo verification reusable"
  assert_output --partial "must not use @main"
}
