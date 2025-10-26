#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
}

teardown() {
  local bigfile="tmp_guard_bigfile"
  git reset --quiet HEAD "$bigfile" >/dev/null 2>&1 || true
  rm -f "$bigfile"
}

@test "guard fails on files >=1MB" {
  local bigfile="tmp_guard_bigfile"
  truncate -s 1M "$bigfile"
  git add "$bigfile"

  run wgx guard
  assert_failure
  assert_output --partial "Zu große Dateien"
}
