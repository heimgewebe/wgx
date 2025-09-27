#!/usr/bin/env bash
# Status-Modul: Projektstatus anzeigen

status_cmd() {
  echo "▶ Repo-Root: $(git rev-parse --show-toplevel 2>/dev/null || echo 'N/A')"
  echo "▶ Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'N/A')"

  # Ahead/Behind
  if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
    local ahead behind
    ahead=$(git rev-list --right-only --count @{u}...HEAD 2>/dev/null || echo 0)
    behind=$(git rev-list --left-only --count @{u}...HEAD 2>/dev/null || echo 0)
    echo "▶ Ahead: $ahead | Behind: $behind"
  fi

  # Erkannte Projektteile
  [[ -d web ]] && echo "▶ Web-Teil vorhanden"
  [[ -d api ]] && echo "▶ API-Teil vorhanden"
  [[ -d crates ]] && echo "▶ Rust crates vorhanden"

  # OFFLINE?
  [[ -n "${OFFLINE:-}" ]] && echo "▶ OFFLINE=1 aktiv"
}
