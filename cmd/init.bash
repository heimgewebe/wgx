#!/usr/bin/env bash

cmd_init() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx init

Description:
  Initialisiert die 'wgx'-Konfiguration im Repository.
  Legt die '.wgx.conf'-Datei und das '.wgx/'-Verzeichnis mit Vorlagen an,
  falls diese noch nicht vorhanden sind.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "FEHLER: Der 'init'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
  # init_cmd "$@"
}

wgx_command_main() {
  cmd_init "$@"
}
