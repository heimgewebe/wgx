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

@test "wgx setup subcommand dispatches" {
  run wgx setup -h
  assert_success
}
