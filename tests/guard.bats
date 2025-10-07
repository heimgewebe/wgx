#!/usr/bin/env bats

setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
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
