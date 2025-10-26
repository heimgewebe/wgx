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

cmd_release() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx release [--version <tag>] [--auto-version <bump>] [...]

Description:
  Erstellt SemVer-Tags und GitHub/GitLab-Releases.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.
  Für eine detaillierte Beschreibung der geplanten Funktionalität,
  siehe 'docs/Command-Reference.de.md'.

Options:
  --version <tag>    Die genaue Version für das Release (z.B. v1.2.3).
  --auto-version     Erhöht die Version automatisch (patch, minor, major).
  -h, --help         Diese Hilfe anzeigen.
USAGE
    return 0
  fi

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
  audit::log "release_start" "$payload_start" || true
  hauski::emit "release.start" "$payload_start" || true

  echo "FEHLER: Der 'release'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  local rc=1

  if command -v python3 >/dev/null 2>&1; then
    payload_finish=$(python3 - "$rc" <<'PY'
import json
import sys
print(json.dumps({"status": "error", "exit_code": int(sys.argv[1])}))
PY
)
  else
    payload_finish="{\"status\":\"error\",\"exit_code\":${rc}}"
  fi
  audit::log "release_finish" "$payload_finish" || true
  hauski::emit "release.finish" "$payload_finish" || true
  return $rc
}

wgx_command_main() {
  cmd_release "$@"
}
