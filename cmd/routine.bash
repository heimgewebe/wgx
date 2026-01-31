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

  if [ -z "${WGX_DIR:-}" ]; then
    # Fallback logic if sourced without WGX_DIR (should be rare)
    WGX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi

  # Helper to load library robustly
  _load_lib() {
    local name="$1"
    if ! declare -F "wgx_routine_${name//-/_}" >/dev/null 2>&1; then
      local libpath="$WGX_DIR/lib/routines_${name//./_}.bash"
      # Try simpler name if structured
      if [[ ! -f "$libpath" ]]; then
        libpath="$WGX_DIR/lib/routines_git.bash" # Fallback/mapping for git.*
      fi

      if [[ -r "$libpath" ]]; then
        # shellcheck source=/dev/null
        source "$libpath"
      else
         echo "Error: Routine library not found for $name" >&2
         return 1
      fi
    fi
  }

  case "$routine_id" in
  git.repair.remote-head)
    _load_lib "git" || return 1
    wgx_routine_git_repair_remote_head "$mode"
    ;;
  *)
    printf 'wgx routine: unknown routine %s\n' "$routine_id" >&2
    return 1
    ;;
  esac
}
