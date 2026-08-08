#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
}

@test "--list exposes only the minimal runner ABI" {
  run wgx --list
  assert_success
  [ "${#lines[@]}" -eq 4 ]
  [ "${lines[0]}" = "help" ]
  [ "${lines[1]}" = "task" ]
  [ "${lines[2]}" = "tasks" ]
  [ "${lines[3]}" = "validate" ]
}

@test "help output includes the retained runner commands" {
  run wgx --help
  assert_success
  assert_output --partial "Commands:"
  assert_output --partial "task"
  assert_output --partial "tasks"
  assert_output --partial "validate"
}

@test "retired commands cannot reappear in the public CLI" {
  local cmd available
  available="$(wgx --list)"
  for cmd in audit clean config doctor env guard heal hooks init integrity lint quick reload release routine run selftest send setup start status sync-remote test version vibe; do
    [[ "$available" != *"$cmd"* ]]
    run wgx "$cmd" --help
    assert_failure
  done
}
