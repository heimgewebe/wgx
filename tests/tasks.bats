#!/usr/bin/env bats

load test_helper

setup() {
  REPO_ROOT="$(pwd)"
  export WGX_DIR="$REPO_ROOT"
  export PATH="$REPO_ROOT/cli:$PATH"

  WORKDIR="$BATS_TEST_TMPDIR/project"
  mkdir -p "$WORKDIR/.wgx"
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  apiVersion: v1
  tasks:
    list:
      desc: Build project
      group: dev
      safe: true
      cmd: echo build
    echo:
      cmd: ./printargs.sh
YAML
  cat >"$WORKDIR/printargs.sh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@"
SH
  chmod +x "$WORKDIR/printargs.sh"
  cd "$WORKDIR"
}

@test "tasks --json returns machine readable output" {
  run wgx tasks --json
  assert_success
  assert_output --partial '"tasks":['
  assert_output --partial '"name":"list"'
  assert_output --partial '"desc":"Build project"'
  assert_output --partial '"group":"dev"'
  assert_output --partial '"safe":true'
  assert_output --partial '"name":"echo"'
}

@test "task command forwards flags transparently" {
  run wgx task echo --json --flag
  assert_success
  assert_line --index 0 -- "--json"
  assert_line --index 1 -- "--flag"
}

@test "task execution has no implicit audit or event side effects" {
  marker="$BATS_TEST_TMPDIR/curl-called"
  fakebin="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$fakebin"
  cat >"$fakebin/curl" <<SH
#!/usr/bin/env bash
touch "$marker"
exit 99
SH
  chmod +x "$fakebin/curl"

  audit_dir="$BATS_TEST_TMPDIR/audit"
  run env PATH="$fakebin:$PATH" HAUSKI_ENABLE=1 WGX_AUDIT_DIR="$audit_dir" wgx task echo -- harmless
  assert_success
  assert_output -- "harmless"
  [ ! -e "$marker" ]
  [ ! -e "$audit_dir" ]
}
