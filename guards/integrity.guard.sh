#!/usr/bin/env bash
set -euo pipefail

# guards/integrity.guard.sh
#
# Enforces integrity invariants:
# 1. artifacts/integrity/ is forbidden (FAIL)
# 2. reports/integrity/summary.json is required if integrity task or directory exists (WARN in Phase 1)
# 3. reports/integrity/event_payload.json must adhere to strict schema (FAIL)

RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Collect warnings instead of exiting early
WARNINGS=()

fail() {
  echo -e "${RED}FAIL: $1${NC}" >&2
  exit 1
}

warn() {
  WARNINGS+=("$1")
}

ok() {
  echo "OK: $1"
  exit 0
}

# A) Hard Path Invariant (FAIL)
if [ -d "artifacts/integrity" ]; then
  # Check if directory is not empty
  if [ -n "$(find artifacts/integrity -mindepth 1 -print -quit)" ]; then
    fail "Integrity artifacts must live under reports/integrity/. artifacts/integrity/ is forbidden."
  fi
fi

# B) Soft Report Duty (WARN)
HAS_INTEGRITY_SIGNAL=0

# Check profile for integrity task
if [ -f ".wgx/profile.yml" ] && grep -qE "^\s*integrity:" ".wgx/profile.yml"; then
  HAS_INTEGRITY_SIGNAL=1
elif [ -f ".wgx/profile.yaml" ] && grep -qE "^\s*integrity:" ".wgx/profile.yaml"; then
  HAS_INTEGRITY_SIGNAL=1
fi

# Check if directory exists
if [ -d "reports/integrity" ]; then
  HAS_INTEGRITY_SIGNAL=1
fi

if [ "$HAS_INTEGRITY_SIGNAL" -eq 1 ]; then
  if [ ! -f "reports/integrity/summary.json" ]; then
    warn "Integrity task detected but no reports/integrity/summary.json produced."
  fi
fi

# C) Event Payload Schema Pre-check (FAIL if exists)
EVENT_FILE="reports/integrity/event_payload.json"
if [ -f "$EVENT_FILE" ]; then
  # Ensure jq is available - strict policy: jq is required
  if ! command -v jq >/dev/null 2>&1; then
    fail "jq is required for event schema validation but was not found."
  fi

  # Validate Top-Level Payload
  # payload (object)
  PAYLOAD_TYPE=$(jq -r 'type' "$EVENT_FILE")
  if [ "$PAYLOAD_TYPE" != "object" ]; then
    fail "Event payload must be an object."
  fi

  # Check payload keys strictly
  # allowed: url, generated_at, repo, status
  UNKNOWN_KEYS=$(jq -r 'keys - ["url", "generated_at", "repo", "status"] | .[]' "$EVENT_FILE")
  if [ -n "$UNKNOWN_KEYS" ]; then
    fail "Event payload contains forbidden keys: $UNKNOWN_KEYS"
  fi

  # Explicit check for forbidden 'counts' (as per instructions)
  if [ "$(jq -r 'has("counts")' "$EVENT_FILE")" == "true" ]; then
    fail "Event payload contains forbidden key: counts"
  fi

  # Check missing mandatory keys
  for key in url generated_at repo status; do
    if [ "$(jq -r "has(\"$key\")" "$EVENT_FILE")" != "true" ]; then
      fail "Event payload missing mandatory key: $key"
    fi
  done

  # Enhanced schema validation: status enum, URL format, generated_at format, repo non-empty
  STATUS=$(jq -r '.status // empty' "$EVENT_FILE")
  if [[ ! "$STATUS" =~ ^(OK|WARN|FAIL|MISSING|UNCLEAR)$ ]]; then
    fail "Event payload.status must be one of: OK, WARN, FAIL, MISSING, UNCLEAR. Found: '$STATUS'"
  fi

  URL=$(jq -r '.url // empty' "$EVENT_FILE")
  if [ -z "$URL" ]; then
    fail "Event payload.url must be a non-empty string."
  fi
  if [[ ! "$URL" =~ ^https?:// ]]; then
    fail "Event payload.url must be a valid HTTP/HTTPS URL. Found: '$URL'"
  fi

  # URL Pattern Check (Soft Invariant)
  # payload.url is expected to point to summary.json (the report)
  if [[ ! "$URL" =~ /summary\.json$ ]]; then
    warn "Event payload.url does not appear to point to a 'summary.json' report. Found: '$URL'"
  fi

  GENERATED_AT=$(jq -r '.generated_at // empty' "$EVENT_FILE")
  if [ -z "$GENERATED_AT" ]; then
    fail "Event payload.generated_at must be a non-empty string."
  fi
  # Basic ISO-8601 format check (simplified)
  if [[ ! "$GENERATED_AT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
    fail "Event payload.generated_at must be in ISO-8601 format (YYYY-MM-DDTHH:MM:SS). Found: '$GENERATED_AT'"
  fi

  REPO=$(jq -r '.repo // empty' "$EVENT_FILE")
  if [ -z "$REPO" ]; then
    fail "Event payload.repo must be a non-empty string."
  fi
fi

# Output warnings at the end if any were collected
if [ ${#WARNINGS[@]} -gt 0 ]; then
  for warning in "${WARNINGS[@]}"; do
    echo -e "${YELLOW}WARN: $warning${NC}" >&2
  done
fi

ok "Integrity checks passed."
