#!/usr/bin/env bash

hauski::enabled() {
  [[ ${HAUSKI_ENABLE:-0} != 0 ]]
}

hauski::emit() {
  hauski::enabled || return 0
  local event="${1:-}" payload="${2:-{}}"
  if [[ -z "$event" ]]; then
    return 1
  fi
  if ! command -v curl >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    return 0
  fi
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local body
  body=$(
    python3 - "$event" "$payload" "$timestamp" <<'PY'
import json
import sys

event = sys.argv[1]
payload_raw = sys.argv[2]
timestamp = sys.argv[3]
try:
    payload = json.loads(payload_raw)
except Exception:
    payload = {"raw": payload_raw}
print(json.dumps({"event": event, "timestamp": timestamp, "payload": payload}))
PY
  )
  curl -fsS -X POST -H 'Content-Type: application/json' \
    --connect-timeout 1 \
    --max-time 2 \
    --retry 0 \
    --data "$body" \
    http://127.0.0.1:7070/v1/events >/dev/null 2>&1 &&
    printf 'hauski: delivered %s\n' "$event" >&2
}
