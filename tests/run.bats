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
  run wgx run 2>&1
  assert_failure
  assert_output --partial "Usage: wgx run <task>"
}

@test "run: forwards args appearing after --" {
  run wgx run echoit -- foo "bar baz"
  assert_success
  assert_output "foo bar baz"
}

@test "run: reports an error when task is unknown" {
  run wgx run does-not-exist 2>&1
  assert_failure
  assert_output --partial "Task not defined: does-not-exist"
}

@test "run: parses -n and produces DRY-RUN output" {
  run wgx run -n echoit -- foo "bar baz"
  assert_success
  assert_output --partial "[DRY-RUN]"
  assert_output --partial "echo"
  assert_output --partial "foo"
  assert_output --partial "bar baz"
}

@test "run: parses --dry-run and produces DRY-RUN output" {
  run wgx run --dry-run echoit -- foo
  assert_success
  assert_output --partial "[DRY-RUN]"
  assert_output --partial "echo"
  assert_output --partial "foo"
}

@test "run: rejects unknown options" {
  run wgx run --nope 2>&1
  assert_failure
  assert_output --partial "Unknown option: --nope"
}
