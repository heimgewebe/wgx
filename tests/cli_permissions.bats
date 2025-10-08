#!/usr/bin/env bats

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
}

@test "CLI entrypoint has executable bit set" {
  run git ls-files -s cli/wgx
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == 100755* ]]
}
