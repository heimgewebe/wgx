#!/usr/bin/env bash

# routine command dispatch
cmd_routine() {
  local routine_id="${1:-}"
  local mode="${2:-preview}"
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

  # Normalize Mode
  if [[ "$mode" == "dry-run" ]]; then
    mode="preview"
  fi

  # Handle Flags as Mode (if user did `wgx routine <id> --help`)
  if [[ "$mode" == -* ]]; then
    # e.g. --help passed as second arg -> treat as flag for the routine, default mode to preview
    rest_args=("$mode" "${rest_args[@]}")
    mode="preview"
  fi

  # Validate Mode
  if [[ "$mode" != "preview" && "$mode" != "apply" ]]; then
    # Printing Usage here because tests expect "Usage:" on invalid arguments
    cat <<USAGE >&2
Usage:
  wgx routine <id> [preview|apply|dry-run]
USAGE
    return 1
  fi

  # Require Repo for Apply
  if [[ "$mode" == "apply" ]]; then
    require_repo
  fi

  # Dispatch Routine
  case "$routine_id" in
    git.repair.remote-head)
      wgx_routine_git_repair_remote_head "$mode" "${rest_args[@]}"
      ;;
    *)
      echo "wgx routine: unknown routine '$routine_id'" >&2
      return 1
      ;;
  esac
}

wgx_command_main() {
  cmd_routine "$@"
}
