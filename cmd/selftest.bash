#!/usr/bin/env bash

selftest_ok() {
  printf '[OK] %s\n' "$1"
}

selftest_warn() {
  printf '[WARN] %s\n' "$1"
}

selftest_info() {
  printf '[INFO] %s\n' "$1"
}

selftest_check_bins() {
  local label="$1"
  shift || true
  local critical="$1"
  shift || true
  local miss=0 bin
  for bin in "$@"; do
    if command -v "$bin" >/dev/null 2>&1; then
      selftest_ok "$label: $bin found"
    else
      if ((critical)); then
        selftest_warn "$label: $bin missing"
        miss=1
      else
        selftest_warn "$label: $bin missing (optional)"
      fi
    fi
  done
  return "$miss"
}

cmd_selftest() {
  echo "=== wgx selftest ==="

  local had_warn=0
  local entry="${WGX_DIR}/wgx"

  if [[ -x "$entry" ]]; then
    selftest_ok "wgx ausführbar (${entry})"
  else
    selftest_warn "wgx nicht ausführbar (${entry})"
    had_warn=1
  fi

  if "$entry" version >/dev/null 2>&1; then
    selftest_ok "Version abrufbar"
  else
    selftest_warn "Version nicht abrufbar"
    had_warn=1
  fi

  if ! selftest_check_bins "Erforderlich" 1 git jq; then
    had_warn=1
  fi
  selftest_check_bins "Optional" 0 gh glab node pnpm || true

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
    selftest_ok "Git-Repository erkannt (${branch})"
  else
    selftest_info "Hinweis: Selbsttest außerhalb eines Git-Repos – einige Kommandos erfordern eins."
  fi

  if ((had_warn == 0)); then
    selftest_ok "Selftest abgeschlossen."
    return 0
  fi

  selftest_warn "Selftest mit Hinweisen abgeschlossen."
  return 1
}
