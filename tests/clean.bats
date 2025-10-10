#!/usr/bin/env bats

setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
}

teardown() {
  rm -rf .pytest_cache .mypy_cache dist build target .tox .nox .venv .uv .pdm-build node_modules
}

@test "clean removes cache directories by default" {
  mkdir -p .pytest_cache/foo
  run wgx clean
  assert_success
  [ ! -d .pytest_cache ]
}

@test "clean --dry-run keeps files intact" {
  mkdir -p .mypy_cache/foo
  run wgx clean --dry-run
  assert_success
  [ -d .mypy_cache ]
}

@test "clean --deep without --force warns" {
  run wgx clean --deep
  [ "$status" -ne 0 ]
  [[ "$output" =~ "--deep ist destruktiv" ]]
}
