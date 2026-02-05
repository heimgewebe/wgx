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
  run "$WGX_DIR/wgx" audit git --correlation-id run-A
  assert_success

  # Check output contains the file path (which is absolute or relative to CWD)
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
  rm -f ".wgx/out/audit.git.v1.json"
  run "$WGX_DIR/wgx" audit git --stdout-json
  assert_success
  assert_output --partial '"kind": "audit.git"'

  # Should not write the default file if stdout-json is used
  [ ! -f ".wgx/out/audit.git.v1.json" ]
}

@test "audit git: returns 0 even on status error (policy check)" {
  # Setup: Remove origin to force audit error (ensure it exists first or ignore error)
  git remote add origin https://example.com/repo.git || true
  git remote remove origin

  run "$WGX_DIR/wgx" audit git --stdout-json
  assert_success

  # Verify status is error in JSON
  assert_output --partial '"status": "error"'

  # Verify uncertainty level is number, not string (robustness check)
  run jq -e '.uncertainty.level | type == "number"' <<< "$output"
  assert_success
}

@test "audit git: missing jq returns non-zero" {
  # Use env var injection to force failure
  WGX_JQ_BIN="/nonexistent-jq" run "$WGX_DIR/wgx" audit git --stdout-json
  assert_failure 1
  assert_output --partial "Error: jq executable not found"
}

@test "audit git: runs outside git repo (returns status error, exit 0)" {
  local nogit_dir
  nogit_dir="$(mktemp -d)"

  # Run inside the clean dir
  pushd "$nogit_dir" >/dev/null

  run "$WGX_DIR/wgx" audit git --stdout-json

  popd >/dev/null
  rm -rf "$nogit_dir"

  assert_success
  assert_output --partial '"status": "error"'
  assert_output --partial '"id": "git.repo.present"'
  assert_output --partial '"message": "No git repository detected."'
  # Check if repo name is auto-detected as the directory name (tmp dir name starts with tmp...)
  # We can't predict exact name but we can check it's not "unknown" or empty if we care,
  # but checking status is sufficient for now.
}

@test "audit git: type checks for numeric fields and booleans" {
  run "$WGX_DIR/wgx" audit git --stdout-json
  assert_success

  run jq -e '
    (.uncertainty.level|type)=="number" and
    (.facts.is_detached_head|type)=="boolean" and
    (.facts.working_tree.staged|type)=="number" and
    (.facts.working_tree.unstaged|type)=="number" and
    (.facts.working_tree.untracked|type)=="number" and
    (.facts.upstream.ref_exists == null or (.facts.upstream.ref_exists|type)=="boolean")
  ' <<<"$output"
  assert_success
}
