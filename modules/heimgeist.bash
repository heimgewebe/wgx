#!/usr/bin/env bash

# Rolle: Heimgeist-Client (Production)
# Erzeugt und versendet Heimgeist-Events.
# Adaptiert aus tests/test_helper/heimgeist_fixture.bash.

# Lädt Environment (falls nötig)
# In wgx-Kontext erwarten wir, dass Environment-Variablen gesetzt sind oder Defaults greifen.

heimgeist::emit() {
  local kind="$1"
  local data_json="$2"
  local role="${3:-wgx.integrity}"

  # ID generieren (Prefix 'evt-')
  local raw_id
  if [ -r /dev/urandom ]; then
    # 4 Bytes aus /dev/urandom -> 8-stelliger Hex-String
    raw_id="$(od -An -N4 -tx8 < /dev/urandom | tr -d ' \n')"
  else
    # Fallback: timestamp-basiert, aber nur, wenn %N unterstützt wird
    if raw_id="$(date +%s%N 2>/dev/null)" && [[ "$raw_id" =~ ^[0-9]+$ ]]; then
      raw_id="$(printf '%s' "$raw_id" | sha256sum | head -c 8)"
    else
      # Letzter Fallback: Sekundenauflösung
      raw_id="$(date +%s | sha256sum | head -c 8)"
    fi
  fi
  local event_id="evt-${raw_id}"

  # Timestamp (ISO 8601)
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # JSON konstruieren (Safe via Python)
  if ! command -v python3 >/dev/null 2>&1; then
    warn "python3 fehlt. Kann Event nicht erzeugen."
    return 1
  fi

  local payload
  export HG_KIND="$kind"
  export HG_ID="$event_id"
  export HG_TIME="$timestamp"
  export HG_ROLE="$role"

  payload=$(python3 -c "import json, sys, os; print(json.dumps({
    'kind': os.environ['HG_KIND'],
    'version': 1,
    'id': os.environ['HG_ID'],
    'meta': {
      'occurred_at': os.environ['HG_TIME'],
      'role': os.environ['HG_ROLE']
    },
    'data': json.loads(sys.stdin.read())
  }))" <<<"$data_json")

  # Output / Send
  # "Nutze vorhandene Event-Publish-Mechanik (kein Neubau)."
  # Da keine zentrale Sende-Mechanik im Code gefunden wurde, gehen wir davon aus,
  # dass das Event auf STDOUT ausgegeben wird (für Log-Scraper/Plexer) oder in eine Datei.
  # Wir geben es auf STDOUT aus, damit der Aufrufer (z.B. CI) es weiterverarbeiten kann.

  # Wir markieren es als Event, z.B. JSON-Line
  echo "$payload"
}
