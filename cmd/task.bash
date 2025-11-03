#!/usr/bin/env bash

if [ -z "${WGX_DIR:-}" ]; then
  WGX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

if ! declare -F audit::log >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$WGX_DIR/lib/audit.bash"
fi

if ! declare -F hauski::emit >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$WGX_DIR/lib/hauski.bash"
fi

wgx::_json_escape_fallback() {
  local input="${1:-}" output="" ch
  while IFS= read -r -n1 ch; do
    case "$ch" in
      \\)
        output+=$'\\\\'
        ;;
      '"')
        output+=$'\\"'
        ;;
      $'\n')
        output+=$'\\n'
        ;;
      $'\r')
        output+=$'\\r'
        ;;
      $'\t')
        output+=$'\\t'
        ;;
      *)
        output+="$ch"
        ;;
    esac
  done <<<"$input"
  printf '%s' "$output"
}

cmd_task() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
    cat <<'USAGE'
Usage:
  wgx task <name> [--] [args...]

Description:
  Führt einen Task aus, der in der '.wgx/profile.yml'-Datei des Repositorys
  definiert ist. Alle Argumente nach dem Task-Namen (und einem optionalen '--')
  werden an den Task weitergegeben.

Example:
  wgx task test -- --verbose

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  if ! profile::ensure_loaded; then
    die ".wgx/profile.yml not found."
  fi

  local name="$1"
  shift || true

  if [[ ${1:-} == -- ]]; then
    shift
  fi

  local -a forwarded=()
  if (($#)); then
    forwarded=("$@")
  fi

  local key
  key="$(profile::_normalize_task_name "$name")"
  local spec
  spec="$(profile::_task_spec "$key")"
  if [[ -z $spec ]]; then
    die "Task not defined: $name"
  fi

  local payload_start payload_finish
  if command -v python3 >/dev/null 2>&1; then
    payload_start=$(
      python3 - "$name" "${forwarded[@]}" <<'PY'
import json
import sys

task = sys.argv[1]
args = list(sys.argv[2:])
print(json.dumps({"task": task, "args": args, "phase": "start"}))
PY
    )
  else
    local esc_name
    if type -t json_escape >/dev/null 2>&1; then
      esc_name=$(json_escape "$name")
    else
      esc_name=$(wgx::_json_escape_fallback "$name")
    fi
    payload_start="{\"task\":\"${esc_name}\",\"phase\":\"start\"}"
  fi
  audit::log "task_start" "$payload_start" || true
  hauski::emit "task.start" "$payload_start" || true

  # Run task, capture real exit code, then branch on it.
  # Important: The CLI wrapper enables `set -e` (errexit). If the task fails,
  # a plain invocation would abort the shell before we can capture `$?`.
  # We therefore (temporarily) disable errexit, run the task, grab rc, and
  # restore the original errexit state afterwards.
  local rc had_errexit=0
  if [[ $- == *e* ]]; then
    had_errexit=1
    set +o errexit
  fi
  profile::run_task "$name" "${forwarded[@]}"
  rc=$?
  if ((had_errexit)); then
    set -o errexit
  fi
  if ((rc != 0)); then
    if command -v python3 >/dev/null 2>&1; then
      payload_finish=$(
        python3 - "$name" "$rc" <<'PY'
import json
import sys
print(json.dumps({"task": sys.argv[1], "status": "error", "exit_code": int(sys.argv[2])}))
PY
      )
    else
      local esc
      if type -t json_escape >/dev/null 2>&1; then
        esc=$(json_escape "$name")
      else
        esc=$(wgx::_json_escape_fallback "$name")
      fi
      payload_finish="{\"task\":\"${esc}\",\"status\":\"error\",\"exit_code\":${rc}}"
    fi
    audit::log "task_finish" "$payload_finish" || true
    hauski::emit "task.finish" "$payload_finish" || true
    return $rc
  fi

  if command -v python3 >/dev/null 2>&1; then
    payload_finish=$(
      python3 - "$name" <<'PY'
import json
import sys
print(json.dumps({"task": sys.argv[1], "status": "ok", "exit_code": 0}))
PY
    )
  else
    local esc
    if type -t json_escape >/dev/null 2>&1; then
      esc=$(json_escape "$name")
    else
      esc=$(wgx::_json_escape_fallback "$name")
    fi
    payload_finish="{\"task\":\"${esc}\",\"status\":\"ok\",\"exit_code\":0}"
  fi
  audit::log "task_finish" "$payload_finish" || true
  hauski::emit "task.finish" "$payload_finish" || true
  return 0
}
