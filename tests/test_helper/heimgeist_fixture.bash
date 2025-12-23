#!/usr/bin/env bash

# Heimgeist Client Library
# Provides internal helpers to archive insights via Chronik.
#
# Environment Variables:
#   WGX_CHRONIK_MOCK_FILE  Path to a file to append events to (instead of real backend).
#   WGX_HEIMGEIST_STRICT   If "1", fails if backend is missing. Default: warn only.

# --- Chronik Logic ---

heimgeist::append_event() {
  local key="$1"
  local value="$2"

  if [[ -n "${WGX_CHRONIK_MOCK_FILE:-}" ]]; then
    # Mock-Modus: Anhängen an Datei
    local dir
    dir="$(dirname "$WGX_CHRONIK_MOCK_FILE")"
    if [[ ! -d "$dir" ]]; then
      mkdir -p "$dir"
    fi
    printf '%s=%s\n' "$key" "$value" >>"$WGX_CHRONIK_MOCK_FILE"
    return 0
  fi

  # Real-Modus (Platzhalter)
  # Hier würde der echte Versand an Chronik stehen (z.B. curl)

  if [[ "${WGX_HEIMGEIST_STRICT:-0}" == "1" ]]; then
      die "Chronik backend not configured and WGX_CHRONIK_MOCK_FILE not set (STRICT mode)."
      return 1
  fi

  warn "Chronik backend not configured and WGX_CHRONIK_MOCK_FILE not set (Warn-only)."
  return 0
}

# --- Archivist Logic ---

heimgeist::archive_insight() {
  local raw_id="$1"
  local role="${2:-archivist}"
  local data_json="$3"

  # ID Consistency: Ensure ID is prefixed with evt-
  local event_id="evt-${raw_id}"

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
  local payload
  if command -v python3 >/dev/null 2>&1; then
    payload=$(python3 -c "import json, sys; print(json.dumps({
      'kind': 'heimgeist.insight',
      'version': 1,
      'id': '$event_id',
      'meta': {
        'occurred_at': '$timestamp',
        'role': '$role'
      },
      'data': json.loads(sys.stdin.read())
    }))" <<< "$data_json")
  else
    die "python3 required for JSON handling in heimgeist lib."
  fi

  # An Chronik senden
  heimgeist::append_event "$event_id" "$payload"
}
