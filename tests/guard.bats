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
  rm -f ".wgx/profile.yml"
  if [[ -f ".wgx/profile.example.yml.bak" ]]; then
    mv .wgx/profile.example.yml.bak .wgx/profile.example.yml
  fi
}

@test "guard fails if no profile is found" {
  if [[ -f ".wgx/profile.example.yml" ]]; then
    mv .wgx/profile.example.yml .wgx/profile.example.yml.bak
  fi
  run wgx guard
  assert_failure
  assert_output --partial "No .wgx/profile.yml or .wgx/profile.example.yml found."
}

@test "guard profile check passes with .wgx/profile.example.yml" {
  run wgx guard --lint --test --no-secrets
  assert_success
  assert_output --partial "Profile found."
}

@test "guard profile check passes with .wgx/profile.yml" {
  touch .wgx/profile.yml
  run wgx guard --lint --test --no-secrets
  assert_success
  assert_output --partial "Profile found."
}

@test "guard fails on files >=1MB" {
  local bigfile="tmp_guard_bigfile"
  truncate -s 1M "$bigfile"
  git add "$bigfile"

  run wgx guard
  assert_failure
  assert_output --partial "Zu große Dateien"
}
