#!/usr/bin/env bash

# Rolle: Heimgeist-Client (Production)
# Erzeugt und versendet Heimgeist-Events im Metarepo-konformen Format.
#
# Schema:
# {
#   "type": "integrity.summary.published.v1",
#   "source": "heimgewebe/wgx",
#   "payload": {
#     "url": "...",
#     "generated_at": "...",
#     "repo": "heimgewebe/wgx",
#     "status": "OK"
#   }
# }

heimgeist::emit() {
  local type="$1"
  local source="$2"
  local payload_json="$3"

  # JSON konstruieren (Safe via Python)
  if ! command -v python3 >/dev/null 2>&1; then
    warn "python3 fehlt. Kann Event nicht erzeugen."
    return 1
  fi

  export HG_TYPE="$type"
  export HG_SOURCE="$source"

  # Construct the envelope
  # Note: payload_json is injected directly into 'payload' key
  local envelope
  if ! envelope=$(python3 -c "import json, sys, os; print(json.dumps({
    'type': os.environ['HG_TYPE'],
    'source': os.environ['HG_SOURCE'],
    'payload': json.loads(sys.stdin.read())
  }))" <<<"$payload_json"); then
    warn "Fehler beim Erstellen des Event-Envelopes."
    return 1
  fi

  # Always output to stdout (for piping/logging)
  echo "$envelope"

  # Optional: Real POST emission if PLEXER_URL is set
  if [[ -n "${PLEXER_URL:-}" ]]; then
    if ! command -v curl >/dev/null 2>&1; then
      warn "PLEXER_URL gesetzt, aber curl fehlt. Kann Event nicht senden."
      return 1
    fi

    local response_file
    if ! response_file=$(mktemp); then
      warn "Konnte temporäre Datei für Antwort nicht erstellen."
      return 1
    fi

    # Construct curl arguments
    local -a args=(-s -o "$response_file" -w "%{http_code}" -X POST -H "Content-Type: application/json")

    if [[ -n "${PLEXER_TOKEN:-}" ]]; then
      args+=(-H "Authorization: Bearer ${PLEXER_TOKEN}")
    fi

    # Send request
    local http_code
    # We pass data via stdin to avoid command line length limits or quoting issues
    http_code=$(curl "${args[@]}" "$PLEXER_URL" -d "$envelope")
    local curl_exit=$?

    if [[ "$curl_exit" -ne 0 ]]; then
      warn "Fehler beim Senden an Plexer (curl exit code $curl_exit)."
      rm -f "$response_file"
      return 1
    fi

    # Check HTTP status code (200-299)
    if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
      warn "Fehler beim Senden an Plexer (HTTP $http_code)."
      if [[ -s "$response_file" ]]; then
        warn "Server Response:"
        cat "$response_file" >&2
        echo >&2 ""
      fi
      rm -f "$response_file"
      return 1
    fi

    info "Event erfolgreich an Plexer gesendet."
    rm -f "$response_file"
  fi

  return 0
}
