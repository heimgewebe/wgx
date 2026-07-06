#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
}

@test "vibe help prints usage" {
  run wgx vibe --help
  assert_success
  [[ "$output" =~ "wgx vibe" ]]
  [[ "$output" =~ "Vibe lane plan" ]]
}

@test "vibe plan requires an idea" {
  run wgx vibe
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Idee fehlt" ]]
}
