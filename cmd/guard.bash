#!/usr/bin/env bash

cmd_guard() {
  # Stellt sicher, dass das guard-Modul geladen ist
  if ! declare -F guard_run >/dev/null 2>&1; then
    # WGX_PROJECT_ROOT wird in Tests gesetzt
    local module_path="${WGX_PROJECT_ROOT:-$WGX_DIR}/modules/guard.bash"
    if [[ -r "$module_path" ]]; then
      # shellcheck source=/dev/null
      source "$module_path"
    else
      die "Guard module not found at: $module_path"
    fi
  fi

  # Führt die guard_run Funktion aus und gibt ihren Exit-Code weiter
  guard_run "$@"
  return $?
}
