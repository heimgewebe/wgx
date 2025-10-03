#!/usr/bin/env bats

setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
}

@test "env doctor reports tool availability" {
  run wgx env doctor
  assert_success
  assert_output --partial "wgx env doctor"
  assert_output --partial "git"
}

@test "env doctor --json emits minimal JSON" {
  run wgx env doctor --json
  assert_success
  assert_output --partial '"tools"'
  assert_output --partial '"platform"'
}

@test "env doctor --fix is a no-op outside Termux" {
  unset TERMUX_VERSION
  run wgx env doctor --fix
  assert_success
  assert_error --partial "only supported on Termux"
}

@test "env doctor --strict fails when git is missing" {
  local tmpbin
  tmpbin="$(mktemp -d)"
  for cmd in dirname readlink uname head tr; do
    ln -s "$(command -v "$cmd")" "$tmpbin/$cmd"
  done
  run env PATH="$tmpbin" "$WGX_DIR/cli/wgx" env doctor --strict
  local strict_status=$status
  rm -rf "$tmpbin"
  [ "$strict_status" -ne 0 ]
}
