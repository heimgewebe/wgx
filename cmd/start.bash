#!/usr/bin/env bash

cmd_start() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx start <branch_name>

Description:
  Erstellt einen neuen Feature-Branch nach einem validierten Schema.
  Der Name wird normalisiert (Sonderzeichen entfernt, etc.) und optional
  mit einer Issue-Nummer versehen.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "FEHLER: Der 'start'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
  # start_cmd "$@"
}

wgx_command_main() {
  cmd_start "$@"
}
