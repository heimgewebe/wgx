#!/usr/bin/env bats

load test_helper

setup() {
  REPO_ROOT="$(pwd)"
  export WGX_DIR="$REPO_ROOT"
  export PATH="$REPO_ROOT/cli:$PATH"

  WORKDIR="$BATS_TEST_TMPDIR/run-profile"
  mkdir -p "$WORKDIR/.wgx"
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  apiVersion: v1
  tasks:
    echoit:
      cmd:
        - echo
      safe: true
YAML
  cd "$WORKDIR"
}

@test "run: shows usage when task is missing" {
  run wgx run
  assert_failure
  assert_error --partial "Usage:"
  assert_error --partial "wgx run [--dry-run|-n] <task> [--] [args...]"
}

@test "run: forwards args appearing after --" {
  run wgx run --dry-run echoit -- foo "bar baz"
  assert_success
  assert_output --partial "[DRY-RUN] echo foo 'bar baz'"
}

@test "run: reports an error when task is unknown" {
  run wgx run --dry-run does-not-exist
  assert_failure
  assert_error --partial "Task not defined: does-not-exist"
}
