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
