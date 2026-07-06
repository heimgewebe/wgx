#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
  export WGX_VIBE_STATE_ROOT="$(mktemp -d)/vibes"
}

@test "vibe help prints usage" {
  run wgx vibe --help
  assert_success
  [[ "$output" =~ "wgx vibe" ]]
  [[ "$output" =~ "doctor" ]]
  [[ "$output" =~ "adopt" ]]
}

@test "vibe without args prints usage" {
  run wgx vibe
  assert_success
  [[ "$output" =~ "Usage:" ]]
}

@test "vibe status reports empty state root" {
  run wgx vibe status
  assert_success
  [[ "$output" =~ "VIBE_STATUS=empty" ]]
}

@test "vibe doctor is read-only and reports repo" {
  run wgx vibe doctor --repo "$WGX_DIR"
  assert_success
  [[ "$output" =~ "VIBE_DOCTOR=ok" ]]
  [[ "$output" =~ "repo=$WGX_DIR" ]]
  [[ "$output" =~ "note=doctor is read-only" ]]
}

@test "vibe adopt writes receipt for explicit branch" {
  run wgx vibe adopt --repo "$WGX_DIR" --branch test-branch --name test-adopt "adopt current wgx branch"
  assert_success
  [[ "$output" =~ "VIBE_ADOPTED=1" ]]
  [[ "$output" =~ "branch=test-branch" ]]
  receipt="$(printf '%s\n' "$output" | awk -F= '/^receipt=/{print $2}')"
  [ -f "$receipt" ]
  grep -q '"state": "adopted"' "$receipt"
}
