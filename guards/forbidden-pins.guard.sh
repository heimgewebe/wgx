#!/usr/bin/env bash
set -euo pipefail

# Guard: prevent known-bad package specs that reliably break CI.
# Offline-robust by design: pure string match (no registry lookups).

main() {
  local bad="@openai/codex@1.0.0"
  local failed=0

  local paths=(
    ".github/workflows"
    "scripts"
  )

  for p in "${paths[@]}"; do
    [ -e "$p" ] || continue
    # Use grep -rInF for recursive, binary-ignoring, line-numbered, fixed-string search.
    if grep -rInF "$bad" "$p" >/dev/null 2>&1; then
      echo "❌ Forbidden npm spec detected: $bad"
      echo "   Reason: version does not exist on npm → CI will fail (ETARGET/notarget)."
      echo "   Fix: pin to an existing version (e.g. @openai/codex@0.77.0) and keep it deterministic."
      # Show the matches
      grep -rInF "$bad" "$p" || true
      failed=1
    fi
  done

  exit "$failed"
}

main "$@"
