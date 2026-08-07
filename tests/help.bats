#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
}

@test "--list shows available commands" {
  run wgx --list
  [ "$status" -eq 0 ]
  [[ "${lines[*]}" =~ reload ]]
  [[ "${lines[*]}" =~ doctor ]]
}

@test "help output includes dynamic command list" {
  run wgx --help
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Commands:" ]]
  [[ "${output}" =~ "reload" ]]
}

@test "removed placeholder commands are not exposed" {
  local cmd available
  available="$(wgx --list)"
  for cmd in config hooks release setup start; do
    [[ "$available" != *"$cmd"* ]]
    run wgx "$cmd" --help
    assert_failure
  done
}
