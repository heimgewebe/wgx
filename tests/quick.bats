#!/usr/bin/env bats

load test_helper

setup() {
  WGX_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
  git init
  git config user.email "t@t.com"
  git config user.name "T"
  git commit --allow-empty -m "init"
  git checkout -b feature
}

teardown() {
  cd "$BATS_TEST_DIRNAME"
  rm -rf "$TEST_DIR"
}

@test "_quick_send_available detects cmd_send when defined" {
  source "$WGX_ROOT/cmd/quick.bash"
  cmd_send() { :; }
  run _quick_send_available
  assert_success
}

@test "_quick_send_available returns false when cmd_send is not defined" {
  source "$WGX_ROOT/cmd/quick.bash"
  unset -f cmd_send 2>/dev/null || true
  run _quick_send_available
  assert_failure
}

@test "cmd_quick propagates non-zero exit code from cmd_send" {
  source "$WGX_ROOT/lib/core.bash"
  source "$WGX_ROOT/cmd/quick.bash"
  guard_run() { return 0; }
  cmd_send() { return 3; }

  run cmd_quick
  assert_failure 3
}

@test "cmd_quick returns 0 when cmd_send succeeds" {
  source "$WGX_ROOT/lib/core.bash"
  source "$WGX_ROOT/cmd/quick.bash"
  guard_run() { return 0; }
  cmd_send() { return 0; }

  run cmd_quick
  assert_success
}
