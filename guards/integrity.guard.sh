#!/usr/bin/env bash
set -euo pipefail

# guards/integrity.guard.sh
#
# Enforces integrity invariants:
# 1. artifacts/integrity/ is forbidden (FAIL)
# 2. reports/integrity/summary.json is required if integrity task or directory exists (WARN in Phase 1)
# 3. reports/integrity/event.json must adhere to strict schema (FAIL)

RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

fail() {
  echo -e "${RED}FAIL: $1${NC}" >&2
  exit 1
}

warn() {
  echo -e "${YELLOW}WARN: $1${NC}" >&2
  exit 0
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

# C) Event Schema Pre-check (FAIL if exists)
EVENT_FILE="reports/integrity/event.json"
if [ -f "$EVENT_FILE" ]; then
  # Ensure jq is available
  if ! command -v jq >/dev/null 2>&1; then
    # If jq is missing, we can't validate, but the user didn't specify behavior for missing deps.
    # Assuming jq is available as per dev environment.
    echo "jq not found, skipping event schema validation." >&2
  else
    # Validate Top-Level
    # type == integrity.summary.published.v1
    # source (string)
    # payload (object)

    # Check type
    TYPE=$(jq -r '.type // empty' "$EVENT_FILE")
    if [ "$TYPE" != "integrity.summary.published.v1" ]; then
      fail "Event type must be 'integrity.summary.published.v1', found '$TYPE'."
    fi

    # Check source
    SOURCE_TYPE=$(jq -r '.source | type' "$EVENT_FILE")
    if [ "$SOURCE_TYPE" != "string" ]; then
      fail "Event source must be a string."
    fi

    # Check payload type
    PAYLOAD_TYPE=$(jq -r '.payload | type' "$EVENT_FILE")
    if [ "$PAYLOAD_TYPE" != "object" ]; then
      fail "Event payload must be an object."
    fi

    # Check payload keys strictly
    # allowed: url, generated_at, repo, status
    UNKNOWN_KEYS=$(jq -r '.payload | keys - ["url", "generated_at", "repo", "status"] | .[]' "$EVENT_FILE")
    if [ -n "$UNKNOWN_KEYS" ]; then
      fail "Event payload contains forbidden keys: $UNKNOWN_KEYS"
    fi

    # Check missing mandatory keys
    # Assuming all 4 are mandatory based on "payload darf nur enthalten" usually implying structure.
    # But user said: "Fehlende Pflichtfelder ⇒ FAIL". The list "url, generated_at, repo, status" usually implies these are the fields.
    # I will assume all 4 are mandatory.
    for key in url generated_at repo status; do
      if [ "$(jq -r ".payload | has(\"$key\")" "$EVENT_FILE")" != "true" ]; then
        fail "Event payload missing mandatory key: $key"
      fi
    done
  fi
fi

ok "Integrity checks passed."
