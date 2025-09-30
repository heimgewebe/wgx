#!/usr/bin/env bash
set -euo pipefail

# Zeigt den Pfad zur Quelldatei eines wgx-Befehls an.

# Hilfetext für den 'which'-Befehl
cmd_which_usage() {
  cat <<USAGE
Usage:
  wgx which <command>

Description:
  Findet die Quelldatei für einen wgx-Befehl und gibt den vollständigen Pfad aus.

Example:
  wgx which status
USAGE
}

# Hauptfunktion für den 'which'-Befehl
cmd_which() {
  if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cmd_which_usage
    return 0
  fi

  if [[ $# -eq 0 ]]; then
    _err "Fehler: Es wurde kein Befehl angegeben."
    cmd_which_usage >&2
    return 1
  fi

  local cmd_name="$1"
  local cmd_path="${WGX_DIR}/cmd/${cmd_name}.bash"

  if [[ -r "$cmd_path" ]]; then
    echo "$cmd_path"
    return 0
  else
    _err "Fehler: Befehl '$cmd_name' nicht gefunden."
    return 1
  fi
}