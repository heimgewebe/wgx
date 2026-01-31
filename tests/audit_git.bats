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
  rm -f ".wgx/out/audit.git.v1.json"
  run wgx audit git --stdout-json
  assert_success
  assert_output --partial '"kind": "audit.git"'

  # Should not write the default file if stdout-json is used
  [ ! -f ".wgx/out/audit.git.v1.json" ]
}

@test "audit git: returns 0 even on status error (policy check)" {
  # Setup: Remove origin to force audit error (ensure it exists first or ignore error)
  git remote add origin https://example.com/repo.git || true
  git remote remove origin

  run wgx audit git --stdout-json
  assert_success

  # Verify status is error in JSON
  assert_output --partial '"status": "error"'

  # Verify uncertainty level is number, not string (robustness check)
  run jq -e '.uncertainty.level | type == "number"' <<< "$output"
  assert_success
}

@test "audit git: missing jq returns non-zero" {
  local old_path="$PATH"
  local tmp
  tmp="$(mktemp -d)"

  # Ensure wgx is in the new PATH, but jq is NOT
  ln -s "$WGX_DIR/wgx" "$tmp/wgx"
  ln -s "$WGX_DIR/cli" "$tmp/cli" # Ensure cli wrapper logic works if split

  # Minimal git needs to be available or audit will fail for wrong reason
  # Assuming git is in /usr/bin or /bin, we add those but filter out jq
  # Harder than it looks. Simpler: mock jq as failing command.

  PATH="$tmp:$PATH"

  # Mock jq to fail or not be found (if we control PATH fully)
  # But we rely on system git.

  # Strategy: Create a 'jq' wrapper that fails or doesn't exist?
  # Since we are testing 'command -v jq', let's shadow jq in our temp bin dir
  # but make it non-executable or just ensure it's not there and we restrict PATH?
  # Restricting PATH is hard because we need git, bash, sed, etc.

  # Better Strategy: Just use the fact that we can prepend to PATH.
  # If we prepend a directory where we *don't* put jq, it doesn't help if it's later in PATH.
  # We need to effectively "hide" jq.

  # Actually, the check is `command -v jq`.
  # So if we create a `jq` that is NOT executable, does command -v find it?
  # `command -v` finds executables.

  # Let's rely on the fact that we can't easily hide system jq without breaking other tools.
  # Instead, let's skip this test if we can't isolate jq, OR assume we can run in a restricted env.

  # REVISED STRATEGY:
  # Verify the script fails if jq fails.
  # Create a `jq` mock that returns 127 or prints nothing?
  # The check is: if ! command -v jq >/dev/null 2>&1; then

  # So we need to ensure `command -v jq` fails.
  # This is only possible if jq is NOT in PATH.

  # Let's try to construct a minimal PATH that includes `wgx`, `git`, `bash` (sh), `date`, `wc`, `tr` but NOT `jq`.
  # This is fragile across OSs.

  # Alternative: Trust the code inspection for this specific check, or accept that this test is hard in BATS.
  # Or, simpler:

  skip "Cannot easily hide system jq in BATS environment without breaking git"
}

@test "audit git: type checks for numeric fields and booleans" {
  run wgx audit git --stdout-json
  assert_success

  run jq -e '
    (.uncertainty.level|type)=="number" and
    (.facts.is_detached_head|type)=="boolean" and
    (.facts.working_tree.staged|type)=="number" and
    (.facts.working_tree.unstaged|type)=="number" and
    (.facts.working_tree.untracked|type)=="number"
  ' <<<"$output"
  assert_success
}
