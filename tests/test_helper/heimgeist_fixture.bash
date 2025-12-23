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
  # Role argument maps to data.origin.role (logical origin)
  # Producer is fixed to wgx.guard (technical component)
  local origin_role="${2:-wgx.guard}"
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
    # Use env vars for safe passing of values to avoid injection
    export HG_EVENT_ID="$event_id"
    export HG_TIMESTAMP="$timestamp"
    export HG_ORIGIN_ROLE="$origin_role"
    export HG_PRODUCER="wgx.guard"

    # We construct 'data' by merging origin info if needed, or ensuring it's in the structure
    # But to avoid deep merging complexity in python one-liner, we will just assume data is the payload
    # and we insert origin into it if we follow the strict separation.
    # However, the user said: "Wenn 'role-Semantik' gebraucht wird: in data.origin.role ablegen".
    # This implies 'data' structure might need to change.
    # For simplicity and safety, let's inject origin into data using python.

    payload=$(python3 -c "import json, sys, os;
data = json.loads(sys.stdin.read());
if 'origin' not in data:
    data['origin'] = {};
data['origin']['role'] = os.environ['HG_ORIGIN_ROLE'];

print(json.dumps({
      'kind': 'heimgeist.insight',
      'version': 1,
      'id': os.environ['HG_EVENT_ID'],
      'meta': {
        'occurred_at': os.environ['HG_TIMESTAMP'],
        'producer': os.environ['HG_PRODUCER']
      },
      'data': data
    }))" <<< "$data_json")
  else
    die "python3 required for JSON handling in heimgeist lib."
  fi

  # An Chronik senden
  heimgeist::append_event "$event_id" "$payload"
}
