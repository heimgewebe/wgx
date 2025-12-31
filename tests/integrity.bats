#!/usr/bin/env bats

load test_helper

setup() {
  export TEST_DIR
  TEST_DIR="$(mktemp -d)"
  export WGX_TARGET_ROOT="$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "integrity: reports MISSING when file not found" {
  run wgx integrity
  assert_success
  # Note: info() output goes to stderr by default in lib/core.bash unless WGX_INFO_STDERR is changed or legacy logic applies.
  # However, run captures both stdout and stderr in $output.
  assert_output --partial "Kein Integritätsbericht gefunden"
  assert_output --partial "Status: MISSING"
}

@test "integrity: reports table when file found" {
  mkdir -p "$TEST_DIR/reports/integrity"
  cat <<JSON > "$TEST_DIR/reports/integrity/summary.json"
{
  "repo": "semantAH",
  "generated_at": "2023-10-27T10:00:00Z",
  "counts": {
    "claims": 12,
    "artifacts": 5,
    "loop_gaps": 3,
    "unclear": 2
  }
}
JSON

  run wgx integrity
  assert_success
  assert_output --partial "Integritäts-Diagnose (Beobachter-Modus)"
  assert_output --partial "Repo:       semantAH"
  assert_output --partial "Claims       | 12"
  assert_output --partial "Loop Gaps    | 3"
}
