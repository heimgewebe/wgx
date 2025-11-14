#!/usr/bin/env bash

# Print usage information for `wgx test`.
_test_usage() {
  cat <<'USAGE'
Usage:
  wgx test [--list] [--] [BATS_ARGS...]
  wgx test --help

Runs the Bats test suite located under tests/.

Options:
  --list        Show discovered *.bats files without executing them.
  --help        Display this help text.
  --            Forward all following arguments directly to bats.

Examples:
  wgx test                 # run all Bats suites
  wgx test -- --filter foo # pass custom flags to bats
  wgx test --list          # list available test files
USAGE
}

# Collect all Bats test files in a directory.
_test_collect_files() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    return 1
  fi

  find "$dir" -maxdepth 1 -type f -name '*.bats' -print0 | sort -z
}

test_cmd() {
  local base_dir="${WGX_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"
  local tests_dir="${base_dir}/tests"
  local show_list=0
  local -a bats_args=()

  while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help)
      _test_usage
      return 0
      ;;
    --list)
      show_list=1
      ;;
    --)
      shift
      while [ $# -gt 0 ]; do
        bats_args+=("$1")
        shift
      done
      break
      ;;
    *)
      bats_args+=("$1")
      ;;
    esac
    shift || true
  done

  local -a test_files=()
  local file
  while IFS= read -r -d '' file; do
    test_files+=("$file")
  done < <(_test_collect_files "$tests_dir") || true

  if [ ${#test_files[@]} -eq 0 ]; then
    warn "No Bats tests found under ${tests_dir}."
    return 0
  fi

  if [ "$show_list" -eq 1 ]; then
    local f
    for f in "${test_files[@]}"; do
      printf '%s\n' "${f#"${tests_dir}"/}"
    done
    return 0
  fi

  if ! command -v bats >/dev/null 2>&1; then
    warn "bats (https://github.com/bats-core/bats-core) is not installed. Please install bats-core to run tests."
    return 127
  fi

  info "Starting Bats tests..."
  bats "${bats_args[@]}" "${test_files[@]}"
}

wgx_command_main() {
  test_cmd "$@"
}
