#!/usr/bin/env bash

# Stellt sicher, dass Python und das `yaml`-Modul für die Profil-Verarbeitung verfügbar sind
_check_python_dependency() {
  if ! command -v python3 >/dev/null 2>&1; then
    die "Python 3 is required for parsing .wgx/profile.yml but is not installed. See README section \"Laufzeitabhängigkeiten\" / \"Runtime dependencies\"."
  fi
  if ! python3 -c "import yaml" >/dev/null 2>&1; then
    die "The 'pyyaml' Python package is required for parsing .wgx/profile.yml. See README section \"Laufzeitabhängigkeiten\" / \"Runtime dependencies\" for installation hints."
  fi
}

cmd_run() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx run <task> [args...]

Description:
  Führt einen definierten Task aus der .wgx/profile.yml Konfiguration aus.
  Argumente nach dem Task-Namen werden an den Task weitergegeben.
  Verwendet '--', um Argumente explizit vom Task zu trennen.

Options:
  -h, --help    Diese Hilfe anzeigen.
  --dry-run     Zeigt an, was ausgeführt würde, ohne es zu tun.

Examples:
  wgx run test
  wgx run lint -- --fix
  wgx run --dry-run deploy
USAGE
    return 0
  fi

  _check_python_dependency

  # Prüft, ob ein Profil existiert, bevor der Task ausgeführt wird
  if ! profile::has_manifest; then
    if [[ -n "${1:-}" ]]; then
      die "Task '$1' not found: .wgx/profile.yml does not exist."
    else
      die "Usage: wgx run <task-name> [--] [args...]\nError: .wgx/profile.yml does not exist."
    fi
  fi

  # Lädt das Profil; bricht bei Parser-Fehlern ab
  if ! profile::load; then
    die "Failed to parse .wgx/profile.yml. Please check its syntax."
  fi

  # Führt den Task aus
  profile::run_task "$@"
}
