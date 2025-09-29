#!/usr/bin/env bats

setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
  source "$PWD/modules/semver.bash"
}

@test "caret range allows updates within next major" {
  run semver_in_caret_range "1.4.5" "^1.2.3"
  assert_success
  run semver_in_caret_range "2.0.0" "^1.2.3"
  assert_failure
}

@test "caret range pins zero major to next minor" {
  run semver_in_caret_range "0.2.5" "^0.2.3"
  assert_success
  run semver_in_caret_range "0.3.0" "^0.2.3"
  assert_failure
}

@test "caret range pins zero major zero minor to next patch" {
  run semver_in_caret_range "0.0.3" "^0.0.3"
  assert_success
  run semver_in_caret_range "0.0.4" "^0.0.3"
  assert_failure
}
