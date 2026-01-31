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
      # WGX_DIR might not be set if invoked directly, try to deduce?
      # Assuming WGX_DIR is exported by wrapper or caller.
      if [[ -n "${WGX_DIR:-}" ]] && [[ -r "$WGX_DIR/lib/routines_git.bash" ]]; then
        # shellcheck source=/dev/null
        source "$WGX_DIR/lib/routines_git.bash"
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
