#!/usr/bin/env bash

# Alias für 'reload' – siehe README.md
cmd_sync-remote() {
  # Lade reload-Befehl, falls noch nicht geladen
  if ! declare -F cmd_reload >/dev/null 2>&1; then
    local CMD_DIR
    CMD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=/dev/null
    source "${CMD_DIR}/reload.bash"
  fi
  cmd_reload "$@"
}
