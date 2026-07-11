#!/usr/bin/env bats

load test_helper

setup() {
  WORKDIR="$(mktemp -d)"
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

@test "repository WGX smoke is reusable and bound to a fixed CLI commit" {
  run python3 "$WGX_PROJECT_ROOT/scripts/check_wgx_smoke_contract.py" \
    "$WGX_PROJECT_ROOT/.github/workflows/wgx-smoke.yml"
  assert_success
  assert_output --partial "is reusable and bound"
}

@test "WGX example profile declares executable guard and smoke tasks" {
  run env WGX_TARGET_ROOT="$WGX_PROJECT_ROOT" \
    "$WGX_PROJECT_ROOT/wgx" tasks --json
  assert_success
  assert_output --partial '"name":"guard"'
  assert_output --partial '"name":"smoke"'

  run env WGX_TARGET_ROOT="$WGX_PROJECT_ROOT" \
    "$WGX_PROJECT_ROOT/wgx" task guard
  assert_success
  assert_output --partial "all external uses references"
  assert_output --partial "is reusable and bound"

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

@test "WGX smoke contract rejects an unhashed PyYAML install" {
  cp "$WGX_PROJECT_ROOT/.github/workflows/wgx-smoke.yml" "$WORKDIR/smoke-unhashed.yml"
  python3 - "$WORKDIR/smoke-unhashed.yml" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("--require-hashes", "--no-cache-dir")
text = text.replace(
    "--hash=sha256:ba1cc08a7ccde2d2ec775841541641e4548226580ab850948cbfda66a1befcdc",
    "--hash=sha256:" + "0" * 64,
)
path.write_text(text, encoding="utf-8")
PY

  run python3 "$WGX_PROJECT_ROOT/scripts/check_wgx_smoke_contract.py" \
    "$WORKDIR/smoke-unhashed.yml"
  assert_failure
  assert_output --partial "missing hash-only dependency install"
  assert_output --partial "missing pinned PyYAML wheel hash"
}

@test "WGX smoke contract rejects a mutable CLI ref" {
  cat >"$WORKDIR/smoke.yml" <<'YAML'
"on":
  workflow_call:
jobs:
  smoke:
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
        with:
          ref: main
      - run: echo "WGX profile does not declare a smoke task"
      - run: wgx task smoke
YAML

  run python3 "$WGX_PROJECT_ROOT/scripts/check_wgx_smoke_contract.py" \
    "$WORKDIR/smoke.yml"
  assert_failure
  assert_output --partial "must not use ref: main"
}
