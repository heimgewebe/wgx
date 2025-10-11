#!/usr/bin/env bats

setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
  export WGX_DIR="$(pwd)"
  export PATH="$WGX_DIR/cli:$PATH"
  export WGX_CLI_ROOT="$WGX_DIR"
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
