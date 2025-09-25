#!/usr/bin/env bats

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR:$PATH"
}

@test "--list shows available commands" {
  run "$WGX_DIR/wgx" --list
  [ "$status" -eq 0 ]
  [[ "${lines[*]}" =~ reload ]]
  [[ "${lines[*]}" =~ doctor ]]
}

@test "help output includes dynamic command list" {
  run "$WGX_DIR/wgx" --help
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Commands:" ]]
  [[ "${output}" =~ "reload" ]]
}
