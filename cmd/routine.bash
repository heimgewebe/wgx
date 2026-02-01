#!/usr/bin/env bash

# routine command dispatch
cmd_routine() {
  local routine_id="${1:-}"
  local mode_arg="${2:-preview}" # CLI default: preview
  local rest_args=("${@:3}")

  # Help / No Args
  if [[ -z "$routine_id" || "$routine_id" == "-h" || "$routine_id" == "--help" ]]; then
    cat <<USAGE
Usage:
  wgx routine <id> [preview|apply|dry-run]

Available routines:
  git.repair.remote-head

Ergebnisse werden als eindeutige JSON-Artefakte in .wgx/out/ gespeichert.
USAGE
    return 0
  fi

  # Load Environment / Core
  if [ -z "${WGX_DIR:-}" ]; then
    WGX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi

  # shellcheck source=lib/core.bash
  source "${WGX_DIR}/lib/core.bash"
  # shellcheck source=lib/routines_git.bash
  source "${WGX_DIR}/lib/routines_git.bash"

  # Handle Flags as Mode (if user did `wgx routine <id> --help`)
  if [[ "$mode_arg" == -* ]]; then
    # e.g. --help passed as second arg -> treat as flag for the routine, default mode to preview
    rest_args=("$mode_arg" "${rest_args[@]}")
    mode_arg="preview"
  fi

  local mode_internal=""

  # Normalize CLI Mode -> Internal Mode
  case "$mode_arg" in
  preview | dry-run | "")
    mode_internal="dry-run"
    ;;
  apply)
    mode_internal="apply"
    ;;
  *)
    # Test expectation: Invalid mode must print "Usage:" to stderr and exit 1
    echo "Error: Invalid mode '$mode_arg'" >&2
    cat <<USAGE >&2
Usage:
  wgx routine <id> [preview|apply|dry-run]
USAGE
    return 1
    ;;
  esac

  # Dispatch Routine
  # NOTE: Do NOT call require_repo here. The routine implementation handles the check
  # and writes the necessary JSON artifact for "apply failed".

  case "$routine_id" in
  git.repair.remote-head)
    wgx_routine_git_repair_remote_head "$mode_internal" "${rest_args[@]}"
    ;;
  *)
    # Test expectation: Unknown routine must print "unknown routine" to stderr
    echo "wgx routine: unknown routine '$routine_id'" >&2
    return 1
    ;;
  esac
}

wgx_command_main() {
  cmd_routine "$@"
}
