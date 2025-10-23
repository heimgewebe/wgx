#!/usr/bin/env bats

setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
  REPO_ROOT="$(pwd)"
  WORKDIR="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$WORKDIR"
  export WGX_DIR="$REPO_ROOT"
  export PATH="$WGX_DIR/cli:$PATH"
}

@test "validate --json ok:true bei gültigem Profil" {
  mkdir -p "$WORKDIR/.wgx"
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  apiVersion: v1
tasks:
  test:
    cmd: echo ok
YAML
  cd "$WORKDIR"
  run wgx validate --json
  assert_success
  assert_output --partial '"ok":true'
}

@test "validate --json ok:false wenn kein Manifest vorhanden" {
  cd "$WORKDIR"
  run wgx validate --json
  [ "$status" -ne 0 ]
  assert_output --partial '"ok":false'
}

