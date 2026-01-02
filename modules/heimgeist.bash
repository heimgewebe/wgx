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
  python3 -c "import json, sys, os; print(json.dumps({
    'type': os.environ['HG_TYPE'],
    'source': os.environ['HG_SOURCE'],
    'payload': json.loads(sys.stdin.read())
  }))" <<<"$payload_json"
}
