#!/usr/bin/env bash

# Dispatcher for routines
cmd_routine() {
  local routine_id="${1:-}"
  local mode="${2:-dry-run}"
  # shift only if args exist to avoid error
  if [[ $# -ge 2 ]]; then
    shift 2
  elif [[ $# -eq 1 ]]; then
    shift 1
  fi

  if [[ -z "$routine_id" || "$routine_id" == "-h" || "$routine_id" == "--help" ]]; then
    cat <<USAGE
Usage:
  wgx routine <routine_id> [preview|apply]

Available routines:
  git.repair.remote-head

Ergebnisse werden als eindeutige JSON-Artefakte in .wgx/out/ gespeichert.
USAGE
    return 0
  fi

  # normalize mode
  if [[ "$mode" == "preview" ]]; then mode="dry-run"; fi
  if [[ "$mode" != "dry-run" && "$mode" != "apply" ]]; then
    printf 'wgx routine: invalid mode %s (use preview/dry-run or apply)\n' "$mode" >&2
    return 1
  fi

  case "$routine_id" in
  git.repair.remote-head)
    if ! declare -F wgx_routine_git_repair_remote_head >/dev/null 2>&1; then
      local lib_path=""
      if [[ -n "${WGX_DIR:-}" ]]; then
        lib_path="$WGX_DIR/lib/routines_git.bash"
      else
        # Try to find relative to this script
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # Normalize path
        lib_path="$(cd "$script_dir/../lib" && pwd)/routines_git.bash" 2>/dev/null
      fi

      if [[ -n "$lib_path" && -r "$lib_path" ]]; then
        # shellcheck source=/dev/null
        source "$lib_path"
      fi
    fi

    if declare -F wgx_routine_git_repair_remote_head >/dev/null 2>&1; then
      wgx_routine_git_repair_remote_head "$mode" "$@"
    else
      printf 'wgx routine: implementation for %s not loaded.\n' "$routine_id" >&2
      return 1
    fi
    ;;
  *)
    printf 'wgx routine: unknown routine %s\n' "$routine_id" >&2
    return 1
    ;;
  esac
}

wgx_command_main() {
  cmd_routine "$@"
}
