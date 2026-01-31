#!/usr/bin/env bats

load test_helper

setup() {
  # Resolve absolute path to WGX root
  export WGX_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  PATH="$WGX_DIR/bin:$WGX_DIR:$PATH"

  # Setup temp git repo
  TEST_TEMP_DIR="$(mktemp -d)"
  cd "$TEST_TEMP_DIR"
  git init
  git config user.email "you@example.com"
  git config user.name "Your Name"
  git commit --allow-empty -m "Initial commit"

  # Create .wgx/out for artifacts
  mkdir -p .wgx/out
}

teardown() {
  cd "$BATS_TEST_DIRNAME" || true
  rm -rf "$TEST_TEMP_DIR"
}

@test "audit git: creates unique artifacts per correlation_id" {
  run wgx audit git --correlation-id run-A
  assert_success

  # Check output contains the file path (which is absolute or relative to CWD)
  # wgx audit git prints relative path usually, but we are in temp dir.
  # It writes to .wgx/out relative to CWD.

  assert_output --partial ".wgx/out/audit.git.v1.run-A.json"

  # Check file exists
  [ -f ".wgx/out/audit.git.v1.run-A.json" ]

  # Validate JSON structure (kind check)
  run jq -e '.kind=="audit.git"' ".wgx/out/audit.git.v1.run-A.json"
  assert_success

  run wgx audit git --correlation-id run-B
  assert_success
  assert_output --partial ".wgx/out/audit.git.v1.run-B.json"
  [ -f ".wgx/out/audit.git.v1.run-B.json" ]

  # Verify both exist
  [ -f ".wgx/out/audit.git.v1.run-A.json" ]
}

@test "audit git: stdout-json does not write file" {
  run wgx audit git --stdout-json
  assert_success
  assert_output --partial '"kind": "audit.git"'

  # Should not write the default file if stdout-json is used
  [ ! -f ".wgx/out/audit.git.v1.json" ]
}
