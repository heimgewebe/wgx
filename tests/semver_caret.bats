#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() { source modules/semver.bash; }

@test "^0.0.3 allows 0.0.3 and <0.0.4" {
  run bash -lc 'semver_in_caret_range 0.0.3 ^0.0.3'
  assert_success
  run bash -lc 'semver_in_caret_range 0.0.4 ^0.0.3'
  assert_failure
}

@test "^0.2.5 allows <0.3.0" {
  run bash -lc 'semver_in_caret_range 0.2.9 ^0.2.5'
  assert_success
  run bash -lc 'semver_in_caret_range 0.3.0 ^0.2.5'
  assert_failure
}

@test "^1.2.3 allows <2.0.0" {
  run bash -lc 'semver_in_caret_range 1.9.9 ^1.2.3'
  assert_success
  run bash -lc 'semver_in_caret_range 2.0.0 ^1.2.3'
  assert_failure
}

@test "v-prefixed versions are accepted" {
  run bash -lc 'semver_in_caret_range v1.2.3 ^1.2.0'
  assert_success
}
