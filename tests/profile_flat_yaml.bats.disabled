#!/usr/bin/env bats

load test_helper

setup() {
  REPO_ROOT="$(pwd)"
  export WGX_DIR="$REPO_ROOT"
  export PATH="$REPO_ROOT/cli:$PATH"
  mkdir -p "$BATS_TEST_TMPDIR/profile/.wgx"
  cd "$BATS_TEST_TMPDIR/profile"
}

@test "profile: cmd array + args merge executes as ARRJSON" {
  cat > .wgx/profile.yml <<'YAML'
wgx:
  apiVersion: v1
  tasks:
    t1:
      cmd:
        - bash
        - -lc
        - echo hi
      args:
        - there
      safe: true
YAML
  run wgx run --dry-run t1
  assert_success
  assert_output --partial "[DRY-RUN] bash -lc 'echo hi' there"
}

@test "profile: platform variants select linux/default" {
  cat > .wgx/profile.yml <<'YAML'
wgx:
  apiVersion: v1
  tasks:
    tplat:
      cmd:
        linux:
          - bash
          - -lc
          - echo linux
        default:
          - bash
          - -lc
          - echo default
      safe: true
YAML
  run wgx run --dry-run tplat
  assert_success
  if [[ "$output" == *"'echo linux'"* ]]; then
    assert_output --partial "[DRY-RUN] bash -lc 'echo linux'"
  else
    assert_output --partial "[DRY-RUN] bash -lc 'echo default'"
  fi
}

@test "profile: platform scalar variants resolve correctly" {
  cat > .wgx/profile.yml <<'YAML'
wgx:
  apiVersion: v1
  tasks:
    tplatstr:
      cmd:
        linux: echo linux scalar
        default: echo default scalar
      safe: true
YAML
  run wgx run --dry-run tplatstr
  assert_success
  if [[ "$output" == *"linux scalar"* ]]; then
    assert_output --partial "[DRY-RUN] echo linux scalar"
  else
    assert_output --partial "[DRY-RUN] echo default scalar"
  fi
}

@test "profile: scalar cmd + args append to dry-run output" {
  cat > .wgx/profile.yml <<'YAML'
wgx:
  apiVersion: v1
  tasks:
    tscalar:
      cmd: echo hello world
      args:
        - and
        - "more stuff"
      safe: true
YAML
  run wgx run --dry-run tscalar
  assert_success
  assert_output --partial "[DRY-RUN] echo hello world and 'more stuff'"
}

@test "profile: inline scalar task treated as STR cmd with args" {
  cat > .wgx/profile.yml <<'YAML'
wgx:
  apiVersion: v1
  tasks:
    tinline: echo inline
    tinlineargs:
      cmd: echo inline
      args:
        - appended
      safe: true
YAML
  run wgx run --dry-run tinlineargs
  assert_success
  assert_output --partial "[DRY-RUN] echo inline appended"
}

@test "profile: empty args keep command intact" {
  cat > .wgx/profile.yml <<'YAML'
wgx:
  apiVersion: v1
  tasks:
    tempty:
      cmd: echo stay put
      args: []
      safe: true
YAML
  run wgx run --dry-run tempty
  assert_success
  assert_output --partial "[DRY-RUN] echo stay put"
}

@test "profile: quoted hash remains inside command" {
  cat > .wgx/profile.yml <<'YAML'
wgx:
  apiVersion: v1
  tasks:
    thash:
      cmd:
        - bash
        - -lc
        - "echo '#hash remains'"
      safe: true
YAML
  run wgx run --dry-run thash
  assert_success
  assert_output --partial "#hash remains"
}

@test "profile: escaped double quotes survive parsing" {
  cat > .wgx/profile.yml <<'YAML'
wgx:
  apiVersion: v1
  tasks:
    tescape:
      cmd:
        - bash
        - -lc
        - "printf \"quote: \\\"X\\\"\""
      args:
        - and spaces
      safe: true
YAML
  run wgx run --dry-run tescape
  assert_success
  assert_output --partial "[DRY-RUN] bash -lc"
  assert_output --partial "'and spaces'"
  assert_output --partial "quote: \\\"X\\\""
}
