#!/usr/bin/env bats

load test_helper

setup() {
  # Setup temp git repo
  TEST_TEMP_DIR="$(mktemp -d)"
  cd "$TEST_TEMP_DIR"
  git init
  git config user.email "you@example.com"
  git config user.name "Your Name"
  git commit --allow-empty -m "Initial commit"

  # Ensure wgx can be found and libs are loaded
  # WGX_DIR is exported by test_helper or we set it here
  export WGX_DIR="$BATS_TEST_DIRNAME/.."
  PATH="$WGX_DIR:$PATH"
}

teardown() {
  cd "$BATS_TEST_DIRNAME" || true
  rm -rf "$TEST_TEMP_DIR"
}

@test "audit git: creates unique artifacts per correlation_id" {
  run wgx audit git --correlation-id run-A
  assert_success

  # Check output contains the file path
  assert_output --partial ".wgx/out/audit.git.v1.run-A.json"

  # Check file exists
  [ -f ".wgx/out/audit.git.v1.run-A.json" ]

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
