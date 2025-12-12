#!/usr/bin/env bash
set -euo pipefail

SCHEMA_REF="${SCHEMA_REF:-contracts-v1}"
SCHEMA_URL="https://raw.githubusercontent.com/heimgewebe/metarepo/${SCHEMA_REF}/contracts/agent.workflow.schema.json"

ajv_validate() {
  # Prefer local/global ajv if available; otherwise fall back to npx (no global install).
  if command -v ajv >/dev/null 2>&1; then
    ajv validate "$@"
    return
  fi
  if command -v npx >/dev/null 2>&1; then
    npx --yes ajv-cli@5 validate "$@"
    return
  fi
  echo "::error::ajv not found and npx not available. Install Node.js (for npx) or ajv-cli." >&2
  return 127
}

if [[ "$#" -eq 0 ]]; then
  echo "usage: $0 <file>..."
  echo "env SCHEMA_REF=<git-ref>"
  exit 2
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
curl -fsSL "$SCHEMA_URL" -o "$tmp"

fail=0
for f in "$@"; do
  [[ -f "$f" ]] || {
    echo "::warning::skip (not a file): $f"
    continue
  }
  echo "→ validate $f"
  if ! ajv_validate --spec=draft2020 --strict=true --validate-formats=true -s "$tmp" -d "$f"; then
    fail=1
  fi
done

exit "$fail"
