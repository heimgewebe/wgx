#!/usr/bin/env bash

# Stellt sicher, dass Python 3 verfügbar ist; PyYAML ist optional und wird nur im Debug-Modus geprüft
_check_python_runtime() {
  if ! command -v python3 >/dev/null 2>&1; then
    die "Python 3 is required for parsing .wgx/profile.yml but is not installed. See README section \"Laufzeitabhängigkeiten\" / \"Runtime dependencies\"."
  fi
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    if ! python3 -c "import yaml" >/dev/null 2>&1; then
      echo "WGX: PyYAML not available; falling back to built-in YAML parser." >&2
    fi
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
  -n, --dry-run Zeigt an, was ausgeführt würde, ohne es zu tun.

Note:
  Unbekannte Optionen werden von wgx run abgelehnt.

Examples:
  wgx run test
  wgx run lint -- --fix
  wgx run --dry-run deploy
USAGE
    return 0
  fi

  local dryrun=0
  while (($#)); do
    case "$1" in
    -n | --dry-run)
      dryrun=1
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      break
      ;;
    esac
  done

  _check_python_runtime

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
  if ((dryrun)); then
    DRYRUN=1 profile::run_task "$@"
  else
    profile::run_task "$@"
  fi
}
