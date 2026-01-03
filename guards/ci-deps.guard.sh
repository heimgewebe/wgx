#!/usr/bin/env bash
set -euo pipefail

# Guard: prevent known-bad package specs and interactive usage in CI.
# Offline-robust by design: pure string match (no registry lookups).

main() {
  local bad_version="@openai/codex@1.0.0"
  local failed=0

  local paths=(
    ".github/workflows"
    "scripts"
  )

  for p in "${paths[@]}"; do
    [ -e "$p" ] || continue

    # Check 1: Forbidden version (existing)
    if grep -rInF "$bad_version" "$p" >/dev/null 2>&1; then
      echo "❌ Forbidden npm spec detected: $bad_version"
      echo "   Reason: version does not exist on npm → CI will fail (ETARGET/notarget)."
      echo "   Fix: pin to an existing version (e.g. @openai/codex@0.77.0) and keep it deterministic."
      grep -rInF "$bad_version" "$p" || true
      failed=1
    fi

    # Check 2: Interactive usage (heuristic)
    # Search for "npx ... @openai/codex@ ... <" AND NOT "exec"
    # grep output format: file:line:content
    local matches
    matches=$(grep -rInE "npx .*@openai/codex@.* <" "$p" | grep -v "exec" || true)
    if [ -n "$matches" ]; then
       echo "❌ Interactive Codex usage detected in CI (potential hang):"
       echo "   Reason: 'npx ... <' starts interactive mode unless 'exec' is used."
       echo "   Fix: Use 'npx ... exec < ...' or ensure non-interactive mode."
       echo "$matches"
       failed=1
    fi
  done

  exit "$failed"
}

main "$@"
