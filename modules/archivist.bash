archivist::archive_insight() {
  local raw_id="$1"
  local role="$2"
  local data_json="$3"

  # ID Consistency: Ensure ID is prefixed with evt-
  local event_id="evt-${raw_id}"

  # Zeitstempel (UTC, ISO 8601)
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  local payload
  if command -v python3 >/dev/null 2>&1; then
    # Build JSON payload safely (no string interpolation; validate input JSON)
    if ! payload="$(
      ARCHIVIST_ID="$event_id" \
      ARCHIVIST_TIMESTAMP="$timestamp" \
      ARCHIVIST_ROLE="$role" \
      python3 - <<'PY' <<<"$data_json"
import json, os, sys

event_id = os.environ.get("ARCHIVIST_ID")
ts = os.environ.get("ARCHIVIST_TIMESTAMP")
role = os.environ.get("ARCHIVIST_ROLE")

missing = [k for k, v in {
    "ARCHIVIST_ID": event_id,
    "ARCHIVIST_TIMESTAMP": ts,
    "ARCHIVIST_ROLE": role,
}.items() if not v]

if missing:
    print(f"Error: Missing required env vars: {', '.join(missing)}", file=sys.stderr)
    sys.exit(1)

raw = sys.stdin.read()
if not raw or not raw.strip():
    print("Error: Empty input JSON", file=sys.stderr)
    sys.exit(1)

try:
    data = json.loads(raw)
except json.JSONDecodeError as e:
    print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
    sys.exit(1)

result = {
    "kind": "heimgeist.insight",
    "version": 1,
    "id": event_id,
    "meta": {
        "occurred_at": ts,
        "role": role,
    },
    "data": data,
}

print(json.dumps(result, separators=(",", ":")))
PY
    )"; then
      die "Failed to build insight payload (python3 JSON processing error)"
    fi
  else
    die "python3 required for JSON handling in archivist."
  fi

  chronik::append "$event_id" "$payload"
}