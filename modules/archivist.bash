#!/usr/bin/env bash

# Archivist-Modul: Bereitet Insights auf und sendet sie an Chronik.

# Importiere abhängige Module (angenommen, diese werden vom Aufrufer oder hier geladen)
# Wir verlassen uns darauf, dass `modules/chronik.bash` verfügbar ist.

archivist::archive_insight() {
  local id="$1"
  local role="$2"
  local data_json="$3"

  # Validiere, dass data_json nicht leer ist
  if [[ -z "$data_json" ]]; then
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
      echo "::error::data_json ist leer oder nicht gesetzt" >&2
    fi
    die "data_json ist leer oder nicht gesetzt"
  fi

  # Zeitstempel generieren (ISO 8601)
  local timestamp
  if date --version >/dev/null 2>&1; then
    # GNU date
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  else
    # BSD date (macOS)
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  fi

  # JSON Wrapper bauen
  # Python3 ist erforderlich für sicheres JSON-Composing
  local payload
  if command -v python3 >/dev/null 2>&1; then
    # Export variables to environment for safe passing to Python
    export ARCHIVIST_ID="$id"
    export ARCHIVIST_TIMESTAMP="$timestamp"
    export ARCHIVIST_ROLE="$role"
    payload=$(python3 -c "
import json, sys, os
data_json_str = sys.stdin.read()
data = json.loads(data_json_str)
result = {
  'kind': 'heimgeist.insight',
  'version': 1,
  'id': os.environ['ARCHIVIST_ID'],
  'meta': {
    'occurred_at': os.environ['ARCHIVIST_TIMESTAMP'],
    'role': os.environ['ARCHIVIST_ROLE']
  },
  'data': data
}
print(json.dumps(result))
" <<< "$data_json")
    # Unset exported variables
    unset ARCHIVIST_ID ARCHIVIST_TIMESTAMP ARCHIVIST_ROLE
  else
    # Python3 ist Voraussetzung – keine unsichere Bash-Fallback-Logik
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
      echo "::error::Python3 ist Voraussetzung für JSON-Auswertung; bitte in Install-Step ergänzen." >&2
    fi
    die "python3 required for JSON handling in archivist."
  fi

  # An Chronik senden
  local key="evt-${id}"
  chronik::append "$key" "$payload"
}
