#!/usr/bin/env bats

load test_helper
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# ------------------------------------------------------------
#  Test: assert_equal and assert_not_equal
# ------------------------------------------------------------

@test "assert_equal succeeds for identical strings" {
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_equal "foo" "foo"'
  assert_success
}

@test "assert_equal fails and shows diff for different multiline values" {
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_equal $'"'"'line1\nline2\n'"'"' $'"'"'line1\nlineX\n'"'"''
  assert_failure
  # Diff output should contain 'lineX'
  [[ "$output" == *"lineX"* ]]
  [[ "$output" == *"expected"* ]]
}

@test "assert_not_equal succeeds for different strings" {
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_not_equal "foo" "bar"'
  assert_success
}

@test "assert_not_equal fails for equal strings" {
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_not_equal "foo" "foo"'
  assert_failure
  [[ "$output" == *"Expected values to differ"* ]]
}

# ------------------------------------------------------------
#  Test: assert_json_equal and assert_json_not_equal
# ------------------------------------------------------------

@test "assert_json_equal ignores key order" {
  local a='{"b":1,"a":2}'
  local b='{"a":2,"b":1}'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_equal "$1" "$2"' _ "$a" "$b"
  assert_success
}

@test "assert_json_equal fails on semantic difference" {
  local a='{"a":1}'
  local b='{"a":2}'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_equal "$1" "$2"' _ "$a" "$b"
  assert_failure
  [[ "$output" == *"assert_equal failed"* ]]
}

@test "assert_json_not_equal succeeds on difference" {
  local a='{"x":1}'
  local b='{"x":2}'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_not_equal "$1" "$2"' _ "$a" "$b"
  assert_success
}

@test "assert_json_not_equal fails on equal JSON" {
  local a='{"x":1,"y":2}'
  local b='{"y":2,"x":1}'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_not_equal "$1" "$2"' _ "$a" "$b"
  assert_failure
  [[ "$output" == *"Expected values to differ"* ]]
}

# ------------------------------------------------------------
#  Test: JSON normalization fallback behavior
# ------------------------------------------------------------

@test "_json_normalize works with jq or python3" {
  if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    skip "neither jq nor python3 available"
  fi
  local j='{"z":1,"a":2}'
  run bash -lc 'source tests/test_helper/bats-assert/load; _json_normalize <<<"$1"' _ "$j"
  assert_success
  # Keys sorted lexicographically
  assert_output partial '"a":2'
  assert_output partial '"z":1'
}

# ------------------------------------------------------------
#  Test: edge/error cases
# ------------------------------------------------------------

@test "assert_json_equal reports invalid JSON" {
  local bad='{"a":1'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_equal "$1" "$2"' _ "$bad" '{"a":1}'
  assert_failure
  [[ "$output" == *"invalid"* ]]
}

@test "assert_json_not_equal reports invalid JSON" {
  local bad='[1,2'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_not_equal "$1" "$2"' _ "$bad" '[1,2,3]'
  assert_failure
  [[ "$output" == *"invalid"* ]]
}

# ------------------------------------------------------------
#  Sanity check for regression: plain success
# ------------------------------------------------------------

@test "assertions library loads cleanly" {
  run bash -lc 'source tests/test_helper/bats-assert/load; echo OK'
  assert_success
  assert_output "OK"
}

# EOF
