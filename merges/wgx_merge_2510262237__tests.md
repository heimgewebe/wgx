### 📄 tests/.gitkeep

**Größe:** 0 B | **md5:** `d41d8cd98f00b204e9800998ecf8427e`

```plaintext

```

### 📄 tests/assertions.bats

**Größe:** 4 KB | **md5:** `66917295732241896c35a5123f2ff8d8`

```plaintext
#!/usr/bin/env bats

load test_helper
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# ------------------------------------------------------------
#  Test: assert_equal and assert_not_equal
# ------------------------------------------------------------

@test "assert_equal succeeds for identical strings" {
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_equal "foo" "foo"'
  assert_success
}

@test "assert_equal fails and shows diff for different multiline values" {
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_equal $'"'"'line1\nline2\n'"'"' $'"'"'line1\nlineX\n'"'"''
  assert_failure
  # Diff output should contain 'lineX'
  [[ "$output" == *"lineX"* ]]
  [[ "$output" == *"expected"* ]]
}

@test "assert_not_equal succeeds for different strings" {
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_not_equal "foo" "bar"'
  assert_success
}

@test "assert_not_equal fails for equal strings" {
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_not_equal "foo" "foo"'
  assert_failure
  [[ "$output" == *"Expected values to differ"* ]]
}

# ------------------------------------------------------------
#  Test: assert_json_equal and assert_json_not_equal
# ------------------------------------------------------------

@test "assert_json_equal ignores key order" {
  local a='{"b":1,"a":2}'
  local b='{"a":2,"b":1}'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_equal "$1" "$2"' _ "$a" "$b"
  assert_success
}

@test "assert_json_equal fails on semantic difference" {
  local a='{"a":1}'
  local b='{"a":2}'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_equal "$1" "$2"' _ "$a" "$b"
  assert_failure
  [[ "$output" == *"assert_equal failed"* ]]
}

@test "assert_json_not_equal succeeds on difference" {
  local a='{"x":1}'
  local b='{"x":2}'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_not_equal "$1" "$2"' _ "$a" "$b"
  assert_success
}

@test "assert_json_not_equal fails on equal JSON" {
  local a='{"x":1,"y":2}'
  local b='{"y":2,"x":1}'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_not_equal "$1" "$2"' _ "$a" "$b"
  assert_failure
  [[ "$output" == *"Expected values to differ"* ]]
}

# ------------------------------------------------------------
#  Test: JSON normalization fallback behavior
# ------------------------------------------------------------

@test "_json_normalize works with jq or python3" {
  if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    skip "neither jq nor python3 available"
  fi
  local j='{"z":1,"a":2}'
  run bash -lc 'source tests/test_helper/bats-assert/load; _json_normalize <<<"$1"' _ "$j"
  assert_success
  # Keys sorted lexicographically
  assert_output partial '"a":2'
  assert_output partial '"z":1'
}

# ------------------------------------------------------------
#  Test: edge/error cases
# ------------------------------------------------------------

@test "assert_json_equal reports invalid JSON" {
  local bad='{"a":1'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_equal "$1" "$2"' _ "$bad" '{"a":1}'
  assert_failure
  [[ "$output" == *"invalid"* ]]
}

@test "assert_json_not_equal reports invalid JSON" {
  local bad='[1,2'
  run bash -lc 'source tests/test_helper/bats-assert/load; assert_json_not_equal "$1" "$2"' _ "$bad" '[1,2,3]'
  assert_failure
  [[ "$output" == *"invalid"* ]]
}

# ------------------------------------------------------------
#  Sanity check for regression: plain success
# ------------------------------------------------------------

@test "assertions library loads cleanly" {
  run bash -lc 'source tests/test_helper/bats-assert/load; echo OK'
  assert_success
  assert_output "OK"
}

# EOF
```

### 📄 tests/clean.bats

**Größe:** 3 KB | **md5:** `f60f70700561721909733607862cab73`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  local test_dir repo_root
  if [ -n "${BATS_TEST_FILENAME:-}" ]; then
    test_dir="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
  else
    test_dir="$(pwd)"
  fi
  repo_root="$(cd "$test_dir/.." && pwd)"

  export WGX_DIR="$(pwd)"
  export PATH="$repo_root/cli:$PATH"
  export WGX_CLI_ROOT="$repo_root"
}

teardown() {
  rm -rf .pytest_cache .mypy_cache dist build target .tox .nox .venv .uv .pdm-build node_modules dirty-tree.txt
}

run_clean_in_dir() {
  local target="$1"
  shift
  local runner
  runner="$(mktemp)"
  cat <<'SCRIPT' >"$runner"
#!/usr/bin/env bash
set -e
set -u
if ! set -o pipefail 2>/dev/null; then
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    echo "clean-runner: 'pipefail' wird nicht unterstützt; fahre ohne fort." >&2
  fi
fi
CLI_ROOT="$1"
TARGET="$2"
shift 2
export WGX_DIR="$TARGET"
source "$CLI_ROOT/lib/core.bash"
source "$CLI_ROOT/cmd/clean.bash"
cd "$TARGET"
cmd_clean "$@"
exit $?
SCRIPT
  chmod +x "$runner"
  run "$runner" "$WGX_CLI_ROOT" "$target" "$@"
  rm -f "$runner"
}

init_git_repo() {
  local repo
  repo="$(mktemp -d)"
  git -C "$repo" init >/dev/null 2>&1
  (cd "$repo" && git config user.email "wgx@example.test" && git config user.name "WGX Test")
  printf '%s' 'tracked' >"$repo/tracked.txt"
  git -C "$repo" add tracked.txt >/dev/null 2>&1
  git -C "$repo" commit -m 'init' >/dev/null 2>&1
  echo "$repo"
}

@test "clean removes cache directories by default" {
  mkdir -p .pytest_cache/foo
  mkdir -p dist/keep
  run wgx clean
  assert_success
  [ ! -d .pytest_cache ]
  [ -d dist ]
}

@test "clean --dry-run keeps files intact" {
  mkdir -p .mypy_cache/foo
  run wgx clean --dry-run
  assert_success
  [ -d .mypy_cache ]
}

@test "clean --build removes build artefacts" {
  mkdir -p dist/foo build/bar
  run wgx clean --build
  assert_success
  [ ! -d dist ]
  [ ! -d build ]
}

@test "clean --git --dry-run succeeds" {
  run wgx clean --git --dry-run
  assert_success
  [[ "$output" =~ "Clean (Dry-Run) abgeschlossen." ]]
}

@test "clean --git aborts on dirty worktree" {
  local repo
  repo="$(init_git_repo)"
  echo 'dirty' >>"$repo"/tracked.txt
  run_clean_in_dir "$repo" --git
  assert_failure
  [[ "$output" =~ "Arbeitsverzeichnis ist nicht sauber" ]]
  rm -rf "$repo"
}

@test "clean --deep without --force warns" {
  run wgx clean --deep
  [ "$status" -ne 0 ]
  [[ "$output" =~ "--deep ist destruktiv" ]]
}

@test "clean --deep --force removes untracked files in repo" {
  local repo
  repo="$(init_git_repo)"
  touch "$repo"/scratch.txt
  run_clean_in_dir "$repo" --deep --force
  assert_success
  [ ! -f "$repo"/scratch.txt ]
  rm -rf "$repo"
}

@test "clean --deep --force aborts on dirty repo" {
  local repo
  repo="$(init_git_repo)"
  echo 'dirty' >>"$repo"/tracked.txt
  run_clean_in_dir "$repo" --deep --force
  assert_failure
  [[ "$output" =~ "Arbeitsverzeichnis ist nicht sauber" ]]
  rm -rf "$repo"
}
```

### 📄 tests/cli_permissions.bats

**Größe:** 248 B | **md5:** `0a753f99184ce8d39e2d2254c42523bc`

```plaintext
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
```

### 📄 tests/env.bats

**Größe:** 988 B | **md5:** `97e89f59da256da9cdb4e93880d095ea`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
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
  assert_output --partial "--fix is currently only supported on Termux"
}

@test "env doctor --strict fails when git is missing" {
  local tmpbin
  tmpbin="$(mktemp -d)"
  for cmd in bash dirname readlink uname head tr; do
    ln -s "$(command -v "$cmd")" "$tmpbin/$cmd"
  done
  run env PATH="$tmpbin" "$WGX_DIR/cli/wgx" env doctor --strict
  local strict_status=$status
  rm -rf "$tmpbin"
  [ "$strict_status" -ne 0 ]
}
```

### 📄 tests/example_wgx.bats

**Größe:** 352 B | **md5:** `1575579e9f9d763df66961ab47fb3d17`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  export PATH="$PWD/cli:$PATH"
}

@test "wgx shows help with -h" {
  run wgx -h
  assert_success
  assert_output --partial "wgx"
  assert_output --partial "help"
}

@test "wgx shows help with --help" {
  run wgx --help
  assert_success
  assert_output --partial "wgx"
  assert_output --partial "help"
}
```

### 📄 tests/guard.bats

**Größe:** 448 B | **md5:** `3a861a1080476d6a78282bbb6f23a66b`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
}

teardown() {
  local bigfile="tmp_guard_bigfile"
  git reset --quiet HEAD "$bigfile" >/dev/null 2>&1 || true
  rm -f "$bigfile"
}

@test "guard fails on files >=1MB" {
  local bigfile="tmp_guard_bigfile"
  truncate -s 1M "$bigfile"
  git add "$bigfile"

  run wgx guard
  assert_failure
  assert_output --partial "Zu große Dateien"
}
```

### 📄 tests/help.bats

**Größe:** 421 B | **md5:** `6f36408619dc58a6d902ae2ddb1fd53d`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
}

@test "--list shows available commands" {
  run wgx --list
  [ "$status" -eq 0 ]
  [[ "${lines[*]}" =~ reload ]]
  [[ "${lines[*]}" =~ doctor ]]
}

@test "help output includes dynamic command list" {
  run wgx --help
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Commands:" ]]
  [[ "${output}" =~ "reload" ]]
}
```

### 📄 tests/metrics_snapshot.bats

**Größe:** 2 KB | **md5:** `a27a3f9ae3c640661f37936f29e42e05`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
  TMPDIR="$(mktemp -d)"
  # Werkzeug-Check: jq wird von den Tests benötigt
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq nicht gefunden – Tests werden übersprungen"
  fi
}

teardown() {
  rm -rf "$TMPDIR"
  # Aufräumen, falls im Repo-Root geschrieben wurde
  rm -f metrics.json
  rm -rf snapshots
}

@test "metrics snapshot creates file at default path (metrics.json) with required keys" {
  run scripts/wgx-metrics-snapshot.sh
  assert_success
  [ -f metrics.json ]
  # required top-level keys present
  run jq -e 'has("ts") and has("host") and has("updates") and has("backup") and has("drift")' metrics.json
  assert_success
}

@test "metrics snapshot respects WGX_METRICS_OUTPUT env" {
  export WGX_METRICS_OUTPUT="$TMPDIR/from-env.json"
  run scripts/wgx-metrics-snapshot.sh
  assert_success
  [ -f "$WGX_METRICS_OUTPUT" ]
  run jq -e 'has("ts") and has("host")' "$WGX_METRICS_OUTPUT"
  assert_success
}

@test "metrics snapshot errors on unknown option" {
  run scripts/wgx-metrics-snapshot.sh --definitely-unknown-flag
  assert_failure
  [[ "$output" =~ "Unbekannte Option" ]]
}

@test "metrics snapshot --output writes to custom path" {
  out="$TMPDIR/custom.json"
  run scripts/wgx-metrics-snapshot.sh --output "$out"
  assert_success
  [ -f "$out" ]
  run jq -e '.backup | has("last_ok") and has("age_days")' "$out"
  assert_success
}

@test "metrics snapshot --json prints valid JSON to stdout" {
  out="$TMPDIR/std.json"
  run scripts/wgx-metrics-snapshot.sh --json --output "$out"
  assert_success
  # stdout must be JSON and match file content structure-wise
  echo "$output" > "$TMPDIR/stdout.json"
  run jq -e type "$TMPDIR/stdout.json"
  assert_success
  run jq -e 'has("ts") and has("host") and has("updates") and has("backup") and has("drift")' "$TMPDIR/stdout.json"
  assert_success
}

@test "metrics snapshot fails on empty output path" {
  run scripts/wgx-metrics-snapshot.sh --output ""
  assert_failure
  [[ "$output" =~ "Der Ausgabe-Pfad darf nicht leer sein" ]]
}

@test "metrics snapshot creates parent directory for custom path" {
  nested="$TMPDIR/snapshots/metrics.json"
  run scripts/wgx-metrics-snapshot.sh --output "$nested"
  assert_success
  [ -f "$nested" ]
}
```

### 📄 tests/profile_parse_tasks.bats

**Größe:** 2 KB | **md5:** `19ba988cea06b5c19cb8639070a691bd`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  REPO_ROOT="$(pwd)"
  export WGX_DIR="$REPO_ROOT"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  # Stub python3 to force flat parser to be exercised when profile::load runs.
  cat >"$BATS_TEST_TMPDIR/bin/python3" <<'SH'
#!/usr/bin/env bash
exit 1
SH
  chmod +x "$BATS_TEST_TMPDIR/bin/python3"
  export PATH="$REPO_ROOT/cli:$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
  source "$REPO_ROOT/modules/profile.bash"
  WORKDIR="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORKDIR/.wgx"
  cd "$WORKDIR"
  profile::_reset
}

teardown() {
  profile::_reset
}

@test "flat parser loads inline and nested tasks without python" {
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  tasks:
    inline: echo inline
    nested:
      desc: Build project
      group: dev
      safe: true
      cmd: echo nested
    caution:
      cmd: echo caution
      safe: No
YAML

  profile::load "$WORKDIR/.wgx/profile.yml"
  assert_equal 0 "$?"

  assert_equal "inline nested caution" "${WGX_TASK_ORDER[*]}"

  assert_equal "STR:echo inline" "${WGX_TASK_CMDS[inline]}"
  assert_equal "" "${WGX_TASK_DESC[inline]}"
  assert_equal "" "${WGX_TASK_GROUP[inline]}"
  assert_equal "0" "${WGX_TASK_SAFE[inline]}"

  assert_equal "STR:echo nested" "${WGX_TASK_CMDS[nested]}"
  assert_equal "Build project" "${WGX_TASK_DESC[nested]}"
  assert_equal "dev" "${WGX_TASK_GROUP[nested]}"
  assert_equal "1" "${WGX_TASK_SAFE[nested]}"

  assert_equal "STR:echo caution" "${WGX_TASK_CMDS[caution]}"
  assert_equal "0" "${WGX_TASK_SAFE[caution]}"

  assert_equal "v1" "$PROFILE_VERSION"
}

@test "flat parser normalizes safe flag casing and defaults" {
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  tasks:
    safe_upper:
      safe: YES
      cmd: echo safe upper
    safe_mixed:
      safe: On
      cmd: echo safe mixed
    safe_false:
      safe: off
      cmd: echo unsafe
    metadata_only:
      desc: Example task
YAML

  profile::load "$WORKDIR/.wgx/profile.yml"
  assert_equal 0 "$?"

  assert_equal "1" "${WGX_TASK_SAFE[safe_upper]}"
  assert_equal "1" "${WGX_TASK_SAFE[safe_mixed]}"
  assert_equal "0" "${WGX_TASK_SAFE[safe_false]}"
  assert_equal "0" "${WGX_TASK_SAFE[metadata_only]}"

  assert_equal "STR:echo safe upper" "${WGX_TASK_CMDS[safe_upper]}"
  assert_equal "STR:echo safe mixed" "${WGX_TASK_CMDS[safe_mixed]}"
  assert_equal "STR:echo unsafe" "${WGX_TASK_CMDS[safe_false]}"
  assert_equal "STR:" "${WGX_TASK_CMDS[metadata_only]}"
  assert_equal "Example task" "${WGX_TASK_DESC[metadata_only]}"
}
```

### 📄 tests/profile_state.bats

**Größe:** 1014 B | **md5:** `778360019a3f19727426d1ec3fe46cc4`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  REPO_ROOT="$(pwd)"
}

@test "profile::ensure_loaded clears cached data when manifest disappears" {
  WORKDIR="$BATS_TEST_TMPDIR/project"
  mkdir -p "$WORKDIR/.wgx"
  cat >"$WORKDIR/.wgx/profile.yml" <<'YAML'
wgx:
  apiVersion: v1
  repoKind: webapp
YAML

  helper_script="$BATS_TEST_TMPDIR/check_profile.sh"
  cat >"$helper_script" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$1"
WORKDIR="$2"
export WGX_DIR="$REPO_ROOT"
source "$REPO_ROOT/lib/core.bash"
source "$REPO_ROOT/modules/profile.bash"
cd "$WORKDIR"
profile::load ".wgx/profile.yml"
printf 'before=%s\n' "${WGX_REPO_KIND}"
rm -f .wgx/profile.yml
if profile::ensure_loaded; then
  printf 'ensure=ok\n'
else
  printf 'ensure=fail\n'
fi
printf 'after=%s\n' "${WGX_REPO_KIND}"
SH
  chmod +x "$helper_script"

  run "$helper_script" "$REPO_ROOT" "$WORKDIR"
  assert_success
  assert_line --index 0 -- "before=webapp"
  assert_line --index 1 -- "ensure=fail"
  assert_line --index 2 -- "after="
}
```

### 📄 tests/profile_tasks.bats

**Größe:** 4 KB | **md5:** `e04784ee146d65632e6c162742c86a7d`

```plaintext
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
```

### 📄 tests/reload.bats

**Größe:** 2 KB | **md5:** `f7006aa8882330dc78b6dc5dc2d01a41`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  rm -rf tmprepo remote

  # Ermittle das Projekt-Root *bevor* wir in das temporäre Repository wechseln.
  # BATS_TEST_DIRNAME kann je nach Bats-Version relativ sein (z. B. "tests"),
  # daher lösen wir den Pfad zunächst absolut auf.
  local project_root
  project_root="$(cd "${BATS_TEST_DIRNAME:-$(dirname "${BATS_TEST_FILENAME}")}" && cd .. && pwd)"

  git init --initial-branch=main tmprepo >/dev/null
  cd tmprepo || exit 1
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "x" > x.txt
  git add x.txt
  git commit -m "init" >/dev/null
  # Already on main after git init --initial-branch=main
  # Fake-Remote
  git tag baseline >/dev/null
  mkdir -p ../remote && (cd ../remote && git init --bare --initial-branch=main >/dev/null 2>&1)
  git remote add origin ../remote
  git push -u origin main >/dev/null
  export WGX_DIR="$project_root"
  export PATH="$WGX_DIR/cli:$PATH"
}

teardown() {
  # zurück ins Tests-Verzeichnis und Repos aufräumen
  cd .. 2>/dev/null || true
  rm -rf tmprepo remote
}

@test "reload aborts on dirty working tree without force" {
  echo "local" > local.txt

  run wgx reload
  [ "$status" -ne 0 ]
  [ -f local.txt ]
  [[ "$output" =~ "reload abgebrochen" ]]
}

@test "reload --force resets and cleans" {
  echo "local" > local.txt

  run wgx reload --force
  [ "$status" -eq 0 ]
  [ ! -f local.txt ]
}

@test "reload --dry-run only prints plan" {
  run wgx reload --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "[DRY-RUN]" ]]
  [ -z "$(git status --porcelain)" ]
}
```

### 📄 tests/semver.bats

**Größe:** 638 B | **md5:** `7d66959371ff623c4da7082422392fbe`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  source "$PWD/modules/semver.bash"
}

@test "caret range allows updates within next major" {
  run semver_in_caret_range "1.4.5" "^1.2.3"
  assert_success
  run semver_in_caret_range "2.0.0" "^1.2.3"
  assert_failure
}

@test "caret range pins zero major to next minor" {
  run semver_in_caret_range "0.2.5" "^0.2.3"
  assert_success
  run semver_in_caret_range "0.3.0" "^0.2.3"
  assert_failure
}

@test "caret range pins zero major zero minor to next patch" {
  run semver_in_caret_range "0.0.3" "^0.0.3"
  assert_success
  run semver_in_caret_range "0.0.4" "^0.0.3"
  assert_failure
}
```

### 📄 tests/semver_caret.bats

**Größe:** 680 B | **md5:** `a0939ba4d8bd58d8b777b2ccc5ffff1b`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  source "$PWD/modules/semver.bash"
}

@test "^0.0.3 allows 0.0.3 and <0.0.4" {
  run semver_in_caret_range "0.0.3" "^0.0.3"
  assert_success
  run semver_in_caret_range "0.0.4" "^0.0.3"
  assert_failure
}

@test "^0.2.5 allows <0.3.0" {
  run semver_in_caret_range "0.2.9" "^0.2.5"
  assert_success
  run semver_in_caret_range "0.3.0" "^0.2.5"
  assert_failure
}

@test "^1.2.3 allows <2.0.0" {
  run semver_in_caret_range "1.9.9" "^1.2.3"
  assert_success
  run semver_in_caret_range "2.0.0" "^1.2.3"
  assert_failure
}

@test "v-prefixed versions are accepted" {
  run semver_in_caret_range "v1.2.3" "^1.2.0"
  assert_success
}
```

### 📄 tests/shell_ci.bats

**Größe:** 2 KB | **md5:** `9c6ab8c93a0a6166c6f503db110ab707`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  REPO_ROOT="$(pwd)"
}

@test "tracked shell scripts declare a shebang" {
  local script="$BATS_TEST_TMPDIR/check-shebang.sh"
  cat <<'SCRIPT' >"$script"
#!/usr/bin/env bash
set -e
set -u
if ! set -o pipefail 2>/dev/null; then
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    echo "shell-ci: 'pipefail' wird nicht unterstützt; fahre ohne fort." >&2
  fi
fi

mapfile -t files < <(git ls-files '*.sh' '*.bash' 'wgx' 'cli/wgx')
missing=()
for file in "${files[@]}"; do
  [[ -f "$file" ]] || continue
  first_line="$(head -n 1 "$file" 2>/dev/null || true)"
  if [[ ${first_line} != '#!'* ]]; then
    missing+=("$file")
  fi
done

if (( ${#missing[@]} > 0 )); then
  {
    echo "Missing shebang in shell scripts:"
    printf '  %s\n' "${missing[@]}"
  } >&2
  exit 1
fi
SCRIPT
  chmod +x "$script"

  run "$script"
  assert_success
  assert_output ""
}

@test "README shell CI commands stay aligned with GitHub Actions" {
  local -a readme_patterns=(
    "bash -n \$(git ls-files '*.sh' '*.bash')"
    "shfmt -d \$(git ls-files '*.sh' '*.bash')"
    "shellcheck -S style \$(git ls-files '*.sh' '*.bash')"
    "bats -r tests"
  )

  for pattern in "${readme_patterns[@]}"; do
    run grep -F "$pattern" "$REPO_ROOT/README.md"
    assert_success
  done

  local -a workflow_patterns=(
    "bash -n"
    "shfmt -d"
    "shellcheck -S style"
    "bats-core/bats-action"
  )

  for pattern in "${workflow_patterns[@]}"; do
    run grep -F "$pattern" "$REPO_ROOT/.github/workflows/ci.yml"
    assert_success
  done
}

@test "assertion helper self-tests pass" {
  run bats -r tests/assertions.bats
  assert_success
}
```

### 📄 tests/sync.bats

**Größe:** 2 KB | **md5:** `21e757af7b11aa0ef2643032de76fcf9`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
  rm -rf tmprepo remote
  git init --initial-branch=main tmprepo >/dev/null
  cd tmprepo || exit 1
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "x" > x.txt
  git add x.txt
  git commit -m "init" >/dev/null
  # Already on main after git init --initial-branch=main
  mkdir -p ../remote && (cd ../remote && git init --bare --initial-branch=main >/dev/null 2>&1)
  git remote add origin ../remote
  git push -u origin main >/dev/null
}

teardown() {
  cd ..
  rm -rf tmprepo remote
}

@test "sync aborts on dirty working tree without force" {
  echo "local" >> x.txt

  run wgx sync
  [ "$status" -ne 0 ]
  [[ "$output" =~ "sync aborted" ]]
}

@test "sync --force keeps local change" {
  echo "local" >> x.txt

  run wgx sync --force
  [ "$status" -eq 0 ]
  grep -q "local" x.txt
}

@test "sync --force with remote updates succeeds without warnings" {
  echo "upstream" >> x.txt
  git add x.txt
  git commit -m "upstream" >/dev/null
  git push origin main >/dev/null
  git reset --hard HEAD~1 >/dev/null

  echo "local" >> x.txt

  run wgx sync --force

  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "sync aborted" ]]
  [[ ! "$output" =~ "Fast-Forward nicht möglich" ]]
  [[ ! "$output" =~ "cannot be used with --ff-only" ]]
  grep -q "upstream" x.txt
  grep -q "local" x.txt
}

@test "sync --dry-run shows planned steps" {
  run wgx sync --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "[DRY-RUN]" ]]
}

@test "sync --base accepts explicit branch" {
  run wgx sync --dry-run --base main
  [ "$status" -eq 0 ]
  [[ "$output" =~ "[DRY-RUN]" ]]
}

@test "sync --base supports inline value" {
  run wgx sync --dry-run --base=main
  [ "$status" -eq 0 ]
  [[ "$output" =~ "origin/main" ]]
}

@test "sync --base overrides positional branch" {
  run wgx sync feature --dry-run --base trunk
  [ "$status" -eq 0 ]
  [[ "$output" =~ "origin/trunk" ]]
  [[ "$output" =~ "überschreibt den angegebenen Branch" ]]
}

@test "sync --dry-run accepts --base option" {
  run wgx sync --dry-run --base develop
  [ "$status" -eq 0 ]
  [[ "$output" =~ "git fetch origin develop" ]]
}
```

### 📄 tests/tasks.bats

**Größe:** 1 KB | **md5:** `aa123e5b066f5c7c8aeab55b7119c59e`

```plaintext
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
```

### 📄 tests/test_helper.bash

**Größe:** 1 KB | **md5:** `f9bbd00abaa282db2b5dcdaf609c44d8`

```bash
#!/usr/bin/env bash

# test_helper.bash

# Gemeinsamer Test-Setup-Code für alle Bats-Tests
# Wird über `load test_helper` in den Test-Skripten geladen

# Stellt die gemeinsamen Bats-Hilfsbibliotheken bereit, damit Assertions wie
# `assert_success` in allen Tests verfügbar sind.
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# Fehler frühzeitig sichtbar machen: Bei unerwarteten Fehlern, unset-Variablen
# oder fehlschlagenden Pipes soll der Test abbrechen.
set -euo pipefail

# Fügt das 'cli'-Verzeichnis zum PATH hinzu, damit die 'wgx'-Befehle in den Tests
# direkt aufgerufen werden können. Einige Bats-Versionen liefern einen relativen
# Pfad in BATS_TEST_FILENAME, daher lösen wir zunächst den absoluten Pfad des
# Testverzeichnisses auf.
_wgx_test_file="${BATS_TEST_FILENAME:-$0}"
_wgx_test_dir="$(cd "$(dirname "$_wgx_test_file")" && pwd)"
_wgx_project_root="$(cd "$_wgx_test_dir/.." && pwd)"

PATH="$_wgx_project_root/cli:$PATH"
export PATH

# Setzt das WGX_DIR, damit die Kern-Bibliotheken gefunden werden
WGX_DIR="$_wgx_project_root"
export WGX_DIR

# Unterdrückt Kompatibilitäts-Hinweise in Tests, damit die Ausgaben stabil bleiben
WGX_PROFILE_DEPRECATION="quiet"
export WGX_PROFILE_DEPRECATION
```

### 📄 tests/validate.bats

**Größe:** 650 B | **md5:** `c532941d159296f0b2d1d44da9f4ce32`

```plaintext
#!/usr/bin/env bats

load test_helper

setup() {
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
```

