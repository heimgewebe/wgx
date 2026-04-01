#!/usr/bin/env bats

load test_helper

setup() {
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

@test "semver_gt: strictly greater returns success, equal or less returns failure" {
  run semver_gt "2.0.0" "1.9.9"
  assert_success
  run semver_gt "1.0.0" "1.0.0"
  assert_failure
  run semver_gt "1.0.0" "2.0.0"
  assert_failure
}

@test "semver_lt: strictly less returns success, equal or greater returns failure" {
  run semver_lt "1.0.0" "2.0.0"
  assert_success
  run semver_lt "1.0.0" "1.0.0"
  assert_failure
  run semver_lt "2.0.0" "1.0.0"
  assert_failure
}

@test "semver_ge: greater-or-equal returns success, less returns failure" {
  run semver_ge "1.0.0" "1.0.0"
  assert_success
  run semver_ge "2.0.0" "1.0.0"
  assert_success
  run semver_ge "1.0.0" "2.0.0"
  assert_failure
}

@test "semver_le: less-or-equal returns success, greater returns failure" {
  run semver_le "1.0.0" "1.0.0"
  assert_success
  run semver_le "1.0.0" "2.0.0"
  assert_success
  run semver_le "2.0.0" "1.0.0"
  assert_failure
}

@test "semver gt/lt/ge/le are consistent with each other" {
  run semver_gt "2.0.0" "1.0.0"; assert_success
  run semver_lt "2.0.0" "1.0.0"; assert_failure
  run semver_ge "2.0.0" "1.0.0"; assert_success
  run semver_le "2.0.0" "1.0.0"; assert_failure
  run semver_gt "1.0.0" "1.0.0"; assert_failure
  run semver_lt "1.0.0" "1.0.0"; assert_failure
  run semver_ge "1.0.0" "1.0.0"; assert_success
  run semver_le "1.0.0" "1.0.0"; assert_success
}
