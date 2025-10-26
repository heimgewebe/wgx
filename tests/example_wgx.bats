#!/usr/bin/env bats

load test_helper

setup() {
  export PATH="$PWD/cli:$PATH"
}

@test "wgx shows help with -h" {
  run wgx -h
  assert_success
  assert_output --partial "wgx"
  assert_output --partial "help"
}

@test "wgx shows help with --help" {
  run wgx --help
  assert_success
  assert_output --partial "wgx"
  assert_output --partial "help"
}
