#!/usr/bin/env bats

setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
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
