#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
}

@test "--list shows retained runner commands" {
  run wgx --list
  [ "$status" -eq 0 ]
  [[ "${lines[*]}" =~ doctor ]]
  [[ "${lines[*]}" =~ tasks ]]
  [[ "${lines[*]}" =~ validate ]]
  [[ "${lines[*]}" =~ version ]]
}

@test "help output includes dynamic command list" {
  run wgx --help
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Commands:" ]]
  [[ "${output}" =~ "validate" ]]
}

@test "retired mutation and placeholder commands are not exposed" {
  local cmd available
  available="$(wgx --list)"
  for cmd in clean config heal hooks init quick reload release routine send setup start sync-remote vibe; do
    [[ "$available" != *"$cmd"* ]]
    run wgx "$cmd" --help
    assert_failure
  done
}
