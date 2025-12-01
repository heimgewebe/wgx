#!/usr/bin/env bats

load test_helper

setup() {
  # Create a clean temp directory for each test
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"

  # Initialize git repo in the temp directory
  git init
  git config user.email "you@example.com"
  git config user.name "Your Name"
  git commit --allow-empty -m "Initial commit"
  git checkout -b feature
}

teardown() {
  cd "$BATS_TEST_DIRNAME"
  rm -rf "$TEST_DIR"
}

@test "send: help works and does not mention sync" {
  run wgx send --help
  assert_success
  assert_output --partial "Usage:"

  # Check that output does NOT contain --no-sync-first
  # Since refute_output is missing, we implement it manually
  if [[ "$output" == *"--no-sync-first"* ]]; then
    fail "Output should not contain --no-sync-first"
  fi
}

@test "send: fails gracefully if not in repo (require_repo check)" {
  # Move out of the repo
  cd "$BATS_TMPDIR"
  run wgx send
  assert_failure
}

@test "send: help does not crash due to missing functions" {
  run wgx send --help
  assert_success
}
