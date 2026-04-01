#!/usr/bin/env bats

load test_helper

setup() {
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
  git init
  git config user.email "t@t.com"
  git config user.name "T"
  git commit --allow-empty -m "init"
  export WGX_DIR="$TEST_DIR"
}

teardown() {
  cd "$BATS_TEST_DIRNAME"
  rm -rf "$TEST_DIR"
  unset WGX_DIR
}

@test "status: OFFLINE=0 does not display offline message" {
  OFFLINE=0 run wgx status
  assert_success
  if [[ "$output" == *"OFFLINE=1 aktiv"* ]]; then
    _assert_fail "Expected no OFFLINE message but got: $output"
  fi
}

@test "status: OFFLINE=1 displays offline message" {
  OFFLINE=1 run wgx status
  assert_success
  assert_output --partial "OFFLINE=1 aktiv"
}
