#!/usr/bin/env bash
# Doctor module: basic repository health checks

doctor_cmd() {
  if ! command -v git >/dev/null 2>&1; then
    echo "❌ git fehlt." >&2
    return 1
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ nicht im Git-Repo." >&2
    return 1
  fi

  if ! git remote -v | grep -q '^origin'; then
    echo "⚠️ Kein origin-Remote." >&2
  fi

  echo "✅ WGX Doctor OK."
}
