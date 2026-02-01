#!/usr/bin/env bash
#
# wgx routine
#
# Executes defined solution routines (predefined repair/optimisation scripts).
# Supports dry-run/preview and apply modes.
#
# Usage:
#   wgx routine <id> [preview|apply|dry-run]
#
# Examples:
#   wgx routine git.repair.remote-head preview
#   wgx routine git.repair.remote-head apply

set -euo pipefail

# shellcheck source=lib/core.bash
source "${WGX_PROJECT_ROOT}/lib/core.bash"
# shellcheck source=lib/routines_git.bash
source "${WGX_PROJECT_ROOT}/lib/routines_git.bash"

wgx_routine_cmd() {
  local routine_id="${1:-}"
  local mode="${2:-preview}"
  local rest_args=("${@:3}")

  if [[ -z "$routine_id" ]]; then
    echo "Usage: wgx routine <id> [preview|apply|dry-run]"
    return 1
  fi

  # Normalize mode aliases
  if [[ "$mode" == "dry-run" ]]; then
    mode="preview"
  fi

  # Validate mode
  if [[ "$mode" != "preview" && "$mode" != "apply" ]]; then
    echo "Error: Invalid mode '$mode'. Must be 'preview' (or 'dry-run') or 'apply'." >&2
    return 1
  fi

  # Require git repo only for apply
  if [[ "$mode" == "apply" ]]; then
    require_repo
  fi

  # Dispatch
  case "$routine_id" in
    git.repair.remote-head)
      wgx_routine_git_repair_remote_head "$mode" "${rest_args[@]}"
      ;;
    *)
      echo "Error: Unknown routine '$routine_id'" >&2
      return 1
      ;;
  esac
}

wgx_routine_cmd "$@"
