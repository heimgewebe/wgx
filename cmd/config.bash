#!/usr/bin/env bash

cmd_config() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx config [show]
  wgx config set <KEY>=<VALUE>

Description:
  Zeigt die aktuelle Konfiguration an oder setzt einen Wert in der
  '.wgx.conf'-Datei.
  Die Implementierung dieses Befehls ist noch in Arbeit.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "FEHLER: Der 'config'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
  # config_cmd "$@"
}

wgx_command_main() {
  cmd_config "$@"
}
