#!/usr/bin/env bats

load test_helper

# No custom wgx() helper needed - tests use `run wgx routine` directly
# and the PATH is already set in setup()

setup() {
  export WGX_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  
  # Sanity check: ensure the CLI binary is executable
  [ -x "$WGX_DIR/cli/wgx" ] || {
    echo "ERROR: wgx CLI not executable: $WGX_DIR/cli/wgx" >&2
    return 1
  }
  
  TEST_TEMP_DIR="$(mktemp -d)"
  cd "$TEST_TEMP_DIR"
  mkdir -p .wgx/out
}

teardown() {
  cd "$BATS_TEST_DIRNAME" || true
  rm -rf "$TEST_TEMP_DIR"
}

@test "wgx routine: help when no args" {
  run "$WGX_DIR/cli/wgx" routine
  assert_success
  assert_output --partial "Usage:"
  assert_output --partial "Available routines:"
}

@test "wgx routine: unknown routine rejected" {
  run "$WGX_DIR/cli/wgx" routine does.not.exist preview
  assert_failure
  assert_output --partial "unknown routine"
}

@test "wgx routine: mode normalization preview -> dry-run (allowed outside git repo)" {
  # This should run preview path of routine and create preview json even outside git repo
  run "$WGX_DIR/cli/wgx" routine git.repair.remote-head preview
  assert_success
  # Should print a file path under .wgx/out
  assert_output --partial ".wgx/out/"
  # Should have created generic fallback
  [ -f ".wgx/out/routine.preview.json" ]
  run jq -e '.kind=="routine.preview" and .mode=="dry-run"' ".wgx/out/routine.preview.json"
  assert_success
  # Check for note about apply requiring git repo
  run jq -e '.note | contains("Apply erfordert ein Git-Repo")' ".wgx/out/routine.preview.json"
  assert_success
}

@test "wgx routine: apply requires git repo (exit 1 + ok false)" {
  # Ensure we are NOT in a git repo (setup creates clean temp dir)
  run "$WGX_DIR/cli/wgx" routine git.repair.remote-head apply
  assert_failure
  # Check stderr message
  assert_output --partial "nicht in einem Git-Repo"

  # Check JSON output for ok:false and error details
  [ -f ".wgx/out/routine.result.json" ]
  run jq -e '.ok == false and (.stderr | contains("nicht in einem Git-Repo"))' ".wgx/out/routine.result.json"
  assert_success
}

@test "wgx routine: invalid mode rejected" {
  run "$WGX_DIR/cli/wgx" routine git.repair.remote-head bananas
  assert_failure
  assert_output --partial "Usage:"
}

@test "wgx routine: flags preserved when mode is absent" {
  # e.g. `wgx routine <id> --help` should not interpret --help as mode
  # The dispatcher whitelisting ensures --help is NOT consumed as mode.
  # So mode defaults to "dry-run".
  # Then routine implementation runs in dry-run mode.
  run "$WGX_DIR/cli/wgx" routine git.repair.remote-head --help
  assert_success
  assert_output --partial ".wgx/out/"
  [ -f ".wgx/out/routine.preview.json" ]
}
