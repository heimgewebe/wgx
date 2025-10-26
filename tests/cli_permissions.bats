#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
}

@test "CLI entrypoint has executable bit set" {
  run git ls-files -s cli/wgx
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == 100755* ]]
}
