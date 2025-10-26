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

cmd_guard() {
  local -a args=("$@")
  local payload_start payload_finish
  if command -v python3 >/dev/null 2>&1; then
    payload_start=$(python3 - "${args[@]}" <<'PY'
import json
import sys
print(json.dumps({"args": list(sys.argv[1:]), "phase": "start"}))
PY
)
  else
    payload_start="{\"phase\":\"start\"}"
  fi
  audit::log "guard_start" "$payload_start" || true
  hauski::emit "guard.start" "$payload_start" || true

  guard_run "${args[@]}"
  local rc=$?

  if command -v python3 >/dev/null 2>&1; then
    payload_finish=$(python3 - "$rc" <<'PY'
import json
import sys
print(json.dumps({"status": "ok" if int(sys.argv[1]) == 0 else "error", "exit_code": int(sys.argv[1])}))
PY
)
  else
    local status_word
    if ((rc == 0)); then
      status_word="ok"
    else
      status_word="error"
    fi
    printf -v payload_finish '{"status":"%s","exit_code":%d}' "$status_word" "$rc"
  fi
  audit::log "guard_finish" "$payload_finish" || true
  hauski::emit "guard.finish" "$payload_finish" || true
  return $rc
}
