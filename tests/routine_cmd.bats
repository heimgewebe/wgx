#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  PATH="$WGX_DIR/bin:$WGX_DIR:$PATH"

  # Setup temp git repo
  TEST_TEMP_DIR="$(mktemp -d)"

  # Create a separate upstream repo to act as origin
  UPSTREAM_DIR="$TEST_TEMP_DIR/upstream.git"
  mkdir -p "$UPSTREAM_DIR"
  git init --bare --initial-branch=main "$UPSTREAM_DIR"

  # Create local repo
  LOCAL_DIR="$TEST_TEMP_DIR/local"
  mkdir -p "$LOCAL_DIR"
  cd "$LOCAL_DIR"

  # Configure git to be quiet about init
  git config --global init.defaultBranch main 2>/dev/null || true

  git init
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Add remote
  git remote add origin "$UPSTREAM_DIR"

  # Create a commit and push to populate upstream
  echo "init" > README.md
  git add README.md
  git commit -m "init"
  git push -u origin main

  mkdir -p .wgx/out
}

teardown() {
  cd "$BATS_TEST_DIRNAME" || true
  rm -rf "$TEST_TEMP_DIR"
}

@test "wgx routine: help when no args" {
  run wgx routine
  assert_success
  assert_output --partial "Usage:"
}

@test "wgx routine: unknown routine rejected" {
  run wgx routine unknown.routine
  assert_failure
  assert_output --partial "unknown routine"
}

@test "wgx routine: mode normalization preview -> dry-run (allowed outside git repo)" {
  local nogit_dir
  nogit_dir="$(mktemp -d)"
  pushd "$nogit_dir" >/dev/null

  run wgx routine git.repair.remote-head preview

  popd >/dev/null
  rm -rf "$nogit_dir"

  assert_success
  assert_output --partial "routine.preview"
}

@test "wgx routine: apply requires git repo (exit 1 + ok false)" {
  local nogit_dir
  nogit_dir="$(mktemp -d)"
  pushd "$nogit_dir" >/dev/null

  run wgx routine git.repair.remote-head apply

  popd >/dev/null
  rm -rf "$nogit_dir"

  assert_failure
  assert_output --partial "routine.result"
}

@test "wgx routine: invalid mode rejected" {
  run wgx routine git.repair.remote-head invalid_mode
  assert_failure
  assert_output --partial "Invalid mode"
}

@test "wgx routine: flags preserved when mode is absent" {
  run wgx routine git.repair.remote-head --help
  assert_success
  assert_output --partial "routine.preview"
}

@test "wgx routine: uses WGX_GIT_BIN for execution" {
  # Resolve real git path portably
  local real_git
  real_git="$(command -v git)" || fail "git not found"

  # Create a wrapper script that acts as 'git' but logs usage
  # We assume we are in LOCAL_DIR from setup
  local mock_git="$TEST_TEMP_DIR/mock_git.sh"
  local git_log="$TEST_TEMP_DIR/git_log.txt"

  # Ensure the mock delegates to real git for EVERYTHING,
  # so behavior is identical to real execution, but we get a log.
  cat <<EOF >"$mock_git"
#!/bin/bash
# Log every invocation arguments
echo "MOCK_GIT_EXEC: \$*" >> "$git_log"
# Passthrough to real git
exec "$real_git" "\$@"
EOF
  chmod +x "$mock_git"

  # We use the mock as our git binary
  WGX_GIT_BIN="$mock_git" run wgx routine git.repair.remote-head apply

  assert_success

  # Check if our mock was called for the actual steps
  if [ ! -f "$git_log" ]; then
    fail "Mock git was not executed for steps"
  fi

  run cat "$git_log"
  assert_output --partial "MOCK_GIT_EXEC: remote set-head origin --auto"
  assert_output --partial "MOCK_GIT_EXEC: fetch origin --prune"
}
