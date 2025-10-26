#!/usr/bin/env bats

load test_helper

setup() {
  REPO_ROOT="$(pwd)"
}

@test "profile::load falls back to root tasks when nested tasks are empty" {
  WORKDIR="$BATS_TEST_TMPDIR/fallback"
  mkdir -p "$WORKDIR/.wgx"
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  apiVersion: v1
  tasks: {}
tasks:
  Build App:
    cmd:
      - npm
      - run
      - build
    args:
      - --prod
    safe: "yes"
YAML

  helper_script="$BATS_TEST_TMPDIR/check_fallback.sh"
  cat >"$helper_script" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$1"
WORKDIR="$2"
source "$REPO_ROOT/lib/core.bash"
source "$REPO_ROOT/modules/profile.bash"
cd "$WORKDIR"
profile::load ".wgx/profile.yml"
printf 'order=%s\n' "${WGX_TASK_ORDER[*]}"
printf 'cmd=%s\n' "${WGX_TASK_CMDS[buildapp]}"
printf 'safe=%s\n' "${WGX_TASK_SAFE[buildapp]}"
SH
  chmod +x "$helper_script"

  run env WGX_PROFILE_DEPRECATION=quiet "$helper_script" "$REPO_ROOT" "$WORKDIR"
  assert_success
  assert_line --index 0 -- "order=buildapp"
  assert_line --index 1 -- "cmd=ARRJSON:[\"npm\", \"run\", \"build\", \"--prod\"]"
  assert_line --index 2 -- "safe=1"
}

@test "profile task parsing deduplicates order and tokenizes commands" {
  WORKDIR="$BATS_TEST_TMPDIR/tokenize"
  mkdir -p "$WORKDIR/.wgx"
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  apiVersion: v1
  tasks:
    BuildApp:
      cmd: echo first
    buildapp:
      cmd: echo second
    Format:
      cmd: go fmt ./...
      args:
        - ./internal/...
      safe: "no"
    Safe Task:
      cmd:
        linux:
          - /bin/echo
          - done
        default:
          - echo
          - default
      args:
        - extra
      safe: "yes"
YAML

  helper_script="$BATS_TEST_TMPDIR/check_tokenize.sh"
  cat >"$helper_script" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$1"
WORKDIR="$2"
source "$REPO_ROOT/lib/core.bash"
source "$REPO_ROOT/modules/profile.bash"
cd "$WORKDIR"
profile::load ".wgx/profile.yml"
printf 'order_count=%s\n' "${#WGX_TASK_ORDER[@]}"
printf 'order_values=%s\n' "${WGX_TASK_ORDER[*]}"
printf 'format_cmd=%s\n' "${WGX_TASK_CMDS[format]}"
printf 'format_safe=%s\n' "${WGX_TASK_SAFE[format]}"
printf 'safetask_cmd=%s\n' "${WGX_TASK_CMDS[safetask]}"
printf 'safetask_safe=%s\n' "${WGX_TASK_SAFE[safetask]}"
SH
  chmod +x "$helper_script"

  run env WGX_PROFILE_DEPRECATION=quiet "$helper_script" "$REPO_ROOT" "$WORKDIR"
  assert_success
  assert_line --index 0 -- "order_count=3"
  assert_line --index 1 -- "order_values=buildapp format safetask"
  assert_line --index 2 -- "format_cmd=STR:go fmt ./... ./internal/..."
  assert_line --index 3 -- "format_safe=0"
  assert_line --index 4 -- "safetask_cmd=ARRJSON:[\"/bin/echo\", \"done\", \"extra\"]"
  assert_line --index 5 -- "safetask_safe=1"
}

@test "profile task preserves raw strings and quotes appended args" {
  WORKDIR="$BATS_TEST_TMPDIR/raw"
  mkdir -p "$WORKDIR/.wgx"
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  apiVersion: v1
tasks:
  raw-str:
    cmd: echo 'a # b'
    args:
      - x y
  array-task:
    cmd:
      - bash
      - -lc
      - echo ok
    args:
      linux:
        - --flag
  scalar-cmd:
    cmd: 42
YAML

  helper_script="$BATS_TEST_TMPDIR/check_raw.sh"
  cat >"$helper_script" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$1"
WORKDIR="$2"
source "$REPO_ROOT/lib/core.bash"
source "$REPO_ROOT/modules/profile.bash"
cd "$WORKDIR"
profile::load ".wgx/profile.yml"
printf 'raw_cmd=%s\n' "${WGX_TASK_CMDS["raw-str"]}"
printf 'array_cmd=%s\n' "${WGX_TASK_CMDS["array-task"]}"
printf 'scalar_cmd=%s\n' "${WGX_TASK_CMDS["scalar-cmd"]}"
SH
  chmod +x "$helper_script"

  run "$helper_script" "$REPO_ROOT" "$WORKDIR"
  assert_success
  assert_line --index 0 -- "raw_cmd=STR:echo 'a # b' 'x y'"
  assert_line --index 1 -- "array_cmd=ARRJSON:[\"bash\", \"-lc\", \"echo ok\", \"--flag\"]"
  assert_line --index 2 -- "scalar_cmd=STR:42"
}
